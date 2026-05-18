with tides_int as (
    select
        *,
        -- just using a subset of cols as an example
        {{ dbt_utils.generate_surrogate_key(['service_date', 'trip_id_performed', 'trip_id_scheduled', 'pattern_id', 'vehicle_id']) }} as row_hash --noqa
    from {{ ref('int_tides_trips_performed_bus_info') }}
),

dupes as (
    select
        row_hash,
        count(*) > 1 as has_dup,
        min(trip_id_performed) as first_instance
    from tides_int
    group by row_hash

),

quality_checks as (
    select
        dupes.has_dup as has_duplicates,
        tides_int.service_date,
        tides_int.trip_id_performed,
        tides_int.trip_id_scheduled,
        tides_int.vehicle_id,
        tides_int.pattern_id,
        -- tides columns
        tides_int.route_type,
        tides_int.ntd_mode,
        tides_int.route_type_agency,
        tides_int.shape_id,
        tides_int.direction_id,
        tides_int.operator_id,
        tides_int.block_id,
        tides_int.trip_start_stop_id,
        tides_int.trip_end_stop_id,
        tides_int.schedule_trip_start,
        tides_int.schedule_trip_end,
        tides_int.actual_trip_start,
        tides_int.actual_trip_end,
        tides_int.trip_type,
        tides_int.schedule_relationship,
        tides_int.route_id,
        tides_int.trip_id_performed = dupes.first_instance as dup_row_to_keep,
        tides_int.service_date is not null as has_service_date,
        tides_int.trip_id_performed is not null as has_trip_id_performed,
        tides_int.trip_id_scheduled is not null as has_trip_id_scheduled,
        tides_int.pattern_id is not null as has_pattern_id,
        {{ date_diff_unit('second', 'tides_int.schedule_trip_start', 'tides_int.actual_trip_start') }}
            as diff_actual_vs_sched_start,
        {{ date_diff_unit('second', 'tides_int.actual_trip_start', 'tides_int.actual_trip_end') }}
        - {{ date_diff_unit('second', 'tides_int.schedule_trip_start', 'tides_int.schedule_trip_end') }}
            as diff_actual_vs_sched_total_time

    from tides_int
    left join dupes on tides_int.row_hash = dupes.row_hash
),

fct_tides_trips_performed_bus_quality as (
    select
        dup_row_to_keep,
        has_duplicates,
        has_service_date,
        has_trip_id_performed,
        has_trip_id_scheduled,
        has_pattern_id,
        service_date,
        trip_id_performed,
        trip_id_scheduled,
        vehicle_id,
        pattern_id,
        route_type,
        ntd_mode,
        route_type_agency,
        shape_id,
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
        schedule_relationship,
        route_id,
        diff_actual_vs_sched_start,
        diff_actual_vs_sched_total_time,
        (
            has_service_date
            and has_trip_id_performed
            and has_trip_id_scheduled
            and has_pattern_id)
            as is_valid

    from quality_checks
)

select * from fct_tides_trips_performed_bus_quality