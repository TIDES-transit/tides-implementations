from dagster import (
    job,
    op,
    OpExecutionContext,
    ScheduleDefinition,
    ConfigurableResource,
    EnvVar,
)
from metadata.generated.schema.metadataIngestion.workflow import Source, SourceConfig
from metadata.generated.schema.metadataIngestion.dashboardServiceMetadataPipeline import (
    DashboardServiceMetadataPipeline,
    LineageInformation,
)
from metadata.generated.schema.entity.services.connections.serviceConnection import (
    ServiceConnection,
)
from metadata.generated.schema.entity.services.dashboardService import (
    DashboardConnection,
)
from metadata.generated.schema.entity.services.connections.dashboard.metabaseConnection import (
    MetabaseConnection,
    MetabaseType,
)

from .common import OpenMetadataIngestionOp


class MetabaseResource(ConfigurableResource):
    """Resource that provides Metabase configuration."""

    host: str = EnvVar("METABASE_HOST")
    username: str = EnvVar("METABASE_BOT_USERNAME")
    password: str = EnvVar("METABASE_BOT_PASSWORD")


# Define Dagster entities
@op(required_resource_keys={"openmetadata_api", "metabase_api"})
def ingest_metabase_metadata_op(context: OpExecutionContext):
    """Dagster op to ingest Metabase metadata into OpenMetadata."""
    return MetabaseIngestionOp().execute(context)


@job
def ingest_metabase_job():
    """Job that ingests Metabase dashboards and charts into OpenMetadata."""
    ingest_metabase_metadata_op()


ingest_metabase_schedule = ScheduleDefinition(
    job=ingest_metabase_job,
    cron_schedule="0 8 * * *",  # 8am every day
    execution_timezone="America/New_York",
)


# Implement ingestion operation
class MetabaseIngestionOp(OpenMetadataIngestionOp):
    """Metabase metadata ingestion operation."""

    def create_source_config(self, context: OpExecutionContext) -> Source:
        """Create Metabase-specific source configuration."""
        return Source(
            type="metabase",
            serviceName="metabase",
            serviceConnection=ServiceConnection(
                root=DashboardConnection(
                    config=MetabaseConnection(
                        type=MetabaseType.Metabase,
                        hostPort=context.resources.metabase_api.host,
                        username=context.resources.metabase_api.username,
                        password=context.resources.metabase_api.password,
                    )
                )
            ),
            sourceConfig=SourceConfig(
                config=DashboardServiceMetadataPipeline(
                    lineageInformation=LineageInformation(
                        dbServicePrefixes=["trino", "trino.datahub"]
                    ),
                    includeOwners=True,
                    markDeletedDashboards=True,
                    markDeletedDataModels=True,
                    includeTags=True,
                    includeDataModels=True,
                    includeDraftDashboard=True,
                    overrideMetadata=False,
                    overrideLineage=False,
                )
            ),
        )
