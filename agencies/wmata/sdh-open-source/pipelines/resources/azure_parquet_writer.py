from dagster import get_dagster_logger, ConfigurableResource
import pyarrow as pa
import pyarrow.parquet as pq
from typing import Dict, Any
import os
import tempfile

from .azure_storage import AzureStorageResource
from .azure_credential import AzureCredentialResource


logger = get_dagster_logger()


class ParquetResource(ConfigurableResource):
    """Resource for Parquet file operations on Azure Blob Storage.

    Parameters
    ----------

    storage_account: str
        Storage account to use for Azure operations
    container: str
        Container for read/write

    Returns
    -------
    ParquetResource
        Resource to instantiate client
    """

    # Config fields
    storage_account: str
    container: str
    azure_credential: AzureCredentialResource

    def setup_for_execution(self, context):
        """Initialize components during resource setup."""
        try:
            # Initialize the storage resource, using existing AzureStorageResource for blob ops
            self._storage_resource = AzureStorageResource(
                storage_account=self.storage_account,
                container=self.container,
                azure_credential=self.azure_credential,
            )
            self._storage_resource.setup_for_execution(context)

            logger.info("Initialized ParquetResource")
        except Exception as e:
            logger.error(f"Error initializing ParquetResource: {e}")
            raise

    def get_client(self):
        """Return a client for Parquet operations."""
        storage_client = self._storage_resource.get_client()

        return ParquetClient(storage_client=storage_client)


class ParquetClient:
    """Client for Parquet file operations using Azure Blob Storage. Create by instantiating a
    ParquetResource and using .get_client()

    Returns
    -------
    ParquetClient
        ParquetClient for handling partitioned parquet files in Azure
    """

    def __init__(
        self,
        storage_client: ParquetResource,
    ):
        """Initialize Parquet client."""
        self.storage_client = storage_client

    def write_table(
        self,
        table_name: str,
        pa_table: pa.Table,
        schema_name: str,
        partition_col: str,
        partition_value: str = None,
        table_prefix: str = None,
        **kwargs,
    ) -> Dict[str, Any]:
        """Write a PyArrow table as a Parquet file to Azure Blob Storage.

        Parameters
        ----------
        table_name : str
            Name of table, such as feed_info
        pa_table : pa.Table
            Table data
        schema_name : str
            Schema name for organizing tables
        partition_col : str
            Column name for partitioning
        partition_value: str
            Optional single-value used for partitioning - used for partitoning parquets
        table_prefix: str
            Optional prefix for table name for writing
        kwargs:
            Additional optional arguments for interop with iceberg

        Returns
        -------
        Dict[str, Any]
            Dict with operation results
        """
        try:
            # Parse table name
            if "." in table_name:
                schema_name, name = table_name.split(".", 1)
            else:
                name = table_name

            if table_prefix:
                name = f"{table_prefix}_{name}"

            if partition_value is None:
                partition_value = partition_col
            # Ensure feed_hash column exists
            if partition_col not in pa_table.column_names:
                df = pa_table.to_pandas()
                df[partition_col] = partition_value
                pa_table = pa.Table.from_pandas(df)

            # Define the blob path
            blob_path = f"{schema_name}/{name}/{partition_value}/{name}.parquet"

            # Create a temporary parquet file
            with tempfile.NamedTemporaryFile(
                suffix=".parquet", delete=False
            ) as temp_file:
                temp_path = temp_file.name

            # Write to temp file
            pq.write_table(pa_table, temp_path)

            # Prepare metadata
            metadata = {
                partition_col: partition_value,
                "table_name": f"{schema_name}.{name}",
                "row_count": str(len(pa_table)),
            }

            # Upload to Azure and clean up
            with open(temp_path, "rb") as f:
                data = f.read()
                self.storage_client.upload_blob(blob_path, data, metadata)
            os.unlink(temp_path)

            return {
                "table_name": f"{schema_name}.{name}",
                "blob_path": blob_path,
                "record_count": len(pa_table),
                "status": "success",
                partition_col: partition_value,
            }

        except Exception as e:
            logger.error(f"Error writing Parquet for {table_name}: {e}")
            return {
                "table_name": table_name,
                "record_count": 0,
                "status": "error",
                "error": str(e),
            }

    def check_feed_exists(self, feed_hash: str) -> bool:
        """Check if a feed exists by looking for data with the given feed_hash."""
        try:
            # Look for any blobs with this feed hash in the feed_info path
            feed_info_path = f"gtfs/feed_info/{feed_hash}/"
            blobs = self.storage_client.list_blobs(name_starts_with=feed_info_path)
            return len(blobs) > 0
        except Exception as e:
            logger.error(f"Error checking if feed exists: {e}")
            return False

    def list_feeds(self) -> list:
        """List all available feed hashes."""
        try:
            feed_info_path = "gtfs/feed_info/"
            blobs = self.storage_client.list_blobs(name_starts_with=feed_info_path)

            # Extract unique feed hashes from the paths
            feed_hashes = set()
            for blob in blobs:
                parts = blob.name.split("/")
                if len(parts) > 3:
                    feed_hashes.add(parts[3])  # Extract the feed_hash part of path

            return list(feed_hashes)
        except Exception as e:
            logger.error(f"Error listing feeds: {e}")
            return []
