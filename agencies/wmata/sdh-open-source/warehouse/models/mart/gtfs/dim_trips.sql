with stg as (
    select * from {{ ref('stg_gtfs_trips') }}
),

feeds as (
    select * from {{ ref('dim_schedule_feeds') }}
),

dim_trips as (
    select
        {{ dbt_utils.generate_surrogate_key(['stg._feed_hash', 'stg.trip_id']) }} as _key,
        stg._feed_hash,
        stg.route_id,
        stg.service_id,
        stg.trip_id,
        stg.trip_headsign,
        stg.direction_id,
        stg.block_id,
        stg.shape_id
    from stg
    inner join feeds
        on stg._feed_hash = feeds._feed_hash
)

select * from dim_trips
