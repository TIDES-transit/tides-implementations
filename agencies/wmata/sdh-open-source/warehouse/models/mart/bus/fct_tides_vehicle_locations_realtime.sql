{{ config(enabled=var('enable_realtime', false)) }}

with vehicle_locations_quality as (
    select * from {{ ref('fct_tides_vehicle_locations_realtime_quality') }}
),

fct_tides_vehicle_locations_realtime as (
    select
        {{ dbt_utils.generate_surrogate_key(
        ['service_date', 'event_timestamp', 'schedule_relationship', 'trip_id_scheduled', 'trip_stop_sequence', 'latitude', 'longitude' ]) }} as _key,
        location_ping_id,
        service_date,
        event_timestamp,
        trip_id_performed,
        trip_id_scheduled,
        trip_stop_sequence,
        scheduled_stop_sequence,
        vehicle_id,
        device_id,
        pattern_id,
        stop_id,
        latitude,
        longitude,
        gps_quality,
        heading,
        speed,
        odometer,
        schedule_deviation,
        headway_deviation,
        trip_type,
        current_status,
        schedule_relationship,
        route_id
    from vehicle_locations_quality
    where is_valid = true
    order by trip_start_time, vehicle_id, pattern_id, event_timestamp
)

select * from fct_tides_vehicle_locations_realtime
