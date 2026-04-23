import datetime
import tempfile
import pathlib
import pyarrow as pa
import pandas as pd
from io import BytesIO
import zipfile
import hashlib
from typing import List
from zoneinfo import ZoneInfo

from azure.core.exceptions import HttpResponseError

from dagster import (
    asset,
    multi_asset,
    AssetExecutionContext,
    MaterializeResult,
    get_dagster_logger,
    asset_check,
    multi_asset_check,
    AssetSpec,
    AssetCheckResult,
    AssetCheckSpec,
    AssetCheckExecutionContext,
    AssetKey,
    DynamicPartitionsDefinition,
    AssetRecordsFilter,
)

from ..resources.utils import unpack_dagster_asset_metadata
from ..common.assets import handle_null_columns

logger = get_dagster_logger()


# Use UTC timezone for consistent timestamps
tz_utc = ZoneInfo("UTC")


# Base GTFS tables that are commonly expected - used for asset checks
# update content as files are included or removed from gtfs
combined_feed_gtfs_tables = [
    "agency",
    "areas",
    "calendar",
    "calendar_dates",
    "fare_leg_rules",
    "fare_media",
    "fare_products",
    "fare_transfer_rules",
    "feed_info",
    "levels",
    "networks",
    "pathways",
    "route_networks",
    "routes",
    "shapes",
    "stop_areas",
    "stop_times",
    "stops",
    "timeframes",
    "trips",
    "shapes",
]


wmata_specific_files = ["timepoint_times", "timepoints"]

# All supported GTFS tables for dag
# add tables from feed to above as needed
# NOTE: only .txt format currently supported, need to add handler for json/other
all_possible_gtfs_tables = set(
    combined_feed_gtfs_tables + wmata_specific_files + ["feed_meta"]
)

# Dynamic partitioning definition using feed_hash as partition key
feed_hash_partitions_def = DynamicPartitionsDefinition(name="feed_hash")


# Helper functions, called by gtfs assets --------------------------------------------
def discover_gtfs_tables_in_zip(zip_data: bytes) -> List[str]:
    """Discover all GTFS tables (.txt files) in the zip archive"""
    tables = []
    try:
        with zipfile.ZipFile(BytesIO(zip_data), "r") as zip_file:
            for filename in zip_file.namelist():
                if filename.endswith(".txt"):
                    table_name = filename.split(".")[0]  # Remove .txt extension
                    tables.append(table_name)

        logger.info(f"Discovered {len(tables)} GTFS tables: {sorted(tables)}")
        return sorted(tables)
    except Exception as e:
        logger.error(f"Error discovering tables in zip: {str(e)}")
        return []


def get_feed_hash_from_context(context: AssetExecutionContext) -> str | None:
    """Get feed hash from partition context. Returns None if not partitioned."""
    try:
        return context.partition_key
    except Exception:
        logger.warning("No partition key available — run must be partition-scoped")
        return None


def get_zip_filename(content_hash: str) -> str:
    """Construct zip filename from content hash. Format is always {hash}.zip."""
    return f"{content_hash}.zip"


def extract_files_from_zip(
    azure_client, zip_filename: str, content_hash: str
) -> List[dict]:
    """Extract files from zip archive and upload to blob storage"""
    logger.info(f"Extracting files for feed hash: {content_hash}")
    zip_data = azure_client.download_blob(f"gtfs/{zip_filename}")

    extracted_files = []

    with tempfile.TemporaryDirectory() as tempdir:
        temp_path = pathlib.Path(tempdir)
        extract_path = temp_path / "extracted_gtfs"
        extract_path.mkdir(exist_ok=True)

        # Extract zip file
        buff = BytesIO(zip_data)
        with zipfile.ZipFile(buff, "r") as zr:
            logger.info(f"Opening zipfile, extracting to {extract_path}")
            zr.extractall(extract_path)
            logger.info("Extraction complete")

        # Process each file found in the zip and upload them
        for file_path in extract_path.iterdir():
            if file_path.is_file():
                filename_with_ext = file_path.name
                file_stem = file_path.stem
                file_ext = file_path.suffix

                logger.info(f"Processing file: {filename_with_ext}")

                # Read file content and upload to blob storage
                with open(file_path, "rb") as f:
                    file_content = f.read()

                # Upload to blob storage
                blob_path = f"gtfs/extracted/{content_hash}/{filename_with_ext}"
                file_metadata = {
                    "feed_hash": content_hash,
                    "filename": filename_with_ext,
                    "file_stem": file_stem,
                    "file_extension": file_ext,
                    "extracted_timestamp": datetime.datetime.now(
                        datetime.timezone.utc
                    ).isoformat(),
                }

                azure_client.upload_blob(
                    blob_path, file_content, metadata=file_metadata
                )

                extracted_files.append(
                    {
                        "filename": filename_with_ext,
                        "file_stem": file_stem,
                        "file_extension": file_ext,
                        "file_size": len(file_content),
                    }
                )

                logger.info(f"Uploaded {filename_with_ext} ({len(file_content)} bytes)")

    return extracted_files


