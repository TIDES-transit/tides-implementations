{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}

with quality_model as (
    select * from {{ ref("fct_tides_stop_visits_bus_quality") }}
),

fct_tides_stop_visits_bus as (
    select
        {{ dbt_utils.generate_surrogate_key(['service_date', 'trip_id_performed', 'trip_stop_sequence']) }} as _key,
        service_date,
        trip_id_performed,
        trip_stop_sequence,
        scheduled_stop_sequence,
        pattern_id,
        vehicle_id,
        dwell_imputed as dwell,
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
        custom_ramp_deployed_count
    from quality_model
    where is_valid
)

select * from fct_tides_stop_visits_bus
