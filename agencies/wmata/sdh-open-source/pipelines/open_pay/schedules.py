from dagster import (
    define_asset_job,
    build_schedule_from_partitioned_job,
    AssetSelection,
)
from .assets import open_pay_tables, lp_evt_txn_recv


# jobs ---------------------------------------------

# Single job for all Open Pay tables since they share the same partition definition and schedule
open_pay_job = define_asset_job(
    "open_pay_job", selection=AssetSelection.assets(open_pay_tables)
)


evt_txn_recv_job = define_asset_job("evt_txn_recv_job", selection=[lp_evt_txn_recv])
# schedules ----------------------------------------------------------

# Single schedule for all Open Pay tables - runs at 8 AM ET
open_pay_schedule = build_schedule_from_partitioned_job(
    open_pay_job,
    hour_of_day=8,
)

# Separate schedule for near realtime table
evt_txn_schedule = build_schedule_from_partitioned_job(evt_txn_recv_job)
