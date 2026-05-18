<!-- docs for GTFS fields other than feed_hash are generally abbreviated gtfs specification descriptions -->

{% docs field_gtfs__feed_hash %}
MD5 hash of the sorted source GTFS feed zip
{% enddocs %}

<!-- docs for intermediate fields used in multiple models derived from calendar and/or calendar_dates -->
{% docs field_gtfs__day_num %}
Integer representation of day of week for a service date, ranging from 1 to 7. Follows ISO 8601. Valid values are:

- `1` - Monday
- `2` - Tuesday
- `3` - Wednesday
- `4` - Thursday
- `5` - Friday
- `6` - Saturday
- `7` - Sunday

{% enddocs %}

{% docs field_gtfs__service_bool %}
Indicator used in calendar models flagging whether a service_id is activate on a particular date, based either on calendar and/or calendar_dates. Valid values are True/False.
{% enddocs %}

<!-- stg_gtfs_agency -->

{% docs field_gtfs_agency_id %}
Identifies a transit brand which is often synonymous with a transit agency. Note that in some cases, such as when a single agency operates multiple separate services, agencies and brands are distinct. This document uses the term "agency" in place of "brand". A dataset may contain data from multiple agencies. Conditionally Required: Required when the dataset contains data for multiple transit agencies. Recommended otherwise.
{% enddocs %}

{% docs field_gtfs_agency_name %}
Full name of the transit agency.
{% enddocs %}

{% docs field_gtfs_agency_url %}
URL of the transit agency.
{% enddocs %}

{% docs field_gtfs_agency_timezone %}
Timezone where the transit agency is located. If multiple agencies are specified in the dataset, each must have the same agency_timezone.
{% enddocs %}

{% docs field_gtfs_agency_lang %}
Primary language used by this transit agency. Should be provided to help GTFS consumers choose capitalization rules and other language-specific settings for the dataset.
{% enddocs %}

{% docs field_gtfs_agency_phone %}
A voice telephone number for the specified agency. This field is a string value that presents the telephone number as typical for the agency's service area. It may contain punctuation marks to group the digits of the number. Dialable text (for example, TriMet's "503-238-RIDE") is permitted, but the field must not contain any other descriptive text.
{% enddocs %}

{% docs field_gtfs_agency_fare_url %}
URL of a web page where a rider can purchase tickets or other fare instruments for that agency, or a web page containing information about that agency's fares.
{% enddocs %}

{% docs field_gtfs_agency_email %}
Email address actively monitored by the agency's customer service department. This email address should be a direct contact point where transit riders can reach a customer service representative at the agency.
{% enddocs %}

<!-- stg_gtfs_calendar_dates -->

{% docs field_gtfs_service_id %}
Identifies a set of dates when a service exception occurs for one or more routes. Each (service_id, date) pair may only appear once in calendar_dates.txt if using calendar.txt and calendar_dates.txt in conjunction. If a service_id value appears in both calendar.txt and calendar_dates.txt, the information in calendar_dates.txt modifies the service information specified in calendar.txt.
{% enddocs %}

{% docs field_gtfs_date %}
Date when service exception occurs.
{% enddocs %}

{% docs field_gtfs_exception_type %}
Indicates whether service is available on the date specified in the date field. Valid options are:

- `1` - Service has been added for the specified date.
- `2` - Service has been removed for the specified date.
{% enddocs %}

<!-- stg_gtfs_calendar -->

{% docs field_gtfs_monday %}
Indicates whether the service operates on all Mondays in the date range specified by the start_date and end_date fields. Note that exceptions for particular dates may be listed in calendar_dates.txt. Valid options are:

- `1` - Service is available for all Mondays in the date range.
- `0` - Service is not available for Mondays in the date range.
{% enddocs %}

{% docs field_gtfs_tuesday %}
Functions in the same way as `monday` except applies to Tuesdays
{% enddocs %}

{% docs field_gtfs_wednesday %}
Functions in the same way as `monday` except applies to Wednesdays
{% enddocs %}

{% docs field_gtfs_thursday %}
Functions in the same way as `monday` except applies to Thursdays
{% enddocs %}

{% docs field_gtfs_friday %}
Functions in the same way as `monday` except applies to Fridays
{% enddocs %}

{% docs field_gtfs_saturday %}
Functions in the same way as `monday` except applies to Saturdays
{% enddocs %}

{% docs field_gtfs_sunday %}
Functions in the same way as `monday` except applies to Sundays
{% enddocs %}

{% docs field_gtfs_start_date %}
Start service day for the service interval.
{% enddocs %}

