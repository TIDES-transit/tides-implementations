from pathlib import Path

from dagster import (
    OpExecutionContext,
)
from metadata.generated.schema.metadataIngestion.workflow import Source, SourceConfig
from metadata.generated.schema.metadataIngestion.dbtPipeline import (
    DbtPipeline,
    DbtConfigType,
)
from metadata.generated.schema.metadataIngestion.dbtconfig.dbtLocalConfig import (
    DbtLocalConfig,
    DbtConfigType as DbtLocalConfigType,
)

from .common import OpenMetadataIngestionOp


# Implement ingestion operations
class DbtIngestionOp(OpenMetadataIngestionOp):
    """DBT metadata ingestion operation."""

    manifest_path: Path
    catalog_path: Path | None
    run_results_path: Path | None
    include_tags: bool
    update_descriptions: bool
    update_owners: bool

    def __init__(
        self,
        manifest_path: Path,
        catalog_path: Path | None = None,
        run_results_path: Path | None = None,
        include_tags: bool = True,
        update_descriptions: bool = True,
        update_owners: bool = True,
    ):
        self.manifest_path = manifest_path
        self.catalog_path = catalog_path
        self.run_results_path = run_results_path
        self.include_tags = include_tags
        self.update_descriptions = update_descriptions
        self.update_owners = update_owners

    def create_source_config(self, context: OpExecutionContext) -> Source:
        """Create DBT-specific source configuration."""
        context.log.debug(
            f"dbt OMD config: tags={self.include_tags} "
            f"descriptions={self.update_descriptions} owners={self.update_owners}"
        )

        return Source(
            type="dbt",
            serviceName="trino",  # Points to the Trino service in OpenMetadata
            sourceConfig=SourceConfig(
                config=DbtPipeline(
                    type=DbtConfigType.DBT,
                    dbtUpdateOwners=self.update_owners,
                    dbtUpdateDescriptions=self.update_descriptions,
                    includeTags=self.include_tags,
                    dbtConfigSource=DbtLocalConfig(
                        dbtConfigType=DbtLocalConfigType.local,
                        dbtManifestFilePath=str(self.manifest_path),
                        dbtCatalogFilePath=str(self.catalog_path)
                        if self.catalog_path
                        else None,
                        dbtRunResultsFilePath=str(self.run_results_path)
                        if self.run_results_path
                        else None,
                    ),
                )
            ),
        )
