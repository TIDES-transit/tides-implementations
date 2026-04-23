{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='_date_retrieved',
    batch_size='day',
    begin=var('incremental_begin_date'),
) }}

with stg as (
    select * from {{ ref('stg_gtfs_stop_times') }}
),

feeds as (
    select * from {{ ref('dim_schedule_feeds') }}
),

dim_stop_times as (
    select
        {{ dbt_utils.generate_surrogate_key(['stg._feed_hash', 'stg.trip_id', 'stg.stop_sequence']) }} as _key,
        stg._feed_hash,
        stg.trip_id,
        stg.arrival_time,
        stg.departure_time,
        {{ gtfs_time_string_to_seconds("stg.arrival_time") }} as arrival_time_secs,
        {{ gtfs_time_string_to_seconds("stg.departure_time") }} as departure_time_secs,
        stg.stop_id,
        stg.stop_sequence,
        stg.stop_headsign,
        stg.pickup_type,
        stg.drop_off_type,
        stg.shape_dist_traveled,
        stg.timepoint,
        date_trunc('day', feeds._date_retrieved) as _date_retrieved
    from stg
    inner join feeds
        on stg._feed_hash = feeds._feed_hash
)

select * from dim_stop_times
