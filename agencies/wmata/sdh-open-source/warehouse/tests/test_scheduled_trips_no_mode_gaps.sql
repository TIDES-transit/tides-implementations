-- Flags dates within recent history where one transit mode has scheduled trips
-- but the other does not. A missing mode on a date typically indicates a feed
-- selection gap in fct_daily_schedule_feed_modes. note that because our dev
-- environment only does incremental microbatching for a handful of dates, it may
-- not parse feeds that are needed to cover months much later (e.g., a january feed
-- that covers dates in march when microbatching is set up for a few short dates in
-- march)
{{ config(
    severity='warn',
    meta={
        'dagster': {
            'ref': {
                'name': 'fct_scheduled_trips',
                'package': 'warehouse'
            }
        }
    }
) }}

with service_dates_with_modes as (
    select
        service_date,
        trip_mode,
        count(*) as trip_count
    from {{ ref('fct_scheduled_trips') }}
    where
        service_date >= current_date - interval '30' day
        and service_date <= current_date
    group by service_date, trip_mode
),

expected_modes as (
    select 'Bus' as expected_mode
    union all
    select 'Rail' as expected_mode
),

all_dates as (
    select distinct service_date
    from service_dates_with_modes
),

expected as (
    select
        all_dates.service_date,
        expected_modes.expected_mode
    from all_dates
    cross join expected_modes
),

test_scheduled_trips_no_mode_gaps as (
    select
        expected.service_date,
        expected.expected_mode as missing_mode
    from expected
    left join service_dates_with_modes
        on
            expected.service_date = service_dates_with_modes.service_date
            and expected.expected_mode = service_dates_with_modes.trip_mode
    where service_dates_with_modes.trip_mode is null
)

select * from test_scheduled_trips_no_mode_gaps