def get_gtfs_source_from_blob(azure_client, content_hash: str, api_client) -> str:
    """Get GTFS source URL from the zip blob's metadata for a specific feed_hash."""
    blob_path = f"gtfs/{content_hash}.zip"
    metadata = azure_client.get_blob_metadata(blob_path)
    source = metadata.get("source")
    if source:
        return source

    logger.info("Source not found in blob metadata, using configured API URL")
    return api_client.base_url


def get_date_retrieved_from_zip_blob(
    azure_client, content_hash: str
) -> datetime.datetime:
    """Get date_retrieved from the zip blob's metadata.

    The date_retrieved field in blob metadata is a UTC date string (YYYY-MM-DD)
    set at upload time. Falls back to current time if not available.
    Returned as America/New_York datetime.
    """
    tz_et = ZoneInfo("America/New_York")
    blob_path = f"gtfs/{content_hash}.zip"
    metadata = azure_client.get_blob_metadata(blob_path)
    date_str = metadata.get("date_retrieved")
    if date_str:
        utc_dt = datetime.datetime.strptime(date_str, "%Y-%m-%d").replace(
            tzinfo=datetime.timezone.utc
        )
        return utc_dt.astimezone(tz_et)

    logger.warning("Falling back to current time for date_retrieved")
    return datetime.datetime.now(tz_et)


def get_available_txt_files_from_storage(azure_client, content_hash: str) -> List[str]:
    """Get list of available .txt files from blob storage for a given partition"""
    partition_path = f"gtfs/extracted/{content_hash}/"
    blobs = azure_client.list_blobs(name_starts_with=partition_path)

    available_txt_files = []
    for blob in blobs:
        blob_name = blob.name
        filename = blob_name.replace(partition_path, "")
        if filename.endswith(".txt"):
            table_name = filename[:-4]  # Remove .txt
            available_txt_files.append(table_name)

    logger.info(f"Available txt files in storage: {available_txt_files}")
    return available_txt_files


def determine_tables_to_process(
    context: AssetExecutionContext, available_txt_files: List[str]
) -> set:
    """Determine which tables should be processed based on selection and availability"""
    selected_asset_keys = context.selected_asset_keys or set()
    selected_table_names = {key.path[-1] for key in selected_asset_keys}

    # Available tables = txt files + feed_meta, filtered by supported tables
    available_tables = (
        set(available_txt_files + ["feed_meta"]) & all_possible_gtfs_tables
    )

    if selected_table_names:
        # When tables are explicitly selected, process only those
        tables_to_process = selected_table_names
    else:
        # When running automatically, only process available tables
        tables_to_process = available_tables

    logger.info(f"Selected tables for this run: {selected_table_names or 'all'}")
    logger.info(f"Tables to process: {tables_to_process}")
    return tables_to_process


