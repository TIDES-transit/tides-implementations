{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='_date_retrieved',
    batch_size='day',
    begin=var('incremental_begin_date'),
) }}

with stop_times as ( --noqa
    select
        _feed_hash,
        trip_id,
        stop_id,
        stop_sequence,
        arrival_time_secs,
        departure_time_secs,
        pickup_type,
        _date_retrieved
    from {{ ref('dim_stop_times') }}
),

-- Pre-compute distinct stop count separately to avoid MarkDistinctOperator memory spike
distinct_stop_counts as (
    select
        _feed_hash,
        trip_id,
        count(distinct stop_id) as num_distinct_stops_serviced
    from stop_times
    group by _feed_hash, trip_id
),

group_trips as (
    select
        _feed_hash,
        trip_id,
        min(_date_retrieved) as _date_retrieved,
        count(*) as num_scheduled_stops,
        min_by(stop_id, stop_sequence) as first_scheduled_stop_id,
        max_by(stop_id, stop_sequence) as last_scheduled_stop_id,
        -- at least one stop time on the trip has passenger service (pickup_type 1 is "no pickup available")
        {{ count_if('coalesce(pickup_type, 0) != 1') }} > 0 as has_rider_service,
        -- to convert the _secs times into actual datetimes we need a service_date
        -- which we don't (and shouldn't) have here, so keep as number of seconds
        min(arrival_time_secs) as first_scheduled_arrival_time_secs,
        min(departure_time_secs) as first_scheduled_departure_time_secs,
        max(arrival_time_secs) as last_scheduled_arrival_time_secs,
        max(departure_time_secs) as last_scheduled_departure_time_secs
    from stop_times
    group by _feed_hash, trip_id
),

int_gtfs_stop_times_grouped_trip_summary as (
    select
        {{ dbt_utils.generate_surrogate_key(['group_trips._feed_hash', 'group_trips.trip_id']) }} as _key,
        group_trips._feed_hash,
        group_trips.trip_id,
        group_trips._date_retrieved,
        distinct_stop_counts.num_distinct_stops_serviced,
        group_trips.num_scheduled_stops,
        group_trips.first_scheduled_stop_id,
        group_trips.last_scheduled_stop_id,
        group_trips.has_rider_service,
        group_trips.first_scheduled_arrival_time_secs,
        group_trips.first_scheduled_departure_time_secs,
        group_trips.last_scheduled_arrival_time_secs,
        group_trips.last_scheduled_departure_time_secs
    from group_trips
    inner join distinct_stop_counts
        on
            group_trips._feed_hash = distinct_stop_counts._feed_hash
            and group_trips.trip_id = distinct_stop_counts.trip_id
)

select * from int_gtfs_stop_times_grouped_trip_summary
