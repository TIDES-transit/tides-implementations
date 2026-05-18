with feed_info_src as (
    select *
    from {{ source('gtfs', 'gtfs_feed_info') }}
),

stg_gtfs_feed_info as (
    select
        feed_hash as _feed_hash,
        {{ flex_cast('feed_publisher_name', "varchar", safe=True) }} as feed_publisher_name,
        {{ flex_cast('feed_publisher_url', "varchar", safe=True) }} as feed_publisher_url,
        {{ flex_cast('feed_lang', "varchar", safe=True) }} as feed_lang,
        {{ parse_datetime('feed_start_date', '%Y%m%d', 8, type="date") }} as feed_start_date,
        {{ parse_datetime('feed_end_date', '%Y%m%d', 8, type="date") }} as feed_end_date,
        {{ flex_cast('feed_version', "varchar", safe=True) }} as feed_version,
        {{ flex_cast('feed_contact_email', "varchar", safe=True) }} as feed_contact_email,
        {{ flex_cast('feed_contact_url', "varchar", safe=True) }} as feed_contact_url
    from feed_info_src
)

select * from stg_gtfs_feed_info
