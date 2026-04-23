from dagster import Definitions

# shared azure credential

from . import DagsterResource, MetabaseResource, OpenMetadataResource
from . import (
    ingest_trino_schedule,
    profile_trino_schedule,
    ingest_dagster_schedule,
    ingest_metabase_schedule,
)


# Currently preserving OMD stuff in root since it's a little different and I'm nervy to touch
# OpenMetadata resources
openmetadata_resources = {
    "openmetadata_api": OpenMetadataResource(),
    "dagster_api": DagsterResource(),
    "metabase_api": MetabaseResource(),
}

schedules = [
    ingest_trino_schedule,
    profile_trino_schedule,
    ingest_dagster_schedule,
    ingest_metabase_schedule,
]


# Main entry point for the dagster pipeline
defs = Definitions(
    resources=openmetadata_resources,
    schedules=schedules,
)
