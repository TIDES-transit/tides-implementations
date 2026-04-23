import pytest
from unittest.mock import MagicMock
from dagster import MaterializeResult


from ..gtfs.assets import (
    gtfs_zip,
    sort_zip_contents,
    generate_file_hash,
)

from ..common.assets import (
    _create_table_identifier,
    _write_table_to_storage,
    _build_result_metadata,
    handle_query_results,
)

from ..resources.utils import generate_redaction_sql_from_schema
from ..resources.azure_storage import AzureStorageClient
from azure.core.exceptions import ResourceExistsError


# Note: these tests are left as examples only.
# TODO: could nest these in a class and save some of the setup, address possible namespace issues
@pytest.mark.integration
def test_gtfs_zip(build_test_context, sample_gtfs_zip):
    """Test the gtfs_zip asset."""
    # Setup
    context = build_test_context()

    api_client = context.resources.api_client.get_client()
    azure_client = context.resources.azure_storage_resource.get_client()

    # Configure mocks for this specific test
    api_client.download_zip.return_value = sample_gtfs_zip
    azure_client.list_hashes.return_value = []  # No existing hashes
    results = list(gtfs_zip(context))

    assert len(results) == 1
    result = results[0]
    assert isinstance(result, MaterializeResult)
    metadata = result.metadata

    assert metadata["status"] == "new"
    assert "content_hash" in metadata
    assert "filename" in metadata

    # Verify the right methods were called
    api_client.download_zip.assert_called_once()
    azure_client.list_blobs.assert_called_once()
    azure_client.list_hashes.assert_called_once()
    azure_client.upload_blob.assert_called_once()


@pytest.mark.integration
def test_gtfs_zip_existing_hash(build_test_context, sample_gtfs_zip):
    """Test gtfs_zip when the hash already exists."""
    context = build_test_context()
    api_client = context.resources.api_client.get_client()
    azure_client = context.resources.azure_storage_resource.get_client()

    # Configure mocks for this specific test
    api_client.download_zip.return_value = sample_gtfs_zip

    # Generate the hash that will be returned
    sorted_zip = sort_zip_contents(sample_gtfs_zip)
    content_hash = generate_file_hash(sorted_zip)

    # Set the mock to return this hash as existing
    azure_client.list_hashes.return_value = [content_hash]
    results = list(gtfs_zip(context))

    # When hash exists, no MaterializeResult should be yielded
    assert len(results) == 0

    # Verify upload was not called
    azure_client.upload_blob.assert_not_called()


class TestAzureStorageClient:
    """Tests for Azure storage resource"""

    @pytest.mark.integration
    def test_init_creates_container_if_needed(self, mock_blob_service_client):
        """Test container creation"""
        mock_client, mock_container_client = mock_blob_service_client

        AzureStorageClient(
            blob_service_client=mock_client.return_value,
            container_name="test_container",
        )

        mock_client.return_value.get_container_client.assert_called_once_with(
            container="test_container"
        )
        mock_container_client.create_container.assert_called_once()

    @pytest.mark.integration
    def test_handles_container_exists(self, mock_blob_service_client):
        """Test catches existing container"""
        mock_client, mock_container_client = mock_blob_service_client
        mock_container_client.create_container.side_effect = ResourceExistsError(
            "Container exists"
        )

        AzureStorageClient(
            blob_service_client=mock_client.return_value,
            container_name="test_container",
        )
        mock_container_client.create_container.assert_called_once()

    @pytest.mark.integration
    def test_upload_blob_error(self, mock_blob_service_client):
        """Test that errors are caught and raised during upload"""

        mock_client, mock_container_client = mock_blob_service_client
        mock_blob_client = MagicMock()
        mock_container_client.get_blob_client.return_value = mock_blob_client
        mock_blob_client.upload_blob.side_effect = Exception("Test Error")

        client = AzureStorageClient(
            blob_service_client=mock_client.return_value,
            container_name="test_container",
        )

        with pytest.raises(Exception) as exception_info:
            client.upload_blob("test_blob.zip", b"test_bytes")
            assert "Test Error" in str(exception_info.value)


