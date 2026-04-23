with agency_src as (
    select *
    from {{ source('gtfs', 'gtfs_agency') }}
),

stg_gtfs_agency as (
    select
        feed_hash as _feed_hash,
        {{ flex_cast('agency_name', "varchar", safe=True) }} as agency_name,
        {{ flex_cast('agency_url', "varchar", safe=True) }} as agency_url,
        {{ flex_cast('agency_timezone', "varchar", safe=True) }} as agency_timezone,
        {{ flex_cast('agency_lang', "varchar", safe=True) }} as agency_lang,
        {{ flex_cast('agency_phone', "varchar", safe=True) }} as agency_phone,
        {{ flex_cast('agency_fare_url', "varchar", safe=True) }} as agency_fare_url,
        {{ flex_cast('agency_email', "varchar", safe=True) }} as agency_email
    from agency_src
)

select * from stg_gtfs_agency
