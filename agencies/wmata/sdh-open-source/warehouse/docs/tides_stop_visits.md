{% docs field_stop_visits_service_date %}
Service date. References GTFS indirectly via calendars.txt and calendar_dates.txt
{% enddocs %}

{% docs field_stop_visits_trip_id_performed %}
Identifies the trip performed
{% enddocs %}

{% docs field_stop_visits_trip_stop_sequence %}
The actual order of stops visited within a performed trip. The values must start at 1 and must be consecutive along the trip. Example: A bus departs the first stop and detours around the second and third scheduled stops, visiting one unscheduled stop and resuming regular service at the 4th scheduled stop. The scheduled_stop_sequence is [1, null, 4], and the trip_stop_sequence is [1, 2, 3].
{% enddocs %}

{% docs field_stop_visits_scheduled_stop_sequence %}
Scheduled order of stops for a particular trip. The values must increase along the trip but do not need to be consecutive. References GTFS
{% enddocs %}

{% docs field_stop_visits_pattern_id %}
Identifies the unique stop-path for a trip, may be distinct from GTFS shapes.shape_id
{% enddocs %}

{% docs field_stop_visits_vehicle_id %}
Identifies the vehicle.
{% enddocs %}

{% docs field_stop_visits_dwell %}
Indicates the amount of time a vehicle spent stopped at a stop in seconds.
{% enddocs %}

{% docs field_stop_visits_stop_id %}
Identifies the stop. References GTFS
{% enddocs %}

{% docs field_stop_visits_timepoint %}
Indicates if the stop should be used for evaluating schedule adherence, on-time performance, and other KPIs. This could be populated to match the GTFS “timepoint” field.
{% enddocs %}

{% docs field_stop_visits_schedule_arrival_time %}
Scheduled timestamp at which the vehicle arrives at a stop. References GTFS
{% enddocs %}

{% docs field_stop_visits_schedule_departure_time %}
Scheduled timestamp at which the vehicle departs from a stop. References GTFS
{% enddocs %}

{% docs field_stop_visits_actual_arrival_time %}
Timestamp at which the vehicle arrives at a stop.
{% enddocs %}

{% docs field_stop_visits_actual_departure_time %}
Timestamp at which the vehicle departs from a stop.
{% enddocs %}

{% docs field_stop_visits_distance %}
Observed distance in meters from the previous stop traveled by the vehicle.
{% enddocs %}

{% docs field_stop_visits_boarding_1 %}
Number of riders who entered through the vehicle’s front doors (in vehicles with doors opening on only one side, or when passengers primarily board through the front, as is typical with buses) or the vehicle’s right doors (in vehicles with doors on both sides, or when passengers board through all doors, as is typical with trains).
{% enddocs %}

{% docs field_stop_visits_alighting_1 %}
Number of riders who exited through the vehicle’s front doors (in vehicles with doors opening on only one side, or when passengers primarily board through the front, as is typical with buses) or the vehicle’s right doors (in vehicles with doors on both sides, or when passengers board through all doors, as is typical with trains).
{% enddocs %}

{% docs field_stop_visits_boarding_2 %}
Number of riders who entered through other doors, such as a bus’s rear door when boarding_1 captures the front door, or a train’s left doors when boarding_1 captures right doors.
{% enddocs %}

{% docs field_stop_visits_alighting_2 %}
Number of riders who exited through other doors, such as a bus’s rear door when alighting_1 captures the front door, or a train’s left doors when alighting_1 captures right doors.
{% enddocs %}

{% docs field_stop_visits_departure_load %}
Number of riders on the vehicle when departing the stop.
{% enddocs %}

{% docs field_stop_visits_door_open %}
Timestamp at which the doors opened.
{% enddocs %}

{% docs field_stop_visits_door_close %}
Timestamp at which the doors closed.
{% enddocs %}

{% docs field_stop_visits_door_status %}
Indicates actions of the doors during the stop visit.
{% enddocs %}

{% docs field_stop_visits_ramp_deployed_time %}
Duration of time a ramp is deployed, in seconds.
{% enddocs %}

{% docs field_stop_visits_ramp_failure %}
Indicates if the ramp deployment failed at a stop.
{% enddocs %}

{% docs field_stop_visits_kneel_deployed_time %}
Duration of time a kneel is deployed in seconds.
{% enddocs %}

{% docs field_stop_visits_lift_deployed_time %}
Duration of time in seconds of time a lift is deployed.
{% enddocs %}

{% docs field_stop_visits_bike_rack_deployed %}
Indicates if the bike rack was deployed at a stop.
{% enddocs %}

{% docs field_stop_visits_bike_load %}
Number of bikes on the vehicle when departing the stop.
{% enddocs %}

{% docs field_stop_visits_revenue %}
Amount of revenue collected at the stop.
{% enddocs %}

{% docs field_stop_visits_number_of_transactions %}
Number of fare transactions that occurred at a stop.
{% enddocs %}

{% docs field_stop_visits_schedule_relationship %}
Indicates the status of the stop.
{% enddocs %}

{% docs field_stop_visits_custom_ramp_deployed_count %}
Custom field with count of ramp deployments at a stop.
{% enddocs %}

{% docs field_stop_visits_dwell_imputed %}
Indicates the amount of time a vehicle spent stopped at a stop in seconds. Dwell is calculated as departure time minus arrival time.
{% enddocs %}

{% docs field_stop_visits_grouped_row %}
A boolean that indicates if row is an aggregate of other upstream rows.
{% enddocs %}