def process_single_gtfs_table(
    table_name: str,
    azure_client,
    database_client,
    content_hash: str,
    gtfs_source: str,
    date_retrieved: datetime.datetime,
    dagster_context: AssetExecutionContext,
) -> MaterializeResult:
    """Process a single GTFS table and return MaterializeResult"""

    if table_name == "feed_meta":
        df = create_feed_meta_df(
            source_name=gtfs_source,
            feed_hash=content_hash,
            date_retrieved=date_retrieved,
        )
    else:
        blob_path = f"gtfs/extracted/{content_hash}/{table_name}.txt"
        try:
            file_content = azure_client.download_blob(blob_path)
            df = pd.read_csv(BytesIO(file_content), low_memory=False, dtype="str")
            df = handle_null_columns(df)
        except Exception as e:
            logger.error(f"Failed to read table {table_name}: {str(e)}")
            return MaterializeResult(
                asset_key=table_name,
                metadata={
                    "table_processed": False,
                    "error": str(e),
                    "feed_hash": content_hash,
                    "processed_timestamp": datetime.datetime.now(
                        datetime.timezone.utc
                    ).isoformat(),
                },
            )

    df["feed_hash"] = content_hash

    table = pa.Table.from_pandas(df, preserve_index=False)
    database_client.write_table(
        table_name=table_name,
        schema_name="gtfs",
        pa_table=table,
        partition_col="feed_hash",
        partition_value=content_hash,
        transform_type="identity",
        overwrite_strategy="identity_equals",
        mode="overwrite",
        dagster_context=dagster_context,
    )

    return MaterializeResult(
        asset_key=table_name,
        metadata={
            "rows": len(df),
            "columns": len(df.columns),
            "feed_hash": content_hash,
            "table_processed": True,
            "processed_timestamp": datetime.datetime.now(
                datetime.timezone.utc
            ).isoformat(),
        },
    )


def verify_is_zip(zip_buffer: BytesIO) -> bool:
    try:
        is_zip = zipfile.is_zipfile(BytesIO(zip_buffer))
        if is_zip:
            return True
        else:
            logger.error(
                "API response does not appear to be zip data, check HTTP status code or contents"
            )
            raise Exception
    except Exception as e:
        logger.error(f"API response does not appear to be zip data: {e}")
        raise


def sort_zip_contents(zip_content: bytes) -> BytesIO:
    """Sorts zip-file for hashing"""
    zip_buffer = BytesIO(zip_content)
    output_buffer = BytesIO()

    with zipfile.ZipFile(zip_buffer, "r") as input_zip:
        files = input_zip.infolist()
        sorted_files = sorted(files, key=lambda x: x.filename)

        with zipfile.ZipFile(
            output_buffer, "w", compression=zipfile.ZIP_DEFLATED
        ) as output:
            for f in sorted_files:
                file_content = input_zip.read(f.filename)
                output.writestr(f, file_content)
    output_buffer.seek(0)
    return output_buffer.getvalue()


def generate_file_hash(zip_data: bytes) -> str:
    """Generates a md5 hash to uniquely identify zip files"""
    hash_data = hashlib.md5(zip_data).hexdigest()
    return hash_data


def create_feed_meta_df(
    source_name: str, feed_hash: str, date_retrieved: datetime.datetime
) -> pd.DataFrame:
    # Convert timezone-aware datetime to timezone-naive, then convert to ms to Iceberg compatibility
    if date_retrieved.tzinfo is not None:
        date_retrieved = date_retrieved.replace(tzinfo=None)

    df = pd.DataFrame.from_dict(
        {
            "source": [source_name],
            "feed_hash": [feed_hash],
            "date_retrieved": [date_retrieved],
        }
    )

    df["date_retrieved"] = pd.to_datetime(df["date_retrieved"]).astype("datetime64[us]")

    return df


# Assets --------------------------------------------------------------------------


