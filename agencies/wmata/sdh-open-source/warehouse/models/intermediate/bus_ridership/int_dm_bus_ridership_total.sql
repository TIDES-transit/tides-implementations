{{ config(materialized='view') }}

with fare_rs as (  -- noqa: PRS
    select
        service_date,
        entdateint,
        period_key,
        facid,
        fare_instrument_id,
        route_number,
        negative_ride_id,
        card_class_id,
        control_date,
        entry_cnt,
        transfer_cnt,
        cash_ride_cnt,
        entry_amt,
        transfer_amt,
        cash_ride_amt,
        load_amt,
        incomplete_ride_cash,
        incomplete_nonride_cash,
        ent_sv_transaction,
        ent_alp_value_used,
        tfr_sv_transaction,
        tfr_alp_value_used,
        mfg_id,
        'FARE' as source
    from {{ source('fare', 'bus_ridership_fare') }}
),

lp_rs as (
    select
        service_date,
        entdateint,
        period_key,
        facid,
        fare_instrument_id,
        route_number,
        negative_ride_id,
        card_class_id,
        control_date,
        entry_cnt,
        transfer_cnt,
        cash_ride_cnt,
        entry_amt,
        transfer_amt,
        cash_ride_amt,
        load_amt,
        incomplete_ride_cash,
        incomplete_nonride_cash,
        ent_sv_transaction,
        ent_alp_value_used,
        tfr_sv_transaction,
        tfr_alp_value_used,
        mfg_id,
        'LP' as source
    from {{ source('lp', 'bus_ridership_lp') }}
),

full_rs as (
    select *
    from fare_rs
    union all
    select *
    from lp_rs
)

select * from full_rs