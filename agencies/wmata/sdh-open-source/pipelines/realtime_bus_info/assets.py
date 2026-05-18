import pathlib

from dagster import (
    asset,
    AssetExecutionContext,
    get_dagster_logger,
    BackfillPolicy,
    asset_check,
    AssetCheckExecutionContext,
    job,
    op,
    OpExecutionContext,
)

from ..common.assets import process_oracle_table, read_schema_data
from ..common.asset_checks import check_time_window_partition_populated
from ..resources.iceberg_writer import IcebergClient
from ..partitions import get_partition_def


logger = get_dagster_logger()

schemas_dir = pathlib.Path(__file__).parent / "schemas"


@asset(
    partitions_def=get_partition_def("realtime_bus_info_data"),
    backfill_policy=BackfillPolicy.multi_run(),
    required_resource_keys={
        "realtime_bus_info_db",
        "realtime_bus_info_storage",
    },
    group_name="oracle_tables",
    kinds=["azure", "oracle"],
)
def realtime_bus_info_data(context: AssetExecutionContext):
    """Retrieves realtime bus info data from Oracle DB for time windows and writes parquet to cloud storage

    Parameters
    ----------
    context : AssetExecutionContext
        dagster asset execution context
    """
    return process_oracle_table(
        context=context,
        db_resource_key="realtime_bus_info_db",
        storage_resource_key="realtime_bus_info_storage",
        table_name="LOG_CC_VEHICLEWORK",
        schema_name="AVL",
        schema_path=pathlib.Path(__file__).parent
        / "schemas"
        / "realtime_bus_info.yaml",
        query_in_utc=True,
    )


@asset_check(
    name="gte_0_rows",
    asset="realtime_bus_info_data",
    blocking=True,
)
def check_realtime_bus_info_data(context: AssetCheckExecutionContext):
    """Check that realtime_bus_info table uploaded successfully by examining materialization info. Modified to handle time-partitioned asset.

    Parameters
    ----------
    context : AssetCheckExecutionContext
        Dagster asset check context

    Returns
    -------
    """

    return check_time_window_partition_populated(context, "realtime_bus_info_data")


# Jobs/helper functions for manually run realtime bus info supplemental tables


def _build_select_query(
    schema_data: dict,
    table_name: str,
    where_col: str,
    where_value,
    quote_value: bool = True,
) -> str:
    """Build a simple SELECT <cols> FROM <schema>.<table> WHERE <col> = <value> query."""
    schema = schema_data["schema"]
    cols = ", ".join(c.upper() for c in schema_data["query_cols"])
    val = f"'{where_value}'" if quote_value else where_value
    return f"SELECT {cols}\nFROM {schema}.{table_name}\nWHERE {where_col} = {val}"


def _run_simple_query_to_iceberg(
    context, schema_data, table_name, where_col, where_value, quote_value=True
):
    """Execute a simple WHERE-equality query against Oracle and write results to Iceberg."""
    oracle_client = context.resources.realtime_bus_info_db.get_client()
    write_client = context.resources.realtime_bus_info_storage.get_client()

    query = _build_select_query(
        schema_data, table_name, where_col, where_value, quote_value=quote_value
    )
    logger.info(f"Running query: {query}")

    transform_type = schema_data.get("transform_type")
    partition_col = schema_data.get("partition_col", where_col)

    total_rows = 0
    for batch in oracle_client.execute_query(query):
        batch_rows = len(batch)
        total_rows += batch_rows
        logger.info(
            f"Retrieved {batch_rows} rows (total: {total_rows}) for {table_name}"
        )

        if isinstance(write_client, IcebergClient):
            if write_client.force_clean_schema:
                cleaned = write_client.clean_column_schema(batch)
            else:
                cleaned = write_client.handle_oracle_data_types(batch)

            write_client.write_table(
                table_name=table_name.lower(),
                schema_name=schema_data["schema"].lower(),
                pa_table=cleaned,
                partition_col=partition_col,
                transform_type=transform_type,
                mode="append",
            )
            del cleaned
        del batch

    if total_rows == 0:
        logger.info(
            f"No data returned for {table_name} WHERE {where_col} = '{where_value}'"
        )

    logger.info(f"Finished: {total_rows} total rows written for {table_name}")


@op(
    required_resource_keys={"realtime_bus_info_db", "realtime_bus_info_storage"},
    config_schema={"date": int},
)
def pull_daily_routes(context: OpExecutionContext):
    """Pull ROUTE_LOOKUP_CROSSWALK from Oracle vendor_1 schema for a configured date (YYYYMMDD)."""
    date = context.op_config["date"]
    schema_data = read_schema_data(schemas_dir / "route_lookup_crosswalk.yaml")
    _run_simple_query_to_iceberg(
        context=context,
        schema_data=schema_data,
        table_name="ROUTE_LOOKUP_CROSSWALK",
        where_col=schema_data["date_col"],
        where_value=str(date),
        quote_value=False,
    )


@op(
    required_resource_keys={"realtime_bus_info_db", "realtime_bus_info_storage"},
    config_schema={"version_id": int},
)
def pull_stop_lookup(context: OpExecutionContext):
    """Pull STOP_LOOKUP_CROSSWALK from Oracle vendor_1 schema for a configured VERSIONID."""
    version_id = context.op_config["version_id"]
    schema_data = read_schema_data(schemas_dir / "stop_lookup_crosswalk.yaml")
    _run_simple_query_to_iceberg(
        context=context,
        schema_data=schema_data,
        table_name="STOP_LOOKUP_CROSSWALK",
        where_col=schema_data["filter_col"],
        where_value=version_id,
        quote_value=False,
    )


@job(
    resource_defs={},
    config={"ops": {"pull_daily_routes": {"config": {"date": 0}}}},
)
def daily_routes_job():
    pull_daily_routes()


@job(
    resource_defs={},
    config={"ops": {"pull_stop_lookup": {"config": {"version_id": 0}}}},
)
def stop_lookup_job():
    pull_stop_lookup()