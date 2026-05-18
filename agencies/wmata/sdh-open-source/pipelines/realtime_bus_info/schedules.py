from dagster import (
    define_asset_job,
    build_schedule_from_partitioned_job,
    schedule,
    RunRequest,
    ScheduleEvaluationContext,
)
from .assets import realtime_bus_info_data


realtime_bus_info_job = define_asset_job(
    "realtime_bus_partitioned_job", selection=[realtime_bus_info_data]
)


realtime_bus_info_schedule = build_schedule_from_partitioned_job(
    realtime_bus_info_job
)


@schedule(
    job_name="daily_routes_job",
    cron_schedule="0 6 * * *",
    execution_timezone="America/New_York",
)
def daily_routes_schedule(context: ScheduleEvaluationContext):
    date = int(context.scheduled_execution_time.strftime("%Y%m%d"))
    return RunRequest(
        run_config={"ops": {"pull_daily_routes": {"config": {"date": date}}}}
    )