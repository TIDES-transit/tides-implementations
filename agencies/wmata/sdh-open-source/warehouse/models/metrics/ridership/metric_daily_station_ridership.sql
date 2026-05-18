{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}

with hourly_station_ridership as (
    select * from {{ ref('metric_hourly_station_ridership') }}
),

metric_daily_station_ridership as (
    select
        {{ dbt_utils.generate_surrogate_key(['service_date', 'stop_id']) }} as _key,
        service_date,
        stop_id,
        sum(total_entries) as total_entries,
        sum(total_exits) as total_exits,
        sum(entry_transactions) as entry_transactions,
        sum(exit_transactions) as exit_transactions,
        sum(number_of_transactions) as number_of_transactions,
        sum(total_activity) as total_activity
    from
        hourly_station_ridership
    group by
        service_date,
        stop_id
    order by
        service_date,
        stop_id
)

select * from metric_daily_station_ridership
