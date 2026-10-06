/*
3.)Each page visited by a user is identified using an event called page_view. Explore the sample dataset and Identity average time spent on each page along with their pageviews.

*/


with page_view as (
     SELECT
		parse_date('%Y%m%d', event_date) AS event_date,
		user_pseudo_id,
		event_timestamp,
		(
			select value.int_value
			from unnest(event_params)
			where key = 'ga_session_id'
		) as ga_session_id
		
        (
            SELECT value.string_value
            FROM UNNEST(event_params)
            WHERE key = 'page_location'
        ) as page_location

    FROM
        `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

    WHERE
        event_name = 'page_view'
),
page_sequence AS (

    SELECT
        *,        
        -- get the next page viewed by the same user in the same session
        LEAD(event_timestamp) OVER (PARTITION BY user_pseudo_id, ga_session_id ORDER BY event_timestamp) AS next_page_timestamp

    FROM page_view
)

SELECT
    page_location,

    -- Number of times the page was viewed
    COUNT(*) AS pageviews,

    -- Average time spent on the page in seconds
    ROUND(
        AVG(
            SAFE_DIVIDE(
                next_page_timestamp - event_timestamp,
                1000000
            )
        ),
        2
    ) AS avg_time_spent_seconds,

    -- Average time spent in minutes
    ROUND(
        AVG(
            SAFE_DIVIDE(
                next_page_timestamp - event_timestamp,
                1000000
            )
        ) / 60,
        2
    ) AS avg_time_spent_minutes

FROM page_sequence

GROUP BY
    page_location

ORDER BY
    pageviews DESC;