@asset(
    required_resource_keys={"api_client", "azure_storage_resource"},
    description="Downloads combined bus+rail GTFS from [AGENCY] API",
    name="gtfs_zip",
    group_name="gtfs",
    kinds=["python", "file"],
    output_required=False,
)
def gtfs_zip(context: AssetExecutionContext):
    """Retrieves GTFS from API and uploads to as blob to Azure container"""
    try:
        # Download, sort zip, hash, and write to blob storage
        current_date = str(datetime.datetime.now(datetime.timezone.utc).date())
        api_client = context.resources.api_client.get_client()

        zip_content = api_client.download_zip()
        logger.info(f"Downloaded zip of {len(zip_content)} bytes")

        if verify_is_zip(zip_content):
            logger.info("Zip contents appear to be a valid zip archive")

        # Discover tables in the zip for metadata
        discovered_tables = discover_gtfs_tables_in_zip(zip_content)

        sorted_zip = sort_zip_contents(zip_content)
        logger.info("Zipfile sorted")

        contents_hash = generate_file_hash(sorted_zip)
        logger.info(f"Generated hash {contents_hash} from source GTFS")

        file_name = f"{contents_hash}.zip"
        logger.info(f"Will save blob to file name {file_name}")

        try:
            azure_client = context.resources.azure_storage_resource.get_client()
        except HttpResponseError as e:
            logger.error(
                f"Received Azure exception - confirm you have the appropriate role: {e}"
            )
            raise
        existing_blobs = azure_client.list_blobs()
        existing_hashes = azure_client.list_hashes(existing_blobs)
        metadata = {
            "filename": file_name,
            "date_retrieved": current_date,
            "size": str(len(zip_content)),
            "content_hash": contents_hash,
            "source": api_client.base_url,
            "discovered_tables": ",".join(discovered_tables),  # Store discovered tables
            "table_count": str(len(discovered_tables)),
        }

        # Always add the feed_hash to the dynamic partition to enable manual reruns
        # Downstream assets can handle cases where gtfs_zip didn't materialize
        try:
            context.instance.add_dynamic_partitions(
                feed_hash_partitions_def.name, [contents_hash]
            )
            logger.info(f"Added partition for feed_hash: {contents_hash}")
        except Exception as e:
            # Log but don't fail - partition might already exist
            logger.warning(f"Could not add dynamic partition {contents_hash}: {str(e)}")

        if contents_hash not in existing_hashes:
            logger.info(
                f"Blob {contents_hash} not in existing storage, performing upload"
            )
            metadata["status"] = "new"
            azure_client.upload_blob(f"gtfs/{file_name}", sorted_zip, metadata=metadata)

            # Only materialize when hash is new - downstream assets will run
            yield MaterializeResult(metadata=metadata)
        else:
            logger.info(
                f"Blob {file_name} already exists with hash {contents_hash}, skipping upload and downstream processing"
            )
            # Don't yield MaterializeResult - this will skip downstream assets
            # Partition is still added above for manual reruns if needed

    except Exception as e:
        logger.error(f"Error retrieving GTFS data: {e}")
        raise


@asset(
    required_resource_keys={"azure_storage_resource"},
    deps=["gtfs_zip"],
    description="Extracts all files from GTFS zip and uploads them to blob storage",
    name="gtfs_unzip_files",
    group_name="gtfs_extracted",
    kinds=["python", "file"],
    partitions_def=feed_hash_partitions_def,
    # No automation_condition — triggered by gtfs_new_feed_sensor
)
def gtfs_unzip_files(context: AssetExecutionContext):
    """Extract all files from GTFS zip and upload them to blob storage"""

    azure_client = context.resources.azure_storage_resource.get_client()

    try:
        # Get feed hash from partition context
        content_hash = get_feed_hash_from_context(context)

        # Skip execution if no partition is available
        if content_hash is None:
            logger.info("No partition key available, skipping gtfs_unzip_files")
            return MaterializeResult(
                metadata={"status": "skipped", "reason": "no_partition_key"}
            )

        # Construct zip filename from partition hash
        filename = get_zip_filename(content_hash)

        # Extract files and upload to blob storage
        extracted_files = extract_files_from_zip(azure_client, filename, content_hash)

        return MaterializeResult(
            metadata={
                "feed_hash": content_hash,
                "extracted_files": [f["filename"] for f in extracted_files],
                "total_files": len(extracted_files),
                "file_types": list(set([f["file_extension"] for f in extracted_files])),
            }
        )

    except Exception as e:
        logger.error(f"Error extracting GTFS files: {str(e)}")
        raise


