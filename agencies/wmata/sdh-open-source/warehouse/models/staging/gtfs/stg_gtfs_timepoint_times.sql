with timepoint_times_src as (
    select *
    from {{ source('gtfs', 'gtfs_timepoint_times') }}
),

stg_gtfs_timepoint_times as (
    select
        feed_hash as _feed_hash,
        {{ flex_cast('trip_id', "varchar", safe=True) }} as trip_id,
        {{ flex_cast('arrival_time', "varchar", safe=True) }} as arrival_time,
        {{ flex_cast('departure_time', "varchar", safe=True) }} as departure_time,
        {{ flex_cast('stop_id', "varchar", safe=True) }} as stop_id,
        {{ flex_cast('stop_sequence', "integer", safe=True) }} as stop_sequence,
        {{ flex_cast('stop_headsign', "varchar", safe=True) }} as stop_headsign,
        {{ flex_cast('pickup_type', "integer", safe=True) }} as pickup_type,
        {{ flex_cast('drop_off_type', "integer", safe=True) }} as drop_off_type,
        {{ flex_cast('shape_dist_traveled', "float", safe=True) }} as shape_dist_traveled,
        {{ flex_cast('timepoint', "integer", safe=True) }} as timepoint
    from timepoint_times_src
)

select * from stg_gtfs_timepoint_times
