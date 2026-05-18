-- Test to verify that pattern_id values from bus info data
-- match the pattern_id values derived from GTFS trips
-- This test captures cases where TIDES pattern_id does not align with GTFS data
{{ config(
    severity='warn',
    meta={
        'dagster': {
            'ref': {
                'name': 'int_tides_vehicle_locations_bus_info',
                'package': 'warehouse'
            }
        }
    }
) }}

with
int_vl as (
    select * from {{ ref("int_tides_vehicle_locations_bus_info") }}
    where trip_type = 'In service'
),

dim_route_pattern_trips as (
    select * from {{ ref("dim_route_pattern_trips") }}
),

fct_daily_feeds as (
    select
        _feed_hash,
        service_date
    from
        {{ ref('fct_daily_schedule_feed_modes') }}
    where
        feed_mode = 'Bus'
),

joined_data as (
    select
        int_vl.service_date,
        int_vl.location_ping_id,
        int_vl.trip_id_scheduled,
        int_vl.pattern_id as tides_pattern_id,
        int_vl.trip_type,
        int_vl.current_status,
        int_vl.trip_stop_sequence,
        int_vl.stop_id,
        int_vl.schedule_relationship,
        dim_route_pattern_trips.route_id as gtfs_route_id,
        dim_route_pattern_trips.pattern_id as gtfs_pattern_id,
        case
            when
                int_vl.trip_type = 'In service'
                and int_vl.pattern_id = dim_route_pattern_trips.pattern_id
                then 'in_service_matches_gtfs' -- this is a successful join
            when
                int_vl.trip_type = 'In service'
                and dim_route_pattern_trips.pattern_id is null
                then 'trip_id_failed_join_to_gtfs'
            when
                int_vl.trip_type = 'In service'
                and int_vl.pattern_id != dim_route_pattern_trips.pattern_id
                and dim_route_pattern_trips.pattern_id is not null
                then 'in_service_pattern_mismatch'
            else 'other_case'
        end as pattern_status
    from int_vl
    left join fct_daily_feeds
        on int_vl.service_date = fct_daily_feeds.service_date
    left join dim_route_pattern_trips
        on
            fct_daily_feeds._feed_hash = dim_route_pattern_trips._feed_hash
            and int_vl.trip_id_scheduled = dim_route_pattern_trips.trip_id
    where
        -- Exclude known-bad stop_sequence values and unscheduled trips before joining.
        -- These rows are intentionally excluded from test evaluation rather than flagged,
        -- as they cannot produce a valid pattern_status match against GTFS.
        int_vl.trip_stop_sequence not in (0, -1)
        and int_vl.trip_id_scheduled is not null
),

test_tides_in_service_vehicle_locations_pattern_id_matches_gtfs_trip as (
    select * from joined_data
    where
        pattern_status not in (
            -- these are successes
            'in_service_matches_gtfs',
            -- these fail for other reasons; see
            -- test_bus_info_scheduled_trips_exist_in_gtfs
            'trip_id_failed_join_to_gtfs'
        )
)

select * from test_tides_in_service_vehicle_locations_pattern_id_matches_gtfs_trip