import datetime
import pathlib
import yaml

import pandas as pd
import pyarrow as pa

from dagster import (
    AssetExecutionContext,
    get_dagster_logger,
    MaterializeResult,
)

from ..resources.azure_parquet_writer import ParquetClient
from ..resources.iceberg_writer import IcebergClient


from ..resources.utils import run_query


logger = get_dagster_logger()


def handle_null_columns(df: pd.DataFrame) -> pd.DataFrame:
    """Handle columns that are fully null by converting them to string type.

    This helps PyArrow properly infer dtypes when converting from pandas DataFrame
    to PyArrow Table, avoiding issues with fully null columns.

    Parameters
    ----------
    df : pd.DataFrame
        Input DataFrame with potential fully null columns

    Returns
    -------
    pd.DataFrame
        DataFrame with fully null columns converted to string type
    """
    df = df.copy()

    for col in df.columns:
        if df[col].isna().all():
            df[col] = df[col].astype(str)

    return df


def read_schema_data(schema_path: pathlib.Path) -> MaterializeResult:
    """Read schema data for table processing"""
    with open(schema_path, "r") as f:
        return yaml.safe_load(f)


def _create_table_identifier(schema_name: str, table_name: str) -> str:
    """Create standardized table identifier"""
    return f"{schema_name.lower()}.{table_name.lower()}"


def _write_table_to_storage(
    write_client: ParquetClient | IcebergClient,
    table: pa.Table,
    schema_name: str,
    table_name: str,
    date_col: str,
    partition_value: str,
    transform_type=None,
    overwrite_strategy: str = None,
    dagster_context=None,
    **kwargs,
) -> dict:
    """Write table to storage (parquet or iceberg) and return results metadata"""
    # Determine if this is Iceberg based on client type
    is_iceberg = isinstance(write_client, IcebergClient)

    if is_iceberg and overwrite_strategy:
        # Use new Iceberg overwrite strategy approach
        logger.info(
            f"Writing {len(table)} rows to Iceberg with strategy '{overwrite_strategy}'"
        )
        return write_client.write_table(
            table_name=table_name,
            schema_name=schema_name.lower(),
            pa_table=table,
            partition_col=date_col,
            mode="overwrite",
            transform_type=transform_type,
            overwrite_strategy=overwrite_strategy,
            query_col=date_col,
            dagster_context=dagster_context,
        )
    else:
        # Legacy approach for parquet - uses table_identifier for backward compatibility
        table_identifier = _create_table_identifier(schema_name, table_name)
        return write_client.write_table(
            table_name=table_identifier,
            pa_table=table,
            schema_name=schema_name.lower(),
            partition_col=date_col,
            partition_value=partition_value,
            transform_type=transform_type,
            mode="overwrite",  # Overwrite partition data on re-runs
        )


def _build_result_metadata(results: dict, current_date: str, query_date: str) -> dict:
    """Build final result metadata for MaterializeResult, handler to insert results concisely"""
    results["retrieved_date"] = current_date
    results["query_date"] = query_date
    return results


def handle_query_results(
    date_col: str,
    table: pa.Table,
    query_date: str,
    current_date: str,
    schema_name: str,
    table_name: str,
    write_client: ParquetClient | IcebergClient,
    transform_type=None,
    overwrite_strategy: str = None,
    dagster_context=None,
) -> MaterializeResult:
    """Process results from query and write the table to parquet

    Parameters
    ----------
    date_col : str
        Column to use for date query where date == some day
    table : pa.Table
        Input table from query result
    query_date : str
        Date used for the query (or time-based partition value)
    current_date : str
        Date that the retrieval query was run
    schema_name : str
        Source schema name
    table_name : str
        Source table name
    parquet_client : ParquetClient
        Parquet client for writing to storage, from ParquetResource.get_client()

    Returns
    -------
    MaterializeResult
        Dagster MaterializeResult with metadata about the operation
    """
    # Write table to storage
    # if iceberg, write with transform type and overwrite strategy
    results = _write_table_to_storage(
        write_client=write_client,
        table=table,
        schema_name=schema_name,
        table_name=table_name,
        date_col=date_col,
        partition_value=query_date,
        transform_type=transform_type,
        overwrite_strategy=overwrite_strategy,
        dagster_context=dagster_context,
    )
    # Build final metadata
    final_metadata = _build_result_metadata(results, current_date, query_date)

    return MaterializeResult(metadata=final_metadata)


