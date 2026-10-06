/*
2.)Find out the number of users day on day who added at least one product to cart but did not make any purchase during the same day. 
(Add to cart is identified by event_name = ‘add_to_cart’ and purchase is identified by event_name = ‘purchase’)
*/

WITH user_activity as(
	
	SELECT
	  parse_date('%Y%m%d' ,event_date) as event_date,
	  user_pseudo_id,
	  
	  max(case
			when event_name = 'add_to_cart' then 1
			else 0
		  end
		  ) as added_to_cart,
	  max(case
			when event_name = 'purchase' then 1
			else 0
		  end
		  ) as purchased
	from `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
	group by 
	event_date,
	user_pseudo_id
)
SELECT
  event_date,
  COUNT(*) AS users_added_to_cart_no_purchase

FROM user_activity

WHERE added_to_cart = 1
  AND purchased = 0

GROUP BY event_date
ORDER BY event_date;
