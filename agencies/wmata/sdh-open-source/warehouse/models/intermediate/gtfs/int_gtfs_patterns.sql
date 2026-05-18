with stg_trips as (
    select * from {{ ref('stg_gtfs_trips') }}
),

stg_routes as (
    select * from {{ ref('stg_gtfs_routes') }}
),

route_patterns as (
    select distinct
        stg_trips._feed_hash,
        stg_trips.route_id,
        stg_routes.route_type,
        stg_trips.shape_id,
        stg_trips.direction_id
    from stg_trips
    inner join stg_routes
        on
            stg_trips._feed_hash = stg_routes._feed_hash
            and stg_trips.route_id = stg_routes.route_id
),

int_gtfs_patterns as (
    select
        {{ dbt_utils.generate_surrogate_key(['_feed_hash', 'shape_id']) }} as _key,
        _feed_hash,
        shape_id,
        route_id,
        case
            when route_type = 1 then replace(shape_id, '_', '')  -- Rail/Metro uses underscore
            when route_type = 3 then replace(shape_id, ':', '')  -- Bus uses colon
            else shape_id
        end as pattern_id,
        direction_id
    from route_patterns
)

select * from int_gtfs_patterns
