with int_pattern_stops as (
    select * from {{ ref('int_gtfs_pattern_stops') }}
),

feeds as (
    select _feed_hash from {{ ref('dim_schedule_feeds') }}
),

dim_pattern_stops as (
    select
        int_pattern_stops._feed_hash,
        int_pattern_stops.pattern_id,
        int_pattern_stops.stop_id,
        int_pattern_stops.stop_sequence
    from int_pattern_stops
    inner join feeds
        on int_pattern_stops._feed_hash = feeds._feed_hash
)

select * from dim_pattern_stops