{% docs field_gtfs_end_date %}
End service day for the service interval. This service day is included in the interval.
{% enddocs %}

<!-- stg_gtfs_routes -->

{% docs field_gtfs_route_id %}
Uniquely identifies a route within a GTFS version.
{% enddocs %}

{% docs field_gtfs_agency_id_routes %}
Agency for the specified route.
{% enddocs %}

{% docs field_gtfs_route_short_name %}
Short name of a route. Often a short, abstract identifier (e.g., "32", "100X", "Green") that riders use to identify a route.
{% enddocs %}

{% docs field_gtfs_route_long_name %}
Full name of a route. This name is generally more descriptive than the `route_short_name` and often includes the route's destination or stop.
{% enddocs %}

{% docs field_gtfs_route_desc %}
Description of a route that provides useful, quality information.
{% enddocs %}

{% docs field_gtfs_route_type %}
Indicates the type of transportation used on a route. Valid options are:

- `0` - Tram, Streetcar, Light rail. Any light rail or street level system within a metropolitan area.
- `1` - Subway, Metro. Any underground rail system within a metropolitan area.
- `2` - Rail. Used for intercity or long-distance travel.
- `3` - Bus. Used for short- and long-distance bus routes.
- `4` - Ferry. Used for short- and long-distance boat service.
- `5` - Cable tram. Used for street-level rail cars where the cable runs beneath the vehicle (e.g., cable car in San Francisco).
- `6` - Aerial lift, suspended cable car (e.g., gondola lift, aerial tramway). Cable transport where cabins, cars, gondolas or open chairs are suspended by means of one or more cables.
- `7` - Funicular. Any rail system designed for steep inclines.
- `11` - Trolleybus. Electric buses that draw power from overhead wires using poles.
- `12` - Monorail. Railway in which the track consists of a single rail or a beam.
{% enddocs %}

{% docs field_gtfs_route_url %}
URL of a web page about the particular route.
{% enddocs %}

{% docs field_gtfs_route_color %}
Route color designation that matches public facing material.
{% enddocs %}

{% docs field_gtfs_route_text_color %}
Legible color to use for text drawn against a background of route_color.
{% enddocs %}

{% docs field_gtfs_as_route %}
[AGENCY]-specific gtfs.routes field. Not currently imported.
{% enddocs %}

{% docs field_gtfs_network_id %}
Identifies a group of routes. Multiple rows in routes.txt may have the same network_id.
{% enddocs %}

<!-- stg_gtfs_stop_times -->

{% docs field_gtfs_trip_id %}
Identifies a trip within a feed version.
{% enddocs %}

{% docs field_gtfs_arrival_time %}
Arrival time at the stop (defined by stop_times.stop_id) for a specific trip (defined by stop_times.trip_id).
{% enddocs %}

{% docs field_gtfs_departure_time %}
Departure time from the stop (defined by stop_times.stop_id) for a specific trip (defined by stop_times.trip_id)
{% enddocs %}

{% docs field_gtfs_arrival_time_secs %}
Arrival time converted to total seconds from midnight. Handles GTFS 24+ hour format
(e.g., '26:30:00' becomes 95400 seconds). Calculated using the gtfs_time_string_to_seconds macro.
{% enddocs %}

{% docs field_gtfs_departure_time_secs %}
Departure time converted to total seconds from midnight. Handles GTFS 24+ hour format
(e.g., '26:30:00' becomes 95400 seconds). Calculated using the gtfs_time_string_to_seconds macro.
{% enddocs %}

{% docs field_gtfs_stop_id %}
Identifies the serviced stop.
{% enddocs %}

{% docs field_gtfs_stop_sequence %}
Order of stops, location groups, or GeoJSON locations for a particular trip. The values must increase along the trip but do not need to be consecutive.
{% enddocs %}

{% docs field_gtfs_stop_headsign %}
Text that appears on signage identifying the trip's destination to riders. T
{% enddocs %}

{% docs field_gtfs_pickup_type %}
Indicates pickup method. Valid options are:

- `0` or empty - Regularly scheduled pickup.
- `1` - No pickup available.
- `2` - Must phone agency to arrange pickup.
- `3` - Must coordinate with driver to arrange pickup.
{% enddocs %}

{% docs field_gtfs_drop_off_type %}
Indicates drop-off method. Valid options are:

- `0` or empty - Regularly scheduled pickup.
- `1` - No pickup available.
- `2` - Must phone agency to arrange pickup.
- `3` - Must coordinate with driver to arrange pickup.
{% enddocs %}

