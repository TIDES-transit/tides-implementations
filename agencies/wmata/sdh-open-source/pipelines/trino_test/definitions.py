from dagster import Definitions, EnvVar

from ..env import azure_credential
from .assets import test_trino_connection

from ..resources.trino import TrinoResource

assets = [
    test_trino_connection,
]


# Trino resources - always included regardless of environment
trino_resources = {
    "trino": TrinoResource(
        azure_credential=azure_credential,
        oauth_scope=EnvVar("TRINO_OAUTH_SCOPE"),
        host=EnvVar("TRINO_HOST"),
        port=EnvVar("TRINO_PORT"),
        user=EnvVar("TRINO_USER"),
        catalog=EnvVar("TRINO_CATALOG"),
        trino_schema=EnvVar("TRINO_SCHEMA"),
        use_https=EnvVar("TRINO_USE_HTTPS"),
    ),
}

# Export TRINO_JWT_TOKEN before dbt loads
# trino_resources["trino_resource"].export_access_token()


# main entry point for the dagster pipeline
defs = Definitions(
    assets=assets,
    resources={
        **trino_resources,
    },
)
