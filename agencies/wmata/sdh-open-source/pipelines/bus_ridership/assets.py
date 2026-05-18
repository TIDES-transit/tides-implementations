import datetime
from datetime import timedelta
import pathlib

from dagster import (
    asset,
    asset_check,
    AssetExecutionContext,
    AssetCheckExecutionContext,
    BackfillPolicy,
    DailyPartitionsDefinition,
    get_dagster_logger,
)
from ..resources.utils import _execute_oracle_query
from ..resources.iceberg_writer import IcebergClient
from ..resources.oracle_db import OracleClient

from ..common.assets import process_oracle_table, read_schema_data
from ..common.asset_checks import check_daily_partition_populated

ORA_DATE_FMT = "YYYY-MM-DD"
ORA_DATETIME_FMT = "YYYY-MM-DD HH24:MI:SS"

logger = get_dagster_logger()

schemas_parent = pathlib.Path(__file__).parent / "schemas"

rs_daily_partitions = DailyPartitionsDefinition(
    start_date=datetime.datetime(year=2026, month=1, day=1),
)

# Shift start date of the calendar to handle late arrival records no matter how far back they go
calendar_daily_partitions = DailyPartitionsDefinition(
    start_date=datetime.datetime(year=2024, month=1, day=1),
    end_offset=1,
)

schemas_parent = pathlib.Path(__file__).parent / "schemas"


@asset(
    required_resource_keys={
        "bus_ridership_db",
        "bus_ridership_storage",
    },
    backfill_policy=BackfillPolicy.single_run(),
    partitions_def=rs_daily_partitions,
    name="bus_ridership_fare_data",
    group_name="oracle_tables",
    kinds=["azure", "oracle"],
)
def bus_ridership_fare_data(context: AssetExecutionContext) -> None:
    """Represents a local iceberg copy of the FARE f_bus_rr_totals table (stored on the rs schema), partitioned by service_date

    Parameters
    ----------
    context : AssetExecutionContext
        Dagster asset context

    Returns
    -------
    """
    process_ridership_table(
        context=context,
        schema_name="rs",
        table_name="f_bus_rr_totals",
        schema_path=schemas_parent / "bus_ridership_fare.yaml",
    )


@asset(
    required_resource_keys={
        "bus_ridership_db",
        "bus_ridership_storage",
    },
    backfill_policy=BackfillPolicy.single_run(),
    partitions_def=rs_daily_partitions,
    name="bus_ridership_lp_data",
    group_name="oracle_tables",
    kinds=["azure", "oracle"],
)
def bus_ridership_lp_data(context: AssetExecutionContext) -> None:
    """Represents a local iceberg copy of the vendor_2 f_bus_rr_totals table, partitioned by service_date

    Parameters
    ----------
    context : AssetExecutionContext
        Dagster asset context

    Returns
    -------
    """
    process_ridership_table(
        context=context,
        schema_name="vendor_2",
        table_name="f_bus_rr_totals",
        schema_path=schemas_parent / "bus_ridership_lp.yaml",
    )


def context_to_date_keys(
    context: AssetExecutionContext, client: OracleClient
) -> tuple[str, str]:
    """Quick lookup function to convert a context into a range of date keys for use with ridership queries

    Parameters
    ----------
    context : AssetExecutionContext
        Dagster asset context
    client : OracleClient
        Oracle client used to query the calendar table

    Returns
    -------
    """
    cal_schema_name = "bus_calendar_db"
    cal_table_name = "d_date_bus_v"

    # Because Oracle BETWEEN are inclusive on both ends, chop a day off the end of the range
    start_date_str = str(context.partition_time_window.start.date())
    end_date_str = str(context.partition_time_window.end.date() - timedelta(days=1))

    logger.info(f"Getting keys for date range {start_date_str} to {end_date_str}")

    cal_query = f"""SELECT date_key FROM {cal_schema_name}.{cal_table_name} WHERE dateday = TO_DATE('{start_date_str}','{ORA_DATE_FMT}')"""
    start_date_key = client.execute_query_raw(cal_query).fetchone()[0]

    cal_query = f"""SELECT date_key FROM {cal_schema_name}.{cal_table_name} WHERE dateday = TO_DATE('{end_date_str}','{ORA_DATE_FMT}')"""
    end_date_key = client.execute_query_raw(cal_query).fetchone()[0]

    return start_date_key, end_date_key


