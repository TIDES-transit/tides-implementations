{% docs field_station_activities_service_date %}
Service date for the station activity.
{% enddocs %}

{% docs field_station_activities_stop_id %}
Identifier for the rail station.
{% enddocs %}

{% docs field_station_activities_time_period_start %}
Start time of the aggregation period (hourly).
{% enddocs %}

{% docs field_station_activities_time_period_end %}
End time of the aggregation period (hourly).
{% enddocs %}

{% docs field_station_activities_time_period_category %}
Category of time period. Valid values are 'AM Peak' (6:00 AM – 9:59 AM; hours 6–9), 'PM Peak' (3:00 PM – 6:59 PM; hours 15–18), and 'Off-peak' (all other hours).
{% enddocs %}

{% docs field_station_activities_total_entries %}
Total number of people who physically entered the station during the time period, based on faregate sensor data only (faregate_data_ORGN source system).
{% enddocs %}

{% docs field_station_activities_total_exits %}
Total number of people who physically exited the station during the time period, based on faregate sensor data only (faregate_data_ORGN source system).
{% enddocs %}

{% docs field_station_activities_entry_transactions %}
Number of entry transactions during the time period from FARE (SmarTrip) and vendor_2 (open payment) systems. This counts fare transactions with fare_action values of 'Enter' or 'Transfer entrance'.

Note: This is a [AGENCY]-specific extension to the TIDES specification that could be proposed for inclusion in future TIDES updates. It provides a more granular view of fare transaction activity separate from passenger movements, which is valuable for financial reconciliation and operational analysis.

This extension aligns with [AGENCY]'s broader TIDES modification proposal for fare gate events, which includes distinguishing between passenger movements and fare transactions through the proposed 'linked_transaction_id' field. Separating entry transactions from general entries provides clarity in stations where fare gates operate in both "free mode" and normal fare collection mode.
{% enddocs %}

{% docs field_station_activities_exit_transactions %}
Number of exit transactions during the time period from FARE (SmarTrip) and vendor_2 (open payment) systems. This counts fare transactions with fare_action values of 'Exit' or 'Transfer exit'.

Note: This is a [AGENCY]-specific extension to the TIDES specification that could be proposed for inclusion in future TIDES updates. It provides a more granular view of fare transaction activity separate from passenger movements, which is valuable for financial reconciliation and operational analysis.

While many transit agencies don't record exit transactions, including this field in the TIDES specification would be valuable for agencies with distance-based fare systems or those monitoring station congestion patterns. This extension complements [AGENCY]'s fare gate events proposal, which aims to better represent the relationship between passenger movements and fare activities.
{% enddocs %}

{% docs field_station_activities_number_of_transactions %}
Total number of fare transactions at the station during the time period from FARE (SmarTrip) and vendor_2 (open payment) systems. This is the sum of entry_transactions and exit_transactions.
{% enddocs %}

{% docs field_station_activities_bike_entries %}
Number of bike entries at the station. Currently NULL as this data is not available.
{% enddocs %}

{% docs field_station_activities_bike_exits %}
Number of bike exits at the station. Currently NULL as this data is not available.
{% enddocs %}

{% docs field_station_activities_ramp_entries %}
Number of entries using ramps. Currently NULL as this data is not available.
{% enddocs %}

{% docs field_station_activities_ramp_exits %}
Number of exits using ramps. Currently NULL as this data is not available.
{% enddocs %}

{% docs field_station_activities_event_timestamp %}
Timestamp when the event occurred.
{% enddocs %}

{% docs field_station_activities_event_type %}
Type of event (entry, exit, or other transaction).
{% enddocs %}

{% docs field_station_activities_rider_category %}
Category of rider (Adult, Senior, etc.).
{% enddocs %}

{% docs field_station_activities_fare_product %}
Type of fare product used (Stored value, Pass, etc.).
{% enddocs %}

{% docs field_station_activities_token_id %}
Identifier for the fare media token used.
{% enddocs %}

{% docs field_station_activities_hour_of_day %}
Hour of day (0-23) when the event occurred.
{% enddocs %}

{% docs field_station_activities_is_entry %}
Flag indicating if the event is an entry to the station.
{% enddocs %}

{% docs field_station_activities_is_exit %}
Flag indicating if the event is an exit from the station.
{% enddocs %}

{% docs field_station_activities_is_entry_transaction %}
Flag indicating if the event is a successful entry fare payment transaction from FARE (SmarTrip) or vendor_2 (open payment) systems. Set to true when fare_action in ('Enter', 'Transfer entrance').
{% enddocs %}

{% docs field_station_activities_is_exit_transaction %}
Flag indicating if the event is a successful exit fare payment transaction from FARE (SmarTrip) or vendor_2 (open payment) systems. Set to true when fare_action in ('Exit', 'Transfer exit').
{% enddocs %}

{% docs field_station_activities_source_system %}
Source system for the event data.
{% enddocs %}

{% docs field_station_activities_total_activity %}
Total number of physical movements at the station (total_entries + total_exits). Derived field introduced at the metric layer.
{% enddocs %}