with stops_src as (
    select *
    from {{ source('gtfs', 'gtfs_stops') }}
),

stg_gtfs_stops as (
    select
        feed_hash as _feed_hash,
        {{ flex_cast('stop_id', "varchar", safe=True) }} as stop_id,
        {{ flex_cast('stop_code', "varchar", safe=True) }} as stop_code,
        {{ flex_cast('stop_name', "varchar", safe=True) }} as stop_name,
        {{ flex_cast('stop_desc', "varchar", safe=True) }} as stop_desc,
        {{ flex_cast('stop_lat', "float", safe=True) }} as stop_lat,
        {{ flex_cast('stop_lon', "float", safe=True) }} as stop_lon,
        {{ flex_cast('zone_id', "varchar", safe=True) }} as zone_id,
        {{ flex_cast('stop_url', "varchar", safe=True) }} as stop_url,
        {{ flex_cast('parent_station', "varchar", safe=True) }} as parent_station,
        {{ flex_cast('wheelchair_boarding', "integer", safe=True) }} as wheelchair_boarding,
        {{ flex_cast('stop_timezone', "varchar", safe=True) }} as stop_timezone,
        {{ flex_cast('level_id', "varchar", safe=True) }} as level_id,
        {{ flex_cast('platform_code', "varchar", safe=True) }} as platform_code
    from stops_src
)

select * from stg_gtfs_stops
