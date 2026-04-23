with int_gtfs_calendar_dates as (select * from {{ ref('stg_gtfs_calendar_dates') }})

select
    {{ dbt_utils.generate_surrogate_key(['_feed_hash', 'service_id', 'date']) }} as _key,
    _feed_hash,
    service_id,
    exception_type,
    date as service_date,
    -- in int_gtfs_calendar_long, we add these fields. We use these in int_gtfs_daily_services. Could
    -- move some of these calcs to that model, but felt cleaner to include here for parallelism with
    -- int_gtfs_calendar_long. Both feel like slight restatements of existing fields, so not worthy
    -- of new models. Need to preface both with underscores, as they're not in spec?
    case
        when exception_type = 1 then true --service added
        when exception_type = 2 then false --service removed
    end as has_service
from
    int_gtfs_calendar_dates
