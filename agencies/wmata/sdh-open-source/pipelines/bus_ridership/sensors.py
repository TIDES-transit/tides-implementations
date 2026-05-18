import datetime
from zoneinfo import ZoneInfo
from dagster import (
    sensor,
    define_asset_job,
    DefaultSensorStatus,
    SensorEvaluationContext,
    RunsFilter,
    DagsterRunStatus,
    RunRequest,
    SkipReason,
)

from pipelines.bus_ridership.assets import (
    bus_ridership_fare_data,
    bus_ridership_lp_data,
)

today = datetime.datetime.now(tz=ZoneInfo("America/New_York")).date()

end_of_yest = datetime.datetime.now(tz=ZoneInfo("America/New_York")).replace(
    hour=23, minute=59, second=59, microsecond=999
) - datetime.timedelta(days=1)

bus_ridership_job = define_asset_job(
    name="bus_ridership_daily",
    selection=[bus_ridership_fare_data, bus_ridership_lp_data],
)


# TODO - move this out to a sensors.py file
@sensor(
    job=bus_ridership_job,
    minimum_interval_seconds=60,
    default_status=DefaultSensorStatus.STOPPED,  # should be changed later
    required_resource_keys={
        "bus_ridership_db",
        "bus_ridership_storage",
    },
)
def bus_ridership_sensor(context: SensorEvaluationContext):
    """
    Launches an execution for today's data for the bus ridership asset if the job hasn't already been successful today.

    We use dagster's internal API to check job status to see if a successful run has been executed since yesterday's end. If no successful job launches are detected, the sensor launches the job.
    """
    database_client = context.resources.bus_ridership_db.get_client()

    # Accesses the latest successful run via a dagster RunsFilter - assumes created_after is exclusive though no docs to support this
    success_filter = RunsFilter(
        job_name="bus_ridership_daily",
        statuses=[DagsterRunStatus.SUCCESS],
        created_after=(end_of_yest),
    )
    success_status = context.instance.get_run_records(filters=success_filter)

    # Accesses any record denoting an in progress run
    # Note: This query doesn't need an order by/limit because, in dagster, the status of a job run is tracked by updating its associated RunRecord rather than creating a new record each time a run's state changes
    running_filter = RunsFilter(
        job_name="bus_ridership_daily",
        statuses=[
            DagsterRunStatus.QUEUED,
            DagsterRunStatus.NOT_STARTED,
            DagsterRunStatus.STARTING,
            DagsterRunStatus.STARTED,
        ],
    )
    running_status = context.instance.get_run_records(filters=running_filter)

    # If the job hasn't yet been run successfully today (and the calendar data is ready), then attempt a load; otherwise, do nothing
    if not success_status and not running_status:
        query = "select count(*) from vendor_2.job_log where trunc(start_date) = trunc(sysdate) and end_date is not null and job_status not like '%error%'"

        cursor = database_client.execute_query_raw(query)

        row = cursor.fetchone()

        if row is not None and row[0] > 0:
            # Determine partition window based on the current date: 8 days ago -> yesterday
            start_partition_key = str(today - datetime.timedelta(days=8))
            end_partition_key = str(today - datetime.timedelta(days=1))

            # Return a RunRequest for the given range
            return RunRequest(
                tags={
                    "dagster/asset_partition_range_start": start_partition_key,
                    "dagster/asset_partition_range_end": end_partition_key,
                }
            )

        cursor.close()
        return

    return SkipReason("Run already completed successfully today.")