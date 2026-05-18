{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}


with quality_model as (
    select * from {{ ref("fct_tides_vehicle_locations_bus_quality") }}
),

fct_tides_vehicle_locations_bus as (
    select --noqa: ST06
        {{ dbt_utils.generate_surrogate_key(
        ['service_date', 'event_timestamp', 'schedule_relationship', 'trip_id_scheduled', 'trip_stop_sequence', 'latitude', 'longitude' ]) }} as _key,
        location_ping_id,
        service_date,
        event_timestamp,
        trip_id_performed_imputed as trip_id_performed,
        trip_id_scheduled,
        trip_stop_sequence_imputed as trip_stop_sequence,
        scheduled_stop_sequence_imputed as scheduled_stop_sequence,
        vehicle_id,
        device_id,
        pattern_id,
        coalesce(stop_id_imputed, stop_id) as stop_id,
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
        schedule_relationship
    from quality_model
    where is_valid
)

select * from fct_tides_vehicle_locations_bus
