import pathlib

from dagster import (
    asset,
    AssetExecutionContext,
    get_dagster_logger,
    asset_check,
    AssetCheckExecutionContext,
)

from ..common.assets import process_oracle_table
from ..common.asset_checks import (
    check_daily_partition_populated,
    check_time_window_partition_populated,
)
from ..partitions import get_partition_def

logger = get_dagster_logger()


schemas_parent = pathlib.Path(__file__).parent / "schemas"


@asset(
    required_resource_keys={
        "faregate_data_db",
        "fare_storage",
    },
    partitions_def=get_partition_def("faregate_data_mtn"),
    name="faregate_data_mtn",
    group_name="oracle_tables",
    kinds=["azure", "oracle"],
)
def faregate_data_mtn(context: AssetExecutionContext):
    """Retrieves faregate_data MTN data from Oracle DB for a specific date and writes parquet to cloud storage

    Parameters
    ----------
    context : AssetExecutionContext
        dagster asset execution context
    """

    return process_oracle_table(
        context=context,
        db_resource_key="faregate_data_db",
        storage_resource_key="fare_storage",
        table_name="SOURCE_TABLE_A",
        schema_name="faregate_data_MAIN",
        schema_path=schemas_parent / "tb_mtn.yaml",
    )


@asset(
    required_resource_keys={
        "faregate_data_db",
        "fare_storage",
    },
    partitions_def=get_partition_def("faregate_data_orgn"),
    name="faregate_data_orgn",
    group_name="oracle_tables",
    kinds=["azure", "oracle"],
)
def faregate_data_orgn(context: AssetExecutionContext):
    """Retrieves faregate_data ORGN data from Oracle DB for a specific date and writes parquet to cloud storage

    Parameters
    ----------
    context : AssetExecutionContext
        dagster asset execution context
    """

    return process_oracle_table(
        context=context,
        db_resource_key="faregate_data_db",
        storage_resource_key="fare_storage",
        table_name="SOURCE_TABLE_B",
        schema_name="faregate_data_MAIN",
        schema_path=schemas_parent / "tb_orgn.yaml",
    )


@asset(
    required_resource_keys={
        "fare_db",
        "fare_storage",
    },
    partitions_def=get_partition_def("fare_sale"),
    name="fare_sale",
    group_name="oracle_tables",
    kinds=["azure", "oracle"],
)
def fare_sale(context: AssetExecutionContext):
    """Retrieves FARE Sale data from Oracle DB for a specific date and writes parquet to cloud storage

    Parameters
    ----------
    context : AssetExecutionContext
        dagster asset execution context
    """

    return process_oracle_table(
        context=context,
        db_resource_key="fare_db",
        storage_resource_key="fare_storage",
        table_name="SALE_TRANSACTION",
        schema_name="FARE",
        schema_path=schemas_parent / "tb_sale_transaction.yaml",
    )


@asset(
    required_resource_keys={
        "fare_db",
        "fare_storage",
    },
    partitions_def=get_partition_def("fare_use"),
    name="fare_use",
    group_name="oracle_tables",
    kinds=["azure", "oracle"],
)
def fare_use(context: AssetExecutionContext):
    """Retrieves FARE Use data from Oracle DB for a specific date and writes parquet to cloud storage

    Parameters
    ----------
    context : AssetExecutionContext
        dagster asset execution context
    """

    return process_oracle_table(
        context=context,
        db_resource_key="fare_db",
        storage_resource_key="fare_storage",
        table_name="USE_TRANSACTION",
        schema_name="FARE",
        schema_path=schemas_parent / "tb_use_transaction.yaml",
    )


# asset checks ------------------------------------------


@asset_check(
    name="gte_0_rows",
    asset="faregate_data_mtn",
    blocking=True,
)
def check_faregate_data_mtn_populated(context: AssetCheckExecutionContext):
    """Check that faregate_data_mtn table uploaded successfully by examining materialization info

    Parameters
    ----------
    context : AssetCheckExecutionContext
        Dagster asset check context

    Returns
    -------
    """
    return check_daily_partition_populated(context, "faregate_data_mtn")


@asset_check(
    name="gte_0_rows",
    asset="faregate_data_orgn",
    blocking=True,
)
def check_faregate_data_orgn_populated(context: AssetCheckExecutionContext):
    """Check that faregate_data_orgn table uploaded successfully by examining materialization info

    Parameters
    ----------
    context : AssetCheckExecutionContext
        Dagster asset check context

    Returns
    -------
    """

    return check_daily_partition_populated(context, "faregate_data_orgn")


@asset_check(
    name="gte_0_rows",
    asset="fare_sale",
    blocking=True,
)
def check_fare_sale_populated(context: AssetCheckExecutionContext):
    """Check that fare_sale table uploaded successfully by examining materialization info

    Parameters
    ----------
    context : AssetCheckExecutionContext
        Dagster asset check context

    Returns
    -------
    """
    return check_time_window_partition_populated(context, "fare_sale")


@asset_check(
    name="gte_0_rows",
    asset="fare_use",
    blocking=True,
)
def check_fare_use_populated(context: AssetCheckExecutionContext):
    """Check that fare_use table uploaded successfully by examining materialization info

    Parameters
    ----------
    context : AssetCheckExecutionContext
        Dagster asset check context

    Returns
    -------
    """
    return check_time_window_partition_populated(context, "fare_use")