-- Test for multiple stop sequence values assigned to the same stop within a trip
-- This identifies cases where the same stop_id_imputed has multiple different trip_stop_sequence_imputed values

{{ config(severity='warn') }}

with test_data as (
    select
        service_date,
        trip_id_performed_imputed,
        stop_id_imputed,
        trip_stop_sequence,
        trip_stop_sequence_imputed
    from {{ ref('int_tides_vehicle_locations_imputation') }}
    where stop_id_imputed is not null
),

multiple_sequence_stops as (
    select
        service_date,
        trip_id_performed_imputed,
        stop_id_imputed
    from test_data
    group by
        service_date,
        trip_id_performed_imputed,
        stop_id_imputed
    having count(distinct trip_stop_sequence_imputed) > 1
),

test_stop_sequence_multiple_values_per_stop as (
    select
        test_data.service_date,
        test_data.trip_id_performed_imputed,
        test_data.stop_id_imputed,
        {{ agg_array_to_string(
            flex_cast("test_data.trip_stop_sequence", "varchar", safe=True),
            separator=",",
            use_distinct=True
        ) }} as trip_stop_sequence_cat,
        {{ agg_array_to_string(
            flex_cast("test_data.trip_stop_sequence_imputed", "varchar", safe=True),
            separator=",",
            use_distinct=True
        ) }} as trip_stop_sequence_imputed_cat,
        count(*) as record_count
    from test_data
    inner join multiple_sequence_stops
        on
            test_data.service_date = multiple_sequence_stops.service_date
            and test_data.trip_id_performed_imputed = multiple_sequence_stops.trip_id_performed_imputed
            and test_data.stop_id_imputed = multiple_sequence_stops.stop_id_imputed
    group by
        test_data.service_date,
        test_data.trip_id_performed_imputed,
        test_data.stop_id_imputed
)

select * from test_stop_sequence_multiple_values_per_stop
