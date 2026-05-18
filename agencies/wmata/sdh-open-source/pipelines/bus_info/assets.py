import pathlib
from dagster import (
    asset,
    AssetExecutionContext,
    get_dagster_logger,
    asset_check,
    AssetCheckExecutionContext,
)

from ..common.assets import process_oracle_table
from ..common.asset_checks import check_daily_partition_populated
from ..partitions import get_partition_def

logger = get_dagster_logger()


schemas_parent = pathlib.Path(__file__).parent / "schemas"


@asset(
    required_resource_keys={
        "bus_info_db",
        "bus_info_storage",
    },
    partitions_def=get_partition_def("bus_info_data"),
    name="bus_info_data",
    group_name="oracle_tables",
    kinds=["azure", "oracle"],
)
def bus_info_data(context: AssetExecutionContext):
    """Retrieves FARE Use data from Oracle DB for a specific date and writes parquet to cloud storage

    Parameters
    ----------
    context : AssetExecutionContext
        dagster asset execution context
    """

    return process_oracle_table(
        context=context,
        db_resource_key="bus_info_db",
        storage_resource_key="bus_info_storage",
        table_name="BUS_INFO_DATA_RAW",
        schema_name="BUSINFO",
        schema_path=schemas_parent / "bus_info.yaml",
    )


@asset_check(
    name="gte_0_rows",
    asset="bus_info_data",
    blocking=True,
)
def check_bus_info_data(context: AssetCheckExecutionContext):
    """Check that bus_info table uploaded successfully by examining materialization info

    Parameters
    ----------
    context : AssetCheckExecutionContext
        Dagster asset check context

    Returns
    -------
    """

    return check_daily_partition_populated(context, "bus_info_data")