with cal_long as (
    select * from {{ ref('int_gtfs_calendar_long') }}
),

cal_dates as (
    select * from {{ ref('int_gtfs_calendar_dates') }}
),

full_feed_index as (
    select
        -- these values will be identical so doesn't matter which is first in coalesce
        coalesce(cal_long.service_date, cal_dates.service_date) as service_date,
        coalesce(cal_long._feed_hash, cal_dates._feed_hash) as _feed_hash,
        coalesce(cal_long.service_id, cal_dates.service_id) as service_id,
        -- calendar_dates takes precedence if present: it can modify calendar
        -- if no calendar_dates, use calendar
        -- if neither, no service
        coalesce(cal_dates.has_service, cal_long.has_service) as has_service
    from cal_long
    full outer join
        cal_dates
        on
            cal_long._feed_hash = cal_dates._feed_hash
            and cal_long.service_date = cal_dates.service_date
            and cal_long.service_id = cal_dates.service_id
),

int_gtfs_daily_services as (
    select
        {{ dbt_utils.generate_surrogate_key(['_feed_hash', 'service_id', 'service_date']) }} as _key,
        service_date,
        _feed_hash,
        service_id
    from full_feed_index
    where
        has_service = true
)

select * from int_gtfs_daily_services
