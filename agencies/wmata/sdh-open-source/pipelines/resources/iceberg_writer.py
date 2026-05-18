from __future__ import annotations

import datetime
from typing import Any, Callable, Dict, List, Optional
import time

from dagster import get_dagster_logger, ConfigurableResource, AssetExecutionContext
import pyarrow as pa
import pandas as pd

from pyiceberg.catalog import load_catalog
from pyiceberg.catalog.rest import RestCatalog
from pyiceberg.table import Table
from pyiceberg.expressions import EqualTo, GreaterThanOrEqual, LessThan, And
from pyiceberg.transforms import (
    DayTransform,
    MonthTransform,
    YearTransform,
    HourTransform,
)

from pyiceberg.exceptions import (
    NoSuchTableError,
    NamespaceAlreadyExistsError,
    CommitFailedException,
    TableAlreadyExistsError,
)

logger = get_dagster_logger()


class IcebergResource(ConfigurableResource):
    """Resource for Iceberg operations via Lakekeeper instance.

    Parameters
    ----------
    lakekeeper_url: str
        Base url for lakekeeper service
    lakekeeper_oauth_scope: str
        OAuth scope for lakekeeper service
    warehouse_name: str
        Warehouse name for lakekeeper service
    catalog_name: str
        Name to use for catalog read/write operations
    client_id: str
        client id for user to connect to iceberg service
    client_secret: str
        client sercret for user to connect to iceberg service
    tenant_id: str
        tenant_id of service for oauth
    container_name: str
        Azure storage container name
    storage_account: str
        Azure storage account name
    force_clean_schema: bool
        whether to force clean schema - mostly only useful to force to str
    """

    lakekeeper_url: str
    lakekeeper_oauth_scope: str
    warehouse_name: str
    catalog_name: str
    client_id: str
    client_secret: str
    tenant_id: str
    container_name: str
    storage_account: str
    force_clean_schema: bool

    def setup_for_execution(self, context):
        """Initialize components during resource setup. Defer connections until client runs."""
        logger.info(
            f"Initialized IcebergResource for connection to {self.warehouse_name}"
        )

    def get_client(self):
        """Return a client for Iceberg operations."""
        return IcebergClient(
            lakekeeper_url=self.lakekeeper_url,
            lakekeeper_oauth_scope=self.lakekeeper_oauth_scope,
            warehouse_name=self.warehouse_name,
            catalog_name=self.catalog_name,
            client_id=self.client_id,
            client_secret=self.client_secret,
            tenant_id=self.tenant_id,
            container_name=self.container_name,
            storage_account=self.storage_account,
            force_clean_schema=self.force_clean_schema,
        )


