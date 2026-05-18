{% docs field_hourly_stop_ridership_calendar_date %}
Calendar date derived from actual_arrival_time, truncated to day level.
{% enddocs %}

{% docs field_hourly_stop_ridership_hour_of_calendar_date %}
Hour of the calendar date (0-23) extracted from actual_arrival_time when the stop visit occurred.
{% enddocs %}

{% docs field_hourly_stop_ridership_boardings %}
Total number of boardings at this stop during this hour. Sum of boarding_1 and boarding_2.
{% enddocs %}

{% docs field_hourly_stop_ridership_alightings %}
Total number of alightings at this stop during this hour. Sum of alighting_1 and alighting_2.
{% enddocs %}

{% docs field_hourly_stop_ridership_total_activity %}
Total ridership activity at this stop during this hour. Sum of boardings and alightings.
{% enddocs %}
