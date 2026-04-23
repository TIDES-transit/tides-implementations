from dagster import build_schedule_from_partitioned_job, define_asset_job
from .assets import bus_info_data


bus_info_job = define_asset_job("bus_partitioned_job", selection=[bus_info_data])

daily_bus_info_schedule = build_schedule_from_partitioned_job(
    bus_info_job,
    hour_of_day=6,
)