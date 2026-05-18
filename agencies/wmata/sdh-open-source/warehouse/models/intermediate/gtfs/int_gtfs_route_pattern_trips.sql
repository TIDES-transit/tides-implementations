with trips as (
    select * from {{ ref('stg_gtfs_trips') }}
),

patterns as (
    select * from {{ ref('int_gtfs_patterns') }}
),

route_trips as (
    select
        trips._feed_hash,
        trips.route_id,
        trips.shape_id,
        trips.trip_id
    from trips
    where trips.shape_id is not null
),

int_gtfs_route_pattern_trips as (
    select
        {{ dbt_utils.generate_surrogate_key(['route_trips._feed_hash', 'route_trips.route_id',  'patterns.pattern_id', 'route_trips.trip_id']) }} -- noqa
            as _key,
        route_trips._feed_hash,
        route_trips.route_id,
        patterns.pattern_id,
        route_trips.shape_id,
        route_trips.trip_id
    from route_trips
    inner join patterns
        on
            route_trips._feed_hash = patterns._feed_hash
            and route_trips.shape_id = patterns.shape_id
)

select * from int_gtfs_route_pattern_trips
