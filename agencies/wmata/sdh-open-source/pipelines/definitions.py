from dagster import Definitions


# defs
from .bus_info import definitions as bus_info_defs
from .dbt import definitions as dbt_defs
from .gtfs import definitions as gtfs_defs
from .iceberg_operations import definitions as iceberg_defs
from .faregate import definitions as faregate_defs
from .open_pay import definitions as open_pay_defs
from .realtime_bus_info import definitions as realtime_bus_info_defs
from .trino_test import definitions as trino_defs
from .bus_ridership import definitions as ridership_defs

# shared azure credential
from .env import azure_credential

from .openmetadata import definitions as openmetadata_defs

# Initialize fare data resource components

# Main entry point for the dagster pipeline
defs = Definitions.merge(
    bus_info_defs.defs,
    dbt_defs.defs,
    gtfs_defs.defs,
    iceberg_defs.defs,  # these are one-off functions that are intended for DE to use to clean up data
    faregate_defs.defs,
    open_pay_defs.defs,
    realtime_bus_info_defs.defs,
    trino_defs.defs,
    openmetadata_defs.defs,
    ridership_defs.defs,
    Definitions(resources={"azure_credential": azure_credential}),
)