{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}

/*
This model adapts faregate events to fit the TIDES passenger_events schema.

IMPORTANT NOTE: This implementation aligns with the TIDES schema modification as proposed by [AGENCY]
and currently under consideration by the TIDES contributors. The key modifications are:

1. Make device_id required in passenger_events instead of vehicle_id
   - vehicle_id becomes optional with a constraint exception: "required unless the event occurs at a fixed location"
2. Make trip_stop_sequence optional when the event is not associated with a trip
   - Add a constraint exception: "required unless the event is not associated with a trip"
3. Add an optional linked_transaction_id field to link to fare_transactions

This approach allows station-based faregate events to be properly represented in the passenger_events schema
without requiring placeholder values for fields that don't apply to station-based events.
*/

with faregate_data_orgn as (
    -- Extract clear entry/exit events from faregate_data_ORGN
    select
        _row_id,
        {{ flex_cast('service_date', 'varchar', safe=True) }}         || '-'
        || {{ flex_cast('trxn_sno', 'varchar', safe=True) }} as passenger_event_id,
        {{ flex_cast('trxn_dtime', 'timestamp') }} as event_timestamp,
        service_date,
        eqmt_id as device_id,
        case
            when trxn_type_cd = '01' then 'Passenger entry'
            when trxn_type_cd = '02' then 'Passenger exit'
        end as event_type,
        {{ flex_cast("null", "varchar") }} as vehicle_id,
        -- Now optional per [AGENCY]'s proposed TIDES modification
        {{ flex_cast("null", "varchar") }}
        -- Now optional per [AGENCY]'s proposed TIDES modification
            as trip_stop_sequence,
        {{ flex_cast("null", "varchar") }} as scheduled_stop_sequence,
        {{ flex_cast("null", "varchar") }} as train_car_id,
        stn_id as stop_id,
        1 as event_count,
        trxn_sno as linked_transaction_id, -- Link to fare transaction if one exists
        -- Note: No documentation is available for rider_cls_cd values,
        -- so we preserve the original codes without interpretation
        case
            when rider_cls_cd is not null then
                'Rider class ' || {{ flex_cast('rider_cls_cd', "varchar", safe=True) }} -- noqa
        end as rider_category,
        'faregate_data_ORGN' as source_system
    from
        {{ ref('stg_faregate_data_orgn') }}
    where
        trxn_type_cd in ('01', '02')
)

select
    _row_id,
    passenger_event_id,
    service_date,
    event_timestamp,
    {{ flex_cast("null", "varchar") }} as location_ping_id,
    {{ flex_cast("null", "varchar") }} as trip_id_performed,
    {{ flex_cast("null", "varchar") }} as trip_id_scheduled,
    trip_stop_sequence,
    scheduled_stop_sequence,
    event_type,
    vehicle_id,
    device_id,
    train_car_id,
    stop_id,
    {{ flex_cast("null", "varchar") }} as pattern_id,
    event_count,
    linked_transaction_id,
    rider_category,
    source_system
from
    faregate_data_orgn