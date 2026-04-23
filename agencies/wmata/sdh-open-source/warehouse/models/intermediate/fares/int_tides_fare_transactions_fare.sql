{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}

/*
This model transforms FARE fare data into the TIDES fare_transactions schema.

IMPORTANT NOTE: This implementation aligns with the TIDES schema modification as proposed by [AGENCY]
and currently under consideration by the TIDES contributors. In this approach:
- FARE data (FARE_SALE and FARE_USE) flows into fare_transactions
- faregate_data data flows into passenger_events
- The two can be linked via the linked_transaction_id field in passenger_events
*/

with fare_instrument_seed as (
    select cast(null as varchar) as fare_instrument_id, cast(null as varchar) as fare_product where 1=0 -- seed excluded from open-source
),

stg_fare_sale as (
    select * from {{ ref('stg_fare_sale') }}
),

stg_fare_use as (
    select * from {{ ref('stg_fare_use') }}
),

fare_sale as (
    select
        stg_fare_sale._row_id,
        stg_fare_sale.transaction_id,
        stg_fare_sale.transaction_dtm as event_timestamp,
        stg_fare_sale.service_date,
        stg_fare_sale.device_id,
        stg_fare_sale.sv_transaction as amount,
        case
            -- CSC/Magnetic Pass Load: activating a time-based pass on a card
            when stg_fare_sale.sale_transaction_type in (1, 3) then 'Activate'
            -- CSC/Magnetic Value Load: adding monetary value to card
            when stg_fare_sale.sale_transaction_type in (2, 4) then 'Add'
            -- POP Sale: creating a new proof of payment ticket
            when stg_fare_sale.sale_transaction_type = 0 then 'New'
            -- On Board Sale: direct purchase of fare media on vehicle
            when stg_fare_sale.sale_transaction_type = 5 then 'Purchase'
            -- TODO: Investigate type 6 in [AGENCY] documentation
            when stg_fare_sale.sale_transaction_type = 6 then 'Other'
            else 'Unknown action type'                               -- For unexpected sale_transaction_type values
        end as fare_action,
        stg_fare_sale.bus_id as vehicle_id,
        stg_fare_sale.run_id as trip_id_performed,
        {{ flex_cast("null", "varchar") }} as trip_id_scheduled,
        stg_fare_sale.route_id as pattern_id,
        {{ flex_cast("null", "integer") }} as trip_stop_sequence,
        {{ flex_cast("null", "integer") }} as scheduled_stop_sequence,
        {{ flex_cast("null", "varchar") }} as stop_id,
        stg_fare_sale.quantity as num_riders,
        case
            when stg_fare_sale.media_type_id in (4, 5) then 'Smart card or ticket'           -- Paper CSC and CSC
            when stg_fare_sale.media_type_id in (2, 3) then 'Magnetic-stripe card or ticket' -- Paper/Plastic Magnetic
            when stg_fare_sale.media_type_id = 7 then 'Cash or coins'                         -- Cash
            -- Paper POP, Smart Token, Token
            when stg_fare_sale.media_type_id in (1, 6, 8) then 'Other type'
            else 'Other type'
        end as fare_media_id,
        {{ flex_cast("null", "varchar") }} as rider_category,
        coalesce(fare_instrument_seed.fare_product, 'Unknown fare product') as fare_product,
        {{ flex_cast("null", "varchar") }} as fare_period,
        false as fare_capped,
        stg_fare_sale.serial_nbr as token_id,
        stg_fare_sale.sv_remaining as balance,
        'FARE_SALE' as source_system,
        stg_fare_sale.fare_instrument_id
    from
        stg_fare_sale
    left join fare_instrument_seed
        on stg_fare_sale.fare_instrument_id = fare_instrument_seed.fare_instrument_id
),