@multi_asset(
    specs=[
        AssetSpec(
            key=table_name,
            group_name="gtfs_tables",
            kinds={"table", "iceberg"},
            deps=["gtfs_unzip_files"],
            partitions_def=feed_hash_partitions_def,
            # No automation_condition — triggered only by gtfs_processing_job via sensor
        )
        for table_name in all_possible_gtfs_tables
    ],
    required_resource_keys={
        "azure_storage_resource",
        "gtfs_database_resource",
        "api_client",
    },
    description="Processes GTFS files into database tables",
    can_subset=True,
    partitions_def=feed_hash_partitions_def,
)
def gtfs_tables(context: AssetExecutionContext):
    """Read GTFS files from blob storage and process into database tables.

    Processes extracted GTFS text files into partitioned database tables,
    with each partition identified by the feed_hash.
    """

    azure_client = context.resources.azure_storage_resource.get_client()
    database_client = context.resources.gtfs_database_resource.get_client()
    api_client = context.resources.api_client.get_client()

    try:
        # Get feed hash from partition context
        content_hash = get_feed_hash_from_context(context)

        # Skip execution if no partition is available
        if content_hash is None:
            logger.info("No partition key available, skipping gtfs_tables")
            # Return MaterializeResult for each possible table so asset checks can inspect them
            for table_name in all_possible_gtfs_tables:
                yield MaterializeResult(
                    asset_key=table_name,
                    metadata={
                        "status": "skipped",
                        "reason": "no_partition_key",
                        "table_processed": False,
                    },
                )
            return

        # Get GTFS source information
        gtfs_source = get_gtfs_source_from_blob(azure_client, content_hash, api_client)

        # Get date_retrieved from the original zip blob metadata
        date_retrieved = get_date_retrieved_from_zip_blob(azure_client, content_hash)

        # Get available files from blob storage
        available_txt_files = get_available_txt_files_from_storage(
            azure_client, content_hash
        )

        # Determine which tables to process
        tables_to_process = determine_tables_to_process(context, available_txt_files)

        logger.info(f"Processing GTFS tables for feed_hash: {content_hash}")

        # Process each table
        for table_name in tables_to_process:
            yield process_single_gtfs_table(
                table_name,
                azure_client,
                database_client,
                content_hash,
                gtfs_source,
                date_retrieved,
                context,
            )

    except Exception as e:
        logger.error(f"Error processing GTFS tables: {str(e)}")
        raise


# Asset checks ----------------------


@asset_check(
    name="exists",
    asset="gtfs_zip",
    required_resource_keys={"azure_storage_resource"},
)
def check_gtfs_zip(context: AssetCheckExecutionContext) -> AssetCheckResult:
    """Retrieve processed blob metadata to check zip size and discovered tables"""

    instance = context.instance
    zip_asset_key = AssetKey(["gtfs_zip"])
    materialization_record = instance.get_latest_materialization_event(zip_asset_key)

    if materialization_record and materialization_record.asset_materialization:
        metadata = materialization_record.asset_materialization.metadata
        filename = unpack_dagster_asset_metadata(metadata, "filename")
        zip_size = unpack_dagster_asset_metadata(metadata, "size")
        discovered_tables = unpack_dagster_asset_metadata(
            metadata, "discovered_tables"
        ).split(",")
        table_count = int(unpack_dagster_asset_metadata(metadata, "table_count"))

        return AssetCheckResult(
            passed=True,
            metadata={
                "filename": filename,
                "zip_size": zip_size,
                "discovered_tables": discovered_tables,
                "table_count": table_count,
            },
        )
    else:
        return AssetCheckResult(
            passed=False, metadata={"error": "No gtfs_zip materialization found"}
        )


@asset_check(
    name="extracted",
    asset="gtfs_unzip_files",
    required_resource_keys={"azure_storage_resource"},
)
def check_gtfs_unzip_files(context: AssetCheckExecutionContext) -> AssetCheckResult:
    """Check that GTFS files were extracted successfully"""

    instance = context.instance
    unzip_asset_key = AssetKey(["gtfs_unzip_files"])

    # Get partition key from run tags for partitioned assets
    partition_key = context.run.tags.get("dagster/partition") if context.run else None

    materialization_record = instance.get_latest_materialization_event(unzip_asset_key)
    if materialization_record and materialization_record.asset_materialization:
        metadata = materialization_record.asset_materialization.metadata

        # Extract file metadata
        extracted_files = unpack_dagster_asset_metadata(metadata, "extracted_files")
        total_files = unpack_dagster_asset_metadata(metadata, "total_files")
        file_types = unpack_dagster_asset_metadata(metadata, "file_types")

        return AssetCheckResult(
            passed=True,
            metadata={
                "extracted_files": extracted_files,
                "total_files": total_files,
                "file_types": file_types,
                "partition_key": partition_key,
            },
        )
    else:
        return AssetCheckResult(
            passed=False,
            metadata={"error": "No gtfs_unzip_files materialization found"},
        )


