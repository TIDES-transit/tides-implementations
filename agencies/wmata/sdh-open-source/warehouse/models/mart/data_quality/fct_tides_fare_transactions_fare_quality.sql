{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}

/*
This model performs quality checks on the FARE fare_transactions intermediate model.

It validates required fields, checks for duplicates, and ensures values conform to expected formats.

IMPORTANT NOTE: This implementation aligns with the TIDES schema modification as proposed by [AGENCY]
and currently under consideration by the TIDES contributors. In this approach:
- FARE data (FARE_SALE and FARE_USE) flows into fare_transactions
- faregate_data data flows into passenger_events
- The two can be linked via the linked_transaction_id field in passenger_events
*/


-- Generate a row hash for duplicate detection
with tides_int as (
    select
        *,
        {{ dbt_utils.generate_surrogate_key(['transaction_id', 'service_date', 'event_timestamp', 'amount', 'fare_action', 'source_system']) }} -- noqa: LT05
            as row_hash
    from {{ ref('int_tides_fare_transactions_fare') }}
),

dupes as (
    select
        row_hash,
        count(*) > 1 as has_dup,
        min(_row_id) as first_instance
    from tides_int
    group by row_hash
),

join_checks as (
    select
        tides_int._row_id,
        dupes.has_dup as has_duplicates,
        tides_int._row_id = dupes.first_instance as dup_row_to_keep,
        tides_int.transaction_id is not null as has_transaction_id,
        tides_int.service_date is not null as has_service_date,
        tides_int.event_timestamp is not null as has_event_timestamp,
        tides_int.amount is not null as has_amount,
        tides_int.fare_action is not null as has_fare_action,
        tides_int.fare_action in (
            'Purchase',
            'Enter',
            'Exit',
            'Transfer entrance',
            'Transfer exit',
            'Add',
            'New',
            'Capture',
            'Extend',
            'Combine',
            'Void',
            'Activate',
            'Adjust',
            'Other'
        ) as has_valid_fare_action,
        tides_int.fare_media_id in (
            'Cash or coins',
            'Smart card or ticket',
            'Magnetic-stripe card or ticket',
            'Bank card',
            'Mobile NFC',
            'Optical scan',
            'Button pressed by driver or operator to indicate a boarding or alighting passenger.',
            'Other type'
        ) as has_valid_fare_media_id
    from tides_int
    left join dupes on tides_int.row_hash = dupes.row_hash
),

fct_tides_fare_transactions_fare_quality as (
    select
        tides_int._row_id,
        tides_int.row_hash,
        join_checks.dup_row_to_keep,
        -- checks
        join_checks.has_duplicates,
        join_checks.has_transaction_id,
        join_checks.has_service_date,
        join_checks.has_event_timestamp,
        join_checks.has_amount,
        join_checks.has_fare_action,
        join_checks.has_valid_fare_action,
        join_checks.has_valid_fare_media_id,
        tides_int.transaction_id,
        -- tides columns
        tides_int.service_date,
        tides_int.event_timestamp,
        tides_int.location_ping_id,
        tides_int.amount,
        tides_int.currency_type,
        tides_int.fare_action,
        tides_int.trip_id_performed,
        tides_int.trip_id_scheduled,
        tides_int.pattern_id,
        tides_int.trip_stop_sequence,
        tides_int.scheduled_stop_sequence,
        tides_int.vehicle_id,
        tides_int.device_id,
        tides_int.fare_id,
        tides_int.stop_id,
        tides_int.num_riders,
        tides_int.fare_media_id,
        tides_int.rider_category,
        tides_int.fare_product,
        tides_int.fare_period,
        tides_int.fare_capped,
        tides_int.token_id,
        tides_int.balance,
        tides_int.source_system,
        (
            join_checks.dup_row_to_keep
            and join_checks.has_transaction_id
            and join_checks.has_service_date
            and join_checks.has_event_timestamp
            and join_checks.has_amount
            and join_checks.has_fare_action
            and join_checks.has_valid_fare_action
            and join_checks.has_valid_fare_media_id
        ) as is_valid,
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
    from tides_int
    left join join_checks on tides_int._row_id = join_checks._row_id
)

select * from fct_tides_fare_transactions_fare_quality