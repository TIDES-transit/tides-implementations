{% docs field_vehicle_locations_location_ping_id %}
An identifier that uniquely identifies an incoming row from a source system. Same as row_id.
This is not a semantically meaningful primary key; it should be used for basic data integrity checks.
{% enddocs %}

{% docs field_vehicle_locations_service_date %}
Service date. References GTFS indirectly via calendars.txt and calendar_dates.txt.
{% enddocs %}

{% docs field_vehicle_locations_event_timestamp %}
Timestamp at which the location ping was recorded.
{% enddocs %}

{% docs field_vehicle_locations_trip_id_performed %}
Identifies the trip that was actually performed.
{% enddocs %}

{% docs field_vehicle_locations_trip_id_scheduled %}
Identifies the originally scheduled trip, if different from the trip performed. References GTFS.
{% enddocs %}

{% docs field_vehicle_locations_trip_stop_sequence %}
Sequence of the stop visited along the trip, based on vehicle reporting, not GTFS stop_times.txt.
{% enddocs %}

{% docs field_vehicle_locations_scheduled_stop_sequence %}
Scheduled stop sequence according to GTFS stop_times.txt, if known.
{% enddocs %}

{% docs field_vehicle_locations_vehicle_id %}
Identifies the vehicle reporting the location.
{% enddocs %}

{% docs field_vehicle_locations_device_id %}
Identifier for the device (e.g., onboard AVL unit) reporting the location.
{% enddocs %}

{% docs field_vehicle_locations_pattern_id %}
Identifies the unique stop-path for a trip, possibly distinct from GTFS shapes.shape_id.
{% enddocs %}

{% docs field_vehicle_locations_stop_id %}
Identifies the GTFS stop ID the vehicle location is associated with. May be matched via a spatial join if not reported directly by the vehicle.
{% enddocs %}

{% docs field_vehicle_locations_current_status %}
Describes the current status of the vehicle based on reported event type. Example values include STOPPED_AT, INCOMING_AT, OFF_ROUTE, or various audio triggers.
{% enddocs %}

{% docs field_vehicle_locations_latitude %}
Latitude of the reported vehicle location in decimal degrees (WGS84).
{% enddocs %}

{% docs field_vehicle_locations_longitude %}
Longitude of the reported vehicle location in decimal degrees (WGS84).
{% enddocs %}

{% docs field_vehicle_locations_gps_quality %}
Quality indicator of the GPS signal at the time of the ping, if available.
{% enddocs %}

{% docs field_vehicle_locations_heading %}
Bearing or compass direction of the vehicle in degrees.
{% enddocs %}

{% docs field_vehicle_locations_speed %}
Speed of the vehicle at the time of the ping, in meters per second.
{% enddocs %}

{% docs field_vehicle_locations_odometer %}
Cumulative odometer reading of the vehicle in meters, if reported.
{% enddocs %}

{% docs field_vehicle_locations_schedule_deviation %}
Schedule deviation in seconds, calculated as actual time minus scheduled time, if available.
{% enddocs %}

{% docs field_vehicle_locations_headway_deviation %}
Difference in seconds between actual headway and scheduled headway.
{% enddocs %}

{% docs field_vehicle_locations_trip_type %}
Indicates whether the trip is revenue service, deadhead, or another classification based on trip context or routing.
{% enddocs %}

{% docs field_vehicle_locations_schedule_relationship %}
Describes how the ping aligns with scheduled service. Example: SCHEDULED, UNSCHEDULED, ADDED, CANCELED.
{% enddocs %}

<!-- imputed values -->

{% docs field_vehicle_location_scheduled_stop_sequence_imputed %}
Stop sequence from GTFS schedule data, imputed by matching with bus info data.
{% enddocs %}

{% docs field_vehicle_locations_has_imputed_stop_id%}
Boolean to denote if stop_id updated from GTFS schedule data by matching with bus info data. Only imputing for records where schedule_relationship is skipped or scheduled.
{% enddocs %}

{% docs field_vehicle_locations_stop_id_imputed%}
Stop id imputed from GFTS schedule data. If no stop id imputed then stop id from stops dimension table. Only imputing for records where schedule_relationship is skipped or scheduled.
{% enddocs %}

{% docs field_vehicle_locations_route_id %}
GTFS route id for the trip. References GTFS routes.
{% enddocs %}

{% docs field_vehicle_locations_trip_start_time %}
The scheduled or actual start time of the trip that the vehicle is performing.
{% enddocs %}

{% docs field_vehicle_locations_trip_end_time %}
The scheduled or actual end time of the trip that the vehicle is performing.
{% enddocs %}

{% docs field_vehicle_locations_is_stop_visit %}
Boolean flag indicating whether this location ping represents an actual stop visit (first instance of each stop for revenue service).
{% enddocs %}

{% docs field_vehicle_locations_apcon %}
Automatic Passenger Counter (APC) boarding count for passengers getting on the vehicle at this stop visit. Only populated for confirmed stop visits.
{% enddocs %}

{% docs field_vehicle_locations_apcoff %}
Automatic Passenger Counter (APC) alighting count for passengers getting off the vehicle at this stop visit. Only populated for confirmed stop visits.
{% enddocs %}