{% macro bounding_box_filter(center_lat, center_lon, target_lat, target_lon, radius_meters=300) %}
{#
    Generate SQL conditions to filter points within a rectangular bounding box.

    This is used as a performance optimization before calculating exact distances.
    A bounding box filter is much faster than calculating Haversine distance for
    every point, so we use it to narrow down candidates before the exact calculation.

    How it works:
        The radius_meters parameter defines the desired circular search area. This macro
        creates a rectangular bounding box that's guaranteed to contain that entire circle.
        The box will include some extra area at the corners (outside the circle), but that's
        acceptable since this is just a first-pass filter. A subsequent Haversine distance
        calculation will filter to the exact circular radius.

    Parameters:
        center_lat: Latitude of the center point (in degrees)
        center_lon: Longitude of the center point (in degrees)
        target_lat: Latitude to filter (in degrees)
        target_lon: Longitude to filter (in degrees)
        radius_meters: Desired circular search radius in meters (default: 300)
                      The bounding box will be sized to contain this entire circular area.

    Returns:
        SQL conditions for latitude and longitude bounding box

    Constants:
        METERS_PER_DEGREE_LAT: 111,320 meters per degree of latitude (constant globally)

    Note:
        Longitude conversion uses ~111,320 * cos(latitude) meters per degree (varies by latitude)
#}
{%- set METERS_PER_DEGREE_LAT = 111320.0 -%}
{{ target_lat }} between {{ center_lat }} - (CAST({{ radius_meters }} AS DOUBLE) / {{ METERS_PER_DEGREE_LAT }})
    and {{ center_lat }} + (CAST({{ radius_meters }} AS DOUBLE) / {{ METERS_PER_DEGREE_LAT }})
    and {{ target_lon }} between {{ center_lon }} - (CAST({{ radius_meters }} AS DOUBLE) / ({{ METERS_PER_DEGREE_LAT }} * cos(radians({{ center_lat }}))))
    and {{ center_lon }} + (CAST({{ radius_meters }} AS DOUBLE) / ({{ METERS_PER_DEGREE_LAT }} * cos(radians({{ center_lat }}))))
{% endmacro %}

