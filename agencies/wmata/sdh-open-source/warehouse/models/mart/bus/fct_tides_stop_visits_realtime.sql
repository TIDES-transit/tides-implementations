{{ config(enabled=var('enable_realtime', false)) }}

with stop_visits_quality as (
    select * from {{ ref('fct_tides_stop_visits_realtime_quality') }}
),

fct_tides_stop_visits_realtime as (
    select
        {{ dbt_utils.generate_surrogate_key(['service_date', 'trip_id_performed', 'trip_stop_sequence']) }} as _key,
        service_date,
        trip_id_performed,
        trip_stop_sequence,
        scheduled_stop_sequence,
        pattern_id,
        vehicle_id,
        dwell,
        stop_id,
        timepoint,
        schedule_arrival_time,
        schedule_departure_time,
        actual_arrival_time,
        actual_departure_time,
        distance,
        boarding_1,
        alighting_1,
        boarding_2,
        alighting_2,
        departure_load,
        door_open,
        door_close,
        door_status,
        ramp_deployed_time,
        ramp_failure,
        kneel_deployed_time,
        lift_deployed_time,
        bike_rack_deployed,
        bike_load,
        revenue,
        number_of_transactions,
        schedule_relationship,
        custom_ramp_deployed_count -- TODO: rename to _custom_ramp_deployed_count (non-TIDES)
    from stop_visits_quality
    where is_valid = true
)

select * from fct_tides_stop_visits_realtime
order by service_date, pattern_id, vehicle_id, actual_arrival_time
