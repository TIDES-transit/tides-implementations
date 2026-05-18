import datetime
from typing import Optional

from dagster import (
    AssetCheckExecutionContext,
    AssetKey,
    AssetCheckResult,
    AssetCheckSeverity,
    EventRecordsFilter,
    DagsterEventType,
    get_dagster_logger,
)
from pyiceberg.expressions import EqualTo, GreaterThanOrEqual, LessThan, And

from ..resources.utils import unpack_dagster_asset_metadata
from ..resources.iceberg_writer import IcebergClient

logger = get_dagster_logger()


# Internal helper functions


def _get_partition_key(context: AssetCheckExecutionContext) -> Optional[str]:
    """Extract partition key from context run tags."""
    partition_key = context.run.tags.get("dagster/asset_partition_range_start")
    if not partition_key:
        partition_key = context.run.tags.get("dagster/partition")
    return partition_key


def _get_materialization_metadata(
    context: AssetCheckExecutionContext,
    table_name: str,
    partition_key: str,
) -> Optional[dict]:
    """Fetch metadata from most recent materialization for partition."""
    records = context.instance.get_event_records(
        EventRecordsFilter(
            asset_key=AssetKey([table_name]),
            event_type=DagsterEventType.ASSET_MATERIALIZATION,
            asset_partitions=[partition_key],
        ),
        limit=1,
    )
    if not records:
        return None
    return records[0].asset_materialization.metadata


def _build_row_filter(
    metadata: dict,
) -> Optional[EqualTo | And]:
    """Build PyIceberg filter from materialization metadata."""
    overwrite_strategy = unpack_dagster_asset_metadata(metadata, "overwrite_strategy")
    query_col = unpack_dagster_asset_metadata(metadata, "query_col")

    if not overwrite_strategy or not query_col:
        return None

    if overwrite_strategy == "identity_equals":
        partition_value = unpack_dagster_asset_metadata(metadata, "partition_key")
        if partition_value:
            return EqualTo(query_col, partition_value)

    elif overwrite_strategy in ("date_equals", "time_between"):
        partition_start = unpack_dagster_asset_metadata(metadata, "partition_start")
        partition_end = unpack_dagster_asset_metadata(metadata, "partition_end")
        if partition_start and partition_end:
            start_ts = datetime.datetime.fromisoformat(partition_start)
            end_ts = datetime.datetime.fromisoformat(partition_end)
            return And(
                GreaterThanOrEqual(query_col, start_ts),
                LessThan(query_col, end_ts),
            )

    return None


def _get_record_count(metadata: dict) -> int:
    """Extract and normalize record_count from metadata."""
    record_count = unpack_dagster_asset_metadata(metadata, "record_count")
    if isinstance(record_count, str):
        return int(record_count)
    return record_count if record_count is not None else 0


def _check_result_error(
    message: str,
    table_name: Optional[str] = None,
    partition_key: Optional[str] = None,
) -> AssetCheckResult:
    """Return a failed AssetCheckResult with error metadata."""
    meta = {"error": message}
    if table_name:
        meta["table_name"] = table_name
    if partition_key:
        meta["partition_key"] = partition_key
    return AssetCheckResult(
        passed=False, metadata=meta, severity=AssetCheckSeverity.ERROR
    )


# --- Public check functions ---


def check_daily_partition_populated(
    context: AssetCheckExecutionContext, table_name: str
) -> AssetCheckResult:
    """Check if a table has >= 0 rows for the current daily partition."""
    try:
        partition_key = _get_partition_key(context)
        if not partition_key:
            return _check_result_error(f"No partition key found for {table_name}")

        metadata = _get_materialization_metadata(context, table_name, partition_key)
        if not metadata:
            return _check_result_error(
                f"No materialization found for {table_name} partition {partition_key}",
                partition_key=partition_key,
            )

        record_count = _get_record_count(metadata)
        return AssetCheckResult(
            passed=record_count >= 0,
            metadata={"record_count": record_count, "partition_key": partition_key},
        )

    except Exception as e:
        return _check_result_error(str(e), table_name=table_name)


def check_time_window_partition_populated(
    context: AssetCheckExecutionContext, table_name: str
) -> AssetCheckResult:
    """Check if a table has >= 0 rows for the current time window partition."""
    try:
        partition_key = _get_partition_key(context)
        if not partition_key:
            return _check_result_error(f"No partition key found for {table_name}")

        metadata = _get_materialization_metadata(context, table_name, partition_key)
        if not metadata:
            return _check_result_error(
                f"No materialization found for {table_name} partition {partition_key}",
                partition_key=partition_key,
            )

        record_count = _get_record_count(metadata)
        return AssetCheckResult(
            passed=record_count >= 0,
            metadata={"record_count": record_count, "partition_key": partition_key},
        )

    except Exception as e:
        logger.info(f"Encountered exception: {e}")
        return _check_result_error(str(e), table_name=table_name)


def check_iceberg_row_count_matches(
    context: AssetCheckExecutionContext,
    iceberg_client: IcebergClient,
    table_name: str,
    namespace: str,
) -> AssetCheckResult:
    """Check if Iceberg table row count matches materialization metadata."""
    try:
        partition_key = _get_partition_key(context)
        if not partition_key:
            return _check_result_error(f"No partition key found for {table_name}")

        metadata = _get_materialization_metadata(context, table_name, partition_key)
        if not metadata:
            return _check_result_error(
                f"No materialization found for partition {partition_key}",
                partition_key=partition_key,
            )

        expected_count = _get_record_count(metadata)
        table = iceberg_client.catalog.load_table(f"{namespace}.{table_name}")
        row_filter = _build_row_filter(metadata)

        if row_filter:
            actual_count = len(table.scan(row_filter=row_filter).to_arrow())
        else:
            actual_count = len(table.scan().to_arrow())

        passed = actual_count == expected_count
        overwrite_strategy = unpack_dagster_asset_metadata(
            metadata, "overwrite_strategy"
        )

        return AssetCheckResult(
            passed=passed,
            metadata={
                "expected_count": expected_count,
                "actual_count": actual_count,
                "partition_key": partition_key,
                "overwrite_strategy": overwrite_strategy or "none",
            },
            severity=AssetCheckSeverity.ERROR
            if not passed
            else AssetCheckSeverity.WARN,
        )

    except Exception as e:
        logger.info(f"Iceberg row count check failed: {e}")
        return _check_result_error(str(e), table_name=table_name)