fare_use as (
    select
        stg_fare_use._row_id,
        stg_fare_use.transaction_id,
        stg_fare_use.transaction_dtm as event_timestamp,
        stg_fare_use.service_date,
        stg_fare_use.device_id,
        stg_fare_use.sv_transaction as amount,
        case
            -- Use the more specific use_type field when available
            when stg_fare_use.use_type = 9 then 'Enter'                -- Entry (Tag On)
            when stg_fare_use.use_type = 10 then 'Exit'                -- Exit (Tag Off)
            when stg_fare_use.use_type = 11 then 'Exit'                -- Free Exit
            when stg_fare_use.use_type = 12 then 'Enter'               -- Free Entry
            -- Transfer with CSC Use
            when stg_fare_use.use_type = 1 and stg_fare_use.use_transaction_type = 1 then 'Transfer entrance'
            -- Fall back to use_transaction_type when use_type isn't specific
            when stg_fare_use.use_transaction_type = 1 then 'Enter'    -- CSC Use
            when stg_fare_use.use_transaction_type = 2 then 'Enter'    -- Magnetic Use
            when stg_fare_use.use_transaction_type = 0 then 'Enter'    -- POP Use
            -- Handle values 3, 4, 5 (not in reference table)
            when stg_fare_use.use_transaction_type = 3 then 'Exit'
            when stg_fare_use.use_transaction_type = 4 then 'Transfer entrance'
            when stg_fare_use.use_transaction_type = 5 then 'Transfer exit'
            else 'Other'
        end as fare_action,
        stg_fare_use.bus_id as vehicle_id,
        stg_fare_use.run_id as trip_id_performed,
        {{ flex_cast("null", "varchar") }} as trip_id_scheduled,
        stg_fare_use.route_id as pattern_id,
        {{ flex_cast("null", "integer") }} as trip_stop_sequence,
        {{ flex_cast("null", "integer") }} as scheduled_stop_sequence,
        stg_fare_use.stop_point_id as stop_id,
        stg_fare_use.riders as num_riders,
        case
            when stg_fare_use.media_type_id in (4, 5) then 'Smart card or ticket'           -- Paper CSC and CSC
            when stg_fare_use.media_type_id in (2, 3) then 'Magnetic-stripe card or ticket' -- Paper/Plastic Magnetic
            when stg_fare_use.media_type_id = 7 then 'Cash or coins'                         -- Cash
            -- Paper POP, Smart Token, Token
            when stg_fare_use.media_type_id in (1, 6, 8) then 'Other type'
            else 'Other type'
        end as fare_media_id,
        {{ flex_cast("null", "varchar") }} as rider_category,
        coalesce(fare_instrument_seed.fare_product, 'Unknown fare product') as fare_product,
        {{ flex_cast("null", "varchar") }} as fare_period,
        false as fare_capped,
        stg_fare_use.serial_nbr as token_id,
        stg_fare_use.sv_remaining as balance,
        'FARE_USE' as source_system,
        stg_fare_use.fare_instrument_id
    from
        stg_fare_use
    left join fare_instrument_seed
        on stg_fare_use.fare_instrument_id = fare_instrument_seed.fare_instrument_id
),

combined as (
    select * from fare_sale
    union all
    select * from fare_use
),

int_tides_fare_transactions_fare as (
    select
        _row_id,
        -- fare_action included because FARE_USE can produce two records with the same
        -- transaction_id + event_timestamp but different use_type/use_transaction_type codes
        -- (root cause unknown -- investigate FARE use_type/use_transaction_type source semantics)
        {{ dbt_utils.generate_surrogate_key(['device_id', 'source_system', 'transaction_id', 'event_timestamp', 'fare_action']) }} as _key, -- noqa: LT05
        transaction_id,
        service_date,
        event_timestamp,
        {{ flex_cast("null", "varchar") }} as location_ping_id,
        amount,
        'USD' as currency_type,
        fare_action,
        trip_id_performed,
        trip_id_scheduled,
        pattern_id,
        trip_stop_sequence,
        scheduled_stop_sequence,
        vehicle_id,
        device_id,
        {{ flex_cast("null", "varchar") }} as fare_id,
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
    from
        combined
)

select * from int_tides_fare_transactions_fare


/*
-- Run this query separately to get a summary of fare_product categories
-- Note: This needs to be run as a separate query after the model is built
-- Do not uncomment this code within the model as it would create a circular reference
--
-- select
--     fare_product,
--     count(*) as count
-- from int_tides_fare_transactions_fare
-- group by fare_product
-- order by count desc
*/