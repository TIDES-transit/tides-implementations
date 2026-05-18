{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}

with station_activities as (
    select * from {{ ref('fct_tides_station_activities') }}
),

metric_hourly_station_ridership as (
    select
        {{ dbt_utils.generate_surrogate_key(['service_date', 'stop_id', 'time_period_start']) }} as _key,
        service_date,
        stop_id,
        time_period_start,
        time_period_end,
        time_period_category,
        total_entries,
        total_exits,
        entry_transactions,
        exit_transactions,
        number_of_transactions,
        total_entries + total_exits as total_activity
    from
        station_activities
    order by
        service_date,
        time_period_start,
        stop_id
)

select * from metric_hourly_station_ridership
