with int_route_pattern_trips as (
    select * from {{ ref('int_gtfs_route_pattern_trips') }}
),

feeds as (
    select * from {{ ref('dim_schedule_feeds') }}
),

dim_route_pattern_trips as (
    select
        int_route_pattern_trips._key,
        int_route_pattern_trips._feed_hash,
        int_route_pattern_trips.route_id,
        int_route_pattern_trips.pattern_id,
        int_route_pattern_trips.shape_id,
        int_route_pattern_trips.trip_id
    from int_route_pattern_trips
    inner join feeds
        on int_route_pattern_trips._feed_hash = feeds._feed_hash
)

select * from dim_route_pattern_trips
