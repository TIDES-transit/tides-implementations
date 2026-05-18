{% docs field_trip_ridership_boardings %}
Total number of boardings for a trip. Sum of boarding_1 and boarding_2 across all stops in the trip.
{% enddocs %}

{% docs field_trip_ridership_alightings %}
Total number of alightings for a trip. Sum of alighting_1 and alighting_2 across all stops in the trip.
{% enddocs %}

{% docs field_trip_ridership_max_trip_stop_sequence %}
Maximum observed `trip_stop_sequence` value for the performed trip.  
Represents how many stops were actually recorded for the trip.
{% enddocs %}

{% docs field_trip_ridership_max_scheduled_stop_sequence %}
Maximum `scheduled_stop_sequence` for the scheduled pattern associated with the trip.  
Represents the expected total number of scheduled stops.
{% enddocs %}

{% docs field_trip_ridership_first_stop_load_warning %}
Boolean value showing whether the first stop of the trip had a non-zero load.  
A non-zero load at the first stop is typically unexpected and may represent a data quality issue.
{% enddocs %}

{% docs field_trip_ridership_last_stop_load_warning %}
Boolean value showing whether the last stop of the trip had a non-zero load.  
A non-zero load at the final stop may indicate incomplete alighting records or a partial trip.
{% enddocs %}

{% docs field_trip_ridership_negative_load %}
Boolean value identifying trips with at least one stop where `departure_load` is negative.  
This is a critical data quality error.
{% enddocs %}

{% docs field_trip_ridership_count_negative_load %}
Number of stops within the trip where `departure_load` is negative.
{% enddocs %}

{% docs field_trip_ridership_load_mismatch %}
Boolean value showing whether the trip contains at least one stop where  
`departure_load != cumulative_boardings - cumulative_alightings`.
{% enddocs %}

{% docs field_trip_ridership_count_load_mismatch %}
Number of stops on the trip where the departure load does not equal  
cumulative boardings minus cumulative alightings.
{% enddocs %}

{% docs field_trip_ridership_on_off_ratio %}
Ratio of total boardings to total alightings on the trip.  
Calculated as `boardings / alightings`, using a fallback denominator of 1 when alightings = 0.
{% enddocs %}

{% docs field_trip_ridership_proportion_stops_served %}
Proportion of scheduled stops served on a trip, calculated as  
`max_trip_stop_sequence / max_scheduled_stop_sequence`.  
Values below 1 indicate incomplete or early-terminated trips.
{% enddocs %}
