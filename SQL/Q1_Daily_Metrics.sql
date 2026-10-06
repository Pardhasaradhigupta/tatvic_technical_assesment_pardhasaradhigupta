/*1.)Write a query to find day on day data for metrics listed here - 
total users, mobile users, desktop users, total sessions, mobile sessions, desktop sessions, total events, mobile events, desktop events.
*/
-- Solution for Question 1
select 
    -- total_users

   count (DISTINCT user_pseudo_id) as total_users,

   --mobile_users
   
   count ( DISTINCT 
        If(device_category = 'mobile', user_pseudo_id, NULL)
		) As mobile_users,

	--desktop_users
   count(DISTINCT If(device_category ='desktop',user_pseudo_id,null)
		) As desktop_users,

	--total_sessions
    count(DISTINCT
		  case 
			when ga_session_id is NOT NULL
			THEN CONCAT(
				user_pseudo_id,
				'_',
				CAST(ga_session_id as string)
				)
		end
		) as total_sessions,
	--mobile_sessions
	count(DISTINCT
		  case 
			when device_category='mobile' and ga_session_id is NOT NULL
			THEN CONCAT(
				user_pseudo_id,
				'_',
				CAST(ga_session_id as string)
				)
		end
		) as mobile_sessions,
	--mobile_sessions
	count(DISTINCT
		  case 
			when device_category='desktop' and ga_session_id is NOT NULL
			THEN CONCAT(
				user_pseudo_id,
				'_',
				CAST(ga_session_id as string)
				)
		end
		) as desktop_sessions,
	--total_events

	count(*) as total_events,
	--mobile_events
	countif(device_category='mobile') as mobile_events,
	--desktop_events
	countif(device_category ='desktop') as desktop_events,
	parse_date('%Y%m%d',event_date) as event_date
	
from 
	(SELECT
		user_pseudo_id,
		device.category as device_category,
		(
		  SELECT
		  value.int_value
			from unnest(event_params)
			where key = 'ga_session_id'
		) as ga_session_id,

    event_date
	from
	   `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
)
group by event_date
order by event_date;
