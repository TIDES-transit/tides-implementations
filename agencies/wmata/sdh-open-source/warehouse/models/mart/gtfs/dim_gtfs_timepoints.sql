with stg as (
    select * from {{ ref('stg_gtfs_timepoints') }}
),

feeds as (
    select * from {{ ref('dim_schedule_feeds') }}
),

dim_gtfs_timepoints as (
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
        stg.stop_url
    from stg
    inner join feeds
        on stg._feed_hash = feeds._feed_hash
)

select * from dim_gtfs_timepoints
