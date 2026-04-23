with source as (
    select *
    from {{ source('vendor_2', 'dev_txns') }}

),

stg_vendor_2_dev_txns as (
    select
        customer_id,
        funding_source_id,
        participant_id,
        channel,
        device_id,
        device_id_issuer,
        device_transaction_id,
        direction,
        granted_zone_ids,
        infile_name,
        latitude,
        vendor_2_transaction_id,
        location_id,
        location_name,
        longitude,
        onward_zone_ids,
        processed_timestamp_utc,
        record_updated_timestamp_utc,
        route_id,
        themode,
        transaction_outcome,
        transaction_timestamp_utc,
        trip_attributes,
        type as lp_type,
        vehicle_id,
        zone_id
    from source
)

select * from stg_vendor_2_dev_txns