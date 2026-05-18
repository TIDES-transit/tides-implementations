with trips_src as (
    select *
    from {{ source('gtfs', 'gtfs_trips') }}
),

stg_gtfs_trips as (
    select
        feed_hash as _feed_hash,
        {{ flex_cast('route_id', "varchar", safe=True) }} as route_id,
        {{ flex_cast('service_id', "varchar", safe=True) }} as service_id,
        {{ flex_cast('trip_id', "varchar", safe=True) }} as trip_id,
        {{ flex_cast('trip_headsign', "varchar", safe=True) }} as trip_headsign,
        {{ flex_cast('direction_id', "integer", safe=True) }} as direction_id,
        {{ flex_cast('block_id', "varchar", safe=True) }} as block_id,
        {{ flex_cast('shape_id', "varchar", safe=True) }} as shape_id
    from trips_src
)

select * from stg_gtfs_trips
