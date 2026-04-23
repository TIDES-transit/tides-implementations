{% macro haversine_distance_meters(lat1, lon1, lat2, lon2) %}
{#
    Calculate the great-circle distance between two points on Earth using the Haversine formula.

    Parameters:
        lat1: Latitude of first point (in degrees)
        lon1: Longitude of first point (in degrees)
        lat2: Latitude of second point (in degrees)
        lon2: Longitude of second point (in degrees)

    Returns:
        Distance in meters

    Formula:
        a = sin²(Δφ/2) + cos(φ1) * cos(φ2) * sin²(Δλ/2)
        c = 2 * atan2(√a, √(1−a))
        d = R * c

    Where:
        φ is latitude, λ is longitude, R is earth's radius
        Δφ is the difference in latitude
        Δλ is the difference in longitude

    Constants:
        EARTH_RADIUS_METERS: 6,371,000 meters (mean radius of Earth)
#}
{%- set EARTH_RADIUS_METERS = 6371000 -%}
    2 * {{ EARTH_RADIUS_METERS }} * asin(
        sqrt(
            pow(sin((radians({{ lat2 }}) - radians({{ lat1 }})) / 2), 2)
            + cos(radians({{ lat1 }})) * cos(radians({{ lat2 }}))
            * pow(sin((radians({{ lon2 }}) - radians({{ lon1 }})) / 2), 2)
        )
    )
{% endmacro %}
