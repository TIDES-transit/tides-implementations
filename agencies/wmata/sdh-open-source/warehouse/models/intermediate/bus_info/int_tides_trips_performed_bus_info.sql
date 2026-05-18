--use fct_vl as the base of fill-in
--supplement fields with stg_bus_info and fct_scheduled_trips
with vl_fct as (
    select *
    from {{ ref('fct_tides_vehicle_locations_bus') }}
    where schedule_relationship in ('Scheduled')
),

stg as (
    select
        _row_id,
        operator_id,
        block_id
    from {{ ref("stg_bus_info") }}
),

fct_sched_trips as (
    select
        service_date,
        trip_id,
        trip_mode as route_type,
        trip_mode as ntd_mode,
        route_id,
        shape_id,
        direction_id,
        --Next, convert the TIMESTAMP WITH TIME ZONE to UTC before applying the UTC-ET conversion macro
        first_scheduled_departure_time at time zone 'utc' as first_scheduled_departure_time_utc,
        last_scheduled_arrival_time at time zone 'utc' as last_scheduled_arrival_time_utc
    from {{ ref("fct_scheduled_trips") }}
),

fct_sched_trips_et as (
    select
        service_date,
        trip_id,
        route_type,
        ntd_mode,
        route_id,
        shape_id,
        direction_id,
        --convert UTC timestamp to ET
        {{ utc_to_timezone('first_scheduled_departure_time_utc', 'America/New_York') }} as schedule_trip_start,
        {{ utc_to_timezone('last_scheduled_arrival_time_utc', 'America/New_York') }} as schedule_trip_end
    from fct_sched_trips
),

--order stop events to find the first and last stop id
--nonnull stop ids only to avoid first/last stop id being null
ordered_nonnull as (
    select
        trip_id_performed,
        stop_id,
        event_timestamp,
        row_number() over (
            partition by trip_id_performed
            order by event_timestamp asc
        ) as rn_first,
        row_number() over (
            partition by trip_id_performed
            order by event_timestamp desc
        ) as rn_last
    from vl_fct
    where stop_id is not null
),

first_last_stop_id as (
    select
        trip_id_performed,
        max(case when rn_first = 1 then stop_id end) as trip_start_stop_id,
        max(case when rn_last = 1 then stop_id end) as trip_end_stop_id
    from ordered_nonnull
    group by trip_id_performed
),

first_last_eventtime as (
    select
        trip_id_performed,
        min(event_timestamp) as actual_trip_start,
        max(event_timestamp) as actual_trip_end
    from vl_fct
    group by trip_id_performed
),

--next, back to stg_bus_info. Need to find the mostly appearing nonnull operator_id and block id
--because for each trip_id_performed, there might be more than one operator_id and block id
trips_raw as (
    select
        vl_fct.service_date,
        vl_fct.trip_id_performed,
        vl_fct.trip_type,
        vl_fct.vehicle_id,
        vl_fct.trip_id_scheduled,
        vl_fct.pattern_id,
        stg.operator_id,
        stg.block_id
    from vl_fct
    left join stg
        on vl_fct.location_ping_id = stg._row_id
    where vl_fct.trip_type = 'In service'
),

--compute the frequency operator_id and block_id appeared in each trip_id_performed
trips_counts as (
    select
        service_date,
        trip_id_performed,
        trip_type,
        vehicle_id,
        trip_id_scheduled,
        pattern_id,
        operator_id,
        block_id,
        -- there are some cases where we get many nulls, but do in fact have non-null values in some cases.
        -- in order to populate 'our best shot', we filter out nulls before counting
        count(case when operator_id is not null then 1 end) over (
            partition by trip_id_performed, operator_id
        ) as operator_count,
        count(case when block_id is not null then 1 end) over (
            partition by trip_id_performed, block_id
        ) as block_count
    from trips_raw
),

