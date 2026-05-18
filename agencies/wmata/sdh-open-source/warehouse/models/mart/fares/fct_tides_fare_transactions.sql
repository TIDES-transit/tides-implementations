{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}

/*
This model presents the final fare transactions data, unioning valid FARE and vendor_2 transactions.

IMPORTANT NOTE: This implementation aligns with the TIDES schema modification as proposed by [AGENCY]
and currently under consideration by the TIDES contributors. In this approach:
- FARE data (FARE_SALE and FARE_USE) flows into fare_transactions
- faregate_data data flows into passenger_events
- The two can be linked via the linked_transaction_id field in passenger_events
*/

with fare_transactions as (
    select
        {{ dbt_utils.generate_surrogate_key(['device_id', 'source_system', 'transaction_id', 'event_timestamp', 'fare_action']) }} as _key, -- noqa: LT05
        transaction_id,
        service_date,
        event_timestamp,
        location_ping_id,
        amount,
        currency_type,
        fare_action,
        trip_id_performed,
        trip_id_scheduled,
        pattern_id,
        trip_stop_sequence,
        scheduled_stop_sequence,
        vehicle_id,
        device_id,
        fare_id,
        stop_id,
        num_riders,
        fare_media_id,
        rider_category,
        fare_product,
        fare_period,
        fare_capped,
        token_id,
        balance,
        source_system
    from {{ ref('fct_tides_fare_transactions_fare_quality') }}
    where is_valid
),

vendor_2_transactions as (
    select
        transaction_id as _key, -- vendor_2 transaction_id is globally unique
        transaction_id,
        service_date,
        event_timestamp,
        location_ping_id,
        amount,
        currency_type,
        fare_action,
        trip_id_performed,
        trip_id_scheduled,
        pattern_id,
        trip_stop_sequence,
        scheduled_stop_sequence,
        vehicle_id,
        device_id,
        fare_id,
        stop_id,
        num_riders,
        fare_media_id,
        rider_category,
        fare_product,
        fare_period,
        fare_capped,
        token_id,
        balance,
        source_system
    from {{ ref('fct_tides_fare_transactions_vendor_2_quality') }}
    where is_valid
),

fct_tides_fare_transactions as (
    select * from fare_transactions
    union all
    select * from vendor_2_transactions
)

select * from fct_tides_fare_transactions