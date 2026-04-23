{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='_date_retrieved',
    batch_size='day',
    begin=var('incremental_begin_date'),
    properties={
        "partitioning": "ARRAY['service_date']",
    },
) }}

with trips as (
    select * from {{ ref('fct_scheduled_trips') }}
),

dim_stop_times as (
    select * from {{ ref('dim_stop_times') }}
),

dim_stops as (
    select * from {{ ref('dim_stops') }}
),

fct_scheduled_stop_times as (
    select
        -- For now, adding differentiation by _feed_hash in the even that a trip_id is reused across
        -- bus and rail feeds per team discussion.
        {{ dbt_utils.generate_surrogate_key(['trips._feed_hash', 'trips.service_date', 'trips.trip_id', 'dim_stop_times.stop_sequence', 'dim_stop_times.stop_id']) }} as _key, --noqa:LT05
        trips._feed_hash,
        trips.service_date,
        trips.service_id,
        trips.trip_id,
        trips.route_id,
        trips.direction_id,
        trips.route_short_name,
        trips.route_long_name,
        trips.route_type,
        dim_stop_times.stop_id,
        dim_stops.stop_code,
        dim_stops.stop_name,
        dim_stop_times.stop_sequence,
        dim_stops.stop_lat,
        dim_stops.stop_lon,
        dim_stop_times.arrival_time,
        dim_stop_times.arrival_time_secs,
        dim_stop_times.departure_time,
        dim_stop_times.departure_time_secs,
        dim_stop_times._date_retrieved
    from
        trips
    left join
        dim_stop_times
        on
            trips._feed_hash = dim_stop_times._feed_hash
            and trips.trip_id = dim_stop_times.trip_id
    left join
        dim_stops
        on
            dim_stop_times._feed_hash = dim_stops._feed_hash
            and dim_stop_times.stop_id = dim_stops.stop_id
)

select * from fct_scheduled_stop_times
