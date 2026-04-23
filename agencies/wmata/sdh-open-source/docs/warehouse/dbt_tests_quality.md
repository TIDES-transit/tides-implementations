# Warehouse Data Quality and Testing in [Project Name]

## Sections

- [Overview](#overview)
- [Testing Practices](#testing-practices)
- [Data Quality Best Practices](#data-quality-best-practices)
- [Quality Model Architecture](#quality-model-architecture)
- [dbt Tests](#dbt-tests)

## Overview

Data quality is managed through two approaches:

- Quality models, such as `fct_tides_station_activities_quality`, that specify how records from source data are transformed or discarded.
  - These models track each row from incoming source data and flag specific data quality issues to allow detailed analysis and diagnosis of issues.
- [Model properties](https://docs.getdbt.com/reference/resource-properties/data-tests) and [singular tests](https://docs.getdbt.com/docs/build/data-tests#singular-data-tests) that validate expectations
  - These tests execute as part of a dbt run and can stop downstream models from materializing upon failure.

**Note: To date, this document assumes all running and testing occurs locally/in development--there is not yet additional detail in this document regarding tests on incremental updates to data.**

## Testing Practices

A quick recap:

- `dbt run` will compile and execute model against the target database, including any materialization.
- `dbt test` will run tests, including model properties tests and singular tests.
- `dbt build` will run and test in order, but will halt executions on portions of the DAG that have testing errors.

In development:

- After checking out a branch, use `dbt run` to make sure your local warehouse/development data reflects the repo's current state.
- While making edits to a model, use `dbt run --select +[your model]+` to run models upstream and downstream of your model.
- Before submitting a pull request, use `dbt build --select [your most upstream model]+`. [Using selectors](https://docs.getdbt.com/reference/node-selection/syntax) includes changes downstream of your model in your materialization and tests.

## Data Quality Best Practices

### Follow Naming Conventions

For consistency across models, consider the following:

- Quality models: `fct_*_quality`
- Quality check columns: `has_*` prefix (e.g., `has_service_date`)
- Standard columns: `is_valid`, `_key`, `row_hash`

### Follow the quality model pattern

For mart models that have a quality model upstream of them, that quality model should be their only parent model.

### Provide Documentation

All quality models and checks are documented in YAML model properties files:

```yaml
columns:
  - name: is_valid
    description: "{{ doc('field_is_valid') }}"
  - name: has_service_date
    description: "{{ doc('field_has_service_date') }}"
  - name: invalid_reason
    description: "{{ doc('field_invalid_reason') }}"
```

Quality model fields are currently all defined in `quality.md`

### Add severity levels

Generally, you should prefer to set tests to 'warn'; we expect in early stages of this effort that not all quality metrics will be met.

- **Error**: Critical issues that should fail builds (e.g., unique constraints on primary keys)
- **Warn**: Quality issues that should be monitored but not block builds (e.g., invalid records exist)

```yaml
    - name: dwell_imputed
      description: "{{ doc('field_stop_visits_dwell_imputed') }}"
      data_tests:
          - dbt_utils.accepted_range:
              arguments: 
                min_value: 0
              config:
                severity: warn 
```

### Avoid testing the same column in multiple models

- **Do** focus testing on:
  - A column when it appears in a mart/`fct_` model.
  - In some cases, you may wish to test the first appearance of a column in an `int_` model as well.
- **Don't** apply tests when:
  - A column is in an intermediate model and will be tested in an upstream or downstream model.

### Use yaml anchors carefully

Yaml anchors can simplify model properties files by avoiding repeating documentation. However, note that any tests will be reapplied downstream unless an empty test array is provided.

```yaml
    # in _int_bus_info.yml
    # under `int_tides_vehicle_locations_bus_info`
      - &vl_schedule_relationship
        name: schedule_relationship
        description: "{{ doc('field_stop_visits_schedule_relationship') }}"
        data_tests:
          - accepted_values:
              arguments: 
                values: ["Scheduled", "Skipped", "Added", "Missing"]
    # ....
    # under `int_tides_vehicle_locations_imputation`
      - <<: *vl_schedule_relationship
        data_tests: []
```

### Prefer model properties tests over singular tests

If a test can be implemented through the model properties test, please use that in lieu of a singular test. dbt packages like [dbt-utils](https://github.com/dbt-labs/dbt-utils) offer a variety of useful tests beyond those included in base dbt.

## Quality Model Architecture

### Three-Layer Quality Pattern

The project follows a consistent three-layer pattern for quality monitoring:

| Intermediate Models → | Quality Models → | Mart Models |
| --- | --- | --- |
| (int_*) → | (fct_*_quality) → | (fct*) |

1. **Intermediate Layer** (`models/intermediate/`): Transforms and prepares data from staging
2. **Quality Layer** (`models/mart/data_quality/`): Performs comprehensive quality checks and adds quality metadata
3. **Mart Layer** (`models/mart/`): Filters to valid records only for analytics consumption.

Using quality models, all records should be traceable from source to their disposition in mart models--whether they were discarded or had their values modified in some fashion.

**Example: Stop Visits Quality Flow:**

```text
-- Intermediate model
int_tides_stop_visits_bus_info
    ↓
-- Quality model with checks
fct_tides_stop_visits_bus_quality
    ↓ 
-- Final mart model
fct_tides_stop_visits_bus
    (WHERE is_valid = true)
```

### Types of Quality Checks

Every quality model creates an `is_valid` field, which is a boolean flag indicating whether the record passes all quality checks. This can be based on a few kinds of quality checks.

#### Duplicate Detection

All quality models implement duplicate detection using row hashes:

```sql+jinja
-- Generate row hash for duplicate detection
with tides_int as (
    select
        *,
        {{ dbt_utils.generate_surrogate_key([
            'transaction_id', 
            'service_date', 
            'event_timestamp', 
            'amount', 
            'fare_action', 
            'source_system'
        ]) }} as row_hash
    from {{ ref('int_tides_fare_transactions_fare') }}
),

-- Identify duplicates
dupes as (
    select
        row_hash,
        count(*) > 1 as has_dup,
        min(_row_id) as first_instance
    from tides_int
    group by row_hash
)
```

These are then implemented downstream with a few fields:

- `has_duplicates`: Boolean indicating if duplicate records exist
- `dup_row_to_keep`: Boolean indicating which duplicate to retain (typically the first instance)

#### Domain Validation

Validates that values conform to expected enums or ranges:

```sql
-- non-null checks

tides_int.transaction_id is not null as has_transaction_id,
tides_int.service_date is not null as has_service_date,
tides_int.event_timestamp is not null as has_event_timestamp

-- Enum validation
tides_int.fare_action in (
    'Purchase',
    'Enter',
    'Exit',
    -- ... other valid values
) as has_valid_fare_action

-- Positive value validation
trip_stop_sequence > 0 as has_positive_trip_stop_sequence
```

#### Business Rule Validation

Complex business logic checks specific to the domain.

**Example: Balanced Entry/Exit Pairs for vendor_2:**

From `fct_tides_fare_transactions_vendor_2_quality.sql`:

```sql
-- Count entries and exits per micropayment
micropayments as (
    select
        micropayment_id,
        charge_type,
        count(case when fare_action in ('Enter', 'Transfer entrance') then 1 end) as entry_count,
        count(case when fare_action in ('Exit', 'Transfer exit') then 1 end) as exit_count
    from int_tides_fare_transactions
    where charge_type = 'complete_variable_fare'
    group by micropayment_id, charge_type
),

-- Validate balance
check_balanced as (
    select
        micropayment_id,
        charge_type,
        entry_count,
        exit_count,
        coalesce(entry_count > 1, false) as has_multiple_entries,
        coalesce(exit_count > 1, false) as has_multiple_exits,
        coalesce(entry_count = 0, false) as has_no_entry,
        coalesce(exit_count = 0, false) as has_no_exit,
        -- Should have exactly 1 entry and 1 exit
        not coalesce(entry_count = 1 and exit_count = 1, false) as is_unbalanced_complete_variable_fare
    from micropayments
)
```

#### Optional Elements

##### Consistency checks

In some cases we may flag records that have imputed values that differ from those in source data. These do not imply an error, but can be used to monitor the extent to which corrections are being applied.

**Example: Vehicle locations comparisons:**

From `fct_tides_vehicle_locations_bus_quality`

```sql
join_checks as (
    select
        --...
        tides_int.stop_id is not null
        and tides_int.trip_stop_sequence <> tides_int.trip_stop_sequence_imputed as has_corrected_stop_sequence,
        tides_int.trip_id_performed_imputed is not null as has_imputed_trip_id_performed
    from tides_int
    left join dupes on tides_int.row_hash = dupes.row_hash
),
```

##### Invalid Reason Tracking

For more complicated data quality logic, we might introduce an `invalid_reason` field that summarizes provides a text description of the first validation failure encountered:

```sql
case
    when not join_checks.has_transaction_id then 'Missing transaction_id'
    when not join_checks.has_service_date then 'Missing service_date'
    when not join_checks.has_event_timestamp then 'Missing event_timestamp'
    when not join_checks.has_amount then 'Missing amount'
    when not join_checks.has_fare_action then 'Missing fare_action'
    when not join_checks.has_valid_fare_action then 'Invalid fare_action'
    when not join_checks.has_valid_fare_media_id then 'Invalid fare_media_id'
    when not join_checks.dup_row_to_keep then 'Duplicate record'
end as invalid_reason
```

### Mart Model Filtering

Final mart models filter quality models to include only valid records:

```sql+jinja
-- From fct_tides_stop_visits_bus.sql
with quality_model as (
    select * from {{ ref("fct_tides_stop_visits_bus_quality") }}
),

fct_tides_stop_visits_bus as (
    select
        service_date,
        trip_id_performed,
        trip_stop_sequence,
        -- ... other columns
    from quality_model
    where is_valid  -- Only valid records reach the mart
)
```

Note:

- The only model upstream of a `fct_` model should be a quality model; there should be no other dependencies.

## dbt Tests

The [Project Name] validates expectations for models and fields through model properties configurations and singular tests.

### Best Practices

### Model-Level Tests

In the [Project Name], two common strategies for testing are:

- Row-count expectations
- Expression is true-style expectations

Notably:

- Column-level expectations should be defined at the column level, not at the model level.

    ```yaml
        # from _int_gtfs.yml
        # under `int_gtfs_patterns`
  models:
    - name: int_gtfs_patterns
        # ...
        data_tests:
        - dbt_utils.expression_is_true:
            arguments:
              expression: "pattern_id not like '%:%'"
            config:
              severity: error # This test should be implemented on the column it is testing
    ```

    Instead, you should implement this as follows:

    ```yaml
      # from _int_gtfs.yml
      # under `int_gtfs_patterns`
  models:
    - name: int_gtfs_patterns # Test now implemented under the pattern_id column
      columns:
        - name: pattern_id
          description: "{{ doc('field_gtfs_pattern_id') }}"
          tests:
            - not_null
            - dbt_utils.expression_is_true:
                arguments:
                  expression: "{{ column_name }} not like '%:%'" # Uses the {{ column }} jinja macro to test within the column
                config:
                  severity: error
    ```

- Composite key tests should *not* be implemented with `dbt_utils.unique_combination_of_columns`. Avoid the following:

    ```yaml
        # in _mart_bus.yml
        - name: fct_tides_stop_visits_bus
            description: "Summarized boarding, alighting, arrival, departure, and other events (kneel engaged, ramp deployed, etc.) by trip and stop for each service date."
            data_tests:
            - dbt_utils.unique_combination_of_columns:
                arguments: 
                  combination_of_columns:
                      - service_date
                      - trip_id_performed
                      - trip_stop_sequence
    ```

    Instead, create a `_key` field that should be unique ...

    ```sql+jinja
        -- from `int_gtfs_pattern_stops`
        int_gtfs_pattern_stops as (
            select
                {{ dbt_utils.generate_surrogate_key(['patterns._feed_hash',  'patterns.pattern_id', 'trip_stop_sequences.stop_id', 'trip_stop_sequences.stop_sequence']) }} -- noqa
                    as _key,
                patterns._feed_hash,
                patterns.pattern_id,
                -- ...
    ```

    ... and then test this for uniqueness:

    ```yaml
        # -- in _int_gtfs.yml
          - name: int_gtfs_pattern_stops
            # ...
            columns:
            - name: _key
                description: "{{ doc('field_gtfs_pattern_stop') }}"
                data_tests:
                - unique
                - not_null
    ```

    This is more transparent and easier to maintain. Note for these `_key` fields:
        - The `_key` shouldn't be used to join on; use natural join keys instead (i.e., columns the key is made of).
        - Provide unique definitions for these columns.

#### Row-count expectations

Use these row-count expectations to confirm that intermediate or quality model row counts match source data row counts (when appropriate) to ensure joins have not created cartesian explosions and that processing has not otherwise filtered records.

> **Note for Trino**: It appears that equal rowcount tests can at times return test failures unexpectedly. See Ticket #787 for details.

```yaml
# From _mart_quality.yml
models:
  - name: fct_tides_fare_transactions_fare_quality
    data_tests:
      - dbt_utils.equal_rowcount:
          arguments: 
            compare_model: ref('int_tides_fare_transactions_fare')
```

#### Expression is true tests

Use these expressions to validate consistency among columns.

```yaml
# From _mart_bus.yml
  - name: fct_daily_stop_ridership
    description: "Daily ridership summary by stop, aggregating total boardings and alightings for each service date."
    data_tests:
    # ...
      - dbt_utils.expression_is_true:
          arguments:
            expression: "total_activity = boardings + alightings"
          config:
            severity: error
```

### Column-Level Tests

#### Standard dbt tests

Use [standard dbt tests](https://docs.getdbt.com/docs/build/data-tests#generic-data-tests) to ensure data completeness and accuracy:

```yaml
columns:
  - name: _row_id
    description: "{{ doc('field_row_id') }}"
    data_tests:
      - unique
  
  - name: transaction_id
    description: "{{ doc('field_transaction_id') }}"
    data_tests:
      - unique
      - not_null
```

#### Column-level expectations

dbt_utils provides additional tests that can be useful for ensuring compliance with the TIDES specification:

```yaml
    # from _int_fares.yml
    # under `int_tides_fare_transactions_fare`
      - name: num_riders
        description: "{{ doc('field_num_riders') }}"
        data_tests:
          # ...
          - dbt_utils.expression_is_true:
              arguments:
                expression: "> 0"
              config:
                severity: warn
```

#### Foreign key relationships

Where possible, if a column is a foreign key from another model, define that in the model properties. Note that because GTFS feeds (and therefore their column values) have effective date ranges, these relationships can be difficult to implement in the model properties.

An example relationship test is shown below:

```yaml
    # in _int_gtfs.yml
    # under int_gtfs_patterns
      - name: shape_id
        description: "{{ doc('field_gtfs_shape_id') }}"
        data_tests:
          - relationships:
              to: ref('stg_gtfs_shapes')
              field: shape_id
              config:
                where: "shape_id is not null"
```

True [foreign key constraints](https://docs.getdbt.com/reference/resource-properties/constraints) can be implemented on materialized tables, but aren't currently used.

### Singular Tests

Singular tests validate complex business rules. The fact that certain GTFS IDs only have validity under certain date ranges mean that certain foreign key relationships cannot be easily established in a model properties file.

**Example: Bus info to GTFS Validation:**

From `test_bus_info_scheduled_trips_exist_in_gtfs.sql`:

```sql+jinja
{{ config(severity='warn') }}

with
int_tides_vehicle_locations_bus_info as (
    select *
    from {{ ref("int_tides_vehicle_locations_bus_info") }}
    where
        trip_type = 'In service'
        and trip_id_scheduled is not null
),

fct_scheduled_trips as (
    select *
    from {{ ref("fct_scheduled_trips") }}
),

distinct_bus_info_trips as (
    select distinct
        service_date,
        trip_id_scheduled
    from int_tides_vehicle_locations_bus_info
),

-- Find trips in bus info that don't exist in GTFS
unmatched_trips as (
    select
        distinct_bus_info_trips.service_date,
        distinct_bus_info_trips.trip_id_scheduled
    from distinct_bus_info_trips
    left join fct_scheduled_trips
        on
            distinct_bus_info_trips.service_date = fct_scheduled_trips.service_date
            and distinct_bus_info_trips.trip_id_scheduled = fct_scheduled_trips.trip_id
    where
        fct_scheduled_trips.trip_id is null
)

select * from unmatched_trips
```

This test:

- Validates cross-system consistency between bus info and GTFS data
- Uses `severity='warn'` to alert without failing builds
- Returns specific unmatched records for investigation