{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}

with base_transactions as (
    select * from {{ ref('int_vendor_2_with_transfers') }}
),

micropay_dev_txns as (
    select * from {{ ref('stg_vendor_2_micropay_dev_txns') }}
),

micropays as (
    select * from {{ ref('stg_vendor_2_micropays') }}
),

transactions_with_payments as (
    select
        base_transactions.*,
        -- Micropayment details
        micropays.micropayment_id,
        micropays.customer_id,
        micropays.funding_source_id,
        micropays.charge_amount,
        micropays.charge_type,
        micropays.nominal_amount,
        micropays.aggregation_id
    from base_transactions
    inner join micropay_dev_txns
        on base_transactions.vendor_2_transaction_id = micropay_dev_txns.vendor_2_transaction_id
    inner join micropays
        on micropay_dev_txns.micropayment_id = micropays.micropayment_id
),

transformed_transactions as (
    select
        vendor_2_transaction_id as transaction_id,
        -- Calculate service_date from transaction timestamp
        {{ date_add(utc_to_timezone('transaction_timestamp_utc', 'America/New_York'), '-4', 'HOUR', 'DAY') }}
            as service_date,
        {{ utc_to_timezone('transaction_timestamp_utc', 'America/New_York') }} as event_timestamp,
        {{ flex_cast("null", "varchar") }} as location_ping_id,
        fare_action,
        'USD' as currency_type, -- source currency is ISO number as opposed to three letter code
        {{ flex_cast("null", "varchar") }} as trip_id_performed,
        {{ flex_cast("null", "varchar") }} as trip_id_scheduled,
        route_id as pattern_id,
        {{ flex_cast("null", "integer") }} as trip_stop_sequence,
        {{ flex_cast("null", "integer") }} as scheduled_stop_sequence,
        vehicle_id,
        device_id,
        {{ flex_cast("null", "varchar") }} as fare_id,
        location_id as stop_id,
        {{ flex_cast("1", "double") }} as num_riders, -- [AGENCY] website specifies one rider per payment
        -- TODO: revisit, need access to 'customer funding sources' table to distinguish "Mobile NFC" from "Bank card".
        -- These are the two relevant TIDES possible values, but we may want to further distinguish watch from phone.
        'Bank card' as fare_media_id,
        {{ flex_cast("null", "varchar") }} as rider_category,
        'Open Payment' as fare_product,
        {{ flex_cast("null", "varchar") }} as fare_period,
        false as fare_capped, -- no fare capping in open payment for now
        funding_source_id as token_id,
        {{ flex_cast("null", "double") }} as balance, -- not applicable to open payment as far as I know
        'vendor_2' as source_system,
        charge_type,
        micropayment_id,
        aggregation_id,
        case
            when
                -- if it's a flat fare or an incomplete variable fare (i.e. tap in or out only)
                -- then assign it the charged amount
                charge_type in ('flat_fare', 'incomplete_variable_fare')
                then charge_amount
            when
                -- if it's a complete variable fare (i.e. tap in and out)
                -- then only assign the charged amount on exit
                charge_type = 'complete_variable_fare' and (fare_action in ('Exit', 'Transfer exit'))
                then charge_amount
            else 0.0
        end as amount,
        -- fare amount cols
        fare_amount,
        adjustment_amount,
        adjustment_description,
        nominal_amount,
        charge_amount
    from transactions_with_payments
),

int_tides_fare_transactions_vendor_2 as (
    select
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
        source_system,
        charge_type,
        micropayment_id,
        aggregation_id,
        -- fare amount cols
        fare_amount,
        adjustment_amount,
        adjustment_description,
        nominal_amount,
        charge_amount
    from transformed_transactions
    order by event_timestamp, transaction_id
)

select * from int_tides_fare_transactions_vendor_2