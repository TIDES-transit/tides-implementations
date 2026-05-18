from dagster import Definitions, EnvVar

from ..env import is_consultant_[Project Name]_env

from .assets import (
    open_pay_tables,
    check_open_pay_tables_populated,
    lp_evt_txn_recv,
    check_evt_txn_recv_populated,
)
from ..resources.oracle_db import OracleDbResource
from ..resources.iceberg_writer import IcebergResource

from .schedules import open_pay_schedule, evt_txn_schedule

# Base assets and schedules that are always included
assets = []
schedules = []
asset_checks = []
# Initialize empty dictionaries for conditional resources
vendor_2_resources = {}

if not is_consultant_[Project Name]_env:
    # specify additional definitions based on environment needs

    vendor_2_resources = {
        # oracle resources ---------------------------------------
        "vendor_2_db": OracleDbResource(
            dsn_secret_name="openpay-dsn",
            db_secret_name_user="openpay-user",
            db_secret_name_password="openpay-pw",
            keyvault_name=EnvVar("KEY_VAULT_NAME"),
        ),
        "vendor_2_storage": IcebergResource(
            lakekeeper_url=EnvVar("LAKEKEEPER_URL"),
            lakekeeper_oauth_scope=EnvVar("LAKEKEEPER_OAUTH_SCOPE"),
            warehouse_name="datahub",
            catalog_name="open_pay",
            client_id=EnvVar("AZURE_CLIENT_ID"),
            client_secret=EnvVar("AZURE_CLIENT_SECRET"),
            tenant_id=EnvVar("AZURE_TENANT_ID"),
            force_clean_schema=False,  # we read-in all tables as string from parquet files, but feed_meta preserves the dateime
            container_name="iceberg",
            storage_account=EnvVar("AZURE_GTFS_STORAGE_ACCOUNT"),
        ),
    }

    assets += [
        # vendor_2 tables (multi-asset and near realtime)
        open_pay_tables,
        lp_evt_txn_recv,
    ]

    # Schedules ---------------------------------------------------------------------
    schedules += [open_pay_schedule, evt_txn_schedule]

    asset_checks += [check_open_pay_tables_populated, check_evt_txn_recv_populated]


# main entry point for the dagster pipeline
defs = Definitions(
    assets=assets,
    asset_checks=asset_checks,
    schedules=schedules,
    resources={
        **vendor_2_resources,
    },
)