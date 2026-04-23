{{ config(enabled=var('enable_realtime', false)) }}

with stg_realtime_bus_info as (
    select * from {{ ref("stg_realtime_bus_info") }}
),

avl_trips as (
    select * from {{ ref("stg_avl_trips") }}
),

avl_stops as (
    select * from {{ ref("stg_avl_stops") }}
),

avl_log as (
    select
        stg_realtime_bus_info.*,
        avl_trips.isrevenue,
        avl_trips.route,
        avl_trips.tapatternid as _avl_tapatternid,
        avl_trips.tripstarttime,
        avl_trips.tripendtime,
        avl_stops.geostopid
    from stg_realtime_bus_info
    left join avl_stops
        on
            stg_realtime_bus_info.versionid = avl_stops.versionid
            and stg_realtime_bus_info.currentstopid = avl_stops.stopid
    left join avl_trips
        on
            stg_realtime_bus_info.currenttripid = avl_trips.vendor_1_tripid
            and stg_realtime_bus_info.service_date = avl_trips.service_date
),

-- Detect stop visits: first instance of each stop within service_date, route, currenttripid, tripstartdts
-- TODO: support cases where the same stop is hit multiple times on the same route.
-- The  reason we don't currently support this is because there is a lot of "jitteriness"
-- in the current stop field, going back and forth between some recent stops.
stop_visit_detection as (
    select
        *,
        case
            when currentstopid is not null then
                row_number() over (
                    partition by service_date, route, currenttripid, tripstartdts, currentstopid
                    order by locationupdatedts
                )
        end as stop_visit_rank
    from avl_log
),

int_tides_vehicle_locations_realtime as (
    select
        {{ dbt_utils.generate_surrogate_key(['vehicleid', 'locationupdatedts', 'vehicleworkid', 'latitude', 'longitude', 'currentstopid', 'vehiclestatusid']) }} --noqa:LT05
            as location_ping_id,
        service_date,
        locationupdatedts as event_timestamp,
        {{ flex_cast("null", "varchar") }} as trip_id_performed,
        currenttripid as trip_id_scheduled, -- DOES NOT MATCH GTFS. Binu said we can't expect a match here.
        {{ flex_cast("null", "integer") }} as trip_stop_sequence,
        {{ flex_cast("null", "integer") }} as scheduled_stop_sequence,
        vehiclenumber as vehicle_id,
        -- per Binu, should match number on the bus
        {{ flex_cast("null", "varchar") }} as device_id,
        concat(route, _avl_tapatternid) as pattern_id,
        geostopid as stop_id, -- maps to GTFS stop ID
        -- per Binu, no realtime source for this, cannot fill from vehiclestatusid
        {{ flex_cast("null", "varchar") }} as current_status,
        latitude,
        longitude,
        {{ flex_cast("null", "varchar") }} as gps_quality,
        hdgdeg as heading,
        speed,
        {{ flex_cast("null", "double") }} as odometer,
        scheddev as schedule_deviation,
        {{ flex_cast("null", "double") }} as headway_deviation,
        case
            when isrevenue = 0
                then
                    case
                        when upper(route) like 'DH%' then 'Deadhead'
                        when upper(route) like 'PI%' then 'Pullin'
                        when upper(route) like 'PO%' then 'Pullout'
                        else 'Other not in service'
                    end
            else 'In service'
        end as trip_type,
        {{ flex_cast("null", "varchar") }} as schedule_relationship,
        tripstarttime as trip_start_time, -- TODO: rename to _trip_start_time (non-TIDES)
        tripendtime as trip_end_time, -- TODO: rename to _trip_end_time (non-TIDES)
        route as route_id,
        -- TODO: rename to _is_stop_visit (non-TIDES)
        coalesce(stop_visit_rank = 1 and isrevenue = 1 and geostopid is not null, false) as is_stop_visit,
        -- TODO: rename to _apcon (non-TIDES)
        case when stop_visit_rank = 1 and isrevenue = 1 and geostopid is not null then apcon end as apcon,
        -- TODO: rename to _apcoff (non-TIDES)
        case when stop_visit_rank = 1 and isrevenue = 1 and geostopid is not null then apcoff end as apcoff

    from stop_visit_detection

)

select * from int_tides_vehicle_locations_realtime
order by trip_start_time, vehicle_id, pattern_id, event_timestamp