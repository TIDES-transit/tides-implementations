with stop_times_src as (
    select *
    from {{ source('gtfs', 'gtfs_stop_times') }}
),

stg_gtfs_stop_times as (
    select
        feed_hash as _feed_hash,
        {{ flex_cast('trip_id', "varchar", safe=True) }} as trip_id,
        nullif({{ flex_cast('arrival_time', "varchar", safe=True) }}, '') as arrival_time,
        nullif({{ flex_cast('departure_time', "varchar", safe=True) }}, '') as departure_time,
        {{ flex_cast('stop_id', "varchar", safe=True) }} as stop_id,
        {{ flex_cast('stop_sequence', "integer", safe=True) }} as stop_sequence,
        {{ flex_cast('stop_headsign', "varchar", safe=True) }} as stop_headsign,
        {{ flex_cast('pickup_type', "integer", safe=True) }} as pickup_type,
        {{ flex_cast('drop_off_type', "integer", safe=True) }} as drop_off_type,
        {{ flex_cast("nullif(shape_dist_traveled, '')", "float", safe=True) }} as shape_dist_traveled, -- noqa: LT05
        {{ flex_cast("nullif(timepoint, '')", "integer", safe=True) }} as timepoint
    from stop_times_src
)

select * from stg_gtfs_stop_times
