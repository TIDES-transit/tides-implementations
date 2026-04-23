from dagster import get_dagster_logger, ConfigurableResource
import oracledb
from oracledb import Cursor

from .utils import get_secret_client, get_vault_secret

import pyarrow as pa


logger = get_dagster_logger()


class OracleDbResource(ConfigurableResource):
    """Resource for connecting to Oracle database"""

    dsn_secret_name: str
    db_secret_name_user: str
    db_secret_name_password: str
    keyvault_name: str

    def setup_for_execution(self, context):  # have to pass context even if unused
        # try to get password from key vault first (more secure than env vars)
        try:
            secret_client = get_secret_client(self.keyvault_name)

            if secret_client:
                user = get_vault_secret(secret_client, self.db_secret_name_user)
                print(user)
                self._db_user = get_vault_secret(
                    secret_client, self.db_secret_name_user
                )
                self._db_password = get_vault_secret(
                    secret_client, self.db_secret_name_password
                )
                self._dsn = get_vault_secret(secret_client, self.dsn_secret_name)
                if all([self._db_user, self._db_password, self._dsn]):
                    logger.info(
                        "Successfully retrieved credentials and DSN from Key Vault"
                    )
                else:
                    raise Exception(
                        "Failed to retrieve credentials from Key Vault, check permissions are activated and secret name"
                    )
        except Exception as e:
            raise Exception(f"Error accessing Key Vault: {str(e)}")

    def get_client(self):
        return OracleClient(self._db_user, self._db_password, self._dsn)


class OracleClient:
    def __init__(self, username, password, dsn):
        self.username = username
        self.password = password
        self.dsn = dsn
        self.connection = None  # connection is established on demand
        self.query_batch_size = 5000  # Used for querying in batches

    def connect(self):
        """Establish connection to Oracle DB"""
        try:
            self.connection = oracledb.connect(
                user=self.username, password=self.password, dsn=self.dsn
            )
            logger.info("Connected to Oracle database")
            return self.connection
        except Exception as e:
            logger.error(f"Error connecting to Oracle: {str(e)}")
            raise e

    def execute_query_raw(self, query: str) -> Cursor:
        """Execute query and return raw cursor results (use for small scale adhoc queries only)"""
        if not self.connection:
            self.connect()

        cursor = self.connection.cursor()

        cursor.execute(query)

        return cursor

    def execute_query(
        self,
        query: str,
        batch_size: int = 100_000,
    ):
        """Execute query and yield PyArrow table chunks.

        Yields one pa.Table per batch of rows for memory-efficient processing.
        The cursor remains open for the lifetime of the generator.

        Parameters
        ----------
        query : str
            SQL query to execute
        batch_size : int
            Number of rows per yielded chunk (default 100K)

        Yields
        ------
        pa.Table
            One PyArrow table per batch of rows
        """
        if not self.connection:
            self.connect()

        cursor = self.connection.cursor()
        cursor.arraysize = self.query_batch_size

        try:
            cursor.execute(query)
            yield from self._fetch_batched(cursor, batch_size)
        finally:
            cursor.close()

    def _oracle_type_to_pyarrow(self, oracle_type):
        """Map Oracle data types to PyArrow types.

        Oracle cursor.description provides type information where:
        - cursor.description[i][1] is the data type object
        """
        # Map common Oracle types to PyArrow types
        type_map = {
            oracledb.DB_TYPE_VARCHAR: pa.string(),
            oracledb.DB_TYPE_CHAR: pa.string(),
            oracledb.DB_TYPE_NVARCHAR: pa.string(),
            oracledb.DB_TYPE_NCHAR: pa.string(),
            oracledb.DB_TYPE_LONG: pa.string(),
            oracledb.DB_TYPE_NUMBER: pa.float64(),  # Oracle NUMBER can be int or float
            oracledb.DB_TYPE_BINARY_FLOAT: pa.float32(),
            oracledb.DB_TYPE_BINARY_DOUBLE: pa.float64(),
            oracledb.DB_TYPE_DATE: pa.timestamp("us"),
            oracledb.DB_TYPE_TIMESTAMP: pa.timestamp("us"),
            oracledb.DB_TYPE_TIMESTAMP_TZ: pa.timestamp("us", tz="UTC"),
            oracledb.DB_TYPE_TIMESTAMP_LTZ: pa.timestamp("us"),
            oracledb.DB_TYPE_CLOB: pa.string(),
            oracledb.DB_TYPE_BLOB: pa.binary(),
            oracledb.DB_TYPE_RAW: pa.binary(),
        }

        return type_map.get(
            oracle_type, pa.string()
        )  # Default to string for unknown types

    def _fetch_batched(self, cursor, batch_size: int):
        """Yield PyArrow tables one batch at a time from cursor results.

        Uses Oracle cursor metadata to ensure consistent type mapping across all queries.
        This prevents schema mismatches when the same column has different inferred types
        (e.g., Oracle NUMBER can be int64 or float64 depending on values).

        Yields
        ------
        pa.Table
            One PyArrow table per batch of rows. Yields nothing if no rows returned.
        """
        columns = [col[0] for col in cursor.description]
        # Extract Oracle type information from cursor description
        # cursor.description format: (name, type_code, display_size, internal_size, precision, scale, null_ok)
        oracle_types = [col[1] for col in cursor.description]

        while True:
            rows = cursor.fetchmany(batch_size)
            if not rows:
                break

            # Transpose for conversion to a table
            column_data = list(zip(*rows))
            del rows
            arrays = []
            for col_data, oracle_type in zip(column_data, oracle_types):
                # Always use Oracle type mapping for consistency
                pa_type = self._oracle_type_to_pyarrow(oracle_type)
                arrays.append(pa.array(col_data, type=pa_type))
            del column_data

            yield pa.table(arrays, names=columns)

    def close(self):
        """Close the database connection"""
        if self.connection:
            self.connection.close()
            self.connection = None
            logger.info("Oracle connection closed")
