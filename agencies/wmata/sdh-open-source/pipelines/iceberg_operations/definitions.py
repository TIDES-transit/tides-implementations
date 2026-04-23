from dagster import Definitions

from .ops import _truncate_job, _expire_job, _orphan_job, _optimize_job


assets = []
jobs = [
    _truncate_job,
    _expire_job,
    _orphan_job,
    _optimize_job,
]

# main entry point for the dagster pipeline
defs = Definitions(
    assets=assets,
    jobs=jobs,
)