@multi_asset_check(
    specs=[
        AssetCheckSpec("gte_0_rows", asset=table_name)
        for table_name in all_possible_gtfs_tables
    ],
    can_subset=True,
)
def check_gtfs_tables_populated(context: AssetCheckExecutionContext):
    """Check that individual GTFS table assets were processed successfully"""

    # Get partition key from run tags for partitioned assets
    partition_key = context.run.tags.get("dagster/partition") if context.run else None

    # Track failures to raise exception at the end (after all checks complete)
    failed_tables = []

    # Check all assets that were materialized in this run, not just selected ones
    instance = context.instance

    # Get all materialized assets for this run by looking at recent materializations
    materialized_tables = []
    for check_key in context.selected_asset_check_keys:
        table_name = check_key.asset_key.to_user_string()
        logger.info(f"table name: {table_name}")
        asset_key = AssetKey([table_name])

        if partition_key:
            records = instance.fetch_materializations(
                records_filter=AssetRecordsFilter(
                    asset_key=asset_key, asset_partitions=[partition_key]
                ),
                limit=1,
            )
            if records:
                materialized_tables.append(table_name)
        else:
            materialization_record = instance.get_latest_materialization_event(
                asset_key
            )
            if materialization_record:
                materialized_tables.append(table_name)

    for table_name in materialized_tables:
        try:
            # Get the materialization record for this table
            asset_key = AssetKey([table_name])

            materialization_record = instance.get_latest_materialization_event(
                asset_key
            )

            if materialization_record:
                metadata = materialization_record.asset_materialization.metadata

                # Check if the table processing failed
                table_processed = unpack_dagster_asset_metadata(
                    metadata, "table_processed"
                )
                if table_processed is False:
                    error_msg = unpack_dagster_asset_metadata(metadata, "error")
                    failed_tables.append(table_name)
                    yield AssetCheckResult(
                        passed=False,
                        check_name="gte_0_rows",
                        asset_key=asset_key,
                        metadata={
                            "table_name": table_name,
                            "table_processed": False,
                            "error": error_msg,
                            "partition_key": partition_key,
                        },
                    )
                    continue

                row_count = unpack_dagster_asset_metadata(metadata, "rows")

                # Convert to int if it's a string
                if isinstance(row_count, str):
                    row_count = int(row_count)
                elif row_count is None:
                    row_count = 0

                # Check if table has >= 0 rows (allows empty tables)
                test_passed = row_count >= 0

                yield AssetCheckResult(
                    passed=test_passed,
                    check_name="gte_0_rows",
                    asset_key=asset_key,
                    metadata={
                        f"{table_name}_rows": row_count,
                        "table_name": table_name,
                        "table_processed": True,
                        "partition_key": partition_key,
                    },
                )
            else:
                # No materialization record found - OK for optional tables that weren't in the feed
                yield AssetCheckResult(
                    passed=True,
                    check_name="gte_0_rows",
                    asset_key=asset_key,
                    metadata={
                        "table_name": table_name,
                        "table_processed": False,
                        "note": "No materialization record found - table not in feed",
                        "partition_key": partition_key,
                    },
                )

        except Exception as e:
            logger.error(f"Error checking GTFS table {table_name}: {str(e)}")
            failed_tables.append(table_name)
            yield AssetCheckResult(
                passed=False,
                check_name="gte_0_rows",
                asset_key=AssetKey([table_name]),
                metadata={
                    "error": str(e),
                    "table_name": table_name,
                    "partition_key": partition_key,
                },
            )

    # After all checks complete, fail the run if any tables failed
    if failed_tables:
        failed_list = ", ".join(failed_tables)
        raise Exception(
            f"Asset check failed for tables: {failed_list}. Run marked as failed."
        )