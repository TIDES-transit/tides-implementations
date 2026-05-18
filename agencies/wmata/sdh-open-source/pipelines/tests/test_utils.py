import pytest
import zipfile
from io import BytesIO
from unittest.mock import MagicMock
from ..gtfs.assets import (
    sort_zip_contents,
    generate_file_hash,
    gtfs_tables,
    verify_is_zip,
)

from ..resources.utils import (
    _resolve_query_date,
    _build_where_clause,
)


@pytest.mark.unit
def test_zip_detection(sample_gtfs_zip):
    fake_zip_contents = b"this is not a zip file"
    with pytest.raises(Exception):
        verify_is_zip(fake_zip_contents)

    assert verify_is_zip(sample_gtfs_zip) is True


@pytest.mark.unit
def test_sort_zip_contents(sample_gtfs_zip):
    """Test that zip files are being sorted so that zip hashing is deterministic"""
    zip_buffer = BytesIO(sample_gtfs_zip)

    # Check original file list
    with zipfile.ZipFile(zip_buffer) as test_zip:
        test_names = test_zip.namelist()

    sorted_zip_bytes = sort_zip_contents(sample_gtfs_zip)

    with zipfile.ZipFile(BytesIO(sorted_zip_bytes)) as sorted_zip:
        sorted_names = sorted_zip.namelist()

    assert len(sorted_names) == len(test_names)  # sorted zip contains  all files within
    assert sorted_names == sorted(test_names)  # sorting is correct
    assert sorted_names != test_names  # sorting happens


@pytest.mark.unit
def test_hashing(mock_file_contents):
    """Test that hashing returns something different than input, agnostic on hashing mechanism"""
    hashed_data = generate_file_hash(mock_file_contents)
    assert hashed_data != str(
        mock_file_contents
    )  # just testing that hashing is occurring rather than specific hash


@pytest.mark.unit
def test_gtfs_tables_raises_exception_without_routes(
    build_test_context, sample_gtfs_zip
):
    """Test that gtfs_tables raises an Exception when routes.txt is not found."""
    # The sample_gtfs_zip fixture doesn't include routes.txt, which should cause an exception
    context = build_test_context()

    # Mock the gtfs_zip input parameter
    gtfs_zip_result = {"content_hash": "test_hash", "filename": "test.zip"}

    # Add the gtfs_database_resource and gtfs_iceberg_namespace to context resources
    mock_db_client = MagicMock()
    mock_db_client.write_table.return_value = True
    context.resources.gtfs_database_resource = MagicMock(
        get_client=lambda: mock_db_client
    )
    context.resources.gtfs_iceberg_namespace = "test_namespace"

    # Mock the azure client to return the sample zip without routes.txt
    azure_client = context.resources.azure_storage_resource.get_client()
    azure_client.download_blob.return_value = sample_gtfs_zip
    azure_client.set_blob_metadata.return_value = True

    with pytest.raises(Exception):
        list(gtfs_tables(context, gtfs_zip_result))


class TestUtilsHelpers:
    """Unit tests for refactored utils helper functions"""

    @pytest.mark.unit
    def test_resolve_query_date(self):
        """Test query date resolution logic"""
        # Test with both parameters provided - query_date takes precedence
        assert _resolve_query_date("2023-01-01", "2023-01-02 10:30:00") == "2023-01-01"

        # Test with only query_date
        assert _resolve_query_date("2023-01-01", None) == "2023-01-01"

        # Test with only start_time - extract date part
        assert _resolve_query_date(None, "2023-01-02 10:30:00") == "2023-01-02"

        # Test with both None - should return None
        assert _resolve_query_date(None, None) is None

    @pytest.mark.unit
    def test_build_where_clause_daily(self):
        """Test WHERE clause building for daily queries"""
        clause = _build_where_clause("DATE_COL", "2023-01-01")

        assert (
            "DATE_COL >= TO_DATE('2023-01-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS')"
            in clause
        )

    @pytest.mark.unit
    def test_build_where_clause_time_window(self):
        """Test WHERE clause building for time window queries"""
        clause = _build_where_clause(
            date_col="TIMESTAMP_COL",
            query_date="2023-01-01",  # This gets ignored for time queries
            start_time="2023-01-01 10:00:00",
            end_time="2023-01-01 10:10:00",
            is_time_query=True,
        )

        assert (
            "TIMESTAMP_COL >= TO_DATE('2023-01-01 10:00:00', 'YYYY-MM-DD HH24:MI:SS')"
            in clause
        )
        assert (
            "TIMESTAMP_COL < TO_DATE('2023-01-01 10:10:00', 'YYYY-MM-DD HH24:MI:SS')"
            in clause
        )

    @pytest.mark.unit
    def test_build_where_clause_time_query_missing_params(self):
        """Test WHERE clause falls back to daily format when time params missing"""
        # Even with is_time_query=True, should fall back if start_time/end_time missing
        clause = _build_where_clause(
            date_col="DATE_COL",
            query_date="2023-01-01",
            start_time=None,
            end_time="2023-01-01 10:10:00",
            is_time_query=True,
        )

        # Should fall back to daily format
        assert (
            "DATE_COL >= TO_DATE('2023-01-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS')"
            in clause
        )
