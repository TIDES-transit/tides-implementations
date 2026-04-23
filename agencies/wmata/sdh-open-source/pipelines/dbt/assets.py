from collections.abc import Mapping
from datetime import datetime, timedelta
from typing import Any

from dagster import (
    AssetCheckResult,
    AssetCheckSeverity,
    AssetExecutionContext,
    AutomationCondition,
)

from dagster_dbt import DagsterDbtTranslator, DbtCliResource, dbt_assets

from ..resources.trino import TrinoResource
from ..openmetadata.common import OpenMetadataResource
from ..openmetadata.dbt import DbtIngestionOp
from .project import warehouse_dbt_project


GTFS_GROUPS = {"bronze_gtfs", "silver_gtfs"}


class CustomDbtTranslator(DagsterDbtTranslator):
    def get_automation_condition(
        self, dbt_resource_props: Mapping[str, Any]
    ) -> AutomationCondition | None:
        # GTFS-downstream models are triggered by gtfs_dbt_sensor, not automation.
        group = dbt_resource_props.get("meta", {}).get("dagster", {}).get("group", "")
        if group in GTFS_GROUPS:
            return None
        return AutomationCondition.eager().without(
            ~AutomationCondition.any_deps_missing()
        )


def setup_vars(context: AssetExecutionContext) -> list[str]:
    """Build --event-time-start/end args from the upstream Dagster partition.

    Supports both:
    - TimeWindowPartitionsDefinition (e.g. 2-hour realtime windows)
    - DailyPartitionsDefinition (partition_key is a date string like "2026-03-11")

    Returns an empty list when run without partitions (e.g. manual subset runs).
    """
    dbt_vars: list[str] = []

    try:
        tw = context.partition_time_window
        if tw:
            dbt_vars += ["--event-time-start", tw.start.strftime("%Y-%m-%d %H:%M:%S")]
            dbt_vars += ["--event-time-end", tw.end.strftime("%Y-%m-%d %H:%M:%S")]
            return dbt_vars
    except Exception:
        pass

    try:
        key = context.partition_key
        if key:
            start = datetime.strptime(key, "%Y-%m-%d")
            yesterday = datetime.now().replace(
                hour=0, minute=0, second=0, microsecond=0
            ) - timedelta(days=1)
            if start > yesterday:
                return dbt_vars  # Don't process today or future partitions
            dbt_vars += ["--event-time-start", key]
            dbt_vars += ["--event-time-end", yesterday.strftime("%Y-%m-%d")]
    except Exception:
        pass

    return dbt_vars


@dbt_assets(
    manifest=warehouse_dbt_project.manifest_path,
    dagster_dbt_translator=CustomDbtTranslator(),
)
def warehouse_dbt_assets(
    context: AssetExecutionContext,
    dbt: DbtCliResource,
    trino: TrinoResource,
    openmetadata_api: OpenMetadataResource,
):
    """dagster-dbt integration to render dbt models on the dag

    Parameters
    ----------
    context : AssetExecutionContext
        Dagster asset execution context
    dbt : DbtCliResource
        dbt CLI class
    trino : TrinoResource
        Trino resource to connect to trino db engine
    openmetadata_api : OpenMetadataResource
        Used by DbtIngestionOp to upload run results
    """
    # Refresh Trino JWT token in os.environ, dbt.cli will pass it down
    trino.export_access_token()

    dbt_cli_task = dbt.cli(["build"] + setup_vars(context), context=context)

    try:
        for event in dbt_cli_task.stream():
            # dagster-dbt sets passed=False for warn-severity checks; treat warns as passing
            if (
                isinstance(event, AssetCheckResult)
                and event.severity == AssetCheckSeverity.WARN
            ):
                yield event._replace(passed=True)
            else:
                yield event
    finally:
        # Upload run results to OpenMetadata regardless of build outcome
        manifest_path = dbt_cli_task.target_path.joinpath("manifest.json")
        run_results_path = dbt_cli_task.target_path.joinpath("run_results.json")

        context.log.info(
            f"Uploading to OpenMetadata:\n\t- {manifest_path}\n\t- {run_results_path}"
        )
        DbtIngestionOp(
            manifest_path=manifest_path,
            run_results_path=run_results_path,
            include_tags=False,
            update_descriptions=False,
            update_owners=False,
        ).execute(context)
