from __future__ import annotations

import datetime
import os
from io import BytesIO

from typing import Dict


from azure.keyvault.secrets import SecretClient
from dagster import get_dagster_logger
from ..env import azure_credential, ROW_LIMIT

import pyarrow.parquet as pq
import pyarrow as pa


logger = get_dagster_logger()


def get_date_start_sliding(earliest_date: str, offset_time_minutes: int = None) -> str:
    """Gets a dynamic start date to use as earliest query date for development.
    Calculates by offsetting using current date, and moving earliest date in data.
    Current earliest_date is provided by data class from checking table.


    Parameters
    ----------
    earliest_date : str
        Earliest date in dataset for offset
    offset_time_minutes: int
        Optional number of minutes to offset time from current time to query, defaults to None

    Returns
    -------
    str
        Adjusted date to use in query WHERE clause
    """
    # NOTE: This is solely for qa environment, need to remove and/or configure only for specific environment
    START_DATE_WINDOW = datetime.datetime(2025, 6, 12).date()
    # Calculate an offset based on a starting date from analysis (june 12th 2025)
    # Get number of days since then, and offset the data we extract to simulate incremental load

    # If the caller provides a number of minutes to offset, we set time as a floor to simulate time window slicing
    date_offset: int = (datetime.datetime.now().date() - START_DATE_WINDOW).days
    min_date = datetime.datetime.strptime(earliest_date, "%Y-%m-%d").date()
    min_date_offset_dt = min_date + datetime.timedelta(days=date_offset)

    if offset_time_minutes is None:
        dt_format = "%Y-%m-%d"
        dt_str_query = min_date_offset_dt.strftime(format=dt_format)
    else:
        dt_format = "%Y-%m-%d %H:%M:%S"
        time_offset = datetime.datetime.now() - datetime.timedelta(
            minutes=offset_time_minutes
        )
        dt_str_query = datetime.datetime(
            year=min_date_offset_dt.year,
            month=min_date_offset_dt.month,
            day=min_date_offset_dt.day,
            hour=time_offset.hour,
            minute=time_offset.minute,
            second=time_offset.second,
        )
    # format date as yymmdd to reflect Oracle db format
    logger.info(f"Using {dt_str_query} as date offset for development")
    return dt_str_query


def generate_redaction_sql_from_schema(
    schema_data: Dict, table_name: str, where_clause: str = None
) -> str:
    """Generates redaction SQL query from read-in YAML schema data

    Parameters
    ----------
    schema_data : Dict
        Read-in schema data from YAML file.
    table_name : str
        Table name to query from
    where_clause : str
        Clause to use in WHERE query. Do not include the `WHERE`.

    Returns
    -------
    str
        Generated SQL with hashing for columns specified in schema.

    Raises
    ------
    ValueError
        ValueError if date_col not in database cols
    ValueError
        ValueError if redacted_col is included in columns_to_query
    """
    # Just reading everything into variables for brevity
    schema = schema_data.get("schema")
    redacted_columns = schema_data.get("redacted_cols", [])
    date_column = schema_data.get("date_col")
    query_cols = schema_data.get("query_cols", [])

    query_cols = [x.upper() for x in query_cols]

    # Normalize column names and validate that date and exclude column is mapped appropriately
    if isinstance(redacted_columns, str):
        redacted_columns = list(redacted_columns)

    if redacted_columns:
        exclude_columns_upper = [col.upper() for col in redacted_columns]
    else:
        exclude_columns_upper = []

    date_column_upper = date_column.upper()

    if date_column_upper not in query_cols:
        raise ValueError(
            f"Date column '{schema_data.get('date_column')}' not found in table '{table_name}'"
        )
    # Check if column to be redacted is in query cols
    included_redacted_col = [col for col in exclude_columns_upper if col in query_cols]
    if included_redacted_col:
        raise ValueError(
            f"Excluded columns were found within the query columns -- fix in the asset:  {table_name} has {included_redacted_col}"
        )

    # Build query, we insert columns but only hash the required columns
    # Outputs as
    # SELECT col_A, col_B,
    # STANDARD_HASH(redacted_col || to_char(date_col)) as redacted_col
    # FROM schema.table
    # WHERE etc
    merged_cols = query_cols + exclude_columns_upper

    # Insert query part as redacted if it needs to be cluded, else just insert the column

    query_parts = [
        f"CAST(STANDARD_HASH({column} || TO_CHAR({date_column_upper}, 'YYYY-MM-DD'), 'SHA1') AS VARCHAR(64)) AS {column}"
        if column in exclude_columns_upper
        else column
        for column in merged_cols
    ]

    query = (
        f"SELECT {(',' + os.linesep).join(query_parts)} \n FROM {schema}.{table_name}"
    )
    if where_clause:
        query += f"\nWHERE {where_clause}"

    return query


