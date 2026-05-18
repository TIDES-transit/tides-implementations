from dagster import ScheduleDefinition, define_asset_job
from .assets import gtfs_zip


# Job for downloading GTFS data - this is the only scheduled job needed
# Processing will happen automatically via auto-materialization
gtfs_download_job = define_asset_job(
    name="gtfs_download_job",
    selection=[gtfs_zip],
    description="Download GTFS data from API and upload to blob storage",
)


daily_gtfs_download_schedule = ScheduleDefinition(
    name="daily_gtfs_download",
    cron_schedule="0 4 * * * ",  # 4am daily
    execution_timezone="America/New_York",
    job=gtfs_download_job,
    description="Daily download of Bus GTFS data - downstream asset materialization happens after this runs.",
)
