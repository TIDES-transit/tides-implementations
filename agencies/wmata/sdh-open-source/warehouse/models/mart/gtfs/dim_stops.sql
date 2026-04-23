with stg as (
    select * from {{ ref('stg_gtfs_stops') }}
),

feeds as (
    select * from {{ ref('dim_schedule_feeds') }}
),

dim_stops as (
    select
        {{ dbt_utils.generate_surrogate_key(['stg._feed_hash', 'stg.stop_id']) }} as _key,
        stg._feed_hash,
        stg.stop_id,
        stg.stop_code,
        stg.stop_name,
        stg.stop_desc,
        stg.stop_lat,
        stg.stop_lon,
        stg.zone_id,
        stg.stop_url,
        stg.parent_station,
        stg.wheelchair_boarding,
        stg.stop_timezone,
        stg.level_id,
        stg.platform_code,
        date_trunc('day', feeds._date_retrieved) as _date_retrieved
    from stg
    inner join feeds
        on stg._feed_hash = feeds._feed_hash
)

select * from dim_stops
