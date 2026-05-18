import time

from dagster import asset, AssetExecutionContext

from ..resources.trino import TrinoResource


@asset(
    name="trino_tables_list",
    group_name="tests",
    description="Tests the connection to Trino using Azure AD JWT authentication",
)
def test_trino_connection(context: AssetExecutionContext, trino: TrinoResource):
    """
    Tests the connection to Trino using Azure AD JWT authentication by executing simple queries.

    Parameters
    ----------
    context : AssetExecutionContext
        Dagster execution context

    Returns
    -------
    dict
        Dictionary containing test results and metadata
    """

    context.log.info("Testing basic Trino connectivity...")
    start_time = time.time()
    try:
        basic_test = trino.execute_query("SELECT 1 AS test")
        basic_test_success = len(basic_test) > 0 and basic_test[0].get("test") == 1
    except Exception as e:
        context.log.error(f"Basic connectivity test failed: {e}")
        basic_test_success = False
        basic_test = []
    basic_test_time = time.time() - start_time

    context.log.info("Listing tables in datahub.public schema...")
    start_time = time.time()
    try:
        tables = trino.execute_query("SHOW TABLES IN datahub.public")
        tables_success = True
    except Exception as e:
        context.log.error(f"Table listing failed: {e}")
        tables_success = False
        tables = []
    tables_test_time = time.time() - start_time

    table_names = []
    if tables and len(tables) > 0:
        if "Table" in tables[0]:
            table_column = "Table"
        elif "table_name" in tables[0]:
            table_column = "table_name"
        else:
            table_column = list(tables[0].keys())[0]

        table_names = [table[table_column] for table in tables]

    return {
        "connection_successful": basic_test_success,
        "basic_test_result": basic_test[0]["test"] if basic_test_success else None,
        "basic_test_time_seconds": round(basic_test_time, 2),
        "tables_query_successful": tables_success,
        "tables_count": len(tables),
        "tables_query_time_seconds": round(tables_test_time, 2),
        "tables": table_names,
    }
