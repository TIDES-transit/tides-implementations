#!/usr/bin/env python3
"""
Recover Iceberg table metadata from Azure Storage to a CSV file.

Scans the iceberg container for metadata.json files in non-UUID top-level
folders, finds the latest metadata file for each table, and writes a CSV
compatible with register_metadata.py.

Use this when Lakekeeper's catalog has been wiped (e.g., after re-bootstrap)
and you need to reconstruct the table registry from the storage layer.

Requirements:
    pip install azure-storage-blob azure-identity

Usage:
    python recover_metadata.py \
        --storage-account [STORAGE_ACCOUNT] \
        --container iceberg \
        --output tables.csv

    # Then re-register with Lakekeeper:
    python register_metadata.py --input tables.csv ...
"""

import argparse
import csv
import re
import sys
from collections import defaultdict

from azure.identity import DefaultAzureCredential
from azure.storage.blob import ContainerClient


# UUID pattern (the folders we want to skip)
UUID_PATTERN = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
    re.IGNORECASE,
)

DEFAULT_CONTAINER_NAME = "iceberg"


def is_uuid_folder(name: str) -> bool:
    """Check if a folder name looks like a UUID."""
    return bool(UUID_PATTERN.match(name))


def find_metadata_files(
    storage_account: str,
    container_name: str = DEFAULT_CONTAINER_NAME,
    filter_ns: str | None = None,
) -> list[dict[str, str]]:
    """
    Scan the container for metadata.json files in non-UUID folders.

    Returns a list of dicts with keys matching download_metadata.py's CSV
    format: namespace, table, identifier, metadata_location.
    """
    account_url = f"https://{storage_account}.blob.core.windows.net"
    credential = DefaultAzureCredential()
    container_client = ContainerClient(
        account_url=account_url,
        container_name=container_name,
        credential=credential,
    )

    # Collect all metadata files grouped by namespace/table
    # Structure: {(namespace, table): [(sequence_number, blob_name)]}
    table_metadata: dict[tuple[str, str], list[tuple[int, str]]] = defaultdict(list)

    print(f"Scanning {account_url}/{container_name} for metadata files...")

    for blob in container_client.list_blobs():
        name = blob.name
        parts = name.split("/")

        # Expected: {namespace}/{table}/metadata/{NNN}-{uuid}.gz.metadata.json
        if len(parts) < 4:
            continue
        if parts[2] != "metadata":
            continue
        if not name.endswith(".metadata.json"):
            continue

        namespace = parts[0]
        table = parts[1]

        if is_uuid_folder(namespace):
            continue

        if filter_ns and not namespace.lower().startswith(filter_ns.lower()):
            continue

        filename = parts[3]
        try:
            seq_num = int(filename.split("-", 1)[0])
        except (ValueError, IndexError):
            continue

        table_metadata[(namespace, table)].append((seq_num, name))

    # Build rows with the latest metadata file for each table
    rows = []
    for (namespace, table), entries in sorted(table_metadata.items()):
        entries.sort(key=lambda x: x[0], reverse=True)
        _latest_seq, latest_blob = entries[0]

        ns_lower = namespace.lower()
        table_lower = table.lower()
        metadata_location = (
            f"abfss://{container_name}@{storage_account}.dfs.core.windows.net/"
            f"{latest_blob}"
        )

        rows.append(
            {
                "namespace": ns_lower,
                "table": table_lower,
                "identifier": f"{ns_lower}.{table_lower}",
                "metadata_location": metadata_location,
            }
        )

    return rows


def main():
    parser = argparse.ArgumentParser(
        description="Recover Iceberg table metadata from Azure Storage to a CSV file"
    )
    parser.add_argument(
        "--storage-account",
        required=True,
        help="Azure storage account name (e.g., [STORAGE_ACCOUNT])",
    )
    parser.add_argument(
        "--container",
        default=DEFAULT_CONTAINER_NAME,
        help=f"Azure storage container name (default: {DEFAULT_CONTAINER_NAME})",
    )
    parser.add_argument(
        "--output",
        "-o",
        default="tables.csv",
        help="Output CSV file path (default: tables.csv)",
    )
    parser.add_argument(
        "--filter",
        help="Only process namespaces matching this prefix (e.g., 'businfo')",
    )

    args = parser.parse_args()

    rows = find_metadata_files(
        args.storage_account,
        args.container,
        filter_ns=args.filter,
    )

    if not rows:
        print("No metadata files found in non-UUID folders.")
        sys.exit(0)

    print(f"\nFound {len(rows)} table(s):\n")
    for row in rows:
        print(f"  {row['identifier']}")
        print(f"    metadata: {row['metadata_location']}")

    with open(args.output, "w", newline="") as f:
        writer = csv.DictWriter(
            f, fieldnames=["namespace", "table", "identifier", "metadata_location"]
        )
        writer.writeheader()
        writer.writerows(rows)

    print(f"\nSaved {len(rows)} table(s) to {args.output}")
    print(f"To register: python register_metadata.py --input {args.output} ...")


if __name__ == "__main__":
    main()