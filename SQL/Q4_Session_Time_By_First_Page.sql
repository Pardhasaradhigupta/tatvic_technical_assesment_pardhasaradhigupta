/*
4.)I want to understand how much time users are spending on the website during each of their visits. Please identify average time spent in sessions against the first page visited during their visit.
*/
WITH base_events AS (

  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    user_pseudo_id,
    event_timestamp,
    event_name,

    (
      SELECT value.int_value
      FROM UNNEST(event_params)
      WHERE key = 'ga_session_id'
      LIMIT 1
    ) AS session_id,

    (
      SELECT value.string_value
      FROM UNNEST(event_params)
      WHERE key = 'page_location'
      LIMIT 1
    ) AS page_location

  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

  WHERE _TABLE_SUFFIX BETWEEN '20210101' AND '20210131'
),

session_details AS (

  SELECT
    user_pseudo_id,
    session_id,

    MIN(event_timestamp) AS session_start,
    MAX(event_timestamp) AS session_end

  FROM base_events

  WHERE session_id IS NOT NULL

  GROUP BY
    user_pseudo_id,
    session_id
),

first_page AS (

  SELECT
    user_pseudo_id,
    session_id,
    page_location AS first_page

  FROM base_events

  WHERE event_name = 'page_view'
    AND session_id IS NOT NULL
    AND page_location IS NOT NULL

  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY user_pseudo_id, session_id
    ORDER BY event_timestamp
  ) = 1
)

SELECT
  f.first_page,

  COUNT(*) AS total_sessions,

  ROUND(
    AVG(
      SAFE_DIVIDE(
        s.session_end - s.session_start,
        1000000
      )
    ),
    2
  ) AS avg_session_time_seconds

FROM session_details s

INNER JOIN first_page f
  ON s.user_pseudo_id = f.user_pseudo_id
 AND s.session_id = f.session_id

GROUP BY f.first_page

ORDER BY total_sessions DESC;
