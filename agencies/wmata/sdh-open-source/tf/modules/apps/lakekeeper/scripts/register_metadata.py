#!/usr/bin/env python3
"""
Re-register Iceberg tables with a Lakekeeper catalog from a CSV file.

Reads a CSV file (produced by download_metadata.py) containing table
identifiers and metadata locations, then registers each table with
Lakekeeper. Intended for use after a Lakekeeper re-bootstrap that
clears catalog metadata.

Requirements:
    pip install "pyiceberg[adlfs,pyarrow]"

Usage:
    python register_metadata.py \
        --lakekeeper-url https://[Project Name]-[env1]-lakekeeper-ca.icyrock-... \
        --client-id <app-client-id> \
        --client-secret <app-client-secret> \
        --tenant-id <tenant-id> \
        --oauth-scope "api://<lakekeeper-client-id>/.default" \
        --input tables.csv

    # Dry run:
    python register_metadata.py ... --input tables.csv --dry-run
"""

import argparse
import csv
import sys

from pyiceberg.catalog import load_catalog


def register_tables(
    input_path: str,
    lakekeeper_url: str,
    warehouse: str,
    client_id: str,
    client_secret: str,
    tenant_id: str,
    oauth_scope: str,
    dry_run: bool = False,
    filter_ns: str | None = None,
):
    """Read a CSV and register each table with Lakekeeper."""

    with open(input_path, newline="") as f:
        reader = csv.DictReader(f)
        rows = list(reader)

    if not rows:
        print("CSV file is empty.")
        sys.exit(0)

    if filter_ns:
        rows = [r for r in rows if r["namespace"].lower().startswith(filter_ns.lower())]
        if not rows:
            print(f"No tables matching namespace filter '{filter_ns}'.")
            sys.exit(0)

    print(f"Found {len(rows)} table(s) in {input_path}")

    if dry_run:
        print("\n=== DRY RUN — no tables will be registered ===\n")
    else:
        print("\n=== Registering tables with Lakekeeper ===\n")

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

    created_namespaces: set[str] = set()
    successes = []
    failures = []

    for row in rows:
        namespace = row["namespace"]
        identifier = row["identifier"]
        metadata_location = row["metadata_location"]

        print(f"  {identifier}")
        print(f"    metadata: {metadata_location}")

        if dry_run:
            print("    -> would register")
            successes.append(identifier)
            continue

        try:
            # Ensure namespace exists (only attempt once per namespace)
            if namespace not in created_namespaces:
                try:
                    catalog.create_namespace(namespace)
                    print(f"    -> created namespace '{namespace}'")
                except Exception:
                    pass  # Already exists
                created_namespaces.add(namespace)

            catalog.register_table(
                identifier=identifier,
                metadata_location=metadata_location,
            )
            print(f"    -> registered: {identifier}")
            successes.append(identifier)

        except Exception as e:
            print(f"    -> FAILED: {e}")
            failures.append((identifier, str(e)))

    print(f"\n{'DRY RUN ' if dry_run else ''}Summary:")
    print(f"  Succeeded: {len(successes)}")
    if failures:
        print(f"  Failed:    {len(failures)}")
        for ident, err in failures:
            print(f"    - {ident}: {err}")

    return len(failures) == 0


def main():
    parser = argparse.ArgumentParser(
        description="Re-register Iceberg tables with Lakekeeper from a CSV file"
    )
    parser.add_argument(
        "--input",
        "-i",
        required=True,
        help="Input CSV file (produced by download_metadata.py)",
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
        "--dry-run",
        action="store_true",
        help="List tables without registering them",
    )
    parser.add_argument(
        "--filter",
        help="Only process namespaces matching this prefix",
    )

    args = parser.parse_args()

    success = register_tables(
        input_path=args.input,
        lakekeeper_url=args.lakekeeper_url,
        warehouse=args.warehouse,
        client_id=args.client_id,
        client_secret=args.client_secret,
        tenant_id=args.tenant_id,
        oauth_scope=args.oauth_scope,
        dry_run=args.dry_run,
        filter_ns=args.filter,
    )

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()