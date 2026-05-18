from dagster import Definitions
from dagster_dbt import DbtCliResource

from .assets import warehouse_dbt_assets
from .project import warehouse_dbt_project
from .schedules import dbt_schedule
from .sensors import (
    dbt_automation_sensor,
    dbt_catalog_updated_sensor,
    gtfs_dbt_refresh_job,
    gtfs_dbt_sensor,
    upload_dbt_catalog_job,
)
from .jobs import dbt_run_job, dbt_test_job, generate_dbt_descriptions_job


jobs = [
    upload_dbt_catalog_job,
    gtfs_dbt_refresh_job,
    dbt_run_job,
    dbt_test_job,
    generate_dbt_descriptions_job,
]

schedules = [dbt_schedule]
sensors = [
    dbt_catalog_updated_sensor,
    dbt_automation_sensor,
    gtfs_dbt_sensor,
]

defs = Definitions(
    assets=[warehouse_dbt_assets],
    schedules=schedules,
    sensors=sensors,
    jobs=jobs,
    resources={
        "dbt": DbtCliResource(project_dir=warehouse_dbt_project),
    },
)
