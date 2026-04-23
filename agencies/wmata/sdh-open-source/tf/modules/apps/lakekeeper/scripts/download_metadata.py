#!/usr/bin/env python3
"""
Download Iceberg table metadata from a Lakekeeper catalog to a CSV file.

Connects to Lakekeeper, enumerates all namespaces and tables, and saves
each table's identifier and metadata location so they can be re-registered
later (e.g., after a Lakekeeper re-bootstrap).

Requirements:
    pip install "pyiceberg[adlfs,pyarrow]"

Usage:
    python download_metadata.py \
        --lakekeeper-url https://[Project Name]-[env1]-lakekeeper-ca.icyrock-... \
        --client-id <app-client-id> \
        --client-secret <app-client-secret> \
        --tenant-id <tenant-id> \
        --oauth-scope "api://<lakekeeper-client-id>/.default" \
        --output tables.csv
"""

import argparse
import csv
import sys

from pyiceberg.catalog import load_catalog


def download_metadata(
    lakekeeper_url: str,
    warehouse: str,
    client_id: str,
    client_secret: str,
    tenant_id: str,
    oauth_scope: str,
    output_path: str,
):
    """Connect to Lakekeeper and save all table metadata to a CSV."""

    catalog = load_catalog(
        "lakekeeper",
        **{
            "type": "rest",
            "uri": f"{lakekeeper_url}/catalog",
            "credential": f"{client_id}:{client_secret}",
            "oauth2-server-uri": f"https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token",
            "scope": oauth_scope,
            "warehouse": warehouse,
        },
    )

    print("Connected to Lakekeeper catalog.")

    namespaces = catalog.list_namespaces()
    print(
        f"Found {len(namespaces)} namespace(s): {['.'.join(ns) for ns in namespaces]}"
    )

    rows = []
    for ns in namespaces:
        ns_name = ".".join(ns)
        tables = catalog.list_tables(ns_name)
        print(f"  {ns_name}: {len(tables)} table(s)")

        for table_id in tables:
            identifier = ".".join(table_id)
            try:
                table = catalog.load_table(identifier)
                rows.append(
                    {
                        "namespace": ns_name,
                        "table": table_id[-1],
                        "identifier": identifier,
                        "metadata_location": table.metadata_location,
                    }
                )
                print(f"    {identifier} -> {table.metadata_location}")
            except Exception as e:
                print(f"    {identifier} -> ERROR: {e}")

    if not rows:
        print("\nNo tables found.")
        sys.exit(0)

    with open(output_path, "w", newline="") as f:
        writer = csv.DictWriter(
            f, fieldnames=["namespace", "table", "identifier", "metadata_location"]
        )
        writer.writeheader()
        writer.writerows(rows)

    print(f"\nSaved {len(rows)} table(s) to {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description="Download Iceberg table metadata from Lakekeeper to a CSV file"
    )
    parser.add_argument(
        "--lakekeeper-url",
        required=True,
        help="Lakekeeper base URL",
    )
    parser.add_argument(
        "--warehouse",
        default="[RESOURCE_NAME]",
        help="Warehouse name in Lakekeeper (default: datahub)",
    )
    parser.add_argument(
        "--client-id",
        required=True,
        help="App registration client ID for Lakekeeper auth",
    )
    parser.add_argument(
        "--client-secret",
        required=True,
        help="App registration client secret for Lakekeeper auth",
    )
    parser.add_argument(
        "--tenant-id",
        required=True,
        help="Azure AD tenant ID",
    )
    parser.add_argument(
        "--oauth-scope",
        required=True,
        help="OAuth scope for Lakekeeper (e.g., api://<client-id>/.default)",
    )
    parser.add_argument(
        "--output",
        "-o",
        default="tables.csv",
        help="Output CSV file path (default: tables.csv)",
    )

    args = parser.parse_args()

    download_metadata(
        lakekeeper_url=args.lakekeeper_url,
        warehouse=args.warehouse,
        client_id=args.client_id,
        client_secret=args.client_secret,
        tenant_id=args.tenant_id,
        oauth_scope=args.oauth_scope,
        output_path=args.output,
    )


if __name__ == "__main__":
    main()