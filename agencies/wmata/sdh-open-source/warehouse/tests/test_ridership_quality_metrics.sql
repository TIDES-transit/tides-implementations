{{ config(severity='warn') }}

select *
from {{ ref('metric_trip_ridership') }}
where
    --has_negative_load
    --or has_load_mismatch
    --or has_first_stop_load_not_zero
    --or has_last_stop_load_not_zero
    (on_off_ratio < 0.5 or on_off_ratio > 1.5) and (abs(boardings - alightings) > 20)
