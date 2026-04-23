-- create a long list of dates to join to calendar
-- last day is set to be Dec 31 2099, reasonably far in future
with dim_dates as (
    select service_date
    from
        {{ ref('dim_dates') }}
),

calendar as (
    select *
    from {{ ref('stg_gtfs_calendar') }}
    -- if necessary, include condition for start_date < end_date
    -- but only if agency feed with invalid start/end is observed in wild
),

int_gtfs_calendar_long as (
    select
        {{ dbt_utils.generate_surrogate_key(['_feed_hash', 'service_id', 'service_date']) }} as _key,
        calendar._feed_hash,
        calendar.service_id,
        dim_dates.service_date,
        -- Use ISO 8601: 1 (monday) - 7 (sunday)
        case
            when {{ extract_isodow('dim_dates.service_date') }} = 1 then {{ flex_cast("calendar.monday", "boolean", safe=True) }} --noqa: LT05
            when {{ extract_isodow('dim_dates.service_date') }} = 2 then {{ flex_cast("calendar.tuesday", "boolean", safe=True) }}  --noqa: LT05
            when {{ extract_isodow('dim_dates.service_date') }} = 3 then {{ flex_cast("calendar.wednesday", "boolean", safe=True) }}  --noqa: LT05
            when {{ extract_isodow('dim_dates.service_date') }} = 4 then {{ flex_cast("calendar.thursday", "boolean", safe=True) }}  --noqa: LT05
            when {{ extract_isodow('dim_dates.service_date') }} = 5 then {{ flex_cast("calendar.friday", "boolean", safe=True) }}  --noqa: LT05
            when {{ extract_isodow('dim_dates.service_date') }} = 6 then {{ flex_cast("calendar.saturday", "boolean", safe=True) }}  --noqa: LT05
            when {{ extract_isodow('dim_dates.service_date') }} = 7 then {{ flex_cast("calendar.sunday", "boolean", safe=True) }}  --noqa: LT05
        end as has_service
    from calendar
    left join dim_dates
        on calendar.start_date <= dim_dates.service_date and calendar.end_date >= dim_dates.service_date
)

select *
from int_gtfs_calendar_long
