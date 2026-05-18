{{ config(
    severity='warn',
    meta={
        'dagster': {
            'ref': {
                'name': 'fct_tides_vehicle_locations_bus_quality',
                'package': 'warehouse'
            }
        }
    }
) }}

with stg as (
    select
        _row_id,
        service_date,
        event_time as event_timestamp,
        bus_id as vehicle_id,
        stop_id,
        coalesce(stop_front_door_entry, 0)
        + coalesce(stop_front_door_exit, 0)
        + coalesce(stop_back_door_entry, 0)
        + coalesce(stop_back_door_exit, 0) as total_ridership_activity
    from {{ ref('stg_bus_info') }}
    where
        coalesce(stop_front_door_entry, 0) > 0
        or coalesce(stop_front_door_exit, 0) > 0
        or coalesce(stop_back_door_entry, 0) > 0
        or coalesce(stop_back_door_exit, 0) > 0
),

-- identify all records from vl whose ridership >0
all_vl_records as (
    select location_ping_id
    from {{ ref('fct_tides_vehicle_locations_bus_quality') }}
),

full_vl_records_with_ridership as (
    select
        stg.*,
        all_vl_records.location_ping_id
    from stg
    inner join all_vl_records
        on stg._row_id = all_vl_records.location_ping_id
),

-- identify rows missing in fct_vl that actually host ridership
factual_vl_ids as (
    select location_ping_id
    from {{ ref('fct_tides_vehicle_locations_bus') }}
),

test_missing_ridership_due_to_filter_in_vehicle_locations as (
    select full_vl_records_with_ridership.*
    from full_vl_records_with_ridership
    left join factual_vl_ids on full_vl_records_with_ridership.location_ping_id = factual_vl_ids.location_ping_id
    where factual_vl_ids.location_ping_id is null
)

select * from test_missing_ridership_due_to_filter_in_vehicle_locations