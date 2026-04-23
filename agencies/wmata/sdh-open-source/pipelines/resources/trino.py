from __future__ import annotations

import os
from contextlib import contextmanager
from collections.abc import Generator

from dagster import InitResourceContext, get_dagster_logger, ConfigurableResource
import trino
from trino.auth import JWTAuthentication
from .azure_credential import AzureCredentialResource


logger = get_dagster_logger()


class TrinoResource(ConfigurableResource):
    """Resource for connecting to Trino with Azure AD JWT authentication.

    Parameters
    ----------
    host: str
        Trino server hostname
    port: str
        Trino server port
    user: str
        Username for Trino authentication (should be the Azure AD client ID)
    catalog: str
        Default catalog to use
    trino_schema: str
        Default schema to use
    use_https: str
        Whether to use HTTPS for connection (true/false)
    oauth_scope: str | None
        OAuth scope Trino server
    azure_credential: AzureCredentialResource
        Azure credential resource for authentication
    request_timeout: Float | None
        Default timeout for requests

    Returns
    -------
    TrinoResource
        Resource for use in Dagster
    """

    host: str
    port: str
    user: str
    catalog: str
    trino_schema: str
    use_https: str
    oauth_scope: str
    azure_credential: AzureCredentialResource
    request_timeout: float | None = 30.0

    _connection: trino.dbapi.Connection | None = None

    @contextmanager
    def yield_for_execution(self, context: InitResourceContext):
        # keep connection open for the duration of the execution
        with self.get_connection() as connection:
            self._connection = connection
            yield self
            self._connection = None

    @contextmanager
    def get_connection(self) -> Generator[trino.dbapi.Connection, None, None]:
        # Build the scope for the Trino app
        access_token = self.azure_credential.get_token(self.oauth_scope)

        if access_token is None:
            raise Exception("Failed to retrieve access token for Trino")

        auth = JWTAuthentication(access_token.token)
        connection = trino.dbapi.connect(
            host=self.host,
            port=self.port,
            user=self.user,
            catalog=self.catalog,
            schema=self.trino_schema,
            http_scheme="https" if self.use_https else "http",
            auth=auth,
            request_timeout=self.request_timeout,
        )

        try:
            yield connection
        finally:
            connection.close()

    def export_access_token(self) -> bool:
        """Export an Azure AD access token for Trino authentication to TRINO_JWT_TOKEN

        Returns
        -------
        bool
            Whether a token was able to be successfully obtained and exported
        """
        access_token = self.azure_credential.get_token(self.oauth_scope)

        if access_token:
            os.environ["TRINO_JWT_TOKEN"] = access_token.token
            return True
        else:
            return False

    def execute_query(self, query):
        """Execute a query against Trino.

        Parameters
        ----------
        query : str
            SQL query to execute

        Returns
        -------
        list
            List of dictionaries containing query results
        """

        with self.get_connection() as connection:
            cursor = connection.cursor()
            logger.info(f"Executing query: {query}")
            cursor.execute(query)

            if cursor.description:
                columns = [desc[0] for desc in cursor.description]

                rows = cursor.fetchall()
                results = [dict(zip(columns, row)) for row in rows]

                logger.info(f"Query executed successfully: {query}")
                logger.info(f"Results: {results}")

                return results
            else:
                logger.info(f"Query executed successfully with no results: {query}")
                return []
