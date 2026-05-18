with shapes_src as (
    select *
    from {{ source('gtfs', 'gtfs_shapes') }}
),

stg_gtfs_shapes as (
    select
        feed_hash as _feed_hash,
        {{ flex_cast('shape_id', "varchar", safe=True) }} as shape_id,
        {{ flex_cast('shape_pt_lat', "float", safe=True) }} as shape_pt_lat,
        {{ flex_cast('shape_pt_lon', "float", safe=True) }} as shape_pt_lon,
        {{ flex_cast('shape_pt_sequence', "integer", safe=True) }} as shape_pt_sequence,
        {{ flex_cast("nullif(shape_dist_traveled, '')", "float", safe=True) }} as shape_dist_traveled -- noqa: LT05
        -- null shape_dist_traveled - in duckdb may be '' rather than null
    from shapes_src
)

select * from stg_gtfs_shapes
