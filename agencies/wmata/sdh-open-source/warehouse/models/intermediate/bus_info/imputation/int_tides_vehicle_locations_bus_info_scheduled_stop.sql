{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='service_date',
    batch_size='day',
    lookback=var('microbatch_lookback_days'),
    begin=var('incremental_begin_date'),
) }}

-- We're joining scheduled stop sequence to the intermediate vehicle locations model.
-- The trick is that simply joining on trip and stop won't work, as some loop routes will be visited twice.
-- Also can't join on bus info's scheduled stop sequence; while it does seem to increment correctly when a stop
-- is scheduled to be visited twice, it has different sequence numbers than GTFS.
-- So, we join on trip, stop, and the increment of how many times a stop has been visited on a trip (such that
-- on loop routes, we can make sure that the first stop visit gets a scheduled stop sequence of '1' and the
-- last stop visit gets a scheduled sequence of n, whichever that is.). Due to other complications with our bus info
-- source data, we make other accommodations here as well.
--
-- The distinct-businfo ranking and GTFS join are computed in int_tides_vehicle_locations_scheduled_stop_mapped
-- to reduce window function stages in this model.

with int_vl as (
    select
        location_ping_id,
        service_date,
        trip_id_scheduled,
        trip_id_performed_imputed,
        trip_stop_sequence,
        trip_stop_sequence_imputed,
        stop_id,
        event_timestamp,
        schedule_relationship
    from
        -- yes, this is the imputed one; we want to use the trip_id_performed_imputed to try to address
        -- some challenges around how many times we 'see' a stop on a performed trip.
        {{ ref("int_tides_vehicle_locations_imputation") }}
    where
        -- 1. without this, we can't join to GTFS anyhow.
        trip_id_scheduled is not null
        -- 2. there are some non-revenue services with trip_id, but they won't join to GTFS
        and trip_type = 'In service'
        -- 3. need to have stop_id as well. a few of the '0' records don't have this
        and stop_id is not null
),

stop_seq_mapped as (
    select *
    from {{ ref("int_tides_vehicle_locations_scheduled_stop_mapped") }}
),

rejoined_sequences as (
    select
        -- we brought in the scheduled stop sequences on a distinct-ified (one record per stop visit),
        -- subset (no 0s or -1s) of the int_tides_vehicle_locations view. Now, we need to bring these sequences
        -- back to the more complete dataset with location_ping_ids so we're ready to join back to the quality
        -- model.
        int_vl.location_ping_id,
        stop_seq_mapped.scheduled_stop_sequence_imputed,
        -- used for some filling, partitioning, and debug later
        int_vl.stop_id,
        int_vl.service_date,
        int_vl.trip_id_performed_imputed,
        int_vl.trip_stop_sequence_imputed,
        int_vl.trip_stop_sequence,
        int_vl.event_timestamp,
        int_vl.schedule_relationship
    from
        int_vl
    left join
        stop_seq_mapped
        on
            int_vl.service_date = stop_seq_mapped.service_date
            and int_vl.trip_id_performed_imputed = stop_seq_mapped.trip_id_performed_imputed
            and int_vl.trip_stop_sequence_imputed = stop_seq_mapped.trip_stop_sequence_imputed
            -- in theory not necessary, but a little bit of proofing in case sequences are not quite in right shape
            and int_vl.stop_id = stop_seq_mapped.stop_id
),

filled_rejoined as (
-- if there are stray cases we don't populate (this can be the case for '0' stop sequences, possibly others)
-- we pull from other observations of that stop_id, filling down, then up. Mostly, the '0' stop sequences
-- don't have stop_ids though so we can't impute a sequence.
-- Would rather just remove 0 stop sequences or apply some upstream corrections so we don't have this logic at all.
-- There is a monotonicity check in the singular tests to catch some of this.

    select
        location_ping_id,
        stop_id,
        service_date,
        trip_id_performed_imputed,
        trip_stop_sequence_imputed,
        trip_stop_sequence,
        event_timestamp,
        schedule_relationship,
        coalesce(
        -- fill down
            {{ last_value_ignore_nulls('scheduled_stop_sequence_imputed') }} over (
                partition by trip_id_performed_imputed, stop_id
                -- in theory the imputed stop sequence could be used; this likely to be slightly safer though
                -- and now that we've rejoined to the full dataset, it's available.
                order by event_timestamp
                rows between unbounded preceding and current row
            ),
            -- fill up
            {{ first_value_ignore_nulls('scheduled_stop_sequence_imputed') }} over (
                partition by trip_id_performed_imputed, stop_id
                order by event_timestamp
                rows between current row and unbounded following
            )
        ) as scheduled_stop_sequence_imputed
    from
        rejoined_sequences
),

int_tides_vehicle_locations_bus_info_scheduled_stop as (
    select
        location_ping_id,
        scheduled_stop_sequence_imputed,
        -- used for some testing and debug later, but not strictly necessary
        service_date,
        trip_id_performed_imputed,
        trip_stop_sequence_imputed,
        trip_stop_sequence,
        stop_id,
        schedule_relationship,
        event_timestamp
    from filled_rejoined
)

select * from int_tides_vehicle_locations_bus_info_scheduled_stop