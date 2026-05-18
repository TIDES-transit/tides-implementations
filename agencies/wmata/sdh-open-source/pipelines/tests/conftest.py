import os

# Set mock Azure credentials before other imports to prevent credential validation errors
os.environ.setdefault("AZURE_TENANT_ID", "test-tenant-id")
os.environ.setdefault("AZURE_CLIENT_ID", "test-client-id")
os.environ.setdefault("AZURE_CLIENT_SECRET", "test-client-secret")


import pytest
import io
import zipfile
from unittest.mock import MagicMock, patch
from dagster import build_asset_context
import pyarrow as pa


def create_test_gtfs_zip():
    """Create a minimal valid GTFS zip file for testing."""
    zip_buffer = io.BytesIO()

    with zipfile.ZipFile(zip_buffer, "w", compression=zipfile.ZIP_DEFLATED) as zip_file:
        # Create a minimal feed_info.txt
        feed_info_content = "feed_publisher_name,feed_publisher_url,feed_lang\nTest Publisher,http://test.com,en"
        zip_file.writestr("feed_info.txt", feed_info_content)

        # Create a minimal agency.txt
        agency_content = "agency_id,agency_name,agency_url,agency_timezone\n1,Test Agency,http://test.com,America/New_York"
        zip_file.writestr("agency.txt", agency_content)

        # Create a minimal stops.txt
        feed_info_content = "stop_id,stop_name,stop_lat,stop_lon\n99,Stop99,99,99"
        zip_file.writestr("stops.txt", feed_info_content)

    zip_buffer.seek(0)
    return zip_buffer.getvalue()


@pytest.fixture
def mock_file_contents():
    return b"mock_data"


@pytest.fixture
def sample_gtfs_zip():
    """Fixture that returns a sample GTFS zip file."""
    return create_test_gtfs_zip()


@pytest.fixture
def mock_azure_creds():
    """Mock Azure storage credentials for testing"""
    with patch(
        "tides_infra_dagster.resources.azure_storage.DefaultAzureCredential"
    ) as mock_creds:
        mock_token = MagicMock()
        mock_token.token = "test-token"
        mock_creds.return_value.get_token.return_value = mock_token
        yield mock_creds


@pytest.fixture
def mock_blob_service_client():
    """Mock bsl for testing"""
    with patch("pipelines.resources.azure_storage.BlobServiceClient") as mock_client:
        mock_container_client = MagicMock()
        mock_client.return_value.get_container_client.return_value = (
            mock_container_client
        )

        mock_container_client.create_container = MagicMock()
        yield (mock_client, mock_container_client)


@pytest.fixture
def mock_azure_client():
    """Create a mock Azure client for testing."""
    mock_client = MagicMock()
    mock_client.upload_blob.return_value = True
    mock_client.download_blob.return_value = create_test_gtfs_zip()
    mock_client.list_blobs.return_value = []
    mock_client.list_hashes.return_value = []
    return mock_client


@pytest.fixture
def mock_parquet_client():
    """Create a mock Parquet client for testing."""
    mock_client = MagicMock()
    mock_client.write_table.return_value = {"status": "success", "rows_loaded": 1}
    mock_client.check_feed_exists.return_value = False
    return mock_client


@pytest.fixture
def mock_api_client():
    """Create a mock API client for testing."""
    mock_client = MagicMock()
    mock_client.download_zip.return_value = create_test_gtfs_zip()
    return mock_client


@pytest.fixture
def mock_redaction_table_schema():
    mock_schema = dict()

    mock_schema["table_name"] = "mock_table"
    mock_schema["schema"] = "mock_schema"
    mock_schema["redacted_cols"] = ["redact_me"]
    mock_schema["date_col"] = "mock_date_column"
    mock_schema["where_clause"] = "mock_where_clause"

    mock_schema["query_cols"] = [
        "mock_a",
        "mock_b",
        "mock_date_column",
        "error_redact_me",
    ]

    mock_schema["col_not_in_query_to_error"] = ["error_redact_me"]
    # we'll add this to the columns and indicate it should be redacted
    # to test that we raise an error
    return mock_schema


# TODO: i think maybe we could skip some of this and do in build_asset_context
# directly, should evaluate that
@pytest.fixture
def build_test_context(mock_azure_client, mock_parquet_client, mock_api_client):
    """Build a test context with configurable mocked resources."""

    def _build_context(partition_key=None, resources=None):
        # Set up default resources
        default_resources = {
            "azure_storage_resource": MagicMock(get_client=lambda: mock_azure_client),
            "parquet_resource": MagicMock(get_client=lambda: mock_parquet_client),
            "api_client": MagicMock(get_client=lambda: mock_api_client),
            "api_key": "test_key",
        }

        # Override with any provided resources
        if resources:
            default_resources.update(resources)

        # Build context with resources
        context = build_asset_context(
            partition_key=partition_key, resources=default_resources
        )

        return context

    return _build_context


@pytest.fixture
def mock_pa_table():
    return pa.table(
        {
            "col1": [1, 2, 3],
            "col2": ["RED", "SILVER", "ORANGE"],
            "date_col": ["2023-01-01", "2023-01-01", "2023-01-01"],
        }
    )
