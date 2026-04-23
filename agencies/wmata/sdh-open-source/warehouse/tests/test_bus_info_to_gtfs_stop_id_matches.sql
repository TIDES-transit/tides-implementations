-- we want to ensure that we're not returning null stop_ids into bus_info if there's some broader
-- mismatch between bus_info stop_ids and GTFS stop_codes. Right now, only a few bus info stop_ids seem to be
-- problematic.
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
int_tides_vehicle_locations_bus_info as (
    select
        location_ping_id,
        stop_id
    from {{ ref("int_tides_vehicle_locations_bus_info") }}
    -- we expect only in service stops to match to gtfs
    where trip_type = 'In service'
),

stg_bus_info as (
    select
        _row_id,
        service_date,
        event_time,
        ta_geo_id,
        route_id,
        trip_id,
        stop_sequence,
        bus_id
    from {{ ref("stg_bus_info") }}
),

unmatched_stops as (
    select
        stg_bus_info._row_id,
        stg_bus_info.service_date,
        stg_bus_info.event_time,
        stg_bus_info.ta_geo_id,
        stg_bus_info.route_id,
        stg_bus_info.trip_id,
        stg_bus_info.stop_sequence,
        stg_bus_info.bus_id,
        int_tides_vehicle_locations_bus_info.stop_id as matched_stop_id
    from int_tides_vehicle_locations_bus_info
    inner join stg_bus_info
        on int_tides_vehicle_locations_bus_info.location_ping_id = stg_bus_info._row_id
    where
        int_tides_vehicle_locations_bus_info.stop_id is null
        and stg_bus_info.ta_geo_id is not null
        -- only include the numeric ta_geo_id values
        -- seems like some of the bus info in service trips can nevertheless get these
        -- stops that appear to not be related to real passenger stops
        and {{ regexp_match('stg_bus_info.ta_geo_id', '^[0-9]+$') }}
),

-- per chat with laurie, have the go-ahead to summarize up from record level here.
-- idea is that you'd take these date ranges to examine overlapping feeds where we might expect
-- stops to be present
test_bus_info_to_gtfs_stop_id_matches as (
    select
        ta_geo_id,
        min(service_date) as service_date_missing_earliest,
        max(service_date) as service_date_missing_latest
    from
        unmatched_stops
    group by
        ta_geo_id
)

select * from test_bus_info_to_gtfs_stop_id_matches