class IcebergClient:
    # Retry configuration for concurrent write handling
    MAX_RETRIES = 3
    BASE_BACKOFF_SECONDS = 0.1

    def __init__(
        self,
        lakekeeper_url: str,
        lakekeeper_oauth_scope: str,
        warehouse_name: str,
        catalog_name: str,
        client_id: str,
        client_secret: str,
        tenant_id: str,
        container_name: str,
        storage_account: str,
        # for some data (see: GTFS) we want to cast everything to nullable str regardless of potential types
        force_clean_schema: bool = False,
    ):
        """Client for writing data to iceberg

        Parameters
        ----------
        lakekeeper_url : str
            URL of lakekeeper/iceberg service
        lakekeeper_oauth_scope: str
            OAuth scope for lakekeeper service
        warehouse_name : str
            warehouse to write to
        catalog_name : str
            catalog to write to
        client_id : str
            client_id of user to connect to iceberg service via oauth
        client_secret : str
            client_secret of user to connect to iceberg service via oauth
        tenant_id : str
            tenant_id to use for token generation in conjunction with client_id:client_secret
        force_clean_schema : bool, optional
            if schema should be force cleaned to all nullable str, by default False
        """
        """Initialize Iceberg client."""
        self.lakekeeper_url = lakekeeper_url
        self.lakekeeper_oauth_scope = lakekeeper_oauth_scope
        self.warehouse_name = warehouse_name
        self.catalog_name = catalog_name
        self.client_id = client_id  # lakekeeper-dagster id
        self.client_secret = client_secret  # lakekeeper-dagster secret
        self.tenant_id = tenant_id  # dagster service tenant
        self.force_clean_schema = force_clean_schema
        self.container_name = container_name
        self.storage_account = storage_account

        self.catalog = self.connect_to_catalog()

    def _ensure_namespace(self, namespace: str) -> None:
        """Ensure namespace exists."""
        try:
            self.catalog.create_namespace(namespace)
            logger.info(f"Created namespace: {namespace}")
        except NamespaceAlreadyExistsError:
            logger.debug(f"Namespace already exists: {namespace}")
        except Exception as e:
            logger.warning(f"Error with namespace {namespace}: {str(e)}")

    def connect_to_catalog(self) -> RestCatalog:
        """Connect to iceberg catalog"""
        logger.info(f"""Initiating connection with:
                    - catalog_name: {self.catalog_name}
                    - warehouse_name: {self.warehouse_name}
                    - lakekeeper_url: {self.lakekeeper_url}
                    """)
        try:
            catalog = load_catalog(
                self.catalog_name,
                **{
                    "type": "rest",
                    "uri": f"{self.lakekeeper_url}/catalog",
                    "credential": f"{self.client_id}:{self.client_secret}",
                    # dagster tenant
                    "oauth2-server-uri": rf"https://login.microsoftonline.com/{self.tenant_id}/oauth2/v2.0/token",
                    "scope": self.lakekeeper_oauth_scope,
                    "warehouse": self.warehouse_name,
                },
            )

            logger.info(f"Connecting to catalog {self.catalog_name}")
            return catalog
        except Exception as e:
            logger.error(
                f"Error connecting to catalog at {self.lakekeeper_url}: {str(e)}"
            )
            raise

    @staticmethod
    def _convert_to_pyarrow(data: pa.Table | pd.DataFrame) -> pa.Table:
        """Convert input data to PyArrow Table."""
        if isinstance(data, pd.DataFrame):
            return pa.Table.from_pandas(data, preserve_index=False)
        elif isinstance(data, pa.Table):
            return data
        else:
            raise TypeError(f"Unsupported data type: {type(data)}")

    def _write_with_retry(
        self,
        table: Table,
        write_fn: Callable,
        data: pa.Table,
        operation_name: str,
        **kwargs,
    ) -> None:
        """
        Execute a write operation with retry logic for concurrent conflicts.

        Mostly to facilitate backfill operations without having to throttle.

        In PyIceberg concurrent writes may fail with CommitFailedException.
        This retries with backoff to handle these conflicts and refreshes snapshot.
        """
        for attempt in range(self.MAX_RETRIES):
            try:
                table.refresh()
                write_fn(data, **kwargs)
                return
            except CommitFailedException as e:
                if attempt < self.MAX_RETRIES - 1:
                    wait_time = self.BASE_BACKOFF_SECONDS * (2**attempt)
                    logger.info(
                        f"Concurrent write during {operation_name} "
                        f"(attempt {attempt + 1}/{self.MAX_RETRIES}), "
                        f"retrying after {wait_time}s..."
                    )
                    time.sleep(wait_time)
                else:
                    logger.error(
                        f"Failed {operation_name} after {self.MAX_RETRIES} attempts: {str(e)}"
                    )
                    raise

    def _create_table(
        self,
        table_id: str,
        schema: pa.Schema,
        location: str,
        partition_col: Optional[str] = None,
        transform_type: Optional[str] = None,
    ) -> Table:
        """Create a new Iceberg table with race condition protection.

        When multiple backfill jobs run concurrently, they may all try to create
        the same table. This method catches TableAlreadyExistsError and loads
        the existing table instead.
        """
        try:
            table = self.catalog.create_table(
                identifier=table_id,
                schema=schema,
                properties={
                    "write.format.default": "parquet",
                    "write.parquet.compression-codec": "snappy",
                    "write.metadata.compression-codec": "gzip",
                },
                location=location,
            )
            logger.info(f"Created new table {table_id}")

            # Add partitioning if specified
            if partition_col:
                partition_transforms = {
                    "day": DayTransform(),
                    "month": MonthTransform(),
                    "year": YearTransform(),
                    "hour": HourTransform(),
                }

                with table.update_spec() as spec_update:
                    if transform_type == "identity":
                        spec_update.add_identity(partition_col)
                    elif transform_type in partition_transforms:
                        spec_update.add_field(
                            source_column_name=partition_col,
                            transform=partition_transforms[transform_type],
                            partition_field_name=f"{partition_col}_{transform_type}",
                        )
                    else:
                        logger.warning(
                            f"Unknown transform '{transform_type}', defaulting to identity"
                        )
                        spec_update.add_identity(partition_col)

                logger.info(
                    f"Added {transform_type} partition on column: {partition_col}"
                )

            return table

        except TableAlreadyExistsError:
            # Another job created the table - may be the case with batched runs/backfills
            logger.info(
                f"Table {table_id} was created by another job, loading existing table"
            )
            table = self.catalog.load_table(table_id)
            table.refresh()
            return table

    def _generate_table_location(
        self,
        schema_name: str,
        table_name: str,
    ) -> str:
        """Generate table location based on name and identity
        Nostly used for manual inspection of file strcutres.
        """
        # Use the known ABFSS base path for your storage account
        base_path = (
            f"abfss://{self.container_name}@{self.storage_account}.dfs.core.windows.net"
        )

        path_components = [base_path, schema_name, table_name]

        # Basically exports as abfss://{container}@{account}.dfs.core.windows.net/{warehouse}}/{namespace}/{hash}/{table}
        # in storage this is storage account > container > warehouse > namespace > hash > table
        location = "/".join(path_components)
        logger.info(f"Generated table location: {location}")
        return location

    def clean_column_schema(self, table: pa.Table) -> pa.Table:
        """Clean and standardize column types for null columns (force all to string)."""
        schema_fixes = []
        for field in table.schema:
            schema_fixes.append(pa.field(field.name, pa.string(), nullable=True))

        fixed_schema = pa.schema(schema_fixes)
        return table.cast(fixed_schema)

    def handle_oracle_data_types(self, table: pa.Table) -> pa.Table:
        """Handle Oracle-specific data type conversions for Iceberg compatibility.

        This method addresses common Oracle -> PyArrow -> Iceberg conversion issues:
        - Converts pa.date64() to pa.timestamp('us') (Iceberg standard for datetime)
        - Converts large string and large binary to string/binary
        - Ensures all columns are nullable
        - Preserves Oracle types for fully null columns (already typed by oracle_db.py)
        """
        # Build schema with Iceberg-compatible types
        schema_fixes = []
        for field in table.schema:
            if pa.types.is_date64(field.type):
                # Convert date64 to timestamp(us) for Iceberg compatibility
                # Iceberg doesn't support date64, use timestamp instead
                schema_fixes.append(
                    pa.field(field.name, pa.timestamp("us"), nullable=True)
                )
                logger.info(
                    f"Converting column '{field.name}' from date64 to timestamp(us)"
                )
            elif pa.types.is_large_string(field.type):
                # Convert large_string to regular string
                schema_fixes.append(pa.field(field.name, pa.string(), nullable=True))
                logger.info(
                    f"Converting column '{field.name}' from large_string to string"
                )
            elif pa.types.is_large_binary(field.type):
                # Convert large_binary to regular binary
                schema_fixes.append(pa.field(field.name, pa.binary(), nullable=True))
                logger.info(
                    f"Converting column '{field.name}' from large_binary to binary"
                )
            else:
                # Keep the type from Oracle
                schema_fixes.append(pa.field(field.name, field.type, nullable=True))
        try:
            fixed_schema = pa.schema(schema_fixes)
            # Cast table to new schema - this handles the type conversions
            fixed_table = table.cast(fixed_schema)
            logger.info("Successfully applied Oracle data type conversions for Iceberg")
            return fixed_table
        except Exception as e:
            logger.error(f"Failed to apply Oracle data type conversions: {e}")
            raise

    def _create_overwrite_filter(
        self,
        overwrite_strategy: str,
        query_col: str,
        dagster_context: Optional[AssetExecutionContext],
    ) -> Optional[EqualTo | And]:
        """Create overwrite filter based on strategy and Dagster context.

        Overwrite filter returns the rows to delete (e.g., matching feed hash, date is equal to a specific date)

        Parameters
        ----------
        overwrite_strategy : str
            Strategy for overwriting data: 'identity_equals', 'date_equals', 'time_between', or 'full'
        query_col : str
            Column to use for filtering
        dagster_context : AssetExecutionContext, optional
            Dagster context containing partition information

        Returns
        -------
        Filter expression or None for full overwrites
        """
        if overwrite_strategy == "identity_equals":
            # Exact match on partition column (e.g., for identity partitions)
            if not dagster_context or not hasattr(dagster_context, "partition_key"):
                raise ValueError(
                    "identity_equals strategy requires dagster_context with partition_key"
                )
            return EqualTo(query_col, dagster_context.partition_key)

        elif overwrite_strategy == "date_equals":
            # Date-based filtering for daily partitions
            if not dagster_context or not hasattr(dagster_context, "partition_key"):
                raise ValueError(
                    "date_equals strategy requires dagster_context with partition_key"
                )

            # Parse partition key (format: YYYY-MM-DD)
            dt = datetime.datetime.strptime(dagster_context.partition_key, "%Y-%m-%d")
            start_of_day = dt.replace(hour=0, minute=0, second=0, microsecond=0)
            end_of_day = start_of_day + datetime.timedelta(days=1)

            return And(  # Using this to work with a datetime col
                #  since that's typically what we have
                GreaterThanOrEqual(query_col, start_of_day),
                LessThan(query_col, end_of_day),
            )

        elif overwrite_strategy == "time_between":
            # Time range filtering (for time-based partitions)
            if not dagster_context or not hasattr(
                dagster_context, "partition_time_window"
            ):
                raise ValueError(
                    "time_between strategy requires dagster_context with partition_time_window"
                )

            return And(
                GreaterThanOrEqual(
                    query_col, dagster_context.partition_time_window.start
                ),
                LessThan(query_col, dagster_context.partition_time_window.end),
            )

        elif overwrite_strategy == "full":
            # Full table overwrite, no filter - generally not used but implementing to be explicit
            return None

        else:
            raise ValueError(
                f"Invalid overwrite_strategy: {overwrite_strategy}. "
                f"Must be one of: 'identity_equals', 'date_equals', 'time_between', 'full'"
            )

    def _perform_overwrite(
        self,
        table: Table,
        cleaned_data: pa.Table,
        partition_col: Optional[str],
        partition_value: Optional[str],
    ) -> None:
        """Legacy method for backward compatibility. Use write_table with overwrite_strategy instead."""
        if partition_col and partition_value is not None:
            # Partition-specific overwrite using filter
            overwrite_filter = EqualTo(partition_col, partition_value)
            table.overwrite(cleaned_data, overwrite_filter=overwrite_filter)
            logger.info(
                f"Overwrote partition {partition_col}={partition_value} with {len(cleaned_data)} rows"
            )
        else:
            # Full table overwrite when no partition filtering specified
            table.overwrite(cleaned_data)
            logger.info(f"Overwrote entire table with {len(cleaned_data)} rows")

    def write_table(
        self,
        table_name: str,
        schema_name: str,
        pa_table: pa.Table,
        partition_col: Optional[str] = None,
        partition_value: Optional[str] = None,
        mode: str = "append",
        table_prefix: Optional[str] = None,
        transform_type: Optional[str] = None,
        # New parameters for overwrite strategy support
        overwrite_strategy: Optional[str] = None,
        query_col: Optional[str] = None,
        dagster_context: Optional[AssetExecutionContext] = None,
        **kwargs,
    ) -> Dict[str, Any]:
        """Write data to Iceberg table with flexible partitioning and overwrite strategies.

        Parameters
        ----------
        table_name : str
            Name of the Iceberg table
        schema_name : str
            Schema/namespace for the table
        pa_table : pa.Table
            PyArrow table containing the data to write
        partition_col : str, optional
            Column to partition the table on
        partition_value : str, optional
            Legacy parameter for backward compatibility
        mode : str, default 'append'
            Write mode ('append' or 'overwrite')
        table_prefix : str, optional
            Prefix to add to table name
        transform_type : str, optional
            Type of partitioning transform ('identity', 'day', 'month', 'year', 'hour')
        overwrite_strategy : str, optional
            Strategy for overwriting data: 'identity_equals', 'date_equals', 'time_between', or 'full'
            Required when mode='overwrite' and using Dagster partitions
        query_col : str, optional
            Column to use for overwrite filtering (defaults to partition_col)
        dagster_context : AssetExecutionContext, optional
            Dagster context for partition-aware operations
        """
        # Lakekeeper namespaces are always lowercase
        schema_name = schema_name.lower()

        if table_prefix:
            table_name = f"{table_prefix}_{table_name}"
        table_id = f"{schema_name}.{table_name}"

        # Make sure the schema exists before writing
        self._ensure_namespace(schema_name)

        try:  # Load existing table - if we get an exception/doesn't exist then create new table
            # Prepare data for Iceberg
            if self.force_clean_schema:
                # Force all columns to string (used for GTFS data)
                cleaned = self.clean_column_schema(pa_table)
            else:
                # Handle Oracle-specific type conversions for Iceberg compatibility
                cleaned = self.handle_oracle_data_types(pa_table)
            del pa_table

            # Set default query_col if not provided
            if not query_col and partition_col:
                query_col = partition_col

            # Warn if overwrite_strategy provided but mode is append
            if mode == "append" and overwrite_strategy:
                logger.warning("overwrite_strategy is ignored when mode='append'")

            logger.info(f"Writing {len(cleaned)} rows to {table_id}")
            logger.info(f"Partitioning data using {partition_col}")

            table = self.catalog.load_table(table_id)
            logger.info(f"Found existing table {table_id}")

            # Refresh to get latest snapshot before operations
            table.refresh()

            if table is not None and table.schema() is not None:
                existing_fields = {field.name for field in table.schema().fields}
                new_fields = set(cleaned.schema.names)

                added_fields = new_fields - existing_fields
                removed_fields = existing_fields - new_fields

                if added_fields:
                    raise ValueError(
                        f"Schema mismatch: new fields {added_fields} not in existing table. "
                        "Schema evolution not yet supported."
                    )
                if removed_fields:
                    logger.warning(
                        f"Fields in table but not in new data: {removed_fields}"
                    )

                if mode == "append":
                    self._write_with_retry(
                        table=table,
                        write_fn=table.append,
                        data=cleaned,
                        operation_name="append",
                    )
                    logger.info(f"Appended {len(cleaned)} rows")

                else:  # mode == "overwrite"
                    overwrite_filter = None
                    if overwrite_strategy:
                        overwrite_filter = self._create_overwrite_filter(
                            overwrite_strategy, query_col, dagster_context
                        )

                    # Log count of rows to be overwritten
                    if overwrite_filter:
                        existing_count = self._get_overwrite_count(
                            table, overwrite_filter
                        )
                        if existing_count > 0:
                            logger.info(f"Overwriting {existing_count} existing rows")

                    self._write_with_retry(
                        table=table,
                        write_fn=table.overwrite,
                        data=cleaned,
                        operation_name="overwrite",
                        overwrite_filter=overwrite_filter,
                    )
                    logger.info(f"Overwrote with {len(cleaned)} rows")

        # Table does not exist; create it ---------------------
        except NoSuchTableError:
            location = self._generate_table_location(
                schema_name=schema_name,
                table_name=table_name,
            )

            # Create table with race condition protection
            table = self._create_table(
                table_id=table_id,
                schema=cleaned.schema,
                location=location,
                partition_col=partition_col,
                transform_type=transform_type,
            )

            # Write initial data with retry (concurrent backfills may conflict)
            self._write_with_retry(
                table=table,
                write_fn=table.append,
                data=cleaned,
                operation_name="initial append",
            )
            logger.info(f"Wrote initial data ({len(cleaned)} rows)")

        # Success path only - exceptions from _write_with_retry propagate up
        table.refresh()
        snapshot = table.current_snapshot()

        # Build metadata dictionary compatible with ParquetClient return format
        result_metadata = {
            "table_name": table_id,
            "record_count": len(cleaned),
            "status": "success",
        }

        if snapshot:
            result_metadata["snapshot_id"] = snapshot.snapshot_id
            result_metadata["total_records"] = snapshot.summary.get(
                "total-records", "N/A"
            )
            logger.info(
                f"Current snapshot - ID: {snapshot.snapshot_id}, "
                f"Total records: {snapshot.summary.get('total-records', 'N/A')}"
            )

        # Add partition information if provided
        if partition_col and partition_value:
            result_metadata[partition_col] = partition_value

        # Add overwrite filter metadata for downstream checks
        if overwrite_strategy and dagster_context:
            result_metadata["overwrite_strategy"] = overwrite_strategy
            result_metadata["query_col"] = query_col
            try:
                time_window = dagster_context.partition_time_window
                result_metadata["partition_start"] = time_window.start.isoformat()
                result_metadata["partition_end"] = time_window.end.isoformat()
            except Exception:
                pass
            try:
                result_metadata["partition_key"] = dagster_context.partition_key
            except Exception:
                pass

        return result_metadata

    def read_table(
        self,
        schema_name: str,
        table_name: str,
        columns: Optional[List[str]] = None,
        limit: Optional[int] = None,
    ) -> pa.Table:
        """Read data from an Iceberg table.

        Parameters
        ----------
        schema_name: str
            Schema of the table to be read
        table_name : str
            Name of the table to read
        columns : List[str], optional
            Specific columns to read
        limit : int, optional
            Maximum number of rows to return

        Returns
        -------
        pa.Table
            PyArrow table with the table
        """
        # Lakekeeper namespaces are always lowercase
        schema_name = schema_name.lower()
        table_id = f"{schema_name}.{table_name}"

        try:
            table = self.catalog.load_table(table_id)
            scan = table.scan()

            if columns:
                scan = scan.select(*columns)

            if limit:
                scan = scan.limit(limit)

            return scan.to_arrow()

        except Exception as e:
            logger.error(f"Error reading table {table_id}: {str(e)}")
            raise

    def list_tables(self, schema_name: str) -> List[str]:
        """List all tables in a schema."""
        schema_name = schema_name.lower()
        tables = self.catalog.list_tables(schema_name)
        return [table[1] for table in tables]  # Return just table names

    def append_chunk(
        self,
        table_name: str,
        schema_name: str,
        pa_chunk: pa.Table,
    ) -> None:
        """Append a single pre-cleaned chunk to an existing Iceberg table.

        The table must already exist (created by the first write_table call).
        Type conversion (handle_oracle_data_types) must be done by the caller.

        Parameters
        ----------
        table_name : str
            Name of the Iceberg table
        schema_name : str
            Schema/namespace for the table
        pa_chunk : pa.Table
            Pre-cleaned PyArrow table chunk to append
        """
        # Lakekeeper namespaces are always lowercase
        schema_name = schema_name.lower()
        table_id = f"{schema_name}.{table_name}"
        table = self.catalog.load_table(table_id)
        table.refresh()

        self._write_with_retry(
            table=table,
            write_fn=table.append,
            data=pa_chunk,
            operation_name=f"chunked append to {table_id}",
        )
        logger.info(f"Appended chunk ({len(pa_chunk)} rows) to {table_id}")

    def _get_overwrite_count(
        self,
        table: Table,
        overwrite_filter: EqualTo | And,
    ) -> int:
        """Return count of rows that would be deleted by an overwrite filter."""
        return table.scan(row_filter=overwrite_filter).count()
