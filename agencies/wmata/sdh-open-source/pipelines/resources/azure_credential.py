"""Azure credential resource for unified authentication across services."""

import time
from typing import Dict, Optional
from datetime import datetime

from dagster import ConfigurableResource, get_dagster_logger, EnvVar
from azure.identity import ClientSecretCredential
from azure.core.credentials import AccessToken, TokenCredential

from ..env import DEMO_MODE  # noqa: E402

logger = get_dagster_logger()


class _DemoCredential:
    """Stub credential that raises on use. Allows definitions to load without Azure config."""

    def get_token(self, *scopes, **kwargs):
        raise RuntimeError(
            "Azure credentials are not configured. "
            "Set AZURE_TENANT_ID, AZURE_CLIENT_ID, and AZURE_CLIENT_SECRET "
            "environment variables to enable authentication."
        )


class AzureCredentialResource(ConfigurableResource):
    """Azure credential resource for OAuth authentication.

    This resource provides Azure authentication using ClientSecretCredential
    for service principal authentication.

    This resource is set up a bit differently than others (e.g. using __init__ instead of
    setup_for_execution to instatiate the client) because we have needs to use it
    via direct import outside Dagster's resource lifecycle

    When Azure credentials are not configured (AZURE_TENANT_ID not set), the resource
    loads in demo mode — Dagster definitions will load and the UI is browsable,
    but any operation requiring authentication will raise an error.

    Parameters
    ----------
    tenant_id : str
        Azure tenant ID
    client_id : str
        Azure client ID
    client_secret : str
        Azure client secret
    """

    tenant_id: str
    client_id: str
    client_secret: str

    _credential: Optional[TokenCredential] = None
    _token_cache: Dict[str, AccessToken] = {}

    # Initialize client during __init__ rather than setup_for_execution
    # so that this resource can be imported directly and used outside Dagster's
    # execution lifecycle
    def __init__(self, **data):
        """Initialize the credential immediately during class instantiation"""
        super().__init__(**data)

        if DEMO_MODE:
            logger.info(
                "Azure credentials not configured — running in demo mode. "
                "The DAG is viewable but pipelines cannot execute."
            )
            self._credential = _DemoCredential()
            return

        logger.info("Initializing ClientSecretCredential")

        # We need to resolve EnvVar values ourselves here because we're doing this ahead of runtime
        self._credential = ClientSecretCredential(
            tenant_id=self.tenant_id.get_value()
            if isinstance(self.tenant_id, EnvVar)
            else self.tenant_id,
            client_id=self.client_id.get_value()
            if isinstance(self.client_id, EnvVar)
            else self.client_id,
            client_secret=self.client_secret.get_value()
            if isinstance(self.client_secret, EnvVar)
            else self.client_secret,
            additionally_allowed_tenants=["*"],
        )

        logger.info("Successfully initialized OAuth credential")

    def get_credential(self) -> TokenCredential:
        """Get the underlying Azure credential object.

        Returns
        -------
        TokenCredential
            The Azure credential object
        """
        if self._credential is None:
            raise RuntimeError(
                "Credential not initialized. This should not happen if resource is properly set up."
            )
        return self._credential

    def get_token(self, scope: str) -> Optional[AccessToken]:
        """Get an Azure AD access token for the specified scope with caching.

        This method implements token caching with expiration checking to minimize
        API calls to Azure AD.

        Parameters
        ----------
        scope : str
            The scope to request a token for (e.g., "https://app-id/.default")

        Returns
        -------
        AccessToken | None
            The access token if successful, None otherwise
        """
        # Check cache first
        if scope in self._token_cache:
            cached_token = self._token_cache[scope]
            if time.time() < cached_token.expires_on:
                logger.debug(f"Using cached access token for scope: {scope}")
                return cached_token
            else:
                logger.debug(f"Cached token for scope {scope} has expired")

        try:
            logger.info(f"Requesting Azure AD token for scope: {scope}")

            # Get new token
            token = self._credential.get_token(scope)

            # Cache it
            self._token_cache[scope] = token

            expires_at = datetime.fromtimestamp(token.expires_on).strftime(
                "%Y-%m-%d %H:%M:%S"
            )
            logger.info(
                f"Successfully acquired Azure AD token for scope {scope}, expires at {expires_at}"
            )

            return token

        except Exception as e:
            logger.error(f"Error acquiring Azure AD token for scope {scope}: {e}")
            return None

    def clear_token_cache(self):
        """Clear the token cache.

        This can be useful for testing or when you need to force a fresh token.
        """
        self._token_cache.clear()
        logger.info("Cleared token cache")
