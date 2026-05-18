from dagster_dbt import build_schedule_from_dbt_selection
from .assets import warehouse_dbt_assets

dbt_schedule = build_schedule_from_dbt_selection(
    [warehouse_dbt_assets],
    job_name="materialize_dbt_models",
    cron_schedule="0 1 * * *",
    dbt_select="fqn:*",
    execution_timezone="America/New_York",
)
