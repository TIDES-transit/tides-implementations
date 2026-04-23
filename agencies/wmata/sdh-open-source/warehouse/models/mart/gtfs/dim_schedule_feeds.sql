-- Feed info and meta, long by mode.
-- Identifies most recent feed by mode
with stg_gtfs_feed_meta as (
    select
        _feed_hash,
        _source,
        _date_retrieved
    from {{ ref('stg_gtfs_feed_meta') }}
),

stg_feed_info as (
    select *
    from {{ ref('stg_gtfs_feed_info') }}
),

feed_meta_with_type as (
    select
        stg_gtfs_feed_meta._feed_hash,
        stg_gtfs_feed_meta._source,
        stg_gtfs_feed_meta._date_retrieved,
        case
            when stg_gtfs_feed_meta._source = 'https://api.[AGENCY].com/gtfs/rail-bus-gtfs-static.zip' then 'Combined'
            when stg_gtfs_feed_meta._source = 'https://api.[AGENCY].com/gtfs/rail-gtfs-static.zip' then 'Rail'
            when stg_gtfs_feed_meta._source = 'https://api.[AGENCY].com/gtfs/bus-gtfs-static.zip' then 'Bus'
        end as _feed_type
    from stg_gtfs_feed_meta
),

dim_schedule_feeds as (
    select
        feed_meta_with_type._feed_hash,
        feed_meta_with_type._source,
        feed_meta_with_type._feed_type,
        feed_meta_with_type._date_retrieved,
        stg_feed_info.feed_version,
        stg_feed_info.feed_start_date,
        stg_feed_info.feed_end_date,
        greatest(stg_feed_info.feed_start_date, date_trunc('day', feed_meta_with_type._date_retrieved)) as _valid_from,
        coalesce( -- TODO: check if this is ok, had issue with onyl single feed in db
            least(
                date_trunc(
                    'day',
                    lead(feed_meta_with_type._date_retrieved) over (
                        partition by feed_meta_with_type._feed_type
                        order by feed_meta_with_type._date_retrieved, feed_meta_with_type._feed_hash
                    )
                ), -- next feed retrieval date for feed of same type
                stg_feed_info.feed_end_date,
                -- default to 1 year if no end date
                {{ date_add('feed_meta_with_type._date_retrieved', 1, 'YEAR', 'DAY') }}
            ),
            stg_feed_info.feed_end_date,
            {{ date_add('feed_meta_with_type._date_retrieved', 1, 'YEAR', 'DAY') }}
            -- fallback to 1 year if all else fails
        ) as _valid_to
    from feed_meta_with_type
    left join stg_feed_info
        on feed_meta_with_type._feed_hash = stg_feed_info._feed_hash
)

select * from dim_schedule_feeds
where _valid_to > _valid_from -- remove when sample data is cleaned up.