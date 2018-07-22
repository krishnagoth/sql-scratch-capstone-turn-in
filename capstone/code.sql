/* First part: Overall churn calculation */

WITH month_starts AS (
  SELECT DISTINCT date(subscription_start,'start of month') AS first_day
  FROM subscriptions
  UNION
  SELECT DISTINCT date(subscription_end,'start of month')
  FROM subscriptions
  WHERE subscription_end IS NOT NULL
),
month_ends AS (
  SELECT DISTINCT date(subscription_start,'start of month', '+1 month', '-1 day') AS last_day
  FROM subscriptions
  UNION
  SELECT DISTINCT date(subscription_end,'start of month', '+1 month', '-1 day')
  FROM subscriptions
  WHERE subscription_end IS NOT NULL
),
months AS (
  SELECT first_day, last_day
  FROM month_starts
  JOIN month_ends
    ON strftime("%m", first_day) = strftime("%m", last_day)
),
cross_on_months AS (
  select *
  FROM subscriptions
  CROSS JOIN months
),
active_stats AS (
  SELECT first_day,
    CASE
      WHEN first_day BETWEEN subscription_start AND subscription_end OR
        (subscription_end BETWEEN first_day AND last_day OR subscription_end IS NULL) THEN 1
      ELSE 0
    END AS is_active,    
    CASE
      WHEN subscription_end BETWEEN first_day AND last_day THEN 1
      ELSE 0
    END AS is_cancelled
  FROM cross_on_months),
status_aggregate AS (
  SELECT strftime("%Y-%m", first_day) AS mon, 
    SUM(is_active) AS sum_active,
    SUM(is_cancelled) AS sum_cancelled
  FROM active_stats
  GROUP BY mon
)
SELECT mon, 
  ROUND((1.0 * sum_cancelled) / sum_active, 2) AS churn
FROM status_aggregate;

/* Second part: Naive churn calculation for segments without grouping */

WITH month_starts AS (
  SELECT DISTINCT date(subscription_start,'start of month') AS first_day
  FROM subscriptions
  UNION
  SELECT DISTINCT date(subscription_end,'start of month')
  FROM subscriptions
  WHERE subscription_end IS NOT NULL
),
month_ends AS (
  SELECT DISTINCT date(subscription_start,'start of month', '+1 month', '-1 day') AS last_day
  FROM subscriptions
  UNION
  SELECT DISTINCT date(subscription_end,'start of month', '+1 month', '-1 day')
  FROM subscriptions
  WHERE subscription_end IS NOT NULL
),
months AS (
  SELECT first_day, last_day
    FROM month_starts
  JOIN month_ends
  ON strftime("%m", first_day) = strftime("%m", last_day)
),
cross_on_months AS (
  select * from subscriptions
  CROSS JOIN months
),
active_stats AS (
  SELECT first_day,
    CASE
      WHEN segment = '87' AND
        (first_day BETWEEN subscription_start AND subscription_end OR
          (subscription_end BETWEEN first_day AND last_day OR subscription_end IS NULL)) THEN 1
      ELSE 0
    END AS is_active_87,
    CASE
      WHEN segment = '30' AND
        (first_day BETWEEN subscription_start AND subscription_end OR
          (subscription_end BETWEEN first_day AND last_day OR subscription_end IS NULL)) THEN 1
      ELSE 0
    END AS is_active_30,
      CASE
      WHEN segment = '87' AND
        subscription_end BETWEEN first_day AND last_day THEN 1
      ELSE 0
    END AS is_canceled_87,
    CASE
      WHEN segment = '30' AND
        subscription_end BETWEEN first_day AND last_day THEN 1
      ELSE 0
    END AS is_canceled_30
  FROM cross_on_months),
status_aggregate AS (
  SELECT strftime("%Y-%m", first_day) AS mon,
     SUM(is_active_87) AS sum_active_87,
     SUM(is_active_30) AS sum_active_30,
     SUM(is_canceled_87) AS sum_canceled_87,
     SUM(is_canceled_30) AS sum_canceled_30
  FROM active_stats
  GROUP BY mon
)
SELECT ROUND((1.0 * sum_canceled_87) / sum_active_87, 2) AS churn_87,
  ROUND((1.0 * sum_canceled_30) / sum_active_30, 2) AS churn_30
  FROM status_aggregate;

/* Third part: Extensible churn calculation for segments with grouping */
  
WITH month_starts AS (
  SELECT DISTINCT date(subscription_start,'start of month') AS first_day
  FROM subscriptions
  UNION
  SELECT DISTINCT date(subscription_end,'start of month')
  FROM subscriptions
  WHERE subscription_end IS NOT NULL
),
month_ends AS (
  SELECT DISTINCT date(subscription_start,'start of month', '+1 month', '-1 day') AS last_day
  FROM subscriptions
  UNION
  SELECT DISTINCT date(subscription_end,'start of month', '+1 month', '-1 day')
  FROM subscriptions
  WHERE subscription_end IS NOT NULL
),
months AS (
  SELECT first_day, last_day
  FROM month_starts
  JOIN month_ends
    ON strftime("%m", first_day) = strftime("%m", last_day)
),
cross_on_months AS (
  select *
  FROM subscriptions
  CROSS JOIN months
),
active_stats AS (
  SELECT segment,
    first_day,
    CASE
      WHEN first_day BETWEEN subscription_start AND subscription_end OR
        (subscription_end BETWEEN first_day AND last_day OR subscription_end IS NULL) THEN 1
      ELSE 0
    END AS is_active,
    CASE
      WHEN subscription_end BETWEEN first_day AND last_day THEN 1
      ELSE 0
    END AS is_cancelled
  FROM cross_on_months),
status_aggregate AS (
  SELECT segment,
    strftime("%Y-%m", first_day) AS mon,
    SUM(is_active) AS sum_active,
    SUM(is_cancelled) AS sum_cancelled
  FROM active_stats
  GROUP BY segment, mon
)
SELECT segment,
  mon,
  ROUND((1.0 * sum_cancelled) / sum_active, 2) AS churn
FROM status_aggregate;