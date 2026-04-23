from dagster import Definitions, EnvVar

from ..env import azure_credential

from .assets import (
    gtfs_zip,
    gtfs_unzip_files,
    check_gtfs_zip,
    check_gtfs_unzip_files,
    check_gtfs_tables_populated,
    gtfs_tables,
)


from ..resources.wmata_gtfs_api import GTFSApiResource
from ..resources.azure_storage import AzureStorageResource
from ..resources.iceberg_writer import IcebergResource

from .schedules import daily_gtfs_download_schedule
from .sensors import gtfs_new_feed_sensor


# Resources ----------------------------------------------------------------------
# resources for the gtfs and dbt pipeline are created for either client/consultant env
# other resources are skipped for consultant env, but we create an empty dict to keep the
# defs object instantiation the same
# dbt selects specific models in the asset, however


gtfs_database_resource = IcebergResource(
    lakekeeper_url=EnvVar("LAKEKEEPER_URL"),
    lakekeeper_oauth_scope=EnvVar("LAKEKEEPER_OAUTH_SCOPE"),
    warehouse_name="datahub",
    catalog_name="gtfs",
    client_id=EnvVar("AZURE_CLIENT_ID"),
    client_secret=EnvVar("AZURE_CLIENT_SECRET"),
    tenant_id=EnvVar("AZURE_TENANT_ID"),
    force_clean_schema=False,  # we read-in all tables as string from parquet files, but feed_meta preserves the dateime
    container_name="iceberg",
    storage_account=EnvVar("AZURE_GTFS_STORAGE_ACCOUNT"),
)


# resources for the gtfs pipeline
gtfs_resources = {
    # GTFS resources ------------------------------------------
    "api_client": GTFSApiResource(
        api_secret_key_name="gtfs-api-combined",
        base_url="https://api.[AGENCY].com/gtfs/rail-bus-gtfs-static.zip",
        keyvault_name=EnvVar("KEY_VAULT_NAME"),
    ),
    "azure_storage_resource": AzureStorageResource(
        azure_credential=azure_credential,
        storage_account=EnvVar("AZURE_GTFS_STORAGE_ACCOUNT"),
        container="raw",
    ),
    "azure_storage_name": EnvVar("AZURE_GTFS_STORAGE_ACCOUNT"),
    "azure_container_name": "raw",
    # Iceberg storage resources ------------------------------
    "gtfs_database_resource": gtfs_database_resource,
}


assets = [
    # gtfs
    gtfs_zip,
    gtfs_unzip_files,
    gtfs_tables,
]

schedules = [
    daily_gtfs_download_schedule,
]

sensors = [gtfs_new_feed_sensor]

# Asset checks are gtfs-only currently so fine for either env
# Asset checks ------------------------------------------------------
asset_checks = [
    # gtfs asset checks
    check_gtfs_zip,
    check_gtfs_unzip_files,
    check_gtfs_tables_populated,
]

# main entry point for the dagster pipeline
defs = Definitions(
    assets=assets,
    asset_checks=asset_checks,
    schedules=schedules,
    sensors=sensors,
    resources={
        "azure_credential": azure_credential,
        **gtfs_resources,
    },
)