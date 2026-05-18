with int_trips_performed_quality as (
    select * from {{ ref("fct_tides_trips_performed_bus_quality") }}
),

fct_tides_trips_performed_bus as (
    select
        {{ dbt_utils.generate_surrogate_key(['service_date', 'trip_id_performed']) }} as _key,
        service_date,
        trip_id_performed,
        vehicle_id,
        trip_id_scheduled,
        route_id,
        route_type,
        ntd_mode,
        route_type_agency,
        shape_id,
        pattern_id,
        direction_id,
        operator_id,
        block_id,
        trip_start_stop_id,
        trip_end_stop_id,
        schedule_trip_start,
        schedule_trip_end,
        actual_trip_start,
        actual_trip_end,
        trip_type,
        schedule_relationship
    from int_trips_performed_quality
    where is_valid
)

select * from fct_tides_trips_performed_bus
