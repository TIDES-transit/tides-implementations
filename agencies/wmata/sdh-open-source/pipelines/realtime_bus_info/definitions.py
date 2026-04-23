from dagster import Definitions, EnvVar

from ..env import is_consultant_[Project Name]_env
from .assets import (
    realtime_bus_info_data,
    check_realtime_bus_info_data,
    daily_routes_job,
    stop_lookup_job,
)

from ..resources.oracle_db import OracleDbResource
from ..resources.iceberg_writer import IcebergResource

from .schedules import realtime_bus_info_schedule, daily_routes_schedule


# Resources ----------------------------------------------------------------------

# Base assets and schedules that we add to if in consultant env
assets = []

schedules = []

asset_checks = []

jobs = []

# Initialize empty dictionaries for conditional resources
realtime_bus_info_resources = {}
fare_resources = {}

if not is_consultant_[Project Name]_env:
    # specify additional definitions based on environment needs
    realtime_bus_info_resources = {
        "realtime_bus_info_storage": IcebergResource(
            lakekeeper_url=EnvVar("LAKEKEEPER_URL"),
            lakekeeper_oauth_scope=EnvVar("LAKEKEEPER_OAUTH_SCOPE"),
            warehouse_name="datahub",
            catalog_name="avl",
            client_id=EnvVar("AZURE_CLIENT_ID"),
            client_secret=EnvVar("AZURE_CLIENT_SECRET"),
            tenant_id=EnvVar("AZURE_TENANT_ID"),
            force_clean_schema=False,  # we read-in all tables as string from parquet files, but feed_meta preserves the dateime
            container_name="iceberg",
            storage_account=EnvVar("AZURE_GTFS_STORAGE_ACCOUNT"),
        ),
        "realtime_bus_info_db": OracleDbResource(
            dsn_secret_name="datahub-rtbusinfo-dsn",
            db_secret_name_user="datahub-rtbusinfo-user",
            db_secret_name_password="datahub-rtbusinfo-pw",
            keyvault_name=EnvVar("KEY_VAULT_NAME"),
        ),
    }

    assets += [
        # bus info
        realtime_bus_info_data,
    ]

    # Schedules ---------------------------------------------------------------------
    schedules += [
        realtime_bus_info_schedule,
        daily_routes_schedule,
    ]

    asset_checks += [check_realtime_bus_info_data]

    jobs += [daily_routes_job, stop_lookup_job]

# main entry point for the dagster pipeline
defs = Definitions(
    assets=assets,
    asset_checks=asset_checks,
    schedules=schedules,
    jobs=jobs,
    resources={
        **realtime_bus_info_resources,
    },
)