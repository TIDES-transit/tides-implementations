"""Tests for IcebergClient utility methods.

Tests utility/helper functions that don't require catalog connections.
"""

import datetime
import pytest
import pyarrow as pa
import pandas as pd
from unittest.mock import MagicMock

from pipelines.resources.iceberg_writer import IcebergClient


@pytest.fixture
def iceberg_client(monkeypatch):
    """Create IcebergClient with mocked catalog connection."""
    monkeypatch.setattr(IcebergClient, "connect_to_catalog", lambda self: MagicMock())
    return IcebergClient(
        lakekeeper_url="http://test",
        lakekeeper_oauth_scope="test-scope",
        warehouse_name="test-warehouse",
        catalog_name="test-catalog",
        client_id="test-client",
        client_secret="test-secret",
        tenant_id="test-tenant",
        container_name="test-container",
        storage_account="test-account",
    )


class TestCreateOverwriteFilter:
    """Tests for overwrite filter raises expected errors."""

    def test_invalid_strategy_raises_error(self, iceberg_client):
        """Invalid strategy raises ValueError."""
        with pytest.raises(ValueError, match="Invalid overwrite_strategy"):
            iceberg_client._create_overwrite_filter(
                overwrite_strategy="invalid_strategy",
                query_col="any_col",
                dagster_context=None,
            )

    def test_missing_context_raises_error(self, iceberg_client):
        """Strategies requiring context raise ValueError when missing."""
        for strategy in ["date_equals", "identity_equals", "time_between"]:
            with pytest.raises(ValueError, match="requires dagster_context"):
                iceberg_client._create_overwrite_filter(
                    overwrite_strategy=strategy,
                    query_col="col",
                    dagster_context=None,
                )


class TestHandleOracleDataTypes:
    """Tests for Oracle type conversions are applied for Iceberg compatibility."""

    def test_converts_date64_to_timestamp(self, iceberg_client):
        """date64 columns are converted to timestamp(us) for Iceberg."""
        table = pa.table(
            {
                "created_at": pa.array(
                    [datetime.date(2026, 1, 1), datetime.date(2026, 1, 2)],
                    type=pa.date64(),
                ),
            }
        )

        result = iceberg_client.handle_oracle_data_types(table)

        assert result.schema.field("created_at").type == pa.timestamp("us")

    def test_mapping_types(self, iceberg_client):
        """Standard types are preserved and nullable."""
        table = pa.table(
            {
                "id": [1, 2, 3],
                "name": ["a", "b", "c"],
            }
        )

        result = iceberg_client.handle_oracle_data_types(table)

        assert result.schema.field("id").type == pa.int64()
        assert result.schema.field("name").type == pa.string()
        assert result.schema.field("id").nullable is True


class TestConvertToPyarrow:
    """Tests for data type conversion to pyarrow."""

    def test_converts_dataframe_to_table(self):
        """pd.DataFrame is converted to pa.Table."""
        df = pd.DataFrame({"id": [1, 2], "name": ["a", "b"]})

        result = IcebergClient._convert_to_pyarrow(df)

        assert isinstance(result, pa.Table)
        assert result.num_rows == 2

    def test_invalid_type_raises_error(self):
        """Unsupported data type raises TypeError."""
        with pytest.raises(TypeError, match="Unsupported data type"):
            IcebergClient._convert_to_pyarrow({"fake": "data"})
