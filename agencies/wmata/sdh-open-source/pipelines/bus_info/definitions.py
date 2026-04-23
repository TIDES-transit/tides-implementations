from dagster import Definitions, EnvVar

from .assets import bus_info_data, check_bus_info_data
from .schedules import daily_bus_info_schedule

from ..env import is_consultant_[Project Name]_env

from ..resources.oracle_db import OracleDbResource
from ..resources.iceberg_writer import IcebergResource


# Resources ----------------------------------------------------------------------
# defs object instantiation the same

# Create the shared Azure credential resource


# Export TRINO_JWT_TOKEN before dbt loads
# trino_resources["trino_resource"].export_access_token()

# Base assets and schedules that are always included
assets = []

schedules = []

asset_checks = []
# Initialize empty dictionaries for conditional resources
bus_info_resources = {}

if not is_consultant_[Project Name]_env:
    # specify additional definitions based on environment needs
    bus_info_resources = {
        "bus_info_storage": IcebergResource(
            lakekeeper_url=EnvVar("LAKEKEEPER_URL"),
            lakekeeper_oauth_scope=EnvVar("LAKEKEEPER_OAUTH_SCOPE"),
            warehouse_name="datahub",
            catalog_name="bus_info",
            client_id=EnvVar("AZURE_CLIENT_ID"),
            client_secret=EnvVar("AZURE_CLIENT_SECRET"),
            tenant_id=EnvVar("AZURE_TENANT_ID"),
            force_clean_schema=False,  # we read-in all tables as string from parquet files, but feed_meta preserves the dateime
            container_name="iceberg",
            storage_account=EnvVar("AZURE_GTFS_STORAGE_ACCOUNT"),
        ),
        "bus_info_db": OracleDbResource(
            dsn_secret_name="datahub-bus_data-dsn",
            db_secret_name_user="datahub-bus_data-user",
            db_secret_name_password="datahub-bus_data-pw",
            keyvault_name=EnvVar("KEY_VAULT_NAME"),
        ),
    }
    assets += [
        # bus info
        bus_info_data,
    ]

    # Schedules ---------------------------------------------------------------------
    schedules += [
        daily_bus_info_schedule,
    ]

    asset_checks += [check_bus_info_data]


# main entry point for the dagster pipeline
defs = Definitions(
    assets=assets,
    asset_checks=asset_checks,
    schedules=schedules,
    resources={
        **bus_info_resources,
    },
)