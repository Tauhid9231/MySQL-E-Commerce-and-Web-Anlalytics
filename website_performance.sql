/********************************** MAVEN E-COMMERCE & WEB ANALYTICS: TRAFFIC SOURCE ANALYSIS *******************************/

-- In the this section, we'll be analysing the utm_parameters and session-to-order conversion rate to identify the
-- most effective and efficient marketign channels. 
-- The goal is to achieve maximum session volume without over-spending on ads.
-- Thus, this analysis will help identify opportunities to eliminate wasted spend and scale high-converting traffic


#### 1 ######################################################################################################################
-- Most viewed web-pages ranked by session volume

SELECT 
    wp.pageview_url AS web_pages,
    COUNT(DISTINCT wp.website_session_id) AS num_sessions
FROM
    website_pageviews wp
WHERE
    wp.created_at < '2012-06-09'
GROUP BY 1
ORDER BY 2 DESC;

		-- > /home, /products, and /the-original-mr-fuzzy are the top 3 viewed web pages 


#### 2 ######################################################################################################################
-- Most viewed entry-pages (url) ranked by session volume

CREATE TEMPORARY TABLE first_pageviews	-- contains first pageview for each session
SELECT
	wp.website_session_id,
    MIN(wp.website_pageview_id) AS first_pv_id
FROM website_pageviews wp
WHERE wp.created_at < '2012-06-12'
GROUP BY wp.website_session_id;

-- Return the first pageview_url(s) along with the sessions_hitting_that_url
SELECT
	wp.pageview_url AS entry_pages,
	COUNT(DISTINCT fp.website_session_id) AS entry_volume
FROM
	first_pageviews fp
	LEFT JOIN website_pageviews wp ON fp.first_pv_id = wp.website_pageview_id
GROUP BY 1
ORDER BY 2 DESC;

		-- > All traffic lands only on the '/home' page first.
		-- > We should analyze landing page performance (for the homepage specifically)
		-- > and think about whether or not the homepage is the best initial experience for all customers.


#### 3 ######################################################################################################################
-- Bounce Rates for traffic landing on the home-page

-- Step 1: Finding first_pv_ids for each relevant session
DROP TEMPORARY TABLE IF EXISTS first_pageviews;
CREATE TEMPORARY TABLE first_pageviews
SELECT
    ws.website_session_id,
    MIN(wp.website_pageview_id) AS first_pv_id
FROM
    website_sessions ws
    LEFT JOIN website_pageviews wp ON ws.website_session_id = wp.website_session_id
WHERE
	ws.created_at < '2012-06-14'
GROUP BY
	1;

-- Step 2: Identifying sessions with landing pages by linking to urls
CREATE TEMPORARY TABLE sessions_w_home_lp
SELECT
	fp.website_session_id,
    wp.pageview_url AS landing_pgs
FROM
	first_pageviews fp
    LEFT JOIN website_pageviews wp ON fp.first_pv_id = wp.website_pageview_id
WHERE
	wp.pageview_url = '/home';
    
-- Step 3: Counting pageviews for each session to identify bounced_sessions
CREATE TEMPORARY TABLE bounced_sessions_only
SELECT
	sl.website_session_id,
    sl.landing_pgs,
    COUNT(wp.website_pageview_id) AS num_pgs_viewed
FROM
	sessions_w_home_lp sl
	LEFT JOIN website_pageviews wp ON sl.website_session_id = wp.website_session_id
GROUP BY
	1, 2
HAVING
	num_pgs_viewed = 1; -- limiting to bounced sessions only


-- Step 4: Summarizing Results
SELECT
    COUNT(DISTINCT sl.website_session_id) AS total_sessions,
    COUNT(DISTINCT bs.website_session_id) AS bounced_sessions,
    COUNT(DISTINCT bs.website_session_id)/COUNT(DISTINCT sl.website_session_id) AS bounce_rate
FROM
	sessions_w_home_lp sl
    LEFT JOIN bounced_sessions_only bs ON sl.website_session_id = bs.website_session_id;
    
		-- > 60% bounce rate is pretty high for paid traffic, thus we'll conduct experiment 
		-- with a custom landing page to see if we can improve results. 


