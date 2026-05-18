import dagster as dg
from ..resources.trino import TrinoResource

logger = dg.get_dagster_logger()

# Base config shared by all single-table operations
BASE_CONFIG = {
    "schema": dg.Field(
        str,
        default_value="target_schema",
        description="Schema name to run the operation on",
    ),
    "table": dg.Field(
        str,
        default_value="target_table",
        description="Table name to run the operation on",
    ),
}

# Extended configs for specific operations
EXPIRE_CONFIG = {
    **BASE_CONFIG,
    "older_than_days": dg.Field(
        int,
        default_value=14,
        description="Threshold to use for snapshot retention - expires snapshots older than this date",
    ),
}

OPTIMIZE_CONFIG = {
    **BASE_CONFIG,
    "file_size_threshold_mb": dg.Field(
        int,
        default_value=128,
        description="File size threshold (in mb) to consolidate table files",
    ),
}


# Op definitions -------------------------------------------------
# These + the jobs are prepended with a _ to visually sort within the jobs list
@dg.op(config_schema=BASE_CONFIG)
def _truncate_table(context, trino: TrinoResource):
    """Truncate table data - deletes records but preserves structure."""
    config = context.op_config
    query = f"TRUNCATE TABLE {trino.catalog}.{config['schema']}.{config['table']}"

    logger.info(f"Truncating data from {config['schema']}.{config['table']}")
    results = trino.execute_query(query)
    logger.info("Truncate completed.")
    return results


@dg.op(config_schema=EXPIRE_CONFIG)
def _expire_snapshots_op(context, trino: TrinoResource):
    """Expire old snapshots using Trino's expire_snapshots procedure."""
    config = context.op_config
    query = f"""
        ALTER TABLE {trino.catalog}.{config["schema"]}.{config["table"]}
        EXECUTE expire_snapshots(
            retention_threshold => '{config["older_than_days"]}d'
        )
    """

    logger.info(f"Expiring snapshots for {config['schema']}.{config['table']}")
    logger.info(
        f"Snapshots older than {config['older_than_days']} days will be expired"
    )
    results = trino.execute_query(query)
    logger.info("Expire snapshots completed.")
    return results


@dg.op(config_schema=EXPIRE_CONFIG)
def _remove_orphan_files_op(context, trino: TrinoResource):
    """Remove orphan files from table storage."""
    config = context.op_config
    query = f"""
        ALTER TABLE {trino.catalog}.{config["schema"]}.{config["table"]}
        EXECUTE remove_orphan_files(
            retention_threshold => '{config["older_than_days"]}d'
        )
    """

    logger.info(f"Removing orphan files for {config['schema']}.{config['table']}")
    logger.info(f"Files older than {config['older_than_days']} days")
    results = trino.execute_query(query)
    logger.info("Remove orphan files completed.")
    return results


@dg.op(config_schema=OPTIMIZE_CONFIG)
def _optimize_table_op(context, trino: TrinoResource):
    """Optimize table files by consolidating small files."""
    config = context.op_config
    query = f"""
        ALTER TABLE {trino.catalog}.{config["schema"]}.{config["table"]}
        EXECUTE optimize(
            file_size_threshold => '{config["file_size_threshold_mb"]}MB'
        )
    """

    logger.info(f"Optimizing table {config['schema']}.{config['table']}")
    logger.info(f"Target file size threshold: {config['file_size_threshold_mb']}MB")
    results = trino.execute_query(query)
    logger.info("Table optimization completed.")
    return results


# Job definitions ---------------------------------------------------------
# These + the ops are prepended with a _ to visually sort within the jobs list
@dg.job(
    description="Truncate table data - deletes records (preserved in snapshot) but preserves structure.",
    config={
        "ops": {
            "_truncate_table": {
                "config": {"schema": "target_schema", "table": "target_table"}
            }
        }
    },
    tags={
        "category": "data_cleanup",
        "operation": "destructive",
    },
)
def _truncate_job():
    _truncate_table()


@dg.job(
    description="Expire old snapshots.",
    config={
        "ops": {
            "_expire_snapshots_op": {
                "config": {
                    "schema": "target_schema",
                    "table": "target_table",
                    "older_than_days": 14,
                }
            }
        }
    },
    tags={
        "category": "maintenance",
        "operation": "cleanup",
    },
)
def _expire_job():
    _expire_snapshots_op()


@dg.job(
    description="Remove orphaned files that are no longer referenced by any table snapshots.",
    config={
        "ops": {
            "_remove_orphan_files_op": {
                "config": {
                    "schema": "target_schema",
                    "table": "target_table",
                    "older_than_days": 14,
                }
            }
        }
    },
    tags={"category": "maintenance", "operation": "cleanup", "level": "advanced"},
)
def _orphan_job():
    _remove_orphan_files_op()


@dg.job(
    description="Optimize table performance by consolidating small files into larger ones.",
    config={
        "ops": {
            "_optimize_table_op": {
                "config": {
                    "schema": "target_schema",
                    "table": "target_table",
                    "file_size_threshold_mb": 128,
                }
            }
        }
    },
    tags={
        "category": "maintenance",
        "operation": "optimization",
    },
)
def _optimize_job():
    _optimize_table_op()
