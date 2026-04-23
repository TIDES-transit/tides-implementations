from dagster import (
    DefaultSensorStatus,
    RunRequest,
    SensorEvaluationContext,
    define_asset_job,
    get_dagster_logger,
    sensor,
    AssetKey,
)

from .assets import gtfs_unzip_files, gtfs_tables, feed_hash_partitions_def

logger = get_dagster_logger()


# Job that materializes gtfs_unzip_files + gtfs_tables for a given partition
gtfs_processing_job = define_asset_job(
    name="gtfs_processing_job",
    selection=[gtfs_unzip_files, gtfs_tables],
    description="Process GTFS files into database tables",
    partitions_def=feed_hash_partitions_def,
)


@sensor(
    name="gtfs_new_feed_sensor",
    job=gtfs_processing_job,
    default_status=DefaultSensorStatus.STOPPED,
    minimum_interval_seconds=300,
)
def gtfs_new_feed_sensor(context: SensorEvaluationContext):
    """Watch for new gtfs_zip materializations and trigger processing for the new feed_hash.

    Bridges the unpartitioned gtfs_zip to partitioned downstream assets
    without triggering all partitions.
    """
    gtfs_zip_key = AssetKey(["gtfs_zip"])

    materialization = context.instance.get_latest_materialization_event(gtfs_zip_key)
    if not materialization or not materialization.asset_materialization:
        return

    metadata = materialization.asset_materialization.metadata
    content_hash_meta = metadata.get("content_hash")
    if not content_hash_meta:
        return

    content_hash = content_hash_meta.value

    # Use the materialization timestamp as cursor to avoid re-triggering
    event_timestamp = str(materialization.timestamp)
    if context.cursor == event_timestamp:
        return

    # Verify the partition exists
    existing_partitions = context.instance.get_dynamic_partitions(
        feed_hash_partitions_def.name
    )
    if content_hash not in existing_partitions:
        logger.info(f"Partition {content_hash} not in dynamic partitions, skipping")
        return

    logger.info(f"New gtfs_zip detected for feed_hash: {content_hash}")
    context.update_cursor(event_timestamp)

    yield RunRequest(
        run_key=f"gtfs_process_{content_hash}",
        partition_key=content_hash,
    )