#### 4 ######################################################################################################################
-- A/B Landing Page Test Results for '/lander-1' against '/home' for 'gsearch-nonbrand' only from the timeframe of implementation of 'lander-1'

DROP TEMPORARY TABLE IF EXISTS first_test_pageviews;
DROP TEMPORARY TABLE IF EXISTS test_sessions_with_lp;
DROP TEMPORARY TABLE IF EXISTS test_bounced_sessions;

-- Step 0: Finding the first instance of /lander-1 to set analysis timeframe
SELECT
	MIN(created_at) AS first_time_lander1_appeared, -- 2012-06-19 00:35:54
    MIN(website_pageview_id) AS firs_pv_id 			-- 23504
FROM
	website_pageviews wp
WHERE
	pageview_url = '/lander-1' AND created_at IS NOT NULL;

-- Step 1: Finding the first_pv_ids for each relevant sessions
CREATE TEMPORARY TABLE first_test_pageviews
SELECT
    ws.website_session_id,
    MIN(wp.website_pageview_id) AS first_pv_id
FROM
    website_sessions ws
    LEFT JOIN website_pageviews wp ON ws.website_session_id = wp.website_session_id
WHERE
    ws.created_at < '2014-07-28'
    AND wp.website_pageview_id > (
        SELECT
            MIN(wp.website_pageview_id)		-- This subquery yields 23504 as the result,
        FROM
            website_pageviews wp			-- which is the first_pv_id when '/lander-1'
        WHERE
            wp.pageview_url = '/lander-1'	-- appeared for the first time and this first_pv_id
            AND wp.created_at IS NOT NULL
    ) 										-- is used to set up the correct analysis timeframe.
    AND ws.utm_source = 'gsearch'
    AND ws.utm_campaign = 'nonbrand'
GROUP BY
    1;

-- Step 2: Identifying the landing_page_urls by linking first_pv_ids for each session
CREATE TEMPORARY TABLE test_sessions_with_lp
SELECT
	fp.website_session_id,
    wp.pageview_url AS landing_pgs
FROM
	first_test_pageviews fp
    LEFT JOIN website_pageviews wp
	ON fp.first_pv_id = wp.website_pageview_id
WHERE
	wp.pageview_url IN ('/home','/lander-1');
    
-- Step 3: Counting pageviews for each session to identify bounced_sessions
CREATE TEMPORARY TABLE test_bounced_sessions
SELECT
	sl.website_session_id,
	sl.landing_pgs,
    COUNT(wp.website_pageview_id) AS num_pgs_viewed
FROM
	test_sessions_with_lp sl
    LEFT JOIN website_pageviews wp
    ON sl.website_session_id = wp.website_session_id
GROUP BY
	1, 2
HAVING 
	num_pgs_viewed = 1; -- limiting to just "bounced" sessions

-- Step 4: Summarizing Results
SELECT
	sl.landing_pgs,
	COUNT(DISTINCT sl.website_session_id) as total_sessions,
    COUNT(DISTINCT bs.website_session_id) as bounced_sessions,
    COUNT(DISTINCT bs.website_session_id) / COUNT(DISTINCT sl.website_session_id) AS bounce_rates
FROM
	test_sessions_with_lp sl
    LEFT JOIN test_bounced_sessions bs
    ON sl.website_session_id = bs.website_session_id
GROUP BY
	1;
    
		-- > The new ‘/lander-1’ has around 6% lesser bounce rate than the '/home' lander, 
		-- > and thus can be considered an option for the gsearch-nonbrand paid traffic campaign.


#### 5 ######################################################################################################################
--  Landing Page Trend Analysis (between2012-06-01 to 2012-08-31)

DROP TEMPORARY TABLE IF EXISTS sessions_w_fp_and_npv;
DROP TEMPORARY TABLE IF EXISTS sessions_w_lp_and_ca;

-- # Step 1: Get first_pv_ids and num_pgs_viewed for each relevant session
CREATE TEMPORARY TABLE sessions_w_fp_and_npv
SELECT
	ws.website_session_id,
    MIN(wp.website_pageview_id) AS first_pv_id,
    COUNT(wp.website_pageview_id) AS num_pgs_viewed
