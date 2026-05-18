from dagster import job, op, OpExecutionContext, ScheduleDefinition, EnvVar

from metadata.workflow.profiler import ProfilerWorkflow
from metadata.generated.schema.metadataIngestion.workflow import (
    Source,
    SourceConfig,
    Processor,
)
from metadata.generated.schema.metadataIngestion.databaseServiceMetadataPipeline import (
    DatabaseServiceMetadataPipeline,
)
from metadata.generated.schema.metadataIngestion.databaseServiceQueryLineagePipeline import (
    DatabaseServiceQueryLineagePipeline,
)
from metadata.generated.schema.metadataIngestion.databaseServiceProfilerPipeline import (
    DatabaseServiceProfilerPipeline,
)
from metadata.generated.schema.entity.services.connections.serviceConnection import (
    ServiceConnection,
)
from metadata.generated.schema.entity.services.databaseService import DatabaseConnection
from metadata.generated.schema.entity.services.connections.database.trinoConnection import (
    TrinoConnection,
    TrinoType,
)
from metadata.generated.schema.entity.services.connections.database.common.azureConfig import (
    AzureConfigurationSource,
)
from metadata.generated.schema.security.credentials.azureCredentials import (
    AzureCredentials,
)
from metadata.generated.schema.type.filterPattern import FilterPattern
from metadata.generated.schema.type.basic import ComponentConfig

from .common import OpenMetadataIngestionOp


# Define Dagster entities
@op(required_resource_keys={"azure_credential", "trino", "openmetadata_api"})
def ingest_trino_metadata_op(context: OpExecutionContext):
    """Dagster op to ingest Trino metadata into OpenMetadata."""
    return TrinoMetadataIngestionOp().execute(context)


@op(required_resource_keys={"openmetadata_api"})
def ingest_trino_lineage_op(context: OpExecutionContext):
    """Dagster op to ingest Trino lineage into OpenMetadata."""
    return TrinoLineageIngestionOp().execute(context)


@op(required_resource_keys={"openmetadata_api"})
def ingest_trino_profile_op(context: OpExecutionContext):
    """Dagster op to ingest Trino data profile into OpenMetadata."""
    return TrinoProfileIngestionOp().execute(context)


@job
def ingest_trino_job():
    """Job that ingests Trino metadata, lineage, and data profiles into OpenMetadata."""
    ingest_trino_metadata_op()
    ingest_trino_lineage_op()


@job
def profile_trino_job():
    """Job that ingests Trino metadata, lineage, and data profiles into OpenMetadata."""
    ingest_trino_profile_op()


ingest_trino_schedule = ScheduleDefinition(
    job=ingest_trino_job,
    cron_schedule="0 6 * * *",  # 6am every day
    execution_timezone="America/New_York",
)

profile_trino_schedule = ScheduleDefinition(
    job=profile_trino_job,
    cron_schedule="0 8 * * SUN",  # 7am every Sunday
    execution_timezone="America/New_York",
)


# Implement ingestion operations
class TrinoMetadataIngestionOp(OpenMetadataIngestionOp):
    """Trino metadata ingestion operation."""

    def create_source_config(self, context: OpExecutionContext) -> Source:
        return Source(
            type="trino",
            serviceName="trino",
            serviceConnection=ServiceConnection(
                root=DatabaseConnection(
                    config=TrinoConnection(
                        type=TrinoType.Trino,
                        hostPort=f"{context.resources.trino.host}:{context.resources.trino.port}",
                        username=context.resources.trino.user,
                        authType=AzureConfigurationSource(
                            azureConfig=AzureCredentials(
                                tenantId=context.resources.azure_credential.tenant_id,
                                clientId=context.resources.azure_credential.client_id,
                                clientSecret=context.resources.azure_credential.client_secret,
                                scopes=context.resources.trino.oauth_scope,
                            )
                        ),
                        catalog=context.resources.trino.catalog,
                    )
                )
            ),
            sourceConfig=SourceConfig(
                config=DatabaseServiceMetadataPipeline(
                    # markDeletedTables=True,
                    # includeTables=True,
                    # includeViews=True,
                    # includeTags=True,
                    databaseFilterPattern=FilterPattern(includes=["datahub"]),
                    schemaFilterPattern=FilterPattern(
                        includes=[str(EnvVar("TRINO_SCHEMA").get_value()) + "*"],
                        excludes=["information_schema", "system"],
                    ),
                )
            ),
        )


class TrinoLineageIngestionOp(OpenMetadataIngestionOp):
    """Trino lineage ingestion operation."""

    def create_source_config(self, context: OpExecutionContext) -> Source:
        return Source(
            type="trino-lineage",
            serviceName="trino",
            sourceConfig=SourceConfig(
                config=DatabaseServiceQueryLineagePipeline(
                    # queryLogDuration=1,
                    # parsingTimeoutLimit=300,
                    # resultLimit=1000,
                    overrideViewLineage=True,
                    databaseFilterPattern=FilterPattern(includes=["datahub"]),
                    schemaFilterPattern=FilterPattern(
                        includes=[str(EnvVar("TRINO_SCHEMA").get_value()) + "*"],
                        excludes=["information_schema", "system"],
                    ),
                )
            ),
        )


class TrinoProfileIngestionOp(OpenMetadataIngestionOp):
    """Trino data profile ingestion operation."""

    workflowClass = ProfilerWorkflow

    def create_source_config(self, context: OpExecutionContext) -> Source:
        return Source(
            type="trino",
            serviceName="trino",
            sourceConfig=SourceConfig(
                config=DatabaseServiceProfilerPipeline(
                    threadCount=1,  # limit to 1 thread to avoid nuking dev Trino
                    # includeViews=True,
                    # Apply same filters as metadata ingestion to avoid profiling system schemas
                    databaseFilterPattern=FilterPattern(includes=["datahub"]),
                    schemaFilterPattern=FilterPattern(
                        includes=[str(EnvVar("TRINO_SCHEMA").get_value()) + "*"],
                        excludes=["information_schema", "system"],
                    ),
                )
            ),
        )

    def create_processor_config(self, context: OpExecutionContext) -> Processor:
        return Processor(type="orm-profiler", config=ComponentConfig({}))
