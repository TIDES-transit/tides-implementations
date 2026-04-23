/*
This model performs quality checks on the station_activities intermediate model.

It validates required fields, checks for duplicates, and ensures consistency
between flags and event types before the data is aggregated in the fact model.
*/

{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}

with tides_int as (
    select *
    from {{ ref('int_disaggregated_station_activities') }}
),

-- Note: Using _key from the intermediate model for duplicate detection rather
-- than computing a separate row_hash. In practice, a row_hash for quality checks
-- could include more columns than just the composite key, but here the previously
-- used row_hash was computed on the same 5 columns as _key, so we avoid the
-- redundant calculation. Window functions replace the GROUP BY + LEFT JOIN
-- pattern to reduce Trino memory pressure (eliminates HashBuilderOperator).
quality_flags as (
    select
        tides_int.*,
        count(*) over (partition by tides_int._key) > 1 as has_duplicates,
        row_number() over (
            partition by tides_int._key
            order by tides_int._key
        ) = 1 as dup_row_to_keep,
        tides_int.service_date is not null as has_service_date,
        tides_int.stop_id is not null as has_stop_id,
        tides_int.event_timestamp is not null as has_event_timestamp
    from tides_int
),

fct_tides_station_activities_quality as (
    select
        quality_flags._key,
        quality_flags.has_duplicates,
        quality_flags.service_date,
        quality_flags.event_timestamp,
        quality_flags.stop_id,
        quality_flags.event_type,
        quality_flags.rider_category,
        quality_flags.fare_product,
        quality_flags.token_id,
        quality_flags.hour_of_day,
        quality_flags.is_entry,
        quality_flags.is_exit,
        quality_flags.is_entry_transaction,
        quality_flags.is_exit_transaction,
        quality_flags.source_system,
        quality_flags.dup_row_to_keep,
        quality_flags.has_service_date,
        quality_flags.has_stop_id,
        quality_flags.has_event_timestamp,
        (
            quality_flags.dup_row_to_keep
            and quality_flags.has_service_date
            and quality_flags.has_stop_id
            and quality_flags.has_event_timestamp
        ) as is_valid,
        case
            when not quality_flags.has_service_date then 'Missing service_date'
            when not quality_flags.has_stop_id then 'Missing stop_id'
            when not quality_flags.has_event_timestamp then 'Missing event_timestamp'
            when not quality_flags.dup_row_to_keep then 'Duplicate record'
        end as invalid_reason
    from quality_flags
)

select * from fct_tides_station_activities_quality
