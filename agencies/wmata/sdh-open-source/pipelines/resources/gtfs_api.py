from dagster import get_dagster_logger, ConfigurableResource
import requests

from .utils import get_vault_secret, get_secret_client

logger = get_dagster_logger()


class GTFSApiResource(ConfigurableResource):
    """Class for API resource - configure resource and call client with GTFSApiResource.get_client()

    Parameters
    ----------
    api_secret_key_name: str
        Name of key vault secret that contains a valid API key
    base_url: str
        URL for the endpoint - provided by dagster

    Returns
    -------
    GTFSApiResource
        Resource for use in dagster. Create client with .get_client()
    """

    # Config fields - these will be provided by Dagster
    api_secret_key_name: str
    base_url: str
    keyvault_name: str

    def setup_for_execution(self, context):
        logger.info(
            f"Authenticating with Azure to retrieve GTFS API Key from {self.keyvault_name}"
        )

        secret_client = get_secret_client(keyvault_name=self.keyvault_name)
        self._api_key = get_vault_secret(
            secret_client=secret_client, secret_name=self.api_secret_key_name
        )

    def get_client(self):
        """Return a client for the GTFS API."""
        logger.info(f"Using {self.base_url} for API query")
        return GTFSApiClient(api_key=self._api_key, base_url=self.base_url)


class GTFSApiClient:
    """Client for retrieving GTFS data. Instantiate with GTFSApiResource.get_client()

    Returns
    -------
    GTFSApiClient
        API client for use in retrieving GTFS data from endpoint
    """

    def __init__(self, api_key: str, base_url: str):
        """Initialize the GTFS API client."""
        self.api_key = api_key
        self.base_url = base_url
        self.headers = {"api_key": api_key}

    def download_zip(self):
        """Download GTFS zip file from API."""
        r = requests.get(self.base_url, headers=self.headers)
        r.raise_for_status()
        return r.content
