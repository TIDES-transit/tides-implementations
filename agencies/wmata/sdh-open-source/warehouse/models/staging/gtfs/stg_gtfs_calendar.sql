with calendar_src as (
    select *
    from {{ source('gtfs', 'gtfs_calendar') }}
),

stg_gtfs_calendar as (
    select
        feed_hash as _feed_hash,
        {{ flex_cast('service_id', "varchar", safe=True) }} as service_id,
        {{ flex_cast('monday', "boolean", safe=True) }} as monday,
        {{ flex_cast('tuesday', "boolean", safe=True) }} as tuesday,
        {{ flex_cast('wednesday', "boolean", safe=True) }} as wednesday,
        {{ flex_cast('thursday', "boolean", safe=True) }} as thursday,
        {{ flex_cast('friday', "boolean", safe=True) }} as friday,
        {{ flex_cast('saturday', "boolean", safe=True) }} as saturday,
        {{ flex_cast('sunday', "boolean", safe=True) }} as sunday,
        {{ parse_datetime('start_date', '%Y%m%d', 8, type="date") }} as start_date,
        {{ parse_datetime('end_date', '%Y%m%d', 8, type="date") }} as end_date
    from calendar_src
)

select * from stg_gtfs_calendar
