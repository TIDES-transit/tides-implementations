{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}

with tides_int_grouped as (
    select *
    from {{ ref('int_tides_stop_visits_bus_info_grouped') }}
),

tides_int_base as (
    select {{ dbt_utils.generate_surrogate_key(['service_date', 'trip_id_performed', 'trip_stop_sequence']) }} as row_hash, --noqa
        *
    from {{ ref('int_tides_stop_visits_bus_info') }}
),

tides_int_union as (
    select
        _row_id,
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
        custom_ramp_deployed_count,
        dwell_imputed,
        distance,
        true as grouped_row,
        false as in_grouped_row
    from tides_int_grouped
    union all
    select
        _row_id,
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
        custom_ramp_deployed_count,
        dwell_imputed,
        distance,
        false as grouped_row,
        coalesce(
            tides_int_base.row_hash in (
                select tides_int_grouped._row_id from tides_int_grouped
            ), false
        ) as in_grouped_row --noqa: RF02
    from tides_int_base
),

quality_checks as (
    select --noqa: ST06
        *,
        service_date is not null as has_service_date,
        trip_id_performed is not null as has_trip_id_performed,
        trip_stop_sequence > 0 as has_positive_trip_stop_sequence
    from tides_int_union
),

fct_tides_stop_visits_bus_quality as (
    select --noqa: ST06
        _row_id,
        (
            has_service_date
            and has_trip_id_performed
            and has_positive_trip_stop_sequence
            and not in_grouped_row)
        as is_valid, --noqa: LT02
        -- checks
        in_grouped_row,
        -- if an aggregate of multiple rows
        grouped_row,
        has_service_date,
        has_trip_id_performed,
        has_positive_trip_stop_sequence,
        -- tides columns
        service_date,
        trip_id_performed,
        trip_stop_sequence,
        scheduled_stop_sequence,
        pattern_id, --unique identifier of route-pattern
        vehicle_id,
        dwell,
        dwell_imputed,
        stop_id,
        timepoint,
        schedule_arrival_time,
        schedule_departure_time,
        actual_arrival_time,
        actual_departure_time,
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
        --custom replacement for ramp_deployed_time
        custom_ramp_deployed_count,
        distance
    from quality_checks
)

select * from fct_tides_stop_visits_bus_quality