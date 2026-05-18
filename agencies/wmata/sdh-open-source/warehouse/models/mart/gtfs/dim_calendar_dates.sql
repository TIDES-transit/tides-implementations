with stg as (
    select * from {{ ref('stg_gtfs_calendar_dates') }}
),

feeds as (
    select * from {{ ref('dim_schedule_feeds') }}
),

dim_calendar_dates as (
    select
        {{ dbt_utils.generate_surrogate_key(['stg._feed_hash', 'stg.service_id', 'stg.date', 'stg.exception_type']) }} as _key, --noqa: LT05
        stg._feed_hash,
        stg.service_id,
        stg.date,
        stg.exception_type
    from stg
    inner join feeds
        on stg._feed_hash = feeds._feed_hash
)

select * from dim_calendar_dates
