from pydantic import Field

from dagster import Config, Output, job, op, OpExecutionContext
from dagster_dbt import DbtCliResource

from ..resources.trino import TrinoResource


class DbtSelectConfig(Config):
    select: str = Field(
        default="",
        description=(
            "dbt node selection syntax. Leave empty to run all models. "
            'Examples: "model_name+", "+model_name+", "tag:nightly"'
        ),
    )
    full_refresh: bool = Field(
        default=False,
        description="Set to true to pass --full-refresh and rebuild incremental models from scratch. Set to false for normal incremental behavior.",
    )
    start_time_event: str = Field(
        default="",
        description=(
            "Inclusive start bound for dbt microbatch (maps to --event-time-start). "
            'Leave empty for normal behaviour. Format: "2026-03-11" or "2026-03-11 00:00:00"'
        ),
    )
    stop_time_event: str = Field(
        default="",
        description=(
            "Exclusive end bound for dbt microbatch (maps to --event-time-end). "
            'Leave empty for normal behaviour. Format: "2026-03-12" or "2026-03-12 00:00:00"'
        ),
    )


def _build_dbt_args(command: str, config: DbtSelectConfig) -> list[str]:
    """Build dbt CLI args, appending --event-time-start/end when provided."""
    args = [command]
    if config.select:
        args += ["--select", config.select]

    if config.full_refresh:
        args += ["--full-refresh"]
    if config.start_time_event:
        args += ["--event-time-start", config.start_time_event]
    if config.stop_time_event:
        args += ["--event-time-end", config.stop_time_event]

    return args


@op(required_resource_keys={"dbt", "trino"})
def dbt_run_op(context: OpExecutionContext, config: DbtSelectConfig):
    """Run dbt models (dbt run). Supports dbt selector syntax (e.g. +model_name+).

    Optionally pass start_time_event / stop_time_event to scope microbatch
    incremental models to a time window (maps to --event-time-start/--event-time-end).
    """
    trino: TrinoResource = context.resources.trino
    trino.export_access_token()

    dbt: DbtCliResource = context.resources.dbt
    dbt_cli_task = dbt.cli(
        _build_dbt_args("run", config),
        context=context,
        raise_on_error=False,
    )
    dbt_cli_task.wait()


@op(required_resource_keys={"dbt", "trino"})
def dbt_test_op(context: OpExecutionContext, config: DbtSelectConfig):
    """Run dbt tests (dbt test). Supports dbt selector syntax (e.g. +model_name+).

    Optionally pass start_time_event / stop_time_event to scope microbatch
    incremental models to a time window (maps to --event-time-start/--event-time-end).
    """
    trino: TrinoResource = context.resources.trino
    trino.export_access_token()

    dbt: DbtCliResource = context.resources.dbt
    dbt_cli_task = dbt.cli(
        _build_dbt_args("test", config),
        context=context,
        raise_on_error=False,
    )
    dbt_cli_task.wait()


@job
def dbt_run_job():
    """Manually-triggered job that runs dbt run."""
    dbt_run_op()


@job
def dbt_test_job():
    """Manually-triggered job that runs dbt test."""
    dbt_test_op()


@op(required_resource_keys={"dbt", "trino"})
def generate_dbt_docs(context: OpExecutionContext):
    """Run dbt docs generate to produce catalog.json."""
    trino: TrinoResource = context.resources.trino
    trino.export_access_token()

    dbt: DbtCliResource = context.resources.dbt
    yield from dbt.cli(["parse"], context=context).stream()
    yield from dbt.cli(["docs", "generate"], context=context).stream()
    context.log.info("dbt docs generate completed successfully")
    yield Output(None)


@job
def generate_dbt_descriptions_job():
    generate_dbt_docs()
