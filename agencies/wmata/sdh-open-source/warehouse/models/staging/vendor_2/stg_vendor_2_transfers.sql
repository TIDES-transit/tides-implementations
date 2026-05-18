with source as (
    select *
    from {{ source('vendor_2', 'transfers') }}

),

stg_vendor_2_transfers as (
    select
        transfer_id,
        from_service_name,
        to_service_name,
        from_trip_id,
        to_trip_id,
        journey_id,
        participant_id,
        record_updated_timestamp_utc,
        channel,
        infile_name
    from source
)

select * from stg_vendor_2_transfers