/*
5.)I want to understand what is the percent change in the number of visits on any given day with respect to the previous 7 day’s average. Write a query to identify this.
*/

WITH daily_visits AS (

  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,

    COUNT(DISTINCT STRUCT(
      user_pseudo_id,
      (
        SELECT value.int_value
        FROM UNNEST(event_params)
        WHERE key = 'ga_session_id'
        LIMIT 1
      )
    )) AS visits

  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

  WHERE _TABLE_SUFFIX BETWEEN '20210101' AND '20210131'

  GROUP BY event_date
),

visits_with_avg AS (

  SELECT
    event_date,
    visits,

    AVG(visits) OVER (
      ORDER BY event_date
      ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING
    ) AS previous_7_day_avg

  FROM daily_visits
)

SELECT
  event_date,
  visits,
  ROUND(previous_7_day_avg, 2) AS previous_7_day_avg,

  ROUND(
    SAFE_DIVIDE(
      visits - previous_7_day_avg,
      previous_7_day_avg
    ) * 100,
    2
  ) AS percent_change

FROM visits_with_avg

WHERE previous_7_day_avg IS NOT NULL

ORDER BY event_date;