FROM
	website_sessions ws
LEFT JOIN
	website_pageviews wp ON ws.website_session_id = wp.website_session_id
WHERE
	ws.created_at BETWEEN '2012-06-01' AND '2012-08-31'
    AND ws.utm_source = 'gsearch'
    AND ws.utm_campaign = 'nonbrand'
GROUP BY
	1; -- 11624 rows

-- # Step 2: Identifying landing pages
-- for each session on each date in the timeframe
CREATE TEMPORARY TABLE sessions_w_lp_and_ca
SELECT
	wp.created_at,
    fp.website_session_id,
    wp.pageview_url
FROM
	sessions_w_fp_and_npv fp
LEFT JOIN
	website_pageviews wp
    ON fp.first_pv_id = wp.website_pageview_id;
SELECT * FROM sessions_w_lp_and_ca;

-- # Step 3: Summarizing results grouped by wk_of_yr to show weekly trend  
SELECT
    WEEK(sl.created_at) AS wk_of_yr,
    MIN(DATE(sl.created_at)) AS st_of_wk,
    COUNT(DISTINCT CASE WHEN sl.pageview_url = '/home' THEN fp.website_session_id ELSE NULL END) AS home_sessions,
    COUNT(DISTINCT CASE WHEN sl.pageview_url = '/lander-1' THEN fp.website_session_id ELSE NULL END) AS lander_1_sessions,
    -- COUNT(DISTINCT fp.website_session_id) AS total_sessions,
    -- COUNT(DISTINCT CASE WHEN fp.num_pgs_viewed = 1 THEN fp.website_session_id ELSE NULL END) AS bounced_sessions,
    ROUND( COUNT(DISTINCT CASE WHEN fp.num_pgs_viewed = 1 THEN fp.website_session_id ELSE NULL END) /
		COUNT(DISTINCT fp.website_session_id) * 100, 2 )AS overall_bounce_rate_pct
FROM
	sessions_w_fp_and_npv fp
LEFT JOIN
	sessions_w_lp_and_ca sl ON fp.website_session_id = sl.website_session_id
GROUP BY
	1
ORDER BY
	1 DESC;

		-- > The implementation of custom '/lander' was a success, as all traffic is routed to the new lander succesfully
		-- > and the overall bounce rate has improved over time by around 7%.

 
#### 6 ######################################################################################################################
/* ANALYZING CONVERSION FUNNELS BETWEEN '2012-08-05' AND '2012-09-05'
Where we lose our 'gsearch - nonbrand' visitors from /lander-1 to /thank-you?
How many customers make through each step along with the click_through_rates (ctr)? */ 

-- # Step 1: Identifying relevant sessions and bringing in relevant pv_ids
CREATE TEMPORARY TABLE session_level_flags
SELECT
    website_session_id,
    MAX(products_pg) AS made_to_products, 	-- When we use GROUP BY we need  
    MAX(fuzzy_pg) AS made_to_fuzzy, 		-- to use aggregate functions in our select statement 
    MAX(cart_pg) AS made_to_cart,		  	-- for any columns not named in the GROUP BY.
    MAX(shipping_pg) AS made_to_shipping, 	-- That’s why we are using MAX()
    MAX(billing_pg) AS made_to_billing,
    MAX(thank_you_pg) AS made_to_thank_you
FROM
    (
        SELECT
            ws.website_session_id,
            wp.created_at AS pv_created_at,
            wp.pageview_url,
            CASE WHEN wp.pageview_url = '/products' THEN 1 ELSE 0 END AS products_pg,
            CASE WHEN wp.pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS fuzzy_pg,
            CASE WHEN wp.pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_pg,
            CASE WHEN wp.pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_pg,
            CASE WHEN wp.pageview_url = '/billing' THEN 1 ELSE 0 END AS billing_pg,
            CASE WHEN wp.pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thank_you_pg
        FROM
            website_sessions ws
            LEFT JOIN website_pageviews wp ON ws.website_session_id = wp.website_session_id
        WHERE
            ws.utm_source = 'gsearch'
            AND ws.utm_campaign = 'nonbrand'
            AND wp.created_at BETWEEN '2012-08-05' AND '2012-09-05'
        ORDER BY
            1,
            2
    ) AS pageview_level
