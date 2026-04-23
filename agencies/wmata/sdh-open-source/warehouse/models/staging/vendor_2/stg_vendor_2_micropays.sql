with source as (
    select *
    from {{ source('vendor_2', 'micropays') }}

),

stg_vendor_2_micropays as (
    select
        customer_id,
        funding_source_id,
        participant_id,
        aggregation_id,
        channel,
        charge_amount,
        charge_type,
        currency_code,
        infile_name,
        micropayment_id,
        nominal_amount,
        payment_liability,
        record_updated_timestamp_utc,
        status as lp_status,
        type as lp_type
    from source
)

select * from stg_vendor_2_micropays