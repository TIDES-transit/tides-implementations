-- Test that each pattern belongs to only one route
-- At [AGENCY], a pattern should never span multiple routes as this violates our assumption that shape_id
--  can be used as a proxy for a pattern of stops.


{{ config(severity='error') }}

with pattern_route_mapping as (
    select
        _feed_hash,
        pattern_id,
        count(distinct route_id) as route_count,
        {{ agg_array_to_string(agg_col='route_id', separator=', ', use_distinct=True) }} as routes
    from {{ ref('int_gtfs_patterns') }}
    group by _feed_hash, pattern_id
),

patterns_with_multiple_routes as (
    select
        _feed_hash,
        pattern_id,
        route_count,
        routes
    from pattern_route_mapping
    where route_count > 1
)

select * from patterns_with_multiple_routes