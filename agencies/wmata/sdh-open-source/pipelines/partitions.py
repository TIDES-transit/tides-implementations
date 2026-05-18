"""
Environment-specific partition definitions for Dagster assets.

Set dev/stg in .env and pass the asset name to get_partition_def().

For staging (stg) environment:
- end_date/end is omitted so Dagster dynamically calculates partitions
  up to "before current time" (yesterday for daily, last completed interval for time windows)
- This uses Dagster's default end_offset=0 behavior
- See: https://docs.dagster.io/api/dagster/partitions
"""

import os
import datetime
import pytz

from dagster import DailyPartitionsDefinition, TimeWindowPartitionsDefinition

# Environment detection - reuse existing env var
_env = os.environ.get("[Project Name]_ENVIRONMENT", "dev")
ENVIRONMENT = _env if _env in ("dev", "stg") else "dev"

# Staging partition start date (Jan 2025)
# end_date is omitted for stg - Dagster's default end_offset=0 means
# "the last partition ends before the current time" (i.e., yesterday for daily)
STG_START_DATE = datetime.datetime(year=2026, month=2, day=10)
STG_START_DATE_TZ = datetime.datetime(
    year=2026, month=2, day=10, tzinfo=pytz.timezone("America/New_York")
)

# Dev time window settings (narrow windows for testing)
_now = datetime.datetime.now(tz=pytz.timezone("America/New_York"))
_dev_time_window_start = _now.replace(
    minute=(_now.minute // 10) * 10, second=0, microsecond=0
) - datetime.timedelta(hours=2)
_dev_time_window_end = _dev_time_window_start + datetime.timedelta(hours=6)

# Format strings for time window partitions
FAREGATE_TIME_FMT = "%Y-%m-%d %H:%M:%S %z"
OPEN_PAY_TIME_FMT = "%Y-%m-%d %H-%M %z"
REALTIME_BUS_INFO_TIME_FMT = "%Y-%m-%d %H:%M:%S %z"
FARE_TIME_FMT = "%Y-%m-%d %H:%M:%S %z"

PARTITION_DEFINITIONS: dict[
    str, dict[str, DailyPartitionsDefinition | TimeWindowPartitionsDefinition]
] = {
    # Fare partitions - daily
    "faregate_data_mtn": {
        "dev": DailyPartitionsDefinition(
            start_date=datetime.datetime(year=2025, month=7, day=5),
            end_date=datetime.datetime(year=2025, month=8, day=5),
            timezone="America/New_York",
        ),
        "stg": DailyPartitionsDefinition(
            start_date=STG_START_DATE,
            timezone="America/New_York",
        ),
    },
    "faregate_data_orgn": {
        "dev": DailyPartitionsDefinition(
            start_date=datetime.datetime(year=2025, month=7, day=5),
            end_date=datetime.datetime(year=2025, month=8, day=5),
            timezone="America/New_York",
        ),
        "stg": DailyPartitionsDefinition(
            start_date=STG_START_DATE,
            timezone="America/New_York",
        ),
    },
    # FARE partitions - 2-hour intervals
    "fare_sale": {
        "dev": TimeWindowPartitionsDefinition(
            cron_schedule="0 */2 * * *",
            start=datetime.datetime(2019, 7, 4, 0, 0, 0),
            end=datetime.datetime(2019, 8, 4, 0, 0, 0),
            timezone="America/New_York",
            fmt=FARE_TIME_FMT,
        ),
        "stg": TimeWindowPartitionsDefinition(
            cron_schedule="0 */2 * * *",
            start=STG_START_DATE_TZ,
            timezone="America/New_York",
            fmt=FARE_TIME_FMT,
        ),
    },
    "fare_use": {
        "dev": TimeWindowPartitionsDefinition(
            cron_schedule="0 */2 * * *",
            start=datetime.datetime(2019, 7, 4, 0, 0, 0),
            end=datetime.datetime(2019, 8, 4, 0, 0, 0),
            timezone="America/New_York",
            fmt=FARE_TIME_FMT,
        ),
        "stg": TimeWindowPartitionsDefinition(
            cron_schedule="0 */2 * * *",
            start=STG_START_DATE_TZ,
            timezone="America/New_York",
            fmt=FARE_TIME_FMT,
        ),
    },
    # Bus info - Daily
    "bus_info_data": {
        "dev": DailyPartitionsDefinition(
            start_date=datetime.datetime(year=2017, month=6, day=3),
            end_date=datetime.datetime(year=2017, month=8, day=3),
            timezone="America/New_York",
        ),
        "stg": DailyPartitionsDefinition(
            start_date=STG_START_DATE,
            timezone="America/New_York",
        ),
    },
    # Open pay - Daily partitions
    "open_pay_tables": {
        "dev": DailyPartitionsDefinition(
            start_date=datetime.datetime(year=2025, month=8, day=15),
            end_date=datetime.datetime(year=2025, month=9, day=15),
            timezone="America/New_York",
        ),
        "stg": DailyPartitionsDefinition(
            start_date=STG_START_DATE,
            timezone="America/New_York",
        ),
    },
    # Near-realtime openpay uses Time Window at 10-minute intervals
    "lp_evt_txn_recv": {
        "dev": TimeWindowPartitionsDefinition(
            cron_schedule="*/10 * * * *",
            start=_dev_time_window_start,
            end=_dev_time_window_end,
            timezone="America/New_York",
            fmt=OPEN_PAY_TIME_FMT,
        ),
        "stg": TimeWindowPartitionsDefinition(
            cron_schedule="*/10 * * * *",
            start=STG_START_DATE_TZ,
            # end omitted: Dagster dynamically calculates last partition
            # as ending before current time
            timezone="America/New_York",
            fmt=OPEN_PAY_TIME_FMT,
        ),
    },
    # Near-realtime businfo uses Time Window at 2-hour intervals
    "realtime_bus_info_data": {
        "dev": TimeWindowPartitionsDefinition(
            cron_schedule="0 */2 * * *",
            start=datetime.datetime(2023, 4, 10, 16, 0, 0),
            end=datetime.datetime(2023, 4, 20, 22, 0, 0),
            timezone="America/New_York",
            fmt=REALTIME_BUS_INFO_TIME_FMT,
        ),
        "stg": TimeWindowPartitionsDefinition(
            cron_schedule="0 */2 * * *",
            start=STG_START_DATE_TZ,
            timezone="America/New_York",
            fmt=REALTIME_BUS_INFO_TIME_FMT,
        ),
    },
}


def get_partition_def(
    asset_name: str,
) -> DailyPartitionsDefinition | TimeWindowPartitionsDefinition:
    """Get the partition definition for an asset based on current environment.

    Parameters
    ----------
    asset_name : str
        The name of the asset to get the partition definition for.

    Returns
    -------
    DailyPartitionsDefinition | TimeWindowPartitionsDefinition
        The partition definition for the asset in the current environment.

    Raises
    ------
    ValueError
        If the asset name is not found or the environment is not configured.
    """
    if asset_name not in PARTITION_DEFINITIONS:
        raise ValueError(
            f"Unknown asset: {asset_name}. Available assets: {list(PARTITION_DEFINITIONS.keys())}"
        )

    env_partitions = PARTITION_DEFINITIONS[asset_name]
    if ENVIRONMENT not in env_partitions:
        raise ValueError(
            f"No partition defined for '{asset_name}' in '{ENVIRONMENT}' environment. "
            f"Available environments: {list(env_partitions.keys())}"
        )

    return env_partitions[ENVIRONMENT]