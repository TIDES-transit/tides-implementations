{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}

with stop_visits as (
    select
        service_date,
        stop_id,
        actual_arrival_time,
        boarding_1,
        boarding_2,
        alighting_1,
        alighting_2
    from {{ ref('fct_tides_stop_visits_bus') }}
    {% if var('enable_realtime', false) %}
        union all
        select
            service_date,
            stop_id,
            actual_arrival_time,
            boarding_1,
            boarding_2,
            alighting_1,
            alighting_2
        from {{ ref('fct_tides_stop_visits_realtime') }}
        where service_date = current_date
    {% endif %}
),

sum_cols as (
    select
        service_date,
        stop_id,
        date_trunc('day', actual_arrival_time) as calendar_date, -- remove?
        hour(actual_arrival_time) as hour_of_calendar_date,
        boarding_1 + boarding_2 as boardings,
        alighting_1 + alighting_2 as alightings
    from
        stop_visits
),

metric_hourly_stop_ridership as (
    select
        {{ dbt_utils.generate_surrogate_key(['service_date', 'stop_id', 'hour_of_calendar_date']) }} as _key,
        service_date,
        calendar_date,
        stop_id,
        hour_of_calendar_date,
        sum(boardings) as boardings,
        sum(alightings) as alightings,
        sum(boardings + alightings) as total_activity
    from
        sum_cols
    group by
        service_date,
        calendar_date,
        stop_id,
        hour_of_calendar_date
    order by
        service_date,
        calendar_date,
        stop_id,
        hour_of_calendar_date
)

select * from metric_hourly_stop_ridership