GROUP BY
    1;

-- Step 2: Finding the session_counts to a particular page
SELECT
    COUNT(DISTINCT website_session_id) AS total_sessions,
    COUNT( CASE WHEN made_to_products = 1 THEN website_session_id ELSE NULL END ) AS lander1_to_products,
    COUNT( CASE WHEN made_to_fuzzy = 1 THEN website_session_id ELSE NULL END ) AS products_to_fuzzy,
    COUNT( CASE WHEN made_to_cart = 1 THEN website_session_id ELSE NULL END ) AS fuzzy_to_cart,
    COUNT( CASE WHEN made_to_shipping = 1 THEN website_session_id ELSE NULL END ) AS cart_to_shipping,
    COUNT( CASE WHEN made_to_billing = 1 THEN website_session_id ELSE NULL END ) AS shipping_to_billing,
    COUNT( CASE WHEN made_to_thank_you = 1 THEN website_session_id ELSE NULL END ) AS billing_to_thank_you
FROM
    session_level_flags;


-- Step 3: Finding CTRs between each step in the conversion funnel
SELECT
	COUNT(DISTINCT website_session_id) AS total_sessions,
    ROUND( COUNT(CASE WHEN made_to_products = 1 THEN website_session_id ELSE NULL END) /
				COUNT(DISTINCT website_session_id) * 100, 2 ) AS lander1_ctr,
	ROUND( COUNT(CASE WHEN made_to_fuzzy = 1 THEN website_session_id ELSE NULL END) /
				COUNT(CASE WHEN made_to_products = 1 THEN website_session_id ELSE NULL END) * 100, 2 ) AS lander1_to_products_ctr,
	ROUND( COUNT(CASE WHEN made_to_cart= 1 THEN website_session_id ELSE NULL END) /
				COUNT(CASE WHEN made_to_fuzzy = 1 THEN website_session_id ELSE NULL END) * 100, 2 ) AS products_to_fuzzy_ctr,
    ROUND( COUNT(CASE WHEN made_to_shipping = 1 THEN website_session_id ELSE NULL END) /
				COUNT(CASE WHEN made_to_cart= 1 THEN website_session_id ELSE NULL END) * 100, 2 ) AS fuzzy_to_cart_ctr,
    ROUND( COUNT(CASE WHEN made_to_billing = 1 THEN website_session_id ELSE NULL END) /
				COUNT(CASE WHEN made_to_shipping = 1 THEN website_session_id ELSE NULL END) * 100, 2 ) AS cart_to_shipping_ctr,
    ROUND( COUNT(CASE WHEN made_to_thank_you = 1 THEN website_session_id ELSE NULL END) /
				COUNT(CASE WHEN made_to_billing = 1 THEN website_session_id ELSE NULL END) * 100, 2 ) AS shipping_to_billing_ctr
FROM
	session_level_flags;
    
		-- > We should focus on improving the performance of the new /lander-1, /the-original-mr-fuzzy, 
		-- > and the /billing pages which have the lowest click-through rates.

#### 7 ######################################################################################################################
-- Conversion Funnel Test Results: billing-2 vs billing till '2012-11-10'
SELECT
	wp.pageview_url,
    COUNT(DISTINCT wp.website_session_id) AS sessions,
    COUNT(DISTINCT o.order_id) AS orders,
    COUNT(DISTINCT o.order_id) /
		COUNT(DISTINCT wp.website_session_id) to_order_pct
FROM
	website_pageviews wp
	LEFT JOIN orders o ON wp.website_session_id = o.website_session_id
WHERE
	wp.created_at < '2012-11-10'
    AND wp.pageview_url IN ('/billing', '/billing-2')
    AND wp.website_pageview_id > (
		SELECT MIN(website_pageview_id) -- first time 'b2' was seen
        FROM website_pageviews
        WHERE pageview_url = '/billing-2'
	) -- output = 53550
GROUP BY
	1
;
    
		-- > The new version of billing page ‘/billing-2’ is definitely a success as the billing-to-order rate 
		-- > is improved by more than 17%, and thus, the engineering team should rollout this new version for entire traffic.