{% docs field_gtfs_shape_dist_traveled %}
Actual distance traveled along the associated shape, from the first stop to the stop specified in this record.
{% enddocs %}

{% docs field_gtfs_timepoint %}
Actual distance traveled along the associated shape, from the first stop to the stop specified in this record. This field specifies how much of the shape to draw between any two stops during a trip. Must be in the same units used in shapes.txt. Values used for shape_dist_traveled must increase along with stop_sequence; they must not be used to show reverse travel along a route.
{% enddocs %}

<!-- stg_gtfs_stops -->

{% docs field_gtfs_stop_code %}
Short text or a number that identifies the location for riders.
{% enddocs %}

{% docs field_gtfs_stop_name %}
Name of the location.
{% enddocs %}

{% docs field_gtfs_stop_desc %}
Description of the location that provides useful, quality information. Should not be a duplicate of stop_name.
{% enddocs %}

{% docs field_gtfs_stop_lat %}
Latitude of the location.
{% enddocs %}

{% docs field_gtfs_stop_lon %}
Longitude of the location.
{% enddocs %}

{% docs field_gtfs_zone_id %}
Identifies the fare zone for a stop.
{% enddocs %}

{% docs field_gtfs_stop_url %}
URL of a web page about the location.
{% enddocs %}

{% docs field_gtfs_location_type %}
Location type. Valid options are:

- `0` (or empty) - Stop (or Platform). A location where passengers board or disembark from a transit vehicle. Is called a platform when defined within a parent_station.
- `1` - Station. A physical structure or area that contains one or more platform.
- `2` - Entrance/Exit. A location where passengers can enter or exit a station from the street. If an entrance/exit belongs to multiple stations, it may be linked by pathways to both, but the data provider must pick one of them as parent.
- `3` - Generic Node. A location within a station, not matching any other location_type, that may be used to link together pathways define in pathways.txt.
- `4` - Boarding Area. A specific location on a platform, where passengers can board and/or alight vehicles.
{% enddocs %}

{% docs field_gtfs_parent_station %}
Defines hierarchy between the different locations defined in stops.

- Stop/platform (location_type=0): the parent_station field contains the ID of a station.
- Station (location_type=1): this field must be empty.
- Entrance/exit (location_type=2) or generic node (location_type=3): the parent_station field contains the ID of a station (location_type=1)
- Boarding Area (location_type=4): the parent_station field contains ID of a platform.
{% enddocs %}

{% docs field_gtfs_wheelchair_boarding %}
Indicates whether wheelchair boardings are possible from the location. Valid options are:

For parentless stops:

- `0` or empty - No accessibility information for the stop.
- `1` - Some vehicles at this stop can be boarded by a rider in a wheelchair.
- `2` - Wheelchair boarding is not possible at this stop.
{% enddocs %}

{% docs field_gtfs_stop_timezone %}
Timezone of the location.
{% enddocs %}

{% docs field_gtfs_level_id %}
Level of the location. The same level may be used by multiple unlinked stations.
{% enddocs %}

{% docs field_gtfs_platform_code %}
Platform identifier for a platform stop (a stop belonging to a station). This should be just the platform identifier (eg. "G" or "3").
{% enddocs %}

<!-- stg_gtfs_trips -->

{% docs field_gtfs_trip_headsign %}
Text that appears on signage identifying the trip's destination to riders.
{% enddocs %}

{% docs field_gtfs_direction_id %}
Indicates the direction of travel for a trip. This field should not be used in routing; it provides a way to separate trips by direction when publishing time tables. Valid options are:

- `0` - Travel in one direction (e.g. outbound travel).
- `1` - Travel in the opposite direction (e.g. inbound travel).
{% enddocs %}

{% docs field_gtfs_block_id %}
Identifies the block to which the trip belongs. A block consists of a single trip or many sequential trips made using the same vehicle, defined by shared service days and block_id.
{% enddocs %}

{% docs field_gtfs_shape_id %}
Identifies a geospatial shape describing the vehicle travel path for a trip.
{% enddocs %}

{% docs field_gtfs_scheduled_trip_id %}
[AGENCY]-specific field. Not currently imported.
{% enddocs %}

{% docs field_gtfs_train_id %}
Metrorail specific field. Not currently imported.
{% enddocs %}

<!-- feed_info -->
{% docs field_gtfs_feed_publisher_name %}
Full name of the organization that publishes the dataset.
{% enddocs %}

{% docs field_gtfs_feed_publisher_url %}
URL of the dataset publishing organization's website.
{% enddocs %}

{% docs field_gtfs_feed_lang %}
Default language used for the text in this dataset.
{% enddocs %}

