from dagster import (
    job,
    op,
    OpExecutionContext,
    ScheduleDefinition,
    ConfigurableResource,
    EnvVar,
)
from metadata.generated.schema.metadataIngestion.workflow import Source, SourceConfig
from metadata.generated.schema.entity.services.connections.serviceConnection import (
    ServiceConnection,
)
from metadata.generated.schema.entity.services.pipelineService import PipelineConnection
from metadata.generated.schema.entity.services.connections.pipeline.dagsterConnection import (
    DagsterConnection,
    DagsterType,
)
from metadata.generated.schema.metadataIngestion.pipelineServiceMetadataPipeline import (
    PipelineServiceMetadataPipeline,
    PipelineMetadataConfigType,
)

from .common import OpenMetadataIngestionOp


class DagsterResource(ConfigurableResource):
    """Resource that provides Dagster configuration."""

    host: str = EnvVar("DAGSTER_HOST")
    token: str = EnvVar("DAGSTER_TOKEN")


# Define Dagster entities
@op(required_resource_keys={"openmetadata_api", "dagster_api"})
def ingest_dagster_metadata_op(context: OpExecutionContext):
    """Dagster op to ingest Dagster metadata into OpenMetadata."""
    return DagsterIngestionOp().execute(context)


@job
def ingest_dagster_job():
    """Job that ingests Dagster pipeline metadata into OpenMetadata."""
    ingest_dagster_metadata_op()


ingest_dagster_schedule = ScheduleDefinition(
    job=ingest_dagster_job,
    cron_schedule="0 7 * * *",  # 7am every day
    execution_timezone="America/New_York",
)


# Implement ingestion operation
class DagsterIngestionOp(OpenMetadataIngestionOp):
    """Dagster metadata ingestion operation."""

    def create_source_config(self, context: OpExecutionContext) -> Source:
        """Create Dagster-specific source configuration."""
        return Source(
            type="dagster",
            serviceName="dagster",
            serviceConnection=ServiceConnection(
                root=PipelineConnection(
                    config=DagsterConnection(
                        type=DagsterType.Dagster,
                        host=context.resources.dagster_api.host,
                        token=context.resources.dagster_api.token,
                        timeout=1000,
                    )
                )
            ),
            sourceConfig=SourceConfig(
                config=PipelineServiceMetadataPipeline(
                    type=PipelineMetadataConfigType.PipelineMetadata,
                    includeLineage=True,
                    includeTags=True,
                    includeOwners=True,
                    markDeletedPipelines=True,
                    includeUnDeployedPipelines=True,
                    overrideLineage=True,
                    overrideMetadata=True,
                )
            ),
        )
