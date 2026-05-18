from dagster import get_dagster_logger, ConfigurableResource
from azure.storage.blob import BlobServiceClient
from azure.core.exceptions import ResourceExistsError
from typing import List
from .azure_credential import AzureCredentialResource


logger = get_dagster_logger()


class AzureStorageResource(ConfigurableResource):
    """Resource for Azure Blob Storage operations with container management."""

    storage_account: str
    container: str
    azure_credential: AzureCredentialResource

    def setup_for_execution(self, context):
        """Initialize authentication during resource setup."""
        try:
            # Get credential from the azure_credential resource
            self._credentials = self.azure_credential.get_credential()

            # Create blob service client
            self._account_url = f"https://{self.storage_account}.blob.core.windows.net"
            self._blob_service_client = BlobServiceClient(
                account_url=self._account_url, credential=self._credentials
            )

            logger.info("Successfully authenticated to Azure using OAuth credential")
            logger.info(
                f"Using storage container: {self._account_url}/{self.container}"
            )
        except Exception as e:
            logger.error(f"Error authenticating to Azure: {e}")
            raise

    def get_client(self):
        """Return a client for Azure Blob Storage operations."""
        return AzureStorageClient(
            blob_service_client=self._blob_service_client, container_name=self.container
        )


class AzureStorageClient:
    def __init__(self, blob_service_client: BlobServiceClient, container_name: str):
        """Initialize the Azure Storage client, create from an AzureStorageResource.get_client()."""
        self.blob_service_client = blob_service_client
        self.container_name = container_name

        # Get container client
        self.container_client = self.blob_service_client.get_container_client(
            container=self.container_name
        )

        # Create container if it doesn't exist
        try:
            self.container_client.create_container()
            logger.info(f"Created new container: {container_name}")
        except ResourceExistsError:
            logger.info(f"Container already exists: {container_name}")

    def upload_blob(self, blob_name: str, data: bytes, metadata: dict = None) -> bool:
        """Upload blob to container.

        Args:
            blob_name (str): Blob name (filename)
            data (bytes): Blob contents
            metadata (dict, optional): Metadata to attach to the blob

        Returns:
            bool: True on success
        """
        try:
            blob_client = self.container_client.get_blob_client(blob_name)
            logger.info(f"Retrieved blob client for {blob_name}")

            blob_client.upload_blob(data, metadata=metadata, overwrite=True)
            logger.info(f"Uploaded {blob_name}")
            return True
        except Exception as e:
            logger.error(f"Error uploading blob {blob_name}: {str(e)}")
            raise e

    def download_blob(self, blob_name: str) -> bytes:
        """Download blob from container.

        Parameters
        ----------
        blob_name : str
            Blob/file name to download

        Returns
        -------
        bytes
            Blob content

        Raises
        ------
        e
            Exception occurred during blob download operation.
        """
        try:
            blob_client = self.blob_service_client.get_blob_client(
                container=self.container_name, blob=blob_name
            )
            logger.info(f"Retrieved blob client for {blob_name}")

            blob_data = blob_client.download_blob().readall()
            logger.info(f"Downloaded {blob_name} with {len(blob_data)} bytes")

            return blob_data
        except Exception as e:
            logger.error(f"Error downloading blob {blob_name}: {str(e)}")
            raise e

    def list_blobs(self, name_starts_with: str = None):
        """List blobs in the container with optional prefix filtering.

        Parameters
        ----------
        name_starts_with : str, optional
            Optional prefix filtering (such as hash), by default None

        Returns
        -------
        list
            List of matching blobs

        Raises
        ------
        e
            Exception if error occurs during blob list operation
        """
        try:
            blobs = list(
                self.container_client.list_blobs(
                    name_starts_with=name_starts_with, include=["metadata"]
                )
            )
            logger.info(
                f"Listed {len(blobs)} blobs with prefix '{name_starts_with or ''}'"
            )
            return blobs
        except Exception as e:
            logger.error(f"Error listing blobs: {str(e)}")
            raise e

    def list_hashes(self, list_of_blobs: List) -> List[str]:
        """Extract content hashes from blob metadata.

        Parameters
        ----------
        list_of_blobs : List
            List of blobs from list_blobs()

        Returns
        -------
        List[str]
            List of hashes found during blob retrieval (basically just the file names, we don't check if it's a hash)
        """
        hashes = []
        for blob in list_of_blobs:
            metadata = blob.metadata
            if metadata is None:
                continue

            content_hash = metadata.get("content_hash")
            if content_hash:
                hashes.append(content_hash)

        return hashes

    def blob_exists(self, blob_name: str) -> bool:
        """Check if a blob exists.

        Parameters
        ----------
        blob_name : str
            Blob name to check

        Returns
        -------
        bool
            True if exists
        """
        try:
            blob_client = self.container_client.get_blob_client(blob_name)
            return blob_client.exists()
        except Exception as e:
            logger.error(f"Error checking if blob {blob_name} exists: {str(e)}")
            return False

    def get_blob_metadata(self, blob_name: str) -> dict:
        """Retrieve metadata about a blob

        Parameters
        ----------
        blob_name : str
            Name of the blob (think file name)

        Returns
        -------
        dict
            Dictionary of metadata content -- expect all values to be str
        """
        try:
            blob_client = self.container_client.get_blob_client(blob_name)
            blob_properties = blob_client.get_blob_properties()
            return blob_properties.metadata or {}
        except Exception as e:
            logger.error(f"Error retrieving blob metadata for {blob_name}: {str(e)}")
            return {}

    def set_blob_metadata(self, blob_name: str, blob_metadata: dict) -> bool:
        """Set blob's metadata to be updated with the provided blob_metadata

        Parameters
        ----------
        blob_name : str
            Blob name to update
        blob_metadata : dict
            New metadata for blob. This is an .update() operation and will not fully replace.

        Returns
        -------
        bool
            True if update succeeded
        """
        try:
            blob_client = self.blob_service_client.get_blob_client(
                container=self.container_name, blob=blob_name
            )
            blob_props = blob_client.get_blob_properties()
            current_metadata = blob_props.metadata

            new_metadata = current_metadata.copy()
            new_metadata.update(blob_metadata)  # Updates in place

            blob_client.set_blob_metadata(metadata=new_metadata)
            return True
        except Exception as e:
            logger.error(f"Unable to update blob metadata for {blob_name}: {e}")
            return False
