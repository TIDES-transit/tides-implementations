import pathlib

from dagster import (
    asset,
    asset_check,
    multi_asset,
    multi_asset_check,
    AssetSpec,
    AssetCheckSpec,
    AssetExecutionContext,
    AssetCheckExecutionContext,
    AssetCheckResult,
    AssetCheckSeverity,
    AssetKey,
    MaterializeResult,
    get_dagster_logger,
    BackfillPolicy,
)

from ..common.assets import process_oracle_table
from ..common.asset_checks import (
    check_daily_partition_populated,
    check_time_window_partition_populated,
)
from ..partitions import get_partition_def

logger = get_dagster_logger()

schemas_parent = pathlib.Path(__file__).parent / "schemas"

# Define table configurations
OPEN_PAY_TABLES = {
    "lp_connections": {
        "table_name": "CONNECTIONS",
        "schema_file": "connections.yaml",
    },
    "lp_dev_txns": {
        "table_name": "dev_txns",
        "schema_file": "dev_txns.yaml",
    },
    "lp_dev_txn_purchases": {
        "table_name": "DEV_TXN_PURCHASES",
        "schema_file": "dev_txn_purchases.yaml",
    },
    "lp_fares": {
        "table_name": "FARES",
        "schema_file": "fares.yaml",
    },
    "lp_micropays": {
        "table_name": "micropays",
        "schema_file": "micropays.yaml",
    },
    "lp_micropay_dev_txns": {
        "table_name": "micropay_DEV_TXNS",
        "schema_file": "micropay_dev_txns.yaml",
    },
    "lp_settlements": {
        "table_name": "SETTLEMENTS",
        "schema_file": "settlements.yaml",
    },
    "lp_transfers": {
        "table_name": "TRANSFERS",
        "schema_file": "transfers.yaml",
    },
}


# assets -------------------------------------------------------------
@multi_asset(
    specs=[
        AssetSpec(
            key=asset_name,
            group_name="open_pay",
            kinds={"azure", "oracle"},
        )
        for asset_name in OPEN_PAY_TABLES.keys()
    ],
    required_resource_keys={
        "vendor_2_db",
        "vendor_2_storage",
    },
    partitions_def=get_partition_def("open_pay_tables"),
    can_subset=True,
)
def open_pay_tables(context: AssetExecutionContext):
    """Retrieves Open Pay data from Oracle DB for a specific date and writes parquet to cloud storage"""

    # Get the selected asset keys for this execution
    selected_asset_keys = context.selected_asset_keys or set()
    selected_table_names = {key.path[-1] for key in selected_asset_keys}

    for asset_name, config in OPEN_PAY_TABLES.items():
        # Only process assets that were selected for this execution
        if asset_name not in selected_table_names:
            continue

        context.log.info(f"Processing {asset_name}")

        result = process_oracle_table(
            context=context,
            db_resource_key="vendor_2_db",
            storage_resource_key="vendor_2_storage",
            table_name=config["table_name"],
            schema_name="vendor_2",
            schema_path=schemas_parent / config["schema_file"],
        )

        yield MaterializeResult(
            asset_key=asset_name,
            metadata=result.metadata if result else {},
        )


@asset(
    partitions_def=get_partition_def("lp_evt_txn_recv"),
    backfill_policy=BackfillPolicy.multi_run(),
    required_resource_keys={
        "vendor_2_db",
        "vendor_2_storage",
    },
    group_name="open_pay",
    kinds=["azure", "oracle"],
)
def lp_evt_txn_recv(context: AssetExecutionContext):
    """Retrieves Open Pay DEV_TXNS data from Oracle DB for a specific date and writes parquet to cloud storage"""
    return process_oracle_table(
        context=context,
        db_resource_key="vendor_2_db",
        storage_resource_key="vendor_2_storage",
        table_name="evt_txn_recv",
        schema_name="vendor_2",
        schema_path=schemas_parent / "evt_txn_recv.yaml",
    )


# asset checks ---------------------------------------------------------
@multi_asset_check(
    specs=[
        AssetCheckSpec("gte_0_rows", asset=asset_name, blocking=True)
        for asset_name in OPEN_PAY_TABLES.keys()
    ],
    can_subset=True,
)
def check_open_pay_tables_populated(context: AssetCheckExecutionContext):
    """Check that Open Pay tables uploaded successfully by examining materialization info"""
    # Get the asset keys that were selected for this check run
    selected_asset_check_keys = context.selected_asset_check_keys or set()
    selected_asset_keys = {
        check_key.asset_key for check_key in selected_asset_check_keys
    }
    selected_table_names = {key.path[-1] for key in selected_asset_keys}

    for asset_name in OPEN_PAY_TABLES.keys():
        if asset_name not in selected_table_names:
            continue

        try:
            # Get the check result and add the asset key
            check_result = check_daily_partition_populated(context, asset_name)

            # Create a new AssetCheckResult with the asset key specified
            yield AssetCheckResult(
                asset_key=AssetKey([asset_name]),
                check_name="gte_0_rows",
                passed=check_result.passed,
                metadata=check_result.metadata,
                severity=check_result.severity,
            )
        except Exception as e:
            # If the check function raises an exception, yield a failed check
            yield AssetCheckResult(
                asset_key=AssetKey([asset_name]),
                check_name="gte_0_rows",
                passed=False,
                metadata={
                    "error": f"Asset check raised exception: {str(e)}",
                    "asset_name": asset_name,
                },
                severity=AssetCheckSeverity.ERROR,
            )


# asset checks --------------------------------------------------------------


@asset_check(
    name="gte_0_rows",
    asset="lp_evt_txn_recv",
    blocking=True,
)
def check_evt_txn_recv_populated(context: AssetCheckExecutionContext):
    """Check that trip_payment_tran table uploaded successfully by examining materialization info"""
    return check_time_window_partition_populated(context, "lp_evt_txn_recv")