{% docs field_gtfs_feed_start_date %}
The dataset provides complete and reliable schedule information for service in the period from the beginning of the feed_start_date day to the end of the feed_end_date day.
{% enddocs %}

{% docs field_gtfs_feed_end_date %}
The dataset provides complete and reliable schedule information for service in the period from the beginning of the feed_start_date day to the end of the feed_end_date day.
{% enddocs %}

{% docs field_gtfs_feed_version %}
String that indicates the current version of their GTFS dataset. Not guaranteed to be unique between feed versions.
{% enddocs %}

{% docs field_gtfs_feed_contact_email %}
Email address for communication regarding the GTFS dataset and data publishing practices.
{% enddocs %}

{% docs field_gtfs_feed_contact_url %}
URL for contact information, a web-form, support desk, or other tools for communication regarding the GTFS dataset and data publishing practices.
{% enddocs %}

<!-- shapes -->

{% docs field_gtfs_shape_pt_lat %}
Latitude of a shape point. Each record in shapes.txt represents a shape point used to define the shape.
{% enddocs %}

{% docs field_gtfs_shape_pt_lon %}
Longitude of a shape point. Each record in shapes.txt represents a shape point used to define the shape.
{% enddocs %}

{% docs field_gtfs_shape_pt_sequence %}
Sequence in which the shape points connect to form the shape. Values must increase along the trip but do not need to be consecutive.
{% enddocs %}

<!-- feed_meta -->

{% docs field_gtfs_source %}
Source of the GTFS feed. Typically a URL.
{% enddocs %}

{% docs field_gtfs_date_retrieved %}
Timestamp of feed retrieval from source such as API endpoint.
{% enddocs %}

<!-- dim_schedule_feeds specific fields -->

{% docs field_gtfs_feed_type %}
Feed type derived from the source URL. Maps [AGENCY] GTFS feed URLs to descriptive feed types:

