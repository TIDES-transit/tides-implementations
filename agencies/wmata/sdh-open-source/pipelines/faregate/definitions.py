from dagster import Definitions, EnvVar

from ..env import is_consultant_[Project Name]_env

from .assets import (
    faregate_data_mtn,
    faregate_data_orgn,
    fare_sale,
    fare_use,
    check_faregate_data_mtn_populated,
    check_faregate_data_orgn_populated,
    check_fare_sale_populated,
    check_fare_use_populated,
)

from ..resources.oracle_db import OracleDbResource
from ..resources.iceberg_writer import IcebergResource

from .schedules import (
    faregate_data_mtn_schedule,
    faregate_data_orgn_schedule,
    fare_sale_schedule,
    fare_use_schedule,
)

# Base assets and schedules that are always included
assets = []
schedules = []
asset_checks = []
# Initialize empty dictionaries for conditional resources
fare_resources = {}

if not is_consultant_[Project Name]_env:
    # specify additional definitions based on environment needs
    fare_resources = {
        # oracle resources ---------------------------------------
        "faregate_data_db": OracleDbResource(
            dsn_secret_name="datahub-faregate_data-dsn",
            db_secret_name_user="datahub-faregate_data-user",
            db_secret_name_password="datahub-faregate_data-pw",
            keyvault_name=EnvVar("KEY_VAULT_NAME"),
        ),
        "fare_db": OracleDbResource(
            dsn_secret_name="datahub-fare-dsn",
            db_secret_name_user="datahub-fare-user",
            db_secret_name_password="datahub-fare-pw",
            keyvault_name=EnvVar("KEY_VAULT_NAME"),
        ),
        "fare_storage": IcebergResource(
            lakekeeper_url=EnvVar("LAKEKEEPER_URL"),
            lakekeeper_oauth_scope=EnvVar("LAKEKEEPER_OAUTH_SCOPE"),
            warehouse_name="datahub",
            catalog_name="faregate",
            client_id=EnvVar("AZURE_CLIENT_ID"),
            client_secret=EnvVar("AZURE_CLIENT_SECRET"),
            tenant_id=EnvVar("AZURE_TENANT_ID"),
            force_clean_schema=False,  # we read-in all tables as string from parquet files, but feed_meta preserves the dateime
            container_name="iceberg",
            storage_account=EnvVar("AZURE_GTFS_STORAGE_ACCOUNT"),
        ),
    }

    assets += [
        # fare tables
        faregate_data_mtn,
        faregate_data_orgn,
        fare_sale,
        fare_use,
    ]

    # Schedules ---------------------------------------------------------------------
    schedules += [
        faregate_data_mtn_schedule,
        faregate_data_orgn_schedule,
        fare_sale_schedule,
        fare_use_schedule,
    ]

    asset_checks += [
        check_faregate_data_mtn_populated,
        check_faregate_data_orgn_populated,
        check_fare_sale_populated,
        check_fare_use_populated,
    ]


# main entry point for the dagster pipeline
defs = Definitions(
    assets=assets,
    asset_checks=asset_checks,
    schedules=schedules,
    resources={
        **fare_resources,
    },
)