@pytest.mark.unit
def test_hash_columns_error(mock_redaction_table_schema):
    """
    Test that the hashing query generation calls as expected
    This is expected to combine the redaction-column and the date using SHA1, and alias as the redact-col's name
    """
    print(mock_redaction_table_schema)
    table_name = mock_redaction_table_schema["table_name"]
    good_query = generate_redaction_sql_from_schema(
        mock_redaction_table_schema, table_name
    )
    print(good_query)

    assert (
        "CAST(STANDARD_HASH(REDACT_ME || TO_CHAR(MOCK_DATE_COLUMN, 'YYYY-MM-DD'), 'SHA1') AS VARCHAR(64)) AS REDACT_ME"
        in good_query
    )  # Test that we construct redaction as expect

    with pytest.raises(ValueError):
        # Test that raises if we try to redact a column present in query cols
        mock_redaction_table_schema["redacted_cols"] = (
            mock_redaction_table_schema["redacted_cols"]
            + mock_redaction_table_schema["col_not_in_query_to_error"]
        )
        generate_redaction_sql_from_schema(mock_redaction_table_schema, table_name)

    with pytest.raises(ValueError):
        mock_redaction_table_schema["date_col"] = "fake_date_col"
        # Test that raises if we're missing date column in query_cols
        generate_redaction_sql_from_schema(mock_redaction_table_schema, table_name)


# Unit tests for common.asset helper functions
class TestCommonAssetHelpers:
    """Unit tests for refactored common asset helper functions"""

    @pytest.mark.unit
    def test_create_table_identifier(self):
        """Test table identifier creation with case normalization"""
        assert _create_table_identifier("SCHEMA", "TABLE") == "schema.table"
        assert _create_table_identifier("MySchema", "MyTable") == "myschema.mytable"
        assert _create_table_identifier("schema", "table") == "schema.table"
        assert _create_table_identifier("", "") == "."

    @pytest.mark.unit
    def test_build_result_metadata(self):
        """Test metadata building preserves existing data and adds required fields"""
        # Test with existing metadata
        existing_results = {"record_count": 100, "status": "success"}
        final_metadata = _build_result_metadata(
            existing_results, "2023-01-01", "2023-01-02"
        )

        assert final_metadata["record_count"] == 100
        assert final_metadata["status"] == "success"
        assert final_metadata["retrieved_date"] == "2023-01-01"
        assert final_metadata["query_date"] == "2023-01-02"

        # Test with empty metadata
        empty_results = {}
        final_metadata = _build_result_metadata(
            empty_results, "2023-01-01", "2023-01-01"
        )

        assert final_metadata["retrieved_date"] == "2023-01-01"
        assert final_metadata["query_date"] == "2023-01-01"

    @pytest.mark.unit
    def test_write_table_to_storage(self, mock_parquet_client, mock_pa_table):
        """Test table writing calls parquet client correctly"""

        # Configure mock to return expected result
        expected_result = {"record_count": 3, "bytes_written": 1024}
        mock_parquet_client.write_table.return_value = expected_result

        # Call function
        result = _write_table_to_storage(
            mock_parquet_client,
            mock_pa_table,
            "TestSchema",
            "TestTable",
            "date_col",
            "2023-01-01",
        )

        # Verify parquet client was called correctly
        mock_parquet_client.write_table.assert_called_once_with(
            table_name="testschema.testtable",
            pa_table=mock_pa_table,
            schema_name="testschema",
            partition_col="date_col",
            partition_value="2023-01-01",
            transform_type=None,
            mode="overwrite",  # New parameter added for partition overwrite
        )

        # Verify result is returned
        assert result == expected_result

    @pytest.mark.unit
    def test_handle_query_results(self, mock_parquet_client, mock_pa_table):
        """Test complete query results handling workflow"""
        # Configure mock
        mock_parquet_client.write_table.return_value = {
            "record_count": 2,
            "bytes_written": 512,
            "partition": "2023-01-01",
        }

        # Call function
        result = handle_query_results(
            date_col="created_date",
            table=mock_pa_table,
            query_date="2023-01-01",
            current_date="2023-01-02",
            schema_name="TestSchema",
            table_name="TestTable",
            write_client=mock_parquet_client,
        )

        # Verify it returns MaterializeResult
        assert isinstance(result, MaterializeResult)

        # Verify metadata is correctly assembled
        metadata = result.metadata
        assert metadata["record_count"] == 2
        assert metadata["bytes_written"] == 512
        assert metadata["partition"] == "2023-01-01"
        assert metadata["retrieved_date"] == "2023-01-02"
        assert metadata["query_date"] == "2023-01-01"
