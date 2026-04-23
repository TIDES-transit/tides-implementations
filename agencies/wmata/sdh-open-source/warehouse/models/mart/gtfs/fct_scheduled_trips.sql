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

with service_index as (
    select * from {{ ref('int_gtfs_daily_services') }}
    where
        service_date <= {{ current_date_local() }}
),

dim_trips as (
    select * from {{ ref('dim_trips') }}
),

dim_routes as (
    select * from {{ ref('dim_routes') }}
),

stop_times as (
    select * from {{ ref('int_gtfs_stop_times_grouped_trip_summary') }}
),

daily_feeds as (
    select * from {{ ref('fct_daily_schedule_feed_modes') }}
),

trip_modes as (
    select
        dim_trips._feed_hash,
        dim_trips.trip_id,
        dim_trips.service_id,
        -- we'll use this to join in feed_mode later, so the names match that
        -- TODO: need to set expectations here, error on unhandled
        case
            when
                dim_routes.route_type = 1 then 'Rail'
            when
                dim_routes.route_type = 3 then 'Bus'
            else
                'Unhandled'
        end as trip_mode
    from dim_trips
    left join
        dim_routes
        on
            dim_trips._feed_hash = dim_routes._feed_hash
            and dim_trips.route_id = dim_routes.route_id
),

daily_feed_services as (
    -- in this cte, we'll create some cases where a combined and Rail feed with overlapping validity
    -- will have the same service_id present (e.g., '65_R' on 2025-09-09 appears twice, with feed_mode bus
    -- and feed_mode rail, even though it is just a rail service_id)
    -- in the subsequent CTE, we'll inner join trips on service_id AND mode to address this
    select
        daily_feeds.service_date,
        daily_feeds._feed_hash,
        service_index.service_id,
        daily_feeds.feed_mode
    from
        service_index
    inner join daily_feeds
        on
            service_index.service_date = daily_feeds.service_date
            and service_index._feed_hash = daily_feeds._feed_hash
),

feed_trips as (
    select
        daily_feed_services.service_date,
        -- GTFS times are relative to "twelve hours before noon" to handle daylight savings
        -- see: https://gtfs.org/documentation/schedule/reference/
        {{ timestamp_add(make_noon('service_date'), '-12', 'HOUR') }} as twelve_hours_before_noon, --noqa
        daily_feed_services._feed_hash,
        daily_feed_services.service_id,
        trip_modes.trip_id,
        trip_modes.trip_mode
    from
        trip_modes
    inner join
        daily_feed_services
        on
            trip_modes._feed_hash = daily_feed_services._feed_hash
            and trip_modes.service_id = daily_feed_services.service_id
            and trip_modes.trip_mode = daily_feed_services.feed_mode
),

fct_scheduled_trips as (
    select
        -- For now, adding differentiation by _feed_hash in the even that a trip_id is reused across
        -- bus and rail feeds per team discussion.
        {{ dbt_utils.generate_surrogate_key(['feed_trips._feed_hash', 'feed_trips.service_date', 'feed_trips.trip_id']) }} as _key, --noqa:LT05
        feed_trips.service_date,
        feed_trips._feed_hash,
        feed_trips.service_id,
        feed_trips.trip_id,
        dim_trips.direction_id,
        dim_trips.block_id,
        dim_trips.shape_id,
        dim_routes.route_id,
        feed_trips.trip_mode,
        dim_routes.route_type,
        dim_routes.route_short_name,
        dim_routes.route_long_name,
        stop_times.num_distinct_stops_serviced,
        stop_times.num_scheduled_stops,
        stop_times.first_scheduled_stop_id,
        stop_times.last_scheduled_stop_id,
        {{ timestamp_add('feed_trips.twelve_hours_before_noon', 
            'stop_times.first_scheduled_arrival_time_secs', 
            'SECOND') }} as first_scheduled_arrival_time, --noqa
        {{ timestamp_add('feed_trips.twelve_hours_before_noon', 
            'stop_times.first_scheduled_departure_time_secs', 
            'SECOND') }} as first_scheduled_departure_time,
        {{ timestamp_add('feed_trips.twelve_hours_before_noon', 
            'stop_times.last_scheduled_arrival_time_secs', 
            'SECOND') }} as last_scheduled_arrival_time,
        {{ timestamp_add('feed_trips.twelve_hours_before_noon',
            'stop_times.last_scheduled_departure_time_secs',
            'SECOND') }} as last_scheduled_departure_time,
        stop_times._date_retrieved
    -- notes on GTFS fields left off:
    --  - GTFS route_desc is blank in [AGENCY].
    --  - agency_id not relevant.
    --  - route color and route text color don't seem particularly needed.
    from feed_trips
    left join
        dim_trips
        on
            feed_trips._feed_hash = dim_trips._feed_hash
            and feed_trips.service_id = dim_trips.service_id
            and feed_trips.trip_id = dim_trips.trip_id
    left join
        dim_routes
        on
            dim_trips._feed_hash = dim_routes._feed_hash
            and dim_trips.route_id = dim_routes.route_id
    left join
        stop_times
        on
            dim_trips._feed_hash = stop_times._feed_hash
            and dim_trips.trip_id = stop_times.trip_id
    where
        stop_times.has_rider_service
        and coalesce(stop_times.num_scheduled_stops, 0) > 0
)

select * from fct_scheduled_trips