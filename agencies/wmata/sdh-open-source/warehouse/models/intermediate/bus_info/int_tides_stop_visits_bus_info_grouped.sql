{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}

with tides_int as (
    select *
    from {{ ref('int_tides_stop_visits_bus_info') }}
),

groups_with_duplicates as (
    select
        service_date,
        trip_id_performed,
        trip_stop_sequence
    from tides_int
    group by
        service_date,
        trip_id_performed,
        trip_stop_sequence
    having count(_row_id) > 1
),

filtered_tides as (
    select tides_int.*
    from tides_int
    inner join groups_with_duplicates
        on
            tides_int.service_date = groups_with_duplicates.service_date
            and tides_int.trip_id_performed = groups_with_duplicates.trip_id_performed
            and tides_int.trip_stop_sequence = groups_with_duplicates.trip_stop_sequence
),

int_tides_stop_visits_bus_info_grouped as (
    select
        {{ dbt_utils.generate_surrogate_key(['service_date', 'trip_id_performed', 'trip_stop_sequence']) }} as _row_id, --noqa: LT05
        service_date,
        trip_id_performed,
        trip_stop_sequence,
        {{ first_agg('scheduled_stop_sequence', 'actual_arrival_time, _row_id') }}  as scheduled_stop_sequence,
        any_value(pattern_id) as pattern_id,
        any_value(vehicle_id) as vehicle_id,
        sum(dwell) as dwell,
        {{ first_agg('stop_id', 'actual_arrival_time, _row_id') }}  as stop_id,
        sum( {{ flex_cast('timepoint', "integer", safe=True) }} ) >= 1 as timepoint,
        min(schedule_arrival_time) as schedule_arrival_time,
        max(schedule_departure_time) as schedule_departure_time,
        min(actual_arrival_time) as actual_arrival_time,
        max(actual_departure_time) as actual_departure_time,
        sum(distance) as distance,
        sum(boarding_1) as boarding_1,
        sum(alighting_1) as alighting_1,
        sum(boarding_2) as boarding_2,
        sum(alighting_2) as alighting_2,
        {{ last_agg('departure_load', 'actual_departure_time, _row_id') }}  as departure_load,
        min(door_open) as door_open,
        max(door_close) as door_close,
        case
            when max(case when door_status = 'All doors opened' then 1 else 0 end) = 1 then 'All doors opened'
            when
                max(case when door_status = 'Front door opened and back doors remain closed' then 1 else 0 end) = 1
                and max(case when door_status = 'Back doors opened and front door remained closed' then 1 else 0 end)
                = 1
                then 'All doors opened'
            when
                max(case when door_status = 'Front door opened and back doors remain closed' then 1 else 0 end) = 1
                then 'Front door opened and back doors remain closed'
            when
                max(case when door_status = 'Back doors opened and front door remained closed' then 1 else 0 end) = 1
                then 'Back doors opened and front door remained closed'
            when max(case when door_status = 'Other configuration' then 1 else 0 end) = 1 then 'Other configuration'
        end as door_status,
        sum(ramp_deployed_time) as ramp_deployed_time,
        sum( {{ flex_cast('ramp_failure', "integer", safe=True) }} ) >= 1 as ramp_failure,
        sum(kneel_deployed_time) as kneel_deployed_time,
        sum(lift_deployed_time) as lift_deployed_time,
        sum( {{ flex_cast('bike_rack_deployed', "integer", safe=True) }} )
        >= 1 as bike_rack_deployed,
        sum(bike_load) as bike_load,
        sum(revenue) as revenue,
        sum(number_of_transactions) as number_of_transactions,
        case
            when max(case when schedule_relationship = 'Scheduled' then 1 else 0 end) = 1 then 'Scheduled'
            when max(case when schedule_relationship = 'Skipped' then 1 else 0 end) = 1 then 'Skipped'
            when max(case when schedule_relationship = 'Added' then 1 else 0 end) = 1 then 'Added'
            when max(case when schedule_relationship = 'Missing' then 1 else 0 end) = 1 then 'Missing'
        end as schedule_relationship,
        sum(custom_ramp_deployed_count) as custom_ramp_deployed_count,
        sum(dwell_imputed) as dwell_imputed
    from filtered_tides
    group by
        service_date,
        trip_id_performed,
        trip_stop_sequence
)

select * from int_tides_stop_visits_bus_info_grouped