def process_oracle_table(
    context: AssetExecutionContext,
    db_resource_key: str,
    storage_resource_key: str,
    table_name: str,
    schema_name: str,
    schema_path: str | pathlib.Path,
    transform_type=None,
    query_in_utc: bool = False,
):
    """General-purpose function to process query from Oracle tables.

    Fetches data in chunks and writes each chunk to storage incrementally.
    The first chunk overwrites existing partition data (deleting prior data for
    that partition); subsequent chunks append to the freshly written partition.

    Parameters
    ----------
    context : AssetExecutionContext
        Dagster asset execution context
    db_resource_key : str
        The resource key, as defined in required resources and definitions used to query the db
    storage_resource_key : str
        The resource key, as defined in required resources and definitions used for azure processing
    table_name : str
        The name of the source table
    schema_name : str
        The schema of the source table
    schema_path : str | pathlib.Path
        The name of the schema file, expected to be stored in the pipeline `schemas` folder
    transform_type : str, optional
        Transform type for iceberg partition, one of ['identity', 'hour', 'day', 'month']
        If None, will be read from schema YAML file
    query_in_utc : bool, optional
        If True, converts partition time window from America/New_York to UTC before
        building the Oracle query. Use when the source table stores timestamps in UTC.
        Default is False.

    """
    # Get clients and configuration
    oracle_client = getattr(context.resources, db_resource_key).get_client()
    write_client = getattr(context.resources, storage_resource_key).get_client()
    is_iceberg = isinstance(write_client, IcebergClient)

    # Load schema and setup
    schema_path = pathlib.Path(schema_path)
    schema_data = read_schema_data(schema_path)
    current_date = str(datetime.datetime.now().date())
    date_col = schema_data.get("date_col")

    # Read Iceberg configuration from schema YAML
    overwrite_strategy = schema_data.get("overwrite_strategy")
    if not transform_type:
        transform_type = schema_data.get("transform_type")

    # Build query kwargs based on partition type
    if hasattr(context, "partition_time_window") and context.partition_time_window:
        # Time-based partitions (e.g., 10-minute windows)
        start_dt = context.partition_time_window.start
        end_dt = context.partition_time_window.end
        query_time_fmt = "%Y-%m-%d %H:%M:%S"
        time_partition_value = start_dt.strftime("%Y-%m-%d_%H-%M-%S")

        if query_in_utc:
            import pytz

            start_dt = start_dt.astimezone(pytz.utc)
            end_dt = end_dt.astimezone(pytz.utc)

        query_kwargs = dict(
            start_time=datetime.datetime.strftime(start_dt, query_time_fmt),
            end_time=datetime.datetime.strftime(end_dt, query_time_fmt),
            is_time_query=True,
        )
    else:
        # Daily partitions
        query_kwargs = dict(query_date=getattr(context, "partition_key"))
        time_partition_value = None

    # Iterate over chunks from Oracle
    total_record_count = 0
    last_result = None
    query_date_resolved = None

    for chunk_info in run_query(
        oracle_client=oracle_client,
        schema_data=schema_data,
        table_name=table_name,
        **query_kwargs,
    ):
        query_date_resolved = chunk_info["query_date"]
        batch = chunk_info["batch"]
        batch_index = chunk_info["batch_index"]
        batch_rows = len(batch)
        total_record_count += batch_rows
        partition_query_value = time_partition_value or query_date_resolved

        logger.info(
            f"Processing chunk {batch_index} ({batch_rows} rows, "
            f"cumulative: {total_record_count}) for {schema_name}.{table_name}"
        )

        if batch_index == 0:
            # First chunk: overwrites existing partition data;
            # subsequent chunks append.
            # This also handles table creation if the Iceberg table
            # doesn't exist yet.
            last_result = handle_query_results(
                date_col=date_col,
                table=batch,
                query_date=partition_query_value,
                current_date=current_date,
                schema_name=schema_name,
                table_name=table_name,
                write_client=write_client,
                transform_type=transform_type,
                overwrite_strategy=overwrite_strategy,
                dagster_context=context,
            )
        elif is_iceberg:
            # Subsequent chunks: old partition data already cleared by chunk 0's
            # overwrite, so these are pure appends of new data.
            if write_client.force_clean_schema:
                cleaned = write_client.clean_column_schema(batch)
            else:
                cleaned = write_client.handle_oracle_data_types(batch)

            write_client.append_chunk(
                table_name=table_name,
                schema_name=schema_name,
                pa_chunk=cleaned,
            )
            del cleaned
        else:
            # Legacy ParquetClient: small datasets only produce one chunk
            logger.warning(
                f"ParquetClient received multiple chunks for {table_name}; "
                "only the first chunk was written."
            )

        del batch

    # Handle case where no chunks were yielded (no data)
    if total_record_count == 0:
        resolved = query_date_resolved or query_kwargs.get("query_date", "YYYY-MM-DD")
        logger.info(
            f"No data returned for {schema_name}.{table_name} (query_date: {resolved})"
        )
        return MaterializeResult(
            metadata={
                "retrieved_date": current_date,
                "query_date": resolved,
                "col_for_query": date_col,
                "record_count": 0,
                "status": "no_data",
            }
        )

    # Update metadata with total record count across all chunks
    if last_result is not None:
        final_metadata = dict(last_result.metadata)
        final_metadata["record_count"] = total_record_count
        return MaterializeResult(metadata=final_metadata)

    return last_result