def get_secret_client(keyvault_name: str | None) -> SecretClient | None:
    """Get secret client given an Azure storage account and Azure credential from an `az login` auth method
    Args:
        keyvault_name (str | None): Name of the Azure Key Vault
    Returns:
        SecretClient | None: Secret client object or None if error
    """
    if keyvault_name is None:
        logger.warning("Keyvault name is None, cannot create secret client")
        return None

    # azure keyvault names have a maximum length restriction
    KEYVAULT_MAX_LENGTH = 24
    if len(keyvault_name) > KEYVAULT_MAX_LENGTH:
        logger.warning("Keyvault resource name too long, exiting request")
        return None

    vault_url = f"https://{keyvault_name}.vault.azure.net"

    try:
        client = SecretClient(
            vault_url=vault_url, credential=azure_credential.get_credential()
        )
        return client
    except Exception as e:
        logger.error(f"Error retrieving Azure secret client: {e}")
        return None


def set_vault_secret(
    secret_client: SecretClient, secret_name: str, secret_content: str
) -> bool:
    """Sets secret using authenticated Azure secret client
    Args:
        secret_client (SecretClient): Authenticated Azure secret client
        secret_name (str): Name of the secret to set
        secret_content (str): Content of the secret to set
    Returns:
        bool: True if successful, False if error
    """
    try:
        secret_client.set_secret(secret_name, secret_content)
        return True
    except Exception as e:
        logger.error(f"Unable to set secret, check secret client settings: {e}")
        return False


def get_vault_secret(secret_client: SecretClient, secret_name: str) -> str:
    """Retrieves secret using authenticated Azure secret client
    Args:
        secret_client (SecretClient): Authenticated Azure secret client
        secret_name (str): Name of the secret to retrieve
    Returns:
        str: Secret value as string
    """

    retrieved_secret = secret_client.get_secret(secret_name)
    return str(retrieved_secret.value)


def _resolve_query_date(query_date: str, start_time: str) -> str:
    """Resolve the query date from parameters - handler to facilitate daily partitio and time-based"""
    if query_date is None and start_time:
        return start_time.split(" ")[0]
    return query_date


def _build_where_clause(
    date_col: str,
    query_date: str,
    start_time: str = None,
    end_time: str = None,
    is_time_query: bool = False,
) -> str:
    """Build WHERE clause for Oracle query"""
    row_limit_clause = f"AND\n        ROWNUM <= {ROW_LIMIT}" if ROW_LIMIT else ""

    if is_time_query and (start_time is not None and end_time is not None):
        return f"""
        {date_col} >= TO_DATE('{start_time}', 'YYYY-MM-DD HH24:MI:SS')
        AND
        {date_col} < TO_DATE('{end_time}', 'YYYY-MM-DD HH24:MI:SS')
        {row_limit_clause}
        """
    else:
        return f"""
        {date_col} >= TO_DATE('{query_date} 00:00:00', 'YYYY-MM-DD HH24:MI:SS')
        AND
        {date_col} < TO_DATE('{query_date} 00:00:00', 'YYYY-MM-DD HH24:MI:SS') + INTERVAL '1' DAY
        {row_limit_clause}
        """


