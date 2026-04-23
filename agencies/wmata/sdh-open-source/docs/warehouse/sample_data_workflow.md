# Sample Data Workflow

This document provides guidance on working with sample data in the TIDES project.

## Contents

- [Quick Decision Guide](#quick-decision-guide)
- [Approach 1: Pre-loaded DuckDB Files (Recommended for Analysts)](#approach-1-pre-loaded-duckdb-files-recommended-for-analysts)
- [Approach 2: Loading Sample Data from ZIP (For Developers)](#approach-2-loading-sample-data-from-zip-for-developers)
- [Best Practices](#best-practices)
- [Running Incremental Models on Trino](#running-incremental-models-on-trino)
- [dbt Style Guide](#dbt-style-guide)
- [Trino Best Practices](#trino-best-practices)
- [Troubleshooting FAQ](#troubleshooting-faq)
- [Expected Data Structure](#expected-data-structure)

## Quick Decision Guide

```text
┌─────────────────────────────────────┐
│ Which approach is right for you?    │
└───────────────┬─────────────────────┘
                │
        ┌───────┴───────┐
        ▼               ▼
┌───────────────┐ ┌───────────────┐
│ I'm an        │ │ I'm a         │
│ ANALYST       │ │ DEVELOPER     │
└───────┬───────┘ └───────┬───────┘
        │                 │
        ▼                 ▼
┌───────────────┐ ┌───────────────┐
│ USE APPROACH 1│ │ USE APPROACH 2│
│ Pre-loaded DB │ │ Load from ZIP │
└───────────────┘ └───────────────┘
```

## Approach 1: Pre-loaded DuckDB Files (Recommended for Analysts)

### ANALYST QUICK START

```text
1. Download: bus_info_sample.duckdb → warehouse/
2. Copy: profiles.yml.template → profiles.yml
3. Edit: path: ./bus_info_sample.duckdb in profiles.yml
4. Test: dbt run -m test_query
5. Start working: dbt run -m your_model
```

#### Detailed Steps for Analysts

1. **Download a Pre-loaded Database:**
   - Access the [DuckDB - Sample Data]([link redacted]) folder on SharePoint
   - download `warehouse.duckdb`. You'll want to do this regularly if you start a new branch, as the data may be updated.
   - Download the file to your `warehouse/` directory

2. **Configure Your Profile:**
   - Create a `profiles.yml` file in the `warehouse/` directory by copying the template:

     ```sh
     # Mac/Linux
     cp profiles.yml.template profiles.yml
     
     # Windows
     Copy-Item profiles.yml.template -Destination profiles.yml
     ```

   - Make any further edits as necessary (unlikely)

3. **Verify Your Setup:**
   - Make sure your virtual environment is activated (see [Environment Setup](../CONTRIBUTING.md#environment-setup))
   - Run a test query to confirm your connection:

     ```sh
     dbt run -m test_query
     ```

   - You should see a successful model build

## Approach 2: Loading Sample Data from ZIP (For Developers)

### DEVELOPER QUICK START

```text
1. Download: bus_info_sample.zip → [project-name]/warehouse/scratch/
2. Change directory (if root): cd warehouse
3. Load data: python data-load-scripts/load_sample_data.py scratch/bus_info_sample.zip
4. Test: dbt run -m test_query
```

#### Detailed Steps for Developers

1. **Obtain the Sample Data:**
   - Access the [AFC and Bus info - [name redacted]]([link redacted]) folder on SharePoint
   - Download the zip file to a consistent location:

     ```sh
     [project-name]/warehouse/scratch/bus_info_sample.zip
     ```

   - This location is git-ignored to prevent accidental commits

2. **Load the Bus info Sample Data:**
   - Make sure you are in warehouse directory and virtual environment is activated
   - Run the loading script with the path to your downloaded zip file:

     ```sh
     # Mac/Linux
     python data-load-scripts/load_sample_data.py scratch/bus_info_sample.zip
     
     # Windows
     python data-load-scripts/load_sample_data.py scratch/bus_info_sample.zip
     ```

   - The script will create or update your `warehouse.duckdb` file with tables from the zip file

3. **Expected Output:**

    - After loading, you should see tables in the `sample_data` schema
    - Key tables may include:
    - `sample_data.tbl_20250120_avl_bus_033047` - Bus location data
    - `sample_data.tbl_20250120_avl_bus_metadata` - Metadata for bus events
    - Verify with the following:

      ```sql
      select table_schema, table_name 
      from information_schema.tables 
      where table_schema = 'sample_data';
      ```

      This query should return results detailing the contents of the schema.

4. **Load Additional Bus info Data**

    The script `data-load-scripts/load_bus_info_week.py` is configured to retrieve bus info data from the QA database and upload a sample week to warehouse.duckdb.

    This may require Azure key-vault access to be configured, as well as the [installation of Oracle Instant Client](https://python-oracledb.readthedocs.io/en/latest/user_guide/installation.html#optionally-install-oracle-client).

    The script can be called with `uv run data-load-scripts/load_bus_info_week.py`. It will take a few minutes to retrieve data and upload it to warehouse.duckdb.

5. **Load GTFS Sample Data**

    GTFS Sample Data may be loaded using one of two GTFS scripts located within `.warehouse/data-load-scripts`:

    - Option 1:  `data-load-scripts/load_azure_gtfs.py` - This connects to Azure to download processed GTFS from a specific blob storage account and container. You will need to have authenticated to Azure using the [az CLI tool](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux) and set appropriate blob storage access permissions.
    - Option 2: `data-load-scripts/load_specific_gtfs.py` - You must pass the filepath to the GTFS that you wish to process when running this script, such as `uv run data-load-scripts/load_specific_gtfs.py path/to/my/gtfs.zip`.

  > NOTE: The ingest scripts are currently written for [AGENCY] feeds as of early 2025 through summer 2025. Feeds from other agencies or older feeds may encounter unexpected column contents and fail to ingest. This is a known issue and updates are planned.

  Either script will update the warehouse.duckdb file with GTFS tables.

## Best Practices

Regardless of which approach you use:

1. **Version Tracking:**
   - Document which sample data version you're using in your PR descriptions
   - Reference the filename and download date for reproducibility

1. **Development Workflow:**
   - Always develop models in the `models/` directory
   - Use the `scratch/` directory for exploratory queries
   - Test your models with `dbt test` before submitting PRs

1. **Data Privacy:**
   - Never commit sample data or database files to GitHub
   - Don't include specific data values in PR descriptions or comments
   - Use the `.gitignore` patterns to prevent accidental commits

## dbt Style Guide

When developing dbt models for this project, follow these style guidelines to ensure consistency and readability:

### SQL Style

sql-formatting and linting will be handled by sqlfluff. In vscode, linting will be performed on save, and fixes can be applied by choosing "Format Document" from the command palette or running `sqlfluff fix <path>`.

However, keep in mind these additional style principles:

1. **Core principles:**

   - Follow the [dbt SQL Style Guide](https://docs.getdbt.com/best-practices/how-we-style/2-how-we-style-our-sql) for general SQL formatting
   - Use consistent formatting and naming conventions
   - Prioritize readability and maintainability over brevity
   - Make dependencies through references (`ref`)

1. **Joins:**
   - Always use explicit join types (`inner join`, `left join`, etc.) instead of just `join`
   - Do not use table aliases in join conditions
   - Always move left to right in joins for readability

1. **Naming Conventions:**
   - Again, use human-readable names rather than initialisms
   - Follow the project naming conventions for models:
     - Staging models: `stg_[source]_[entity]`
     - Intermediate models: `int_[entity]_[verb]`
     - Mart/fact models: `fct_[entity]_[domain]`
   - Use snake_case for all names

1. **CTEs and Model Structure:**
   - Start models with "import" CTEs that load references to make dependencies explicit:

     ```sql+jinja
     with
     dim_calendar_dates AS (
       select *
       from {{ ref('dim_calendar_dates') }}
     ),
     int_gtfs_schedule__long_calendar AS (
       select *
       from {{ ref('int_gtfs_schedule__long_calendar') }}
     ),
     ```

   - Use human-readable CTE names instead of initialisms or abbreviations
   - The final CTE should be named to match the model itself and should list all columns explicitly:

     ```sql
     final_model_name AS (
       select
         column_1,
         column_2,
         column_3,
         -- etc.
       from intermediate_cte
       where condition = true
     )
     ```

   - The last line of the file should be a simple select from the final CTE:

     ```sql
     select * from final_model_name
     ```

1. **Project-specific Style Guide:**

- Row identifiers:
  - Create a `_row_id` field only to identify a row in source data. `_row_id` fields are generally used to
    idenfity cases of fan-out from improper joins. Broadly speaking, `_row_id` is process- and pipeline-oriented
    and does not have meaning on its own.
  - Create a `_key` field (note leading underscore) when creating a new model and creating a unique, per-row
    composite key/identifier. In the model properties, create uniqueness tests in your using this `_key` field, rather than the
    `dbt_utils.unique_combination_of_columns` data test.
  - Don't join on the `_key` field; use columns with semantic meaning instead.
  - Place this `_key` field first in a model's columns.
  - Don't try to elaborate on the key name, e.g., `_key_feed_service_date`; just use `_key`
- Model names:
  - If `daily` or `monthly` is in the model name, the model should represent an aggregation to that level of
  granularity (e.g., average daily or monthly ridership). It should not be used to represent scheduled trips that also
  happen to have a date as an attribute (e.g., a scheduled instance of a trip on particular days).

### Documentation

- Document a model in the model property YAML file (e.g., _mart_bus.yml) that lives in the same directory as your model's .sql file (e.g., in `warehouse/models/mart/bus/`).
- In this file, include descriptions for all columns; use `doc()` references in jinja to link to descriptions in docs/ folder. For example, use:

  ```yaml
      columns:
        - name: service_date
          description: "{{ doc('field_stop_visits_service_date') }}"
  ```
  
  Which references in `docs/tides_stop_visits.md`:

  ```md
  {% docs field_stop_visits_service_date %}
  Service date. References GTFS indirectly via calendars.txt and calendar_dates.txt
  {% enddocs %}
  ```

- Add tests for primary keys and important relationships. Use dbt_utils for composite keys, not dbt constraints.

### Example

Here's an example of a well-structured model (note: this is pseudo-code) following these guidelines:

```sql+jinja
with source_data as (
    select *
    from {{ ref('stg_source__transactions') }}
),

filtered_transactions as (
    select
        transaction_id,
        customer_id,
        transaction_date,
        amount,
        status
    from source_data
    where status != 'cancelled'
),

daily_customer_transactions as (
    select
        customer_id,
        transaction_date,
        sum(amount) as daily_total,
        count(*) as transaction_count
    from filtered_transactions
    group by 1, 2
),

final_daily_customer_transactions as (
    select
        customer_id,
        transaction_date,
        daily_total,
        transaction_count,
        daily_total / transaction_count as average_transaction_value
    from daily_customer_transactions
)

select * from final_daily_customer_transactions

```

## Running Incremental Models on Trino

Most dbt models in the warehouse are **incremental**, processing only a portion of data on each run rather than rebuilding the entire table. This is essential for performance as data grows and even a few days' worth of data can outstrip what the Trino dev environment can handle.

> NOTE: dbt recommends setting `full_refresh=false` in the model config. This is currently un-set due to limited data volumes and to facilitate data updates during active development.

### Which models are incremental?

Three parts of the pipeline have been converted to incremental builds:

**Fares and faregates pipeline (microbatch on `service_date`)** — FARE fare transactions, vendor_2 open payment transactions, faregate passenger events, and downstream station activities. Covers staging models (`stg_fare_sale`, `stg_fare_use`, `stg_faregate_data_orgn`), intermediates (`int_tides_fare_transactions_fare`, `int_tides_fare_transactions_vendor_2`, `int_vendor_2_with_transfers`, `int_tides_passenger_events_faregates`, `int_disaggregated_station_activities`), quality models, and mart tables through `fct_tides_station_activities`. Use `--event-time-start` and `--event-time-end` to control which service dates are built.

**Bus info and rail pipeline (microbatch on `service_date`)** — vehicle locations, stop visits, station activities, and ridership metrics. These models use dbt's `microbatch` strategy, processing one day at a time based on `service_date`. Use `--event-time-start` and `--event-time-end` CLI flags to control which days are built.

**GTFS schedule pipeline (microbatch on `_date_retrieved`)** — `dim_stop_times`, `fct_scheduled_trips`, `fct_scheduled_stop_times`, and `int_gtfs_stop_times_grouped_trip_summary`. These models process static GTFS feed data, batching by the feed's `_date_retrieved` date (when the feed was retrieved from the API, truncated to day). Use `--event-time-start` and `--event-time-end` to control which feed dates are built.

All other models (GTFS dimensions, `dim_dates`, `fare_instrument` seed) remain unpartitioned and build in full on each run.

### Default vars

All microbatch models use `begin` in their model config, set via the project variable `incremental_begin_date` (currently `2026-03-01` in `dbt_project.yml`). To change the earliest processable date for all models at once, update this variable. The date range for incremental runs is controlled via `--event-time-start` and `--event-time-end` CLI flags.

### Common workflows

**First run (create tables):**

On Trino dev, you cannot full-refresh the entire project — the dataset is too large. Instead, run incremental models with a narrow date range to create the tables:

```sh
dbt run --event-time-start 2026-03-07 --event-time-end 2026-03-08
```

Since microbatch processes one day at a time, each batch replaces its partition. Use `--full-refresh` only if you need to change the table's partitioning config.

**Incremental run (defaults):**

```sh
dbt run
```

Without `--event-time-start`/`--event-time-end`, dbt microbatch processes any new data since the last run.

**Incremental run for specific dates:**

```sh
dbt run --event-time-start 2026-03-07 --event-time-end 2026-03-08
```

**Incremental run for a specific GTFS feed date:**

```sh
dbt run --select models/mart/gtfs models/intermediate/gtfs \
  --event-time-start 2026-03-07 --event-time-end 2026-03-08
```

**Backfill a date range:**

```sh
dbt run --event-time-start 2026-03-01 --event-time-end 2026-03-09
```

dbt will automatically split this into individual daily batches, processing one day at a time. This avoids the memory pressure that caused OOM errors when processing multiple days at once.

### How microbatch works

All incremental models use the `microbatch` strategy:

1. Splits the requested date range into individual batches (one per day, configured via `batch_size='day'`)
2. For each batch, filters the model's input data to that day using the `event_time` column (`service_date` for fares/faregates and bus/rail, `_date_retrieved` for GTFS)
3. Deletes existing rows for that day and inserts the new rows

This means each batch is processed independently with low memory overhead. Re-running for the same dates replaces the data (idempotent), and data for other dates is untouched.

### Disabling realtime models

If the realtime data sources (e.g., `int_tides_vehicle_locations_realtime`) is creating difficulty in your environment, you can disable it:

```sh
dbt run --vars '{"enable_realtime": false}'
```

This prevents errors from the `int_tides_stop_visits_realtime` model and its downstream metrics dependencies.

## Trino Best Practices

Brief guidelines for writing performant dbt SQL against our Trino cluster.

### Join order matters

Trino uses hash joins. The **right-hand table is the build side** — loaded entirely into an in-memory hash table. The left-hand table is the probe side, streamed row-by-row against it.

If the build side is too large, Trino can hit `EXCEEDED_LOCAL_MEMORY_LIMIT`.

**Rule: put the larger table on the left.**

```sql
-- Good: large table streamed, small table in hash table
from stg_gtfs_stop_times        -- 57M rows (probe)
inner join dim_schedule_feeds    -- 3 rows (build)
    on stg._feed_hash = feeds._feed_hash

-- Bad: tiny table streamed, huge table in hash table -> OOM
from dim_schedule_feeds          -- 3 rows (probe)
inner join stg_gtfs_stop_times   -- 57M rows (build)
    on feeds._feed_hash = stg._feed_hash
```

This reorder is safe for INNER JOINs (commutative in relational algebra). It does not apply to LEFT/RIGHT/FULL OUTER joins, where table position determines which side preserves unmatched rows.

Trino's cost-based optimizer can sometimes choose the right build side automatically (using "replicated"/broadcast distribution when it has table stats), but our Hive connector often lacks stats. When stats are missing, the CBO falls back to partitioned distribution with syntactic ordering — so the SQL text is what determines build vs. probe. Always write joins largest-to-smallest to be safe.

As a bonus, correct join ordering allows dynamic filtering: when the build side is small, Trino extracts its join key values and pushes them as a filter into the probe-side table scan, skipping non-matching rows at read time. In the example above, Trino pushes 3 `_feed_hash` values into the 57M-row scan, dramatically reducing I/O.

### Decompose large models

Trino's query planner can struggle with high stage counts from chained window functions and multiple joins in a single query. When a model has too many stages, materialize intermediate steps as separate dbt models.

We do this in the bus info imputation pipeline (`models/intermediate/bus_info/imputation/`), where slim 2-5 column materialized tables are computed separately, then LEFT JOINed back to the full dataset.

### References

- [#783](https://github.com/[ORGANIZATION]/[project-name]/issues/783) — join order audit and OOM investigation
- [Trino: Cost-based Optimizations](https://trino.io/docs/current/optimizer/cost-based-optimizations.html)
- [Trino: Dynamic Filtering](https://trino.io/docs/current/admin/dynamic-filtering.html)

## Troubleshooting FAQ

### Common Issues

**Q: "I get 'relation does not exist' errors when running dbt"**  
A: Your profiles.yml probably doesn't match your .duckdb filename. Check both files.

**Q: "DuckDB says the database is locked"**  
A: Close any other applications that might be using the database (DBeaver, VS Code, etc.)

**Q: "I can't find the right tables in my database"**  
A: You might have downloaded the wrong pre-loaded database. Check the SharePoint folder for the correct one.

**Q: "The load_sample_data.py script fails"**  
A: Make sure your virtual environment is activated and you're running the script from the project root.

**Q: "I can't access the SharePoint links"**  
A: You need to be logged in with your [AGENCY] credentials. Contact IT if you have access issues.

### Getting Help

If you encounter issues not covered here:

1. Check the [Training and Troubleshooting]([link redacted]) channel in Teams
2. Ask a question in the channel, including:
   - Which approach you're using (pre-loaded DB or ZIP)
   - The exact error message you're seeing
   - What steps you've already tried
3. For urgent issues, contact the project lead directly

## Expected Data Structure

After setting up your sample data (either approach), you should expect to see the following structure:

### Bus info Data

- **Main Tables:**
  - `tbl_20250120_avl_bus_033047` - Contains bus location events with columns:
    - `vehicle_id` - Unique identifier for the bus
    - `timestamp` - When the event was recorded
    - `latitude`, `longitude` - Geographic coordinates
    - `route_id` - The bus route identifier
    - `direction` - Direction of travel
    - `speed` - Current speed in mph
    - `status` - Operational status code

### AFC Data (if applicable)

- **Main Tables:**
  - `tbl_afc_transactions` - Contains fare transactions with columns:
    - `transaction_id` - Unique identifier for the transaction
    - `timestamp` - When the transaction occurred
    - `card_id` - Anonymized fare card identifier
    - `transaction_type` - Type of transaction (entry, exit, etc.)
    - `location_id` - Where the transaction occurred
    - `amount` - Transaction amount (if applicable)

### GTFS Data (if applicable)

**Main Tables:**

- `gtfs_routes` - This table is the equivalent of the GTFS `routes` table.
- `gtfs_stops` - This table is the equivalent of the GTFS `stops` table.
- `gtfs_stop_times` - This table is the equivalent of the GTFS `stop_times` table.
- `gtfs_calendar` - This table is the equivalent of the GTFS `calendar` table.
- `gtfs_calendar_dates` - This table is the equivalent of the GTFS `calendar_dates` table.
- `gtfs_trips` - This table is the equivalent of the GTFS `trips` table.

This structure provides a foundation for developing models that transform the raw data into useful analytics.