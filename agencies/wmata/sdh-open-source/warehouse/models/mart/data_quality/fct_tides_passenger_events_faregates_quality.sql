{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}

/*
This model performs quality checks on the passenger_events intermediate model.

It validates required fields, checks for duplicates, and ensures values conform to expected formats.

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

with tides_int as (
    select -- generate a row hash for dupe detection
        *,
        {{ dbt_utils.generate_surrogate_key(['passenger_event_id', 'service_date', 'event_timestamp', 'event_type', 'source_system']) }} -- noqa: LT05
            as row_hash
    from {{ ref('int_tides_passenger_events_faregates') }}
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
        tides_int.passenger_event_id is not null as has_passenger_event_id,
        tides_int.service_date is not null as has_service_date,
        tides_int.event_timestamp is not null as has_event_timestamp,
        tides_int.event_type is not null as has_event_type,
        tides_int.device_id is not null as has_device_id, -- Now required instead of vehicle_id
        tides_int.event_type in (
            'Vehicle arrived at stop',
            'Vehicle departed stop',
            'Door opened',
            'Door closed',
            'Passenger entry',
            'Passenger exit',
            'Kneel was engaged',
            'Kneel was disengaged',
            'Ramp was deployed',
            'Ramp was raised',
            'Ramp deployment failed',
            'Lift was deployed',
            'Lift was raised',
            'Individual bike boarded',
            'Individual bike alighted',
            'Bike rack deployed'
        ) as has_valid_event_type
    from tides_int
    left join dupes on tides_int.row_hash = dupes.row_hash
),

fct_tides_passenger_events_faregates_quality as (
    select
        tides_int._row_id,
        tides_int.row_hash,
        join_checks.dup_row_to_keep,
        -- checks
        join_checks.has_duplicates,
        join_checks.has_passenger_event_id,
        join_checks.has_service_date,
        join_checks.has_event_timestamp,
        join_checks.has_event_type,
        join_checks.has_device_id,
        join_checks.has_valid_event_type,
        -- passenger_events columns
        tides_int.passenger_event_id,
        tides_int.service_date,
        tides_int.event_timestamp,
        tides_int.location_ping_id,
        tides_int.trip_id_performed,
        tides_int.trip_id_scheduled,
        tides_int.trip_stop_sequence,
        tides_int.scheduled_stop_sequence,
        tides_int.event_type,
        tides_int.vehicle_id,
        tides_int.device_id,
        tides_int.train_car_id,
        tides_int.stop_id,
        tides_int.pattern_id,
        tides_int.event_count,
        tides_int.linked_transaction_id,
        tides_int.rider_category,
        tides_int.source_system,
        -- Simplified validity check to avoid long line
        (
            join_checks.dup_row_to_keep
            and join_checks.has_passenger_event_id
            and join_checks.has_service_date
            and join_checks.has_event_timestamp
            and join_checks.has_event_type
            and join_checks.has_device_id
            and join_checks.has_valid_event_type
        ) as is_valid,
        case
            when not join_checks.has_passenger_event_id then 'Missing passenger_event_id'
            when not join_checks.has_service_date then 'Missing service_date'
            when not join_checks.has_event_timestamp then 'Missing event_timestamp'
            when not join_checks.has_event_type then 'Missing event_type'
            when not join_checks.has_device_id then 'Missing device_id'
            when not join_checks.has_valid_event_type then 'Invalid event_type'
            when not join_checks.dup_row_to_keep then 'Duplicate record'
        end as invalid_reason
    from tides_int
    left join join_checks on tides_int._row_id = join_checks._row_id
)

select * from fct_tides_passenger_events_faregates_quality