def run_query(
    oracle_client,
    schema_data: dict,
    table_name: str,
    query_date: str = None,
    start_time: str = None,
    end_time: str = None,
    is_time_query=False,
):
    """Run query using oracle resource, yielding results in chunks.

    Parameters
    ----------
    oracle_client :
        Oracle client from oracle_rescource.get_client()
    schema_data : dict
        Database table's schema data loaded from YAML file
    table_name : str
        name of table for query
    query_date : str, optional
        query date as str formatted as "%Y-%m-%d" from dagster partition
    start_time : str, optional
        query start_time str formatted as "%Y-%m-%d %H:%M:%S" from dagster partition
    end_time : str, optional
        query end_time str formatted as "%Y-%m-%d %H:%M:%S" from dagster partition
    is_time_query : bool, optional
        boolean flag for whether to query by time or just == date, by default False

    Yields
    ------
    dict
        {"query_date": str, "batch": pa.Table, "batch_index": int}
    """
    date_col = schema_data.get("date_col")

    # Resolve query date
    resolved_query_date = _resolve_query_date(query_date, start_time)
    logger.info(f"Executing query for date {resolved_query_date} for {table_name}")

    # Build WHERE clause
    where_clause = _build_where_clause(
        date_col, resolved_query_date, start_time, end_time, is_time_query
    )

    # Generate and execute query
    query = generate_redaction_sql_from_schema(
        schema_data, table_name, where_clause=where_clause
    )
    logger.info(f"Generated query: {query}")

    batch_index = 0
    try:
        for batch_table in oracle_client.execute_query(query):
            record_count = len(batch_table)
            logger.info(
                f"Chunk {batch_index}: retrieved {record_count} records for {table_name}"
            )
            yield {
                "query_date": resolved_query_date,
                "batch": batch_table,
                "batch_index": batch_index,
            }
            batch_index += 1
    except Exception as e:
        logger.error(f"Error executing Oracle query for {table_name}: {str(e)}")
        logger.error(f"Failed query was: {query}")
        raise

    if batch_index == 0:
        logger.info(f"No records retrieved for {table_name}")


def upload_table(
    azure_client,
    table: pa.Table,
    record_count: int,
    schema_name: str,
    table_name: str,
    query_date: str,
    current_date: str,
    start_time: str = None,
):
    # return metadata even when no data is found for tracking and debugging
    if not table or table is None:
        logger.info(f"No {table_name} data found for date {query_date}")
        return {
            "status": "no_data",
            "query_date": query_date,
            "retrieved_date": current_date,
            "record_count": 0,
        }

    if record_count < 1:
        raise Exception("No rows retrieved from query, exiting asset materialization.")
    logger.info(f"Retrieved {record_count} bus info records for date {query_date}")

    # convert to parquet format
    buffer = BytesIO()
    pq.write_table(table, buffer)
    buffer.seek(0)
    parquet_data = buffer.getvalue()
    if not start_time:
        file_name = f"{schema_name}/{table_name}/{table_name}_{query_date}.parquet"
    else:
        file_name = (
            f"{schema_name}/{table_name}/{table_name}_{query_date}_{start_time}.parquet"
        )

    metadata = {
        "filename": file_name,
        "retrieved_date": current_date,
        "record_count": str(record_count),
        "source": table_name,
        "content_type": "parquet",
        "query_date": query_date,
    }

    azure_client.upload_blob(file_name, parquet_data, metadata=metadata)
    logger.info(f"Uploaded {file_name} to Azure blob storage")

    # metadata appears in the dagster UI and logs
    return metadata


def _execute_oracle_query(oracle_client, query: str, table_name: str):
    """Execute an Oracle query and return the full result as a single PyArrow table.

    Returns
    -------
    tuple[pa.Table, int]
        (table, record_count)
    """
    batches = list(oracle_client.execute_query(query))
    if not batches:
        logger.info(f"No records retrieved for {table_name}")
        return pa.table({}), 0

    table = pa.concat_tables(batches)
    return table, len(table)


def unpack_dagster_asset_metadata(metadata, key: str):
    """Dagster materialization results are stored like a dictionary where all results are wrapped
    and accessed using the .value accessor
    """
    try:
        metadata_key = metadata.get(key)
        value = metadata_key.value
        return value
    except Exception as e:
        logger.info(f"Error unpacking metadata for key {key}: {e}")
        return None