operator_mode as (
    select
        trip_id_performed,
        operator_id,
        row_number() over (
            partition by trip_id_performed
            order by operator_count desc, operator_id asc
        ) as rn
    from trips_counts
    where operator_id is not null
),

block_mode as (
    select
        trip_id_performed,
        block_id,
        row_number() over (
            partition by trip_id_performed
            order by block_count desc, block_id asc
        ) as rn
    from trips_counts
    where block_id is not null
),

--create trip roster based on trip_id_performed
--trip_id_performed is a composite key containing vehicle_id,trip_id_scheduled,pattern_id
--for each trip_id_performed, all of these fields have only one possible value.
trip_roster as (
    select
        service_date,
        trip_id_performed,
        trip_type,
        any_value(vehicle_id) as vehicle_id,
        any_value(trip_id_scheduled) as trip_id_scheduled,
        any_value(pattern_id) as pattern_id
    from trips_counts
    group by service_date, trip_id_performed, trip_type
),

distinct_trips as (
    select
        trip_roster.service_date,
        trip_roster.trip_id_performed,
        trip_roster.trip_type,
        trip_roster.vehicle_id,
        trip_roster.trip_id_scheduled,
        trip_roster.pattern_id,
        operator_mode.operator_id,
        block_mode.block_id,
        -- todo: consider updating to use join to dim_patterns in the future
        substring(trip_roster.pattern_id, 1, length(trip_roster.pattern_id) - 2) as route_id
    from trip_roster
    left join operator_mode
        on
            trip_roster.trip_id_performed = operator_mode.trip_id_performed
            and operator_mode.rn = 1
    left join block_mode
        on
            trip_roster.trip_id_performed = block_mode.trip_id_performed
            and block_mode.rn = 1
),

final_join as (
    select
        distinct_trips.service_date,
        distinct_trips.trip_id_performed,
        distinct_trips.trip_id_scheduled,
        distinct_trips.vehicle_id,
        distinct_trips.trip_type,
        distinct_trips.pattern_id,
        distinct_trips.route_id,
        distinct_trips.operator_id,
        distinct_trips.block_id,
        first_last_stop_id.trip_start_stop_id,
        first_last_stop_id.trip_end_stop_id,
        first_last_eventtime.actual_trip_start,
        first_last_eventtime.actual_trip_end,
        fct_sched_trips_et.route_type,
        fct_sched_trips_et.ntd_mode,
        fct_sched_trips_et.shape_id,
        fct_sched_trips_et.direction_id,
        fct_sched_trips_et.schedule_trip_start,
        fct_sched_trips_et.schedule_trip_end

    from distinct_trips
    left join first_last_stop_id on distinct_trips.trip_id_performed = first_last_stop_id.trip_id_performed
    left join first_last_eventtime on distinct_trips.trip_id_performed = first_last_eventtime.trip_id_performed
    left join fct_sched_trips_et on --merge with gtfs on service date, trip id and route id
        distinct_trips.service_date = fct_sched_trips_et.service_date
        and distinct_trips.trip_id_scheduled = fct_sched_trips_et.trip_id
        and distinct_trips.route_id = fct_sched_trips_et.route_id
),

int_tides_trips_performed_bus_info as (
    select
        service_date,
        trip_id_performed,
        trip_id_scheduled,
        vehicle_id,
        route_type,
        ntd_mode,
        {{ flex_cast("null", "varchar") }} as route_type_agency,
        shape_id,
        pattern_id,
        route_id,
        direction_id,
        operator_id,
        block_id,
        trip_start_stop_id,
        trip_end_stop_id,
        schedule_trip_start,
        schedule_trip_end,
        actual_trip_start,
        actual_trip_end,
        trip_type, --only including in-service events
        case --if trip_id_schedule is available then the trip is scheduled
            when trip_id_scheduled is not null then 'Scheduled'
            else 'Added' --otherwise, a trip performed would be added temporarily
        end as schedule_relationship
    from final_join
)

select * from int_tides_trips_performed_bus_info