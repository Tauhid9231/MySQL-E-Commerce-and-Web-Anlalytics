/********************************** MAVEN E-COMMERCE & WEB ANALYTICS: TRAFFIC SOURCE ANALYSIS *******************************/

-- In the very first section, we'll be analysing the utm_parameters and session-to-order conversion rate to identify the
-- most effective and efficient marketign channels. 
-- The goal is to achieve maximum session volume without over-spending on ads.
-- Thus, this analysis will help identify opportunities to eliminate wasted spend and scale high-converting traffic


#### 1 ######################################################################################################################
-- Retrieving website session counts to identify top perfroming marketing channels.
SELECT
	ws.utm_source,
    ws.utm_campaign,
    ws.http_referer AS referring_domain,
	COUNT( DISTINCT ws.website_session_id) AS num_sessions
FROM
	website_sessions ws
WHERE
	ws.created_at < '2012-04-12'
GROUP BY
	ws.utm_source,
    ws.utm_campaign,
    ws.http_referer
ORDER BY
	num_sessions DESC;

		-- > Bulk of the sessions are driven by 'gsearch-nonbrand' paifd marketing campaign.


#### 2 ######################################################################################################################
-- Understanding whether the most traffic driving marketing channel i.e., gsearch-nonbrand, is also driving sales
-- by studying session-to-order conversion rates.
-- NOTE: Based on what the business is paying for clicks, it need a CVR of atleast 4% to make the numbers work.

SELECT
	COUNT( DISTINCT ws.website_session_id) AS num_sessions,
    COUNT( DISTINCT o.order_id) AS num_orders,
    ROUND( COUNT(DISTINCT o.order_id)/COUNT(DISTINCT ws.website_session_id)*100, 2 ) AS conversion_rate
FROM
	website_sessions ws
	LEFT JOIN orders o ON ws.website_session_id = o.website_session_id
WHERE
	ws.created_at < '2012-04-14'
    AND ws.utm_source = 'gsearch'
    AND ws.utm_campaign = 'nonbrand';
    
		-- > Gsearch-nonbrand has CVR of 2.88% only, which is lesser than 4% threshold
		-- > This implies that we’re over-spending on our search bids, and thus need to reduce it.


#### 3 ######################################################################################################################
-- NOTE: Based on the past suggestion, the bid reduction for gsearch-nonbrand was implemented on 2012-04-15.
-- Now, let's see the impact of this bid reduction on session volumes for gsearch-nonbrand till 2012-5-10.

SELECT
	MIN( DATE(created_at) ) AS start_of_week,
	WEEK(created_at) AS week_num,
	COUNT(website_session_id) AS num_sessions
FROM 
	website_sessions
WHERE
	created_at < '2012-5-10'
	AND utm_source = 'gsearch'
    AND utm_campaign = 'nonbrand'
GROUP BY
	YEAR(created_at),
	WEEK(created_at)
ORDER BY
	2 DESC;

		-- > Session volume for gsearch-nonbrand has declined significantly after bid reduction.
		-- > Thus, we should continue to monitor volume levels and think about additional ways to make our campaigns more efficient.


#### 4 ######################################################################################################################
-- Let's see if the performance is consistent across all types of devices or not, to identify optimization opportunities.

SELECT
	ws.device_type,
    COUNT(DISTINCT ws.website_session_id) AS sessions,
    COUNT(DISTINCT o.order_id) AS orders,
	ROUND( COUNT(DISTINCT o.order_id)/COUNT(DISTINCT ws.website_session_id)*100, 2 ) AS CVR_pct
FROM
	website_sessions ws
	LEFT JOIN orders o ON ws.website_session_id = o.website_session_id
WHERE
	ws.created_at < '2012-05-11'
	AND ws.utm_source = 'gsearch'
	AND utm_campaign = 'nonbrand'
GROUP BY 
	1
ORDER BY 
	2 DESC;

		-- > The website doesn't look well optimized for mobile devices and needs to be improved.
		-- > Meanwhile, focus on increasing gsearch-nonbrand bids only for desktops and see that makes any difference.


#### 5 #####################################################################################################################
-- Gsearch nonbrand desktop sessions were bid up on 2012-05-19. However, we'll see the impact 
-- since the first bid up till the date of request i.e., 2012-06-09.

SELECT
	MIN(DATE(ws.created_at)) AS start_of_wk,
    WEEK(ws.created_at) AS wk_of_yr,
    COUNT(DISTINCT CASE WHEN ws.device_type = 'desktop' THEN ws.website_session_id ELSE NULL END) AS desktop_sessions,
    COUNT(DISTINCT CASE WHEN ws.device_type = 'mobile' THEN ws.website_session_id ELSE NULL END) AS mobile_sessions,
    COUNT(ws.website_session_id)
FROM website_sessions ws
WHERE
	ws.created_at < '2012-06-09'
    AND ws.created_at > '2012-04-15'
    AND ws.utm_source = 'gsearch'
    AND ws.utm_campaign = 'nonbrand'
GROUP BY
	YEAR(ws.created_at),
    WEEK(ws.created_at)
ORDER BY
	1 DESC;

		-- > There is significant increase in desktop session volumes after the second bid-up (on desktop sessions only).
		-- > Thus, the bid optimization led to effective results i.e., over 19% increase in over session volume by optimizing bids. 
		-- > We need to keep monitoring the impact of bid changes over time
		-- > on device level session volume and conversion rates to further optimize spend.
