/*
This model aggregates rail station activity data into hourly time periods,
following the TIDES station_activities schema.

PHYSICAL ACTIVITY METRICS (from faregate sensors):
- total_entries
- total_exits

PAYMENT TRANSACTION METRICS (from fare payment systems FARE and vendor_2):
- entry_transactions:
- exit_transactions
- number_of_transactions

Primary key: {service_date, time_period_start, stop_id, time_period_end}
per TIDES specification.

Note: bike_entries, bike_exits, ramp_entries, and ramp_exits are included in the
schema but set to NULL as this data is not currently available from rail ridership data.

Time Period Categorization:
---------------------------
This model uses [AGENCY] operational time periods aligned with analytics team practices:
- Early Morning: 4:00 AM - 6:59 AM (service day start to pre-rush)
- AM Peak: 7:00 AM - 8:59 AM (advertised "AM Rush" period)
- Midday: 9:00 AM - 3:59 PM
- PM Peak: 4:00 PM - 5:59 PM (advertised "PM Rush" period)
- Evening: 6:00 PM - 9:29 PM
- Late Night: 9:30 PM - 3:59 AM (after fare reduction cutoff to service day end)
- Weekend: Saturday and Sunday, all hours

Note: [AGENCY]'s service day begins at 4:00 AM. The 9:30 PM cutoff reflects the
fare structure change to base fare only after this time.

Note that [AGENCY] eliminated peak/off-peak pricing effective June 26, 2023
(https://www.[AGENCY].com/about/news/June-2023-service-improvements.cfm) as part of the
FY2024 budget approval:
(https://www.[AGENCY].com/about/news/Metros-Board-Approves-48B-Budget-Simplifies-Fares-and-Increases-Frequency-of-Service-Redesign-of-Better-Bus-Network.cfm).  -- noqa: LT05

Prior to this change, [AGENCY] defined peak hours as weekdays 5:00 AM - 9:30 AM and
3:00 PM - 7:00 PM based on the [AGENCY] tariff structure and historical fare tables.

We maintain these historical time period categories for operational analysis and to
enable year-over-year comparisons of ridership patterns, even though [AGENCY]'s fare
structure changed to a single distance-based fare on weekdays before 9:30 PM.
*/

{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}

with station_events as (
    select *
    from {{ ref('fct_tides_station_activities_quality') }}
    where
        is_valid
),

-- define time period boundaries (hourly)
time_periods as (
    select
        service_date,
        stop_id,
        hour_of_day,
        -- create timestamp for the start of the hour
        -- using the date_add macro for Iceberg compatibility
        {{ date_add(
            flex_cast("service_date", "timestamp", safe=True),
            "hour_of_day", "hour", "second") }} as time_period_start,
        -- create timestamp for the end of the hour
        -- using the date_add macro for Iceberg compatibility
        {{ date_add(
            flex_cast("service_date", "timestamp", safe=True),
             "hour_of_day + 1", "hour", "second") }} as time_period_end,
        -- categorize time periods based on historical [AGENCY] peak/off-peak definitions
        -- TODO: Consider enhancing time period categorization with holiday handling:
        -- 1. Create a dimension table with federal holidays
        -- 2. Join to this table to flag holidays
        -- 3. Treat holidays like weekends in the categorization
        case
            when extract(dow from service_date) in (0, 6) then 'Weekend'
            when extract(dow from service_date) between 1 and 5
                then
                    case
                        when hour_of_day >= 4 and hour_of_day < 7 then 'Early Morning'
                        when hour_of_day >= 7 and hour_of_day < 9 then 'AM Peak'
                        when hour_of_day >= 9 and hour_of_day < 16 then 'Midday'
                        when hour_of_day >= 16 and hour_of_day < 18 then 'PM Peak'
                        when hour_of_day >= 18 and hour_of_day < 22 then 'Evening'
                        -- Late Night covers two parts: after 9:30 PM (hour 22-23) and before 4 AM (hour 0-3)
                        when hour_of_day >= 22 or hour_of_day < 4 then 'Late Night'
                        else 'Off-Peak'
                    end
            else 'Off-Peak'
        end as time_period_category
    from
        (select distinct
            service_date,
            stop_id,
            hour_of_day
        from station_events)
),

-- aggregate the events by time period
aggregated_events as (
    select
        station_events.service_date,
        station_events.stop_id,
        station_events.hour_of_day,
        sum(case when station_events.is_entry then 1 else 0 end) as total_entries,
        sum(case when station_events.is_exit then 1 else 0 end) as total_exits,
        sum(case when station_events.is_entry_transaction then 1 else 0 end) as entry_transactions,
        sum(case when station_events.is_exit_transaction then 1 else 0 end) as exit_transactions,
        sum(case when station_events.is_entry_transaction or station_events.is_exit_transaction then 1 else 0 end)
            as number_of_transactions
    from
        station_events
    group by
        station_events.service_date,
        station_events.stop_id,
        station_events.hour_of_day
),

fct_tides_station_activities as (
    select
        time_periods.service_date,
        time_periods.stop_id,
        time_periods.time_period_start,
        time_periods.time_period_end,
        time_periods.time_period_category,
        coalesce(aggregated_events.total_entries, 0) as total_entries,
        coalesce(aggregated_events.total_exits, 0) as total_exits,
        coalesce(aggregated_events.entry_transactions, 0) as entry_transactions,
        coalesce(aggregated_events.exit_transactions, 0) as exit_transactions,
        coalesce(aggregated_events.number_of_transactions, 0) as number_of_transactions,
        {{ flex_cast("null", "integer", safe=True) }} as bike_entries,
        {{ flex_cast("null", "integer", safe=True) }} as bike_exits,
        {{ flex_cast("null", "integer", safe=True) }} as ramp_entries,
        {{ flex_cast("null", "integer", safe=True) }} as ramp_exits
    from
        time_periods
    left join
        aggregated_events
        on
            time_periods.service_date = aggregated_events.service_date
            and time_periods.stop_id = aggregated_events.stop_id
            and time_periods.hour_of_day = aggregated_events.hour_of_day
    order by
        time_periods.service_date,
        time_periods.time_period_start,
        time_periods.stop_id,
        time_periods.time_period_end
)

select * from fct_tides_station_activities