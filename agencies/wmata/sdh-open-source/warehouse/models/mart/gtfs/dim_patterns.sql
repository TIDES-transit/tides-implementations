with int_patterns as (
    select * from {{ ref('int_gtfs_patterns') }}
),

feeds as (
    select * from {{ ref('dim_schedule_feeds') }}
),

dim_patterns as (
    select
        int_patterns._feed_hash,
        int_patterns.route_id,
        int_patterns.pattern_id,
        int_patterns.shape_id
    from int_patterns
    inner join feeds
        on int_patterns._feed_hash = feeds._feed_hash
)

select * from dim_patterns
