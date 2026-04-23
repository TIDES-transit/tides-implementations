with calendar_dates_src as (
    select *
    from {{ source('gtfs', 'gtfs_calendar_dates') }}
),

stg_gtfs_calendar_dates as (
    select
        feed_hash as _feed_hash,
        {{ flex_cast('service_id', "varchar", safe=True) }} as service_id,
        {{ flex_cast('exception_type', "integer", safe=True) }} as exception_type,
        {{ parse_datetime('date', '%Y%m%d', 8, type="date") }} as date -- noqa: RF04
    from calendar_dates_src
)

select * from stg_gtfs_calendar_dates
