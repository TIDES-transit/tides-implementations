-- Test to verify that trip_id_scheduled values from bus info data
-- exist in the GTFS scheduled trips, matching on both trip_id and service_date
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
    select *
    from {{ ref("int_tides_vehicle_locations_bus_info") }}
    where
        trip_type = 'In service'
        and trip_id_scheduled is not null
),

fct_scheduled_trips as (
    select *
    from {{ ref("fct_scheduled_trips") }}
),

distinct_bus_info_trips as (
    select distinct
        service_date,
        trip_id_scheduled
    from int_tides_vehicle_locations_bus_info
),

unmatched_trips as (
    select
        distinct_bus_info_trips.service_date,
        distinct_bus_info_trips.trip_id_scheduled
    from distinct_bus_info_trips
    left join fct_scheduled_trips
        on
            distinct_bus_info_trips.service_date = fct_scheduled_trips.service_date
            and distinct_bus_info_trips.trip_id_scheduled = fct_scheduled_trips.trip_id
    where
        fct_scheduled_trips.trip_id is null
),

test_bus_info_scheduled_trips_exist_in_gtfs as (
    select
        service_date,
        trip_id_scheduled
    from unmatched_trips
)

select * from test_bus_info_scheduled_trips_exist_in_gtfs