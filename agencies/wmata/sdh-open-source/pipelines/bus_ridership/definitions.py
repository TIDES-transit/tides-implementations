from dagster import Definitions, EnvVar

from .assets import (
    bus_ridership_lp_data,
    bus_ridership_fare_data,
    d_date_bus_data,
    check_d_date_bus_data,
)

from .sensors import bus_ridership_sensor
from .schedules import daily_calendar_update_schedule

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

sensors = []

asset_checks = []
# Initialize empty dictionaries for conditional resources
bus_ridership_resources = {}

if not is_consultant_[Project Name]_env:
    # specify additional definitions based on environment needs
    bus_ridership_resources = {
        "bus_ridership_storage": IcebergResource(
            lakekeeper_url=EnvVar("LAKEKEEPER_URL"),
            lakekeeper_oauth_scope=EnvVar("LAKEKEEPER_OAUTH_SCOPE"),
            warehouse_name="datahub",
            catalog_name="bus_ridership",
            client_id=EnvVar("AZURE_CLIENT_ID"),
            client_secret=EnvVar("AZURE_CLIENT_SECRET"),
            tenant_id=EnvVar("AZURE_TENANT_ID"),
            force_clean_schema=False,  # we read-in all tables as string from parquet files, but feed_meta preserves the dateime
            container_name="iceberg",
            storage_account=EnvVar("AZURE_GTFS_STORAGE_ACCOUNT"),
        ),
        "bus_ridership_db": OracleDbResource(
            dsn_secret_name="bus-ridership-dsn",
            db_secret_name_user="bus-ridership-user",
            db_secret_name_password="bus-ridership-pw",
            keyvault_name=EnvVar("KEY_VAULT_NAME"),
        ),
    }

    assets += [
        bus_ridership_lp_data,
        bus_ridership_fare_data,
        d_date_bus_data,
    ]

    schedules += [
        daily_calendar_update_schedule,
    ]

    sensors += [
        bus_ridership_sensor,
    ]

    asset_checks += [check_d_date_bus_data]

# main entry point for the dagster pipeline
defs = Definitions(
    assets=assets,
    asset_checks=asset_checks,
    schedules=schedules,
    sensors=sensors,
    resources={
        **bus_ridership_resources,
    },
)