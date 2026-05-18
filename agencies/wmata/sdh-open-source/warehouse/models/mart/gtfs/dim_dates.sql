{{ config(materialized='table') }}

with date_spine as (
    {{
        dbt_utils.date_spine(
            datepart="day",
            start_date=flex_cast("'2018-01-01'", "date", safe=True),
            end_date=flex_cast("'2030-12-31'", "date", safe=True)
        )
    }}),

add_dow as (
    select
        cast(date_trunc('day', date_day) as date) as service_date,
        extract(year from date_day) as year_of_date,
        extract(month from date_day) as month_of_year,
        extract(day from date_day) as day_of_month,
        extract(doy from date_day) as day_of_year,
        -- Cross-database compatible weekday name formatting
        {{ format_datetime('date_day', '%A') }} as day_of_week
    from date_spine
),

dim_dates as (
    select
        *,
        case
            when day_of_week in ('Saturday', 'Sunday') then 'Weekend'
            else 'Weekday'
        end as weekday_weekend
    from add_dow
)

select * from dim_dates
