{% docs field_trips_performed_service_date %}
Service date. References GTFS
{% enddocs %}

{% docs field_trips_performed_trip_id_performed %}
Uniquely identifies the trip performed. It must be unique for a service_date (and it can optionally be unique across all time). It does not have to equal trip_id_scheduled.
{% enddocs %}

{% docs field_trips_performed_vehicle_id %}
Identifies the vehicle.
{% enddocs %}

{% docs field_trips_performed_trip_id_scheduled %}
Identifies the scheduled trip associated with the trip performed. One scheduled trip may be associated with multiple operated trips, or an operated trip may not be associated with a scheduled trip. References GTFS. If this trip was published in GTFS Schedule, this value should be consistent with the GTFS trip_id. If this trip was not scheduled, the value should be Null.
{% enddocs %}

{% docs field_trips_performed_route_id %}
Identifies the route. References GTFS
{% enddocs %}

{% docs field_trips_performed_route_type %}
Indicates the type of transportation used on a route. References GTFS routes.route_type including Google’s Extended Route Types GTFS extension
{% enddocs %}

{% docs field_trips_performed_ntd_mode %}
NTD mode, references the Modes and Types of Service section of the Introduction to the [NTD Full Reporting Policy Manual](https://www.transit.dot.gov/ntd/manuals)
{% enddocs %}

{% docs field_trips_performed_route_type_agency %}
Agency specific route type
{% enddocs %}

{% docs field_trips_performed_shape_id %}
Identifies a geospatial shape that describes the vehicle travel path for a trip. References GTFS
{% enddocs %}

{% docs field_trips_performed_pattern_id %}
Identifies the unique stop-path for a trip, may be distinct from GTFS shapes.shape_id
{% enddocs %}

{% docs field_trips_performed_direction_id %}
Indicates the direction of travel for a trip. References GTFS
{% enddocs %}

{% docs field_trips_performed_operator_id %}
Identifies the vehicle’s operator.
{% enddocs %}

{% docs field_trips_performed_block_id %}
Identifies the block to which the trip belongs. A block consists of a single trip, or many sequential trips made using the same vehicle, defined by shared service days and block_id. A block_id can have trips with different service days, making distinct blocks. See example in GTFS documentation. References GTFS
{% enddocs %}

{% docs field_trips_performed_trip_start_stop_id %}
Origin stop_id. References GTFS
{% enddocs %}

{% docs field_trips_performed_trip_end_stop_id %}
Destination stop_id. References GTFS
{% enddocs %}

{% docs field_trips_performed_schedule_trip_start %}
Scheduled departure time from the trip’s origin.
{% enddocs %}

{% docs field_trips_performed_schedule_trip_end %}
Scheduled end timestamp at the trip’s destination.
{% enddocs %}

{% docs field_trips_performed_actual_trip_start %}
Timestamp at which the vehicle departed its origin.
{% enddocs %}

{% docs field_trips_performed_actual_trip_end %}
Timestamp at which the vehicle arrived at its destination.
{% enddocs %}

{% docs field_trips_performed_trip_type %}
Indicates status of travel with regard to service.
{% enddocs %}

{% docs field_trips_performed_schedule_relationship %}
Indicates the status of the trip. References GTFS-realtime TripUpdate.trip.schedule_relationship
{% enddocs %}
