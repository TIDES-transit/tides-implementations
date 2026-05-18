with feed_meta_src as (
    select *
    from {{ source('gtfs', 'gtfs_feed_meta') }}
),

stg_gtfs_feed_meta as (
    select
        {{ flex_cast('feed_hash', "varchar", safe=True) }} as _feed_hash,
        {{ flex_cast('source', "varchar", safe=True) }} as _source,
        date_retrieved as _date_retrieved
    from feed_meta_src
)

select * from stg_gtfs_feed_meta
