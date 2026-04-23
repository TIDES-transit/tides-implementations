import os

from dagster import EnvVar

# shared flag for environment settings
ENVIRONMENT = os.environ.get("[Project Name]_ENVIRONMENT", "dev")
is_consultant_[Project Name]_env = ENVIRONMENT == "consultant"

# Demo mode: allow Dagster to load definitions without Azure/Oracle credentials
DEMO_MODE = not os.environ.get("AZURE_TENANT_ID")

from .resources.azure_credential import AzureCredentialResource  # noqa: E402

# Row limit for Oracle queries: 100 for dev (testing), None for stg (no limit)
ROW_LIMIT: int | None = 100 if ENVIRONMENT == "dev" else None

if not is_consultant_[Project Name]_env and not DEMO_MODE:
    # NOTE: we only connect to oracle dbs in client env
    import oracledb

    oracledb.init_oracle_client()

# shared credential imported/used by some tools
azure_credential = AzureCredentialResource(
    tenant_id=EnvVar("AZURE_TENANT_ID"),
    client_id=EnvVar("AZURE_CLIENT_ID"),
    client_secret=EnvVar("AZURE_CLIENT_SECRET"),
)