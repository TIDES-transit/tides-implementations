{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}

/*
This model presents the final, validated passenger events data.

It filters the quality model to include only valid records.

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

with deduplicated as (
    select
        *,
        row_number() over (
            partition by passenger_event_id
            order by event_timestamp
        ) as rn
    from
        {{ ref('fct_tides_passenger_events_faregates_quality') }}
    where is_valid
)

select
    service_date,
    event_timestamp,
    location_ping_id,
    trip_id_performed,
    trip_id_scheduled,
    trip_stop_sequence,
    scheduled_stop_sequence,
    event_type,
    vehicle_id,
    device_id,
    train_car_id,
    stop_id,
    pattern_id,
    event_count,
    linked_transaction_id,
    rider_category,
    source_system,
    case
        when rn > 1
            then
                {{ flex_cast('passenger_event_id', "varchar", safe=True) }}
                || '-'
                || {{ flex_cast('rn', "varchar", safe=True) }}
        else passenger_event_id
    end as passenger_event_id
from
    deduplicated