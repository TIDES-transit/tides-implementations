-- Test that scheduled_stop_sequence_imputed increases monotonically with trip_stop_sequence
-- within each (service_date, trip_id_performed_imputed) group
-- there may be some failures due to trip_id_performed_imputed values being repeated over the course of the day
-- later, when trip_id_performed_imputed is calculated by the warehouse, we should see this passing consistently.

{{ config(severity='warn') }}

with int_vl as (
    select
        service_date,
        trip_id_performed_imputed,
        trip_stop_sequence,
        trip_stop_sequence_imputed,
        scheduled_stop_sequence_imputed,
        event_timestamp,
        schedule_relationship
    from
        {{ ref('int_tides_vehicle_locations_bus_info_scheduled_stop') }}
    where scheduled_stop_sequence_imputed is not null
    -- because the non-stop event cases can occur in all sorts of orders, the check for monotonicity
    -- can be rather screwy if we don't just focus on these.
    and schedule_relationship in ('Skipped', 'Scheduled')
),

base_data as (
    select
        *,
        lag(scheduled_stop_sequence_imputed) over (
            partition by service_date, trip_id_performed_imputed
            -- in theory we could sort by trip_stop_sequence_imputed, but given that's influx,
            -- seems more relevant to end users to just sort on event_timestamp, which is likely more 'real'
            order by event_timestamp
        ) as prev_schedule_stop_sequence
    from int_vl

),

test_schedule_stop_sequence_monotonic as (

    select
        service_date,
        trip_id_performed_imputed,
        event_timestamp,
        trip_stop_sequence,
        trip_stop_sequence_imputed,
        scheduled_stop_sequence_imputed,
        prev_schedule_stop_sequence
    from base_data
    where
        prev_schedule_stop_sequence is not null
        and scheduled_stop_sequence_imputed < prev_schedule_stop_sequence
)

select * from
    test_schedule_stop_sequence_monotonic