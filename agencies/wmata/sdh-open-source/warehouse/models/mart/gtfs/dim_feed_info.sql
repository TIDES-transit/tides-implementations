with stg as (
    select * from {{ ref('stg_gtfs_feed_info') }}
),

feeds as (
    select * from {{ ref('dim_schedule_feeds') }}
),

dim_feed_info as (
    select
        stg._feed_hash,
        stg.feed_publisher_name,
        stg.feed_publisher_url,
        stg.feed_lang,
        stg.feed_start_date,
        stg.feed_end_date,
        stg.feed_version,
        stg.feed_contact_email,
        stg.feed_contact_url
    from feeds
    inner join stg
        on feeds._feed_hash = stg._feed_hash
)

select * from dim_feed_info