def process_ridership_table(
    context: AssetExecutionContext, schema_name: str, table_name: str, schema_path: str
):
    """Processes ridership tables into their iceberg counterparts in a multi-stage process
        1. Grab the date key for the partition key from the calendar table
        2. Grab the data by date key for the partition requested from the oracle source ridership table
        3. Convert the data to iceberg types using SDH built-in function
        4. If table exists, overwrite the existing partition (if found) with the new one; otherwise, create the table and append the partition

    This asset also contains a simple translation from date_key to actual dates, forming the appended service_date column in the output iceberg table.
    The table is then partitioned by this service_date to bolster downstream views.

    Parameters
    ----------
    context : AssetExecutionContext
        Dagster asset context
    schema_name : str
        Name of the schema containing the ridership source table
    table_name : str
        Name of the table containing the ridership data

    Returns
    -------
    """
    # grab clients
    oracle_client: OracleClient = getattr(
        context.resources, "bus_ridership_db"
    ).get_client()
    write_client: IcebergClient = getattr(
        context.resources, "bus_ridership_storage"
    ).get_client()

    cal_schema_name = "bus_calendar_db"
    cal_table_name = "d_date_bus_v"

    ib_catalog = write_client.catalog
    ib_table_id = f"{schema_name}.{table_name}"
    ib_table_exists = ib_catalog.table_exists(f"{schema_name}.{table_name}")

    # get date key associated with partition key from calendar
    start_key, end_key = context_to_date_keys(context, oracle_client)

    logger.info(f"Selected key range for partition range is {start_key} to {end_key}")

    # load table column names from schema file
    schema_path = pathlib.Path(schema_path)
    schema_data = read_schema_data(schema_path)
    cols = ",".join(schema_data.get("query_cols", []))

    # get data from oracle where entdateint = current date and add service_date to the columns

    query = f"""SELECT dateday as service_date, {cols} FROM {schema_name}.{table_name} JOIN {cal_schema_name}.{cal_table_name} ON date_key = entdateint WHERE entdateint BETWEEN {start_key} AND {end_key}"""

    table, record_count = _execute_oracle_query(
        oracle_client=oracle_client, query=query, table_name=table_name
    )

    logger.info(f"Obtained {str(record_count)} records from table")

    # preprocess data applying casts for iceberg prep
    cleaned = write_client.handle_oracle_data_types(table)

    # if table does exist, overwrite the partition or simply append if one doesn't already exist
    if ib_table_exists:
        ib_table = ib_catalog.load_table(ib_table_id)

        ib_table.refresh()

        overwrite_filter = write_client._create_overwrite_filter(
            "time_between", "SERVICE_DATE", context
        )
        ib_table.overwrite(cleaned, overwrite_filter)

    # if table doesn't exist, create and load it
    else:
        location = write_client._generate_table_location(
            schema_name=schema_name,
            table_name=table_name,
        )

        ib_table = write_client._create_table(
            table_id=ib_table_id,
            schema=cleaned.schema,
            location=location,
            partition_col="SERVICE_DATE",
            transform_type="day",
        )

        write_client._write_with_retry(
            table=ib_table,
            write_fn=ib_table.append,
            data=cleaned,
            operation_name="initial append",
        )


@asset(
    required_resource_keys={
        "bus_ridership_db",
        "bus_ridership_storage",
    },
    partitions_def=calendar_daily_partitions,
    name="d_date_bus_data",
    group_name="oracle_tables",
    kinds=["azure", "oracle"],
)
# Uses SDH functions to copy bus_calendar_db d_date_bus_v data into the iceberg warehouse, partitioned by dateday
def d_date_bus_data(context: AssetExecutionContext):
    """Loads the d_date_bus_data asset via the d_date_bus_v calendar view on bus_calendar_db

    Parameters
    ----------
    context : AssetCheckExecutionContext
        Dagster asset check context

    Returns
    -------
    """
    return process_oracle_table(
        context=context,
        db_resource_key="bus_ridership_db",
        storage_resource_key="bus_ridership_storage",
        table_name="D_DATE_BUS_V",
        schema_name="bus_calendar_db",
        schema_path=schemas_parent / "d_date_bus.yaml",
    )


@asset_check(
    name="gte_0_rows",
    asset="d_date_bus_data",
    blocking=True,
)
def check_d_date_bus_data(context: AssetCheckExecutionContext):
    """Check that the d_date_bus_data calendar table uploaded successfully by examining materialization info

    Parameters
    ----------
    context : AssetCheckExecutionContext
        Dagster asset check context

    Returns
    -------
    """

    return check_daily_partition_populated(context, "d_date_bus_data")