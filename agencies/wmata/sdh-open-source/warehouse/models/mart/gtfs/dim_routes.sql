with stg as (
    select * from {{ ref('stg_gtfs_routes') }}
),

feeds as (
    select * from {{ ref('dim_schedule_feeds') }}
),

dim_routes as (
    select
        {{ dbt_utils.generate_surrogate_key(['stg._feed_hash', 'stg.route_id']) }} as _key,
        stg._feed_hash,
        stg.route_id,
        stg.agency_id,
        stg.route_short_name,
        stg.route_long_name,
        stg.route_desc,
        stg.route_type,
        stg.route_url,
        stg.route_color,
        stg.route_text_color
    from stg
    inner join feeds
        on stg._feed_hash = feeds._feed_hash
)

select * from dim_routes
