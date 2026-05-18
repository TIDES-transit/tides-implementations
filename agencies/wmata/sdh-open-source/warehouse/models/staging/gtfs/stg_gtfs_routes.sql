with routes_src as (
    select *
    from {{ source('gtfs', 'gtfs_routes') }}
),

stg_gtfs_routes as (
    select
        feed_hash as _feed_hash,
        {{ flex_cast('route_id', "varchar", safe=True) }} as route_id,
        {{ flex_cast('agency_id', "varchar", safe=True) }} as agency_id,
        {{ flex_cast('route_short_name', "varchar", safe=True) }} as route_short_name,
        {{ flex_cast('route_long_name', "varchar", safe=True) }} as route_long_name,
        {{ flex_cast('route_desc', "varchar", safe=True) }} as route_desc,
        {{ flex_cast('route_type', "integer", safe=True) }} as route_type,
        {{ flex_cast('route_color', "varchar", safe=True) }} as route_color,
        {{ flex_cast('route_text_color', "varchar", safe=True) }} as route_text_color,
        {{ flex_cast('route_url', "varchar", safe=True) }} as route_url
    from routes_src
)

select * from stg_gtfs_routes
