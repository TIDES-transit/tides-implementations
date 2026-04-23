with stg as (
    select * from {{ ref('stg_gtfs_shapes') }}
),

feeds as (
    select * from {{ ref('dim_schedule_feeds') }}
),

dim_shapes as (
    select
        {{ dbt_utils.generate_surrogate_key(['stg._feed_hash', 'stg.shape_id', 'stg.shape_pt_sequence']) }} as _key,
        stg._feed_hash,
        stg.shape_id,
        stg.shape_pt_lat,
        stg.shape_pt_lon,
        stg.shape_pt_sequence,
        stg.shape_dist_traveled
    from stg
    inner join feeds
        on stg._feed_hash = feeds._feed_hash
)

select * from dim_shapes
