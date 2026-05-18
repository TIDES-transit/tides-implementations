with stg as (
    select * from {{ ref('stg_gtfs_calendar') }}
),

feeds as (
    select * from {{ ref('dim_schedule_feeds') }}
),

dim_calendar as (
    select
        {{ dbt_utils.generate_surrogate_key(['stg._feed_hash', 'stg.service_id']) }} as _key,
        stg._feed_hash,
        stg.service_id,
        stg.monday,
        stg.tuesday,
        stg.wednesday,
        stg.thursday,
        stg.friday,
        stg.saturday,
        stg.sunday,
        stg.start_date,
        stg.end_date
    from stg
    inner join feeds
        on stg._feed_hash = feeds._feed_hash
)

select * from dim_calendar
