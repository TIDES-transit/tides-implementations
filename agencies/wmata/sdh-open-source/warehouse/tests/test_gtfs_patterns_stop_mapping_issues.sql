-- Test for pattern stop mapping issues
-- 1. All patterns should have at least 2 stops (origin and destination)
-- This helps identify incomplete patterns or problems with stop_times to pattern mapping

{{ config(severity='warn') }}

with pattern_stop_counts as (
    select
        _feed_hash,
        pattern_id,
        count(*) as total_stops,
        count(distinct stop_id) as unique_stops
    from {{ ref('int_gtfs_pattern_stops') }}
    group by _feed_hash, pattern_id
),

pattern_issues as (
    -- Patterns with insufficient stops
    select
        _feed_hash,
        pattern_id,
        total_stops as detail_count,
        'Insufficient stops: ' || {{ flex_cast('total_stops', "varchar", safe=True) }} as issue_type
    from pattern_stop_counts
    where total_stops < 2
)

select * from pattern_issues
