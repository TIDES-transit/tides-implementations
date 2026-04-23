{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}

with hourly_stop_ridership as (
    select * from {{ ref('metric_hourly_stop_ridership') }}
),

metric_daily_stop_ridership as (
    select
        {{ dbt_utils.generate_surrogate_key(['service_date', 'stop_id']) }} as _key,
        service_date,
        stop_id,
        sum(boardings) as boardings,
        sum(alightings) as alightings,
        sum(total_activity) as total_activity
    from
        hourly_stop_ridership
    group by
        service_date,
        stop_id
    order by
        service_date,
        stop_id
)

select * from metric_daily_stop_ridership