- Combined ([rail-bus-gtfs-static.zip](https://api.[AGENCY].com/gtfs/rail-bus-gtfs-static.zip))
- Rail ([rail-gtfs-static.zip](https://api.[AGENCY].com/gtfs/rail-gtfs-static.zip))
- Bus ([bus-gtfs-static.zip](https://api.[AGENCY].com/gtfs/bus-gtfs-static.zip))
{% enddocs %}

{% docs field_gtfs_valid_from %}
Start date when this feed becomes valid. Calculated as the later of:

- feed_start_date (from feed_info.txt)
- date_retrieved (when the feed was retrieved from the API)
{% enddocs %}

{% docs field_gtfs_valid_to %}
End date when this feed becomes invalid. Calculated as the earliest of:

- Next feed retrieval date for the same feed type
- feed_end_date (explicit end date from feed_info.txt)
- One year from date_retrieved (default expiry period)
{% enddocs %}

<!-- dim_dates specific fields -->

{% docs field_dim_dates_service_date %}
The calendar date, truncated to day precision. Primary key for the date dimension.
Used as the service date for transit operations.
{% enddocs %}

{% docs field_dim_dates_year_of_date %}
Year extracted from the service date (e.g., 2024).
{% enddocs %}

{% docs field_dim_dates_month_of_year %}
Month number extracted from the service date (1-12).
{% enddocs %}

{% docs field_dim_dates_day_of_month %}
Day of month extracted from the service date (1-31).
{% enddocs %}

{% docs field_dim_dates_day_of_year %}
Day of year extracted from the service date (1-366).
{% enddocs %}

{% docs field_dim_dates_day_of_week %}
Full day name extracted from the service date using cross-database compatible formatting.
Values: Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday.
Uses date_format() for Trino and strftime() for other databases.
{% enddocs %}

{% docs field_dim_dates_weekday_weekend %}
Classification of the service date as either 'Weekday' or 'Weekend'.
{% enddocs %}

<!-- fct_daily_schedule_feeds specific fields -->

{% docs field_daily_schedule_feeds_service_date %}
The service date for which the GTFS feed is applicable for the given mode.
{% enddocs %}

{% docs field_gtfs_feed_mode %}
Transit mode for the feed, derived from the feed type. Combined feeds are expanded into separate Bus and Rail modes:

- Bus: Bus transit services (from Bus or Combined feeds)
- Rail: Rail transit services (from Rail or Combined feeds)

{% enddocs %}

<!-- int_gtfs_calendar_long specific fields -->

{% docs field_has_service %}
Boolean indicator for whether a service_id has service for a service_date.
{% enddocs %}

<!-- Additional GTFS key used in several models -->

{% docs field_key_feed_service_id_date %}
Unique identifier for a long calendar record, generated by hashing service_date,_feed_hash, and service_id.
{% enddocs %}

<!-- fct_scheduled_trips and fct_scheduled_stop_times specific fields -->

{% docs field_key_feed_service_date_trip_id %}
Unique identifier for a scheduled trip id on a date, generated by hashing _feed_hash, service_date and trip_id.
{% enddocs %}

{% docs field_gtfs_trip_mode %}
Transit mode classification derived from route_type. Valid values are:

- `Rail` - For route_type = 1 (Subway, Metro)
- `Bus` - For route_type = 3 (Bus)
- `Unhandled` - For all other route_type values; in theory doesn't appear and should be an error.
{% enddocs %}

{% docs field_key_feed_service_date_trip_id_stop_seq_stop %}
Unique identifier for a scheduled stop time on a date, generated by hashing feed_hash, service_date, trip_id, stop_id, and stop_sequence.
{% enddocs %}

{% docs field_gtfs_pattern_id %}
An identifier for a trip pattern on a given route. The pattern_id is generally the route_id and a pattern-level identifier without a colon, such as 3201. Stops may be repeated within a pattern stop sequence, such as on a loop.
{% enddocs %}

{% docs field_gtfs_route_pattern %}
Unique key for route-patterns within a given GTFS version.
{% enddocs %}

{% docs field_gtfs_pattern_stop %}
Unique key for a pattern-stop_id-stop_sequence combination within a given GTFS version.
{% enddocs %}

{% docs field_gtfs_route_pattern_trip %}
Unique key for a route-pattern-trip combination within a given GTFS version.
{% enddocs %}

{% docs field_gtfs_first_scheduled_arrival_time %}
Timestamp (in America/New_York time zone) of first scheduled stop arrival for this trip.
(From stop_times.arrival_time, applied to this service date, for the stop with first stop_sequence value on the trip.)
{% enddocs %}

{% docs field_gtfs_first_scheduled_departure_time %}
Timestamp (in America/New_York time zone) of first scheduled stop departure for this trip.
(From stop_times.departure_time, applied to this service date, for the stop with first stop_sequence value on the trip.)
{% enddocs %}

{% docs field_gtfs_last_scheduled_arrival_time %}
Timestamp (in America/New_York time zone) of last scheduled stop arrival for this trip.
(From stop_times.arrival_time, applied to this service date, for the stop with last stop_sequence value on the trip.)
{% enddocs %}

{% docs field_gtfs_last_scheduled_departure_time %}
Timestamp (in America/New_York time zone) of last scheduled stop departure for this trip.
(From stop_times.departure_time, applied to this service date, for the stop with last stop_sequence value on the trip.)
{% enddocs %}

<!-- fields calculated in int_gtfs_stop_times_grouped_trip_summary -->

{% docs field_gtfs_num_distinct_stops_serviced %}
Count of distinct stop_id values for this trip in GTFS stop_times.
An individual stop (stop_id) may be visited more than once in a given trip, so this may be less than the number of rows (stop events) for the trip.
{% enddocs %}

{% docs field_gtfs_num_scheduled_stops %}
Count of rows for this trip in GTFS stop_times.
An individual stop (stop_id) may be visited more than once in a given trip, so this may be greater than the number of distinct stop_id values for the trip.
{% enddocs %}

{% docs field_gtfs_first_scheduled_stop_id %}
The stop_id for the first stop on this trip (trip with the lowest stop_sequence value.)
{% enddocs %}

{% docs field_gtfs_last_scheduled_stop_id %}
The stop_id for the last stop on this trip (trip with the greatest stop_sequence value.)
{% enddocs %}

{% docs field_gtfs_has_rider_service %}
Boolean indicator for whether this trip has at least one stop event with pickup_type != 1, meaning that at least one stop has revenue service.
{% enddocs %}

{% docs field_gtfs_first_scheduled_arrival_time_secs %}
Scheduled arrival time in seconds (after 12 hours before noon) for the first stop on this trip
{% enddocs %}

{% docs field_gtfs_first_scheduled_departure_time_secs %}
Scheduled departure time in seconds (after 12 hours before noon) for the first stop on this trip
{% enddocs %}

{% docs field_gtfs_last_scheduled_arrival_time_secs %}
Scheduled arrival time in seconds (after 12 hours before noon) for the first stop on this trip
{% enddocs %}

{% docs field_gtfs_last_scheduled_departure_time_secs %}
Scheduled departure time in seconds (after 12 hours before noon) for the first stop on this trip
{% enddocs %}