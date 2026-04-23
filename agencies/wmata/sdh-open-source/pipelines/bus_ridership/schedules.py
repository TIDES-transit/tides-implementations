from dagster import ScheduleDefinition, define_asset_job
from .assets import d_date_bus_data


# Job for importing calendar data from d_date_bus
calendar_update_job = define_asset_job(
    name="calendar_update_job",
    selection=[d_date_bus_data],
    description="Update calendar data with yesterday's d_date_bus data.",
)


daily_calendar_update_schedule = ScheduleDefinition(
    name="daily_calendar_update",
    cron_schedule="0 1 * * * ",  # 1am daily
    execution_timezone="America/New_York",
    job=calendar_update_job,
    description="Daily update of the calendar data required for downstream date key to date translation.",
)
