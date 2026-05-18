from pathlib import Path

from dagster import (
    AssetKey,
    AutomationConditionSensorDefinition,
    DefaultSensorStatus,
    MultiAssetSensorEvaluationContext,
    OpExecutionContext,
    RunRequest,
    SensorEvaluationContext,
    SkipReason,
    define_asset_job,
    job,
    multi_asset_sensor,
    op,
    sensor,
)
from dagster_dbt import DbtCliResource, build_dbt_asset_selection

from ..gtfs.assets import all_possible_gtfs_tables
from ..openmetadata.dbt import DbtIngestionOp
from .assets import warehouse_dbt_assets


dbt_automation_sensor = AutomationConditionSensorDefinition(
    name="dbt_automation_sensor",
    target=[warehouse_dbt_assets],
    default_status=DefaultSensorStatus.STOPPED,
)

gtfs_dbt_selection = build_dbt_asset_selection(
    [warehouse_dbt_assets],
    dbt_select="source:gtfs+",
)

gtfs_dbt_refresh_job = define_asset_job(
    name="gtfs_dbt_refresh_job",
    selection=gtfs_dbt_selection,
    description="Runs all dbt models downstream of GTFS sources in a single run",
)

_monitored_gtfs_assets = [AssetKey([table]) for table in all_possible_gtfs_tables]


@multi_asset_sensor(
    monitored_assets=_monitored_gtfs_assets,
    job=gtfs_dbt_refresh_job,
    name="gtfs_dbt_sensor",
    description=(
        "Triggers all GTFS-downstream dbt models in a single run "
        "when gtfs_tables materializes a new feed_hash partition."
    ),
    minimum_interval_seconds=60,
    default_status=DefaultSensorStatus.RUNNING,
)
def gtfs_dbt_sensor(context: MultiAssetSensorEvaluationContext):
    feed_hashes_seen: set[str] = set()

    for asset_key in _monitored_gtfs_assets:
        records = context.latest_materialization_records_by_key([asset_key])
        for _key, record in records.items():
            if record is not None:
                partition = record.event_log_entry.dagster_event.partition
                if partition:
                    feed_hashes_seen.add(partition)

    if not feed_hashes_seen:
        context.advance_all_cursors()
        yield SkipReason("No new gtfs_tables materializations detected")
        return

    for feed_hash in feed_hashes_seen:
        context.log.info(
            f"New GTFS feed_hash {feed_hash} detected, triggering dbt refresh"
        )
        yield RunRequest(
            run_key=f"gtfs_dbt_{feed_hash}",
            tags={"feed_hash": feed_hash},
        )

    context.advance_all_cursors()


@op(required_resource_keys={"dbt", "openmetadata_api"})
def upload_dbt_catalog_to_openmetadata(context: OpExecutionContext):
    """Upload dbt catalog to OpenMetadata when catalog.json is updated."""
    dbt_resource: DbtCliResource = context.resources.dbt
    target_dir = Path(dbt_resource.project_dir) / "target"

    manifest_path = target_dir / "manifest.json"
    catalog_path = target_dir / "catalog.json"

    context.log.info(
        f"Uploading dbt catalog to OpenMetadata:\n\t- {manifest_path}\n\t- {catalog_path}"
    )

    DbtIngestionOp(
        manifest_path=manifest_path,
        catalog_path=catalog_path,
    ).execute(context)


@job
def upload_dbt_catalog_job():
    upload_dbt_catalog_to_openmetadata()


@sensor(
    name="dbt_catalog_updated_sensor",
    job=upload_dbt_catalog_job,
    minimum_interval_seconds=60,
    default_status=DefaultSensorStatus.RUNNING,
    required_resource_keys={"dbt"},
)
def dbt_catalog_updated_sensor(context: SensorEvaluationContext):
    """Trigger OMD catalog upload when a new container is deployed with an updated catalog.

    The catalog.json is baked into the container image at build time.
    This sensor detects when the file's mtime differs from the last seen value,
    which happens on each new container deployment.
    """
    dbt_resource: DbtCliResource = context.resources.dbt
    catalog_path = Path(dbt_resource.project_dir) / "target" / "catalog.json"

    if not catalog_path.exists():
        context.log.debug(f"File {catalog_path} does not exist, skipping")
        return

    mtime = catalog_path.stat().st_mtime
    last_mtime = float(context.cursor) if context.cursor else 0

    if mtime != last_mtime:
        context.log.info(
            f"catalog.json changed (mtime {last_mtime} -> {mtime}), "
            "triggering OpenMetadata upload"
        )
        yield RunRequest(run_key=f"dbt_catalog_upload:{mtime}")

    context.update_cursor(str(mtime))
