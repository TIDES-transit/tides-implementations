with source as (
    select *
    from {{ source('vendor_2', 'settlements') }}

),

stg_vendor_2_settlements as (
    select
        customer_id,
        funding_source_id,
        participant_id,
        acquirer_code,
        acquirer_response_rrn,
        aggregation_id,
        amount,
        channel,
        currency_code,
        external_reference_number,
        infile_name,
        vendor_2_reference_number,
        record_updated_timestamp_utc,
        refund_id,
        request_created_timestamp_utc,
        response_created_timestamp_utc,
        retrieval_reference_number,
        settlement_id,
        settlement_status,
        settlement_type,
        transaction_timestamp_utc
    from source
)

select * from stg_vendor_2_settlements