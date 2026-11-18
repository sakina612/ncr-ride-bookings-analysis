--SELECT * FROM ride_bookings_cleaned
--SQL Question 1: How big is the dataset?
USE ride_dataset;
GO

SELECT
    COUNT(*)                        AS total_bookings,
    COUNT(DISTINCT customer_id)     AS unique_customers,
    COUNT(DISTINCT pickup_location) AS pickup_locations,
    COUNT(DISTINCT vehicle_type)    AS vehicle_types,
    MIN([date])                     AS first_date,
    MAX([date])                     AS last_date,
    DATEDIFF(DAY, MIN([date]), MAX([date])) + 1 AS days_covered
FROM dbo.ride_bookings_cleaned;

--Question 2: How many missing values are in each column?
USE ride_dataset;
GO

SELECT
    COUNT(*) AS total_rows,

    -- numeric columns: empty cells import as NULL
    SUM(CASE WHEN avg_vtat       IS NULL THEN 1 ELSE 0 END) AS avg_vtat_nulls,
    SUM(CASE WHEN avg_ctat       IS NULL THEN 1 ELSE 0 END) AS avg_ctat_nulls,
    SUM(CASE WHEN booking_value  IS NULL THEN 1 ELSE 0 END) AS booking_value_nulls,
    SUM(CASE WHEN ride_distance  IS NULL THEN 1 ELSE 0 END) AS ride_distance_nulls,
    SUM(CASE WHEN driver_ratings IS NULL THEN 1 ELSE 0 END) AS driver_ratings_nulls,
    SUM(CASE WHEN customer_rating IS NULL THEN 1 ELSE 0 END) AS customer_rating_nulls,

    -- text columns: an empty cell may import as NULL or as '' (empty text), so check both
    SUM(CASE WHEN payment_method IS NULL OR payment_method = '' THEN 1 ELSE 0 END) AS payment_method_nulls,
    SUM(CASE WHEN reason_for_cancelling_by_customer IS NULL OR reason_for_cancelling_by_customer = '' THEN 1 ELSE 0 END) AS customer_reason_nulls,
    SUM(CASE WHEN driver_cancellation_reason IS NULL OR driver_cancellation_reason = '' THEN 1 ELSE 0 END) AS driver_reason_nulls,
    SUM(CASE WHEN incomplete_rides_reason IS NULL OR incomplete_rides_reason = '' THEN 1 ELSE 0 END) AS incomplete_reason_nulls
FROM dbo.ride_bookings_cleaned;

--SQL Question 3: Are there duplicate booking IDs?
--Query A: how many IDs repeat?
USE ride_dataset;
GO

SELECT
    COUNT(*)       AS repeated_ids,
    SUM(times_used)     AS rows_involved,
    SUM(times_used - 1) AS extra_rows,
    MAX(times_used)     AS max_times
FROM (
    SELECT booking_id, COUNT(*) AS times_used
    FROM dbo.ride_bookings_cleaned
    GROUP BY booking_id
    HAVING COUNT(*) > 1
) AS repeated;

--Query B: look at the repeated IDs side by side
SELECT TOP 10
    booking_id, customer_id, [date], booking_status, vehicle_type
FROM dbo.ride_bookings_cleaned
WHERE booking_id IN (
        SELECT booking_id
        FROM dbo.ride_bookings_cleaned
        GROUP BY booking_id
        HAVING COUNT(*) > 1
      )
ORDER BY booking_id, [date];

--Query C: are any of them true duplicates (the same booking entered twice)?
SELECT booking_id, customer_id, booking_datetime, COUNT(*) AS times_used
FROM dbo.ride_bookings_cleaned
GROUP BY booking_id, customer_id, booking_datetime
HAVING COUNT(*) > 1;


--SQL Question 4: How do bookings end?
--Version 1: with a subquery (easiest to read)
USE ride_dataset;
GO

SELECT
    booking_status,
    COUNT(*) AS bookings,
    CAST(100.0 * COUNT(*) / (SELECT COUNT(*) FROM dbo.ride_bookings_cleaned) AS DECIMAL(5,2)) AS percent_of_total
FROM dbo.ride_bookings_cleaned
GROUP BY booking_status
ORDER BY bookings DESC, booking_status;

--SQL Question 5: What are the completion rate and the unsuccessful rate?
--Query A: the three headline rates in one row
USE ride_dataset;
GO

SELECT
    COUNT(*) AS total_bookings,

    SUM(CASE WHEN booking_status = 'Completed' THEN 1 ELSE 0 END) AS completed,
    SUM(CASE WHEN booking_status <> 'Completed' THEN 1 ELSE 0 END) AS unsuccessful,
    SUM(CASE WHEN booking_status IN ('Cancelled by Driver', 'Cancelled by Customer')
             THEN 1 ELSE 0 END) AS cancelled,

    CAST(100.0 * SUM(CASE WHEN booking_status = 'Completed' THEN 1 ELSE 0 END)
         / COUNT(*) AS DECIMAL(5,2)) AS completion_rate_pct,
    CAST(100.0 * SUM(CASE WHEN booking_status <> 'Completed' THEN 1 ELSE 0 END)
         / COUNT(*) AS DECIMAL(5,2)) AS unsuccessful_rate_pct,
    CAST(100.0 * SUM(CASE WHEN booking_status IN ('Cancelled by Driver', 'Cancelled by Customer')
                          THEN 1 ELSE 0 END)
         / COUNT(*) AS DECIMAL(5,2)) AS cancellation_rate_pct
FROM dbo.ride_bookings_cleaned;

--Query B: a shortcut using AVG
SELECT
    CAST(AVG(CASE WHEN booking_status = 'Completed' THEN 100.0 ELSE 0 END) AS DECIMAL(5,2)) AS completion_rate_pct
FROM dbo.ride_bookings_cleaned;

--Query C: group the 5 statuses into 4 business groups
SELECT
    outcome_group,
    COUNT(*) AS bookings,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS percent_of_total
FROM (
    SELECT
        CASE
            WHEN booking_status = 'Completed' THEN 'Completed'
            WHEN booking_status IN ('Cancelled by Driver', 'Cancelled by Customer')
                 THEN 'Cancelled (driver + customer)'
            ELSE booking_status
        END AS outcome_group
    FROM dbo.ride_bookings_cleaned
) AS grouped
GROUP BY outcome_group
ORDER BY bookings DESC;


--SQL Question 6: Who cancels more, drivers or customers?
--Query A: cancellations by who cancelled
USE ride_dataset;
GO

SELECT
    booking_status,
    COUNT(*) AS cancellations,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS share_of_cancellations,
    CAST(100.0 * COUNT(*) / (SELECT COUNT(*) FROM dbo.ride_bookings_cleaned) AS DECIMAL(5,2)) AS share_of_all_bookings
FROM dbo.ride_bookings_cleaned
WHERE booking_status IN ('Cancelled by Driver', 'Cancelled by Customer')
GROUP BY booking_status
ORDER BY cancellations DESC;

--Query B: the ratio in one number
SELECT
    SUM(CASE WHEN booking_status = 'Cancelled by Driver'   THEN 1 ELSE 0 END) AS driver_cancels,
    SUM(CASE WHEN booking_status = 'Cancelled by Customer' THEN 1 ELSE 0 END) AS customer_cancels,
    CAST(1.0 * SUM(CASE WHEN booking_status = 'Cancelled by Driver' THEN 1 ELSE 0 END)
         / SUM(CASE WHEN booking_status = 'Cancelled by Customer' THEN 1 ELSE 0 END)
         AS DECIMAL(5,2)) AS drivers_per_customer_cancel
FROM dbo.ride_bookings_cleaned;

---SQL Question 7: Why do customers cancel, why do drivers cancel, and why do rides end incomplete?
--Query A: why customers cancel
USE ride_dataset;
GO

SELECT
    reason_for_cancelling_by_customer AS reason,
    COUNT(*) AS bookings,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS percent_of_total
FROM dbo.ride_bookings_cleaned
WHERE booking_status = 'Cancelled by Customer'
GROUP BY reason_for_cancelling_by_customer
ORDER BY bookings DESC;

--Query B: why drivers cancel
SELECT
    driver_cancellation_reason AS reason,
    COUNT(*) AS bookings,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS percent_of_total
FROM dbo.ride_bookings_cleaned
WHERE booking_status = 'Cancelled by Driver'
GROUP BY driver_cancellation_reason
ORDER BY bookings DESC;

--Query C: why rides end incomplete
SELECT
    incomplete_rides_reason AS reason,
    COUNT(*) AS bookings,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS percent_of_total
FROM dbo.ride_bookings_cleaned
WHERE booking_status = 'Incomplete'
GROUP BY incomplete_rides_reason
ORDER BY bookings DESC;

--Query D (stretch): all three in one table
SELECT cancelled_by, reason, bookings, percent_within_group
FROM (
    SELECT booking_status AS cancelled_by,
           reason_for_cancelling_by_customer AS reason,
           COUNT(*) AS bookings,
           CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY booking_status) AS DECIMAL(5,2)) AS percent_within_group
    FROM dbo.ride_bookings_cleaned
    WHERE booking_status = 'Cancelled by Customer'
    GROUP BY booking_status, reason_for_cancelling_by_customer

    UNION ALL

    SELECT booking_status, driver_cancellation_reason, COUNT(*),
           CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY booking_status) AS DECIMAL(5,2))
    FROM dbo.ride_bookings_cleaned
    WHERE booking_status = 'Cancelled by Driver'
    GROUP BY booking_status, driver_cancellation_reason

    UNION ALL

    SELECT booking_status, incomplete_rides_reason, COUNT(*),
           CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY booking_status) AS DECIMAL(5,2))
    FROM dbo.ride_bookings_cleaned
    WHERE booking_status = 'Incomplete'
    GROUP BY booking_status, incomplete_rides_reason
) AS all_reasons
ORDER BY cancelled_by, bookings DESC;

--SQL Question 8: Which hours of the day have the most bookings?
--Query A: bookings for each hour, 0 to 23
USE ride_dataset;
GO

SELECT
    DATEPART(HOUR, booking_datetime) AS booking_hour,
    COUNT(*) AS bookings
FROM dbo.ride_bookings_cleaned
GROUP BY DATEPART(HOUR, booking_datetime)
ORDER BY booking_hour;

--Query B: the top 5 busiest hours with a rank and a share
SELECT TOP 5
    DATEPART(HOUR, booking_datetime) AS booking_hour,
    COUNT(*) AS bookings,
    RANK() OVER (ORDER BY COUNT(*) DESC) AS demand_rank,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS percent_of_total
FROM dbo.ride_bookings_cleaned
GROUP BY DATEPART(HOUR, booking_datetime)
ORDER BY bookings DESC;

--Query C: group the hours into parts of the day
SELECT
    part_of_day,
    COUNT(*) AS bookings,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,1)) AS percent_of_total
FROM (
    SELECT
        CASE
            WHEN DATEPART(HOUR, booking_datetime) BETWEEN 5  AND 11 THEN '1 Morning (5-11)'
            WHEN DATEPART(HOUR, booking_datetime) BETWEEN 12 AND 16 THEN '2 Afternoon (12-16)'
            WHEN DATEPART(HOUR, booking_datetime) BETWEEN 17 AND 21 THEN '3 Evening (17-21)'
            ELSE '4 Night (22-4)'
        END AS part_of_day
    FROM dbo.ride_bookings_cleaned
) AS parts
GROUP BY part_of_day
ORDER BY part_of_day;

--SQL Question 9: Which day is busiest, and weekday versus weekend?
--Query A: bookings by day of week, Monday first
USE ride_dataset;
GO

WITH days AS (
    SELECT
        DATENAME(WEEKDAY, [date]) AS day_name,
        DATEDIFF(DAY, '19000101', CAST([date] AS DATE)) % 7 AS day_no   -- 0 = Monday ... 6 = Sunday
    FROM dbo.ride_bookings_cleaned
)
SELECT
    day_name,
    COUNT(*) AS bookings
FROM days
GROUP BY day_name, day_no
ORDER BY day_no;


--Query B: weekday versus weekend, per day
WITH days AS (
    SELECT
        CAST([date] AS DATE) AS ride_date,
        CASE
            WHEN DATEDIFF(DAY, '19000101', CAST([date] AS DATE)) % 7 IN (5, 6) THEN 'Weekend'
            ELSE 'Weekday'
        END AS day_type
    FROM dbo.ride_bookings_cleaned
)
SELECT
    day_type,
    COUNT(*)                  AS bookings,
    COUNT(DISTINCT ride_date) AS days_in_data,
    CAST(1.0 * COUNT(*) / COUNT(DISTINCT ride_date) AS DECIMAL(6,1)) AS avg_bookings_per_day
FROM days
GROUP BY day_type
ORDER BY day_type;

--SQL Question 10: How do bookings change month by month?
USE ride_dataset;
GO

SELECT
    MONTH(CAST([date] AS DATE))                    AS month_no,
    DATENAME(MONTH, CAST([date] AS DATE))          AS month_name,
    COUNT(*)                                       AS bookings,
    COUNT(DISTINCT CAST([date] AS DATE))           AS days_in_data,
    CAST(1.0 * COUNT(*) / COUNT(DISTINCT CAST([date] AS DATE)) AS DECIMAL(6,1)) AS bookings_per_day
FROM dbo.ride_bookings_cleaned
GROUP BY MONTH(CAST([date] AS DATE)), DATENAME(MONTH, CAST([date] AS DATE))
ORDER BY month_no;

--SQL Question 11: Do completion and cancellation rates change by hour or day?
--Query A: rates by hour
USE ride_dataset;
GO

SELECT
    DATEPART(HOUR, booking_datetime) AS booking_hour,
    COUNT(*) AS bookings,
    CAST(AVG(CASE WHEN booking_status = 'Completed' THEN 100.0 ELSE 0 END) AS DECIMAL(5,1)) AS completed_pct,
    CAST(AVG(CASE WHEN booking_status IN ('Cancelled by Driver', 'Cancelled by Customer')
                  THEN 100.0 ELSE 0 END) AS DECIMAL(5,1)) AS cancelled_pct,
    CAST(AVG(CASE WHEN booking_status = 'Cancelled by Driver' THEN 100.0 ELSE 0 END) AS DECIMAL(5,1)) AS driver_cancelled_pct
FROM dbo.ride_bookings_cleaned
GROUP BY DATEPART(HOUR, booking_datetime)
ORDER BY booking_hour;

--Query B: rates by day of week
WITH days AS (
    SELECT
        booking_status,
        DATENAME(WEEKDAY, [date]) AS day_name,
        DATEDIFF(DAY, '19000101', CAST([date] AS DATE)) % 7 AS day_no   -- 0 = Monday
    FROM dbo.ride_bookings_cleaned
)
SELECT
    day_name,
    COUNT(*) AS bookings,
    CAST(AVG(CASE WHEN booking_status = 'Completed' THEN 100.0 ELSE 0 END) AS DECIMAL(5,1)) AS completed_pct,
    CAST(AVG(CASE WHEN booking_status IN ('Cancelled by Driver', 'Cancelled by Customer')
                  THEN 100.0 ELSE 0 END) AS DECIMAL(5,1)) AS cancelled_pct
FROM days
GROUP BY day_name, day_no
ORDER BY day_no;

--Query C: the range of the hourly rates
WITH hourly AS (
    SELECT
        DATEPART(HOUR, booking_datetime) AS booking_hour,
        AVG(CASE WHEN booking_status = 'Completed' THEN 100.0 ELSE 0 END) AS completed_pct,
        AVG(CASE WHEN booking_status IN ('Cancelled by Driver', 'Cancelled by Customer')
                 THEN 100.0 ELSE 0 END) AS cancelled_pct
    FROM dbo.ride_bookings_cleaned
    GROUP BY DATEPART(HOUR, booking_datetime)
)
SELECT
    CAST(MIN(completed_pct) AS DECIMAL(5,1)) AS lowest_completed,
    CAST(MAX(completed_pct) AS DECIMAL(5,1)) AS highest_completed,
    CAST(MIN(cancelled_pct) AS DECIMAL(5,1)) AS lowest_cancelled,
    CAST(MAX(cancelled_pct) AS DECIMAL(5,1)) AS highest_cancelled
FROM hourly;

--SQL Question 12: Which vehicle type is booked the most?
--Query A: bookings by vehicle type
USE ride_dataset;
GO

SELECT
    vehicle_type,
    COUNT(*) AS bookings,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS percent_of_total,
    RANK() OVER (ORDER BY COUNT(*) DESC) AS popularity_rank
FROM dbo.ride_bookings_cleaned
GROUP BY vehicle_type
ORDER BY bookings DESC;

--Query B: group the 7 vehicle types into 3 categories
SELECT
    category,
    COUNT(*) AS bookings,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS percent_of_total
FROM (
    SELECT
        CASE
            WHEN vehicle_type IN ('Auto', 'Go Mini', 'Go Sedan') THEN 'Everyday cars and autos'
            WHEN vehicle_type IN ('Bike', 'eBike')               THEN 'Two-wheelers'
            ELSE 'Premium and large'
        END AS category
    FROM dbo.ride_bookings_cleaned
) AS grouped
GROUP BY category
ORDER BY bookings DESC;

--SQL Question 13: What is the completion rate for each vehicle type?
--Query A: completion and cancellation rate by vehicle type
USE ride_dataset;
GO

SELECT
    vehicle_type,
    COUNT(*) AS bookings,
    CAST(AVG(CASE WHEN booking_status = 'Completed' THEN 100e0 ELSE 0e0 END) AS DECIMAL(5,2)) AS completed_pct,
    CAST(AVG(CASE WHEN booking_status IN ('Cancelled by Driver', 'Cancelled by Customer')
                  THEN 100e0 ELSE 0e0 END) AS DECIMAL(5,2)) AS cancelled_pct
FROM dbo.ride_bookings_cleaned
GROUP BY vehicle_type
ORDER BY completed_pct DESC;

--Query B: is any difference real, or just noise?
WITH overall AS (
    SELECT AVG(CASE WHEN booking_status = 'Completed' THEN 1e0 ELSE 0e0 END) AS p
    FROM dbo.ride_bookings_cleaned
)
SELECT
    v.vehicle_type,
    COUNT(*) AS bookings,
    CAST(AVG(CASE WHEN v.booking_status = 'Completed' THEN 100e0 ELSE 0e0 END) AS DECIMAL(5,2)) AS completed_pct,
    CAST(AVG(CASE WHEN v.booking_status = 'Completed' THEN 100e0 ELSE 0e0 END) - 100e0 * o.p AS DECIMAL(5,2)) AS diff_vs_overall,
    CAST(1.96 * SQRT(o.p * (1 - o.p) / COUNT(*)) * 100 AS DECIMAL(5,2)) AS margin_of_error
FROM dbo.ride_bookings_cleaned AS v
CROSS JOIN overall AS o
GROUP BY v.vehicle_type, o.p
ORDER BY completed_pct DESC;

--SQL Question 14: Which vehicle type earns the most revenue, and what is its average fare?
--Query A: revenue, average fare and share by vehicle type
USE ride_dataset;
GO

SELECT
    vehicle_type,
    COUNT(*)                                   AS completed_rides,
    COUNT(*) - COUNT(booking_value)            AS missing_values,
    CAST(SUM(booking_value) AS DECIMAL(14,0))  AS revenue,
    CAST(AVG(booking_value) AS DECIMAL(8,1))   AS avg_fare,
    CAST(100.0 * SUM(booking_value) / SUM(SUM(booking_value)) OVER () AS DECIMAL(5,1)) AS revenue_share_pct
FROM dbo.ride_bookings_cleaned
WHERE booking_status = 'Completed'
GROUP BY vehicle_type
ORDER BY revenue DESC;

--SQL Question 15: Average distance and waiting times by vehicle type
--Query A: the averages
USE ride_dataset;
GO

SELECT
    vehicle_type,
    COUNT(*)                                  AS total_bookings,
    COUNT(avg_vtat)                           AS rows_with_vtat,
    COUNT(ride_distance)                      AS rows_with_distance,
    CAST(AVG(CAST(avg_vtat AS FLOAT))      AS DECIMAL(6,2)) AS avg_vtat_min,
    CAST(AVG(CAST(avg_ctat AS FLOAT))      AS DECIMAL(6,2)) AS avg_ctat_min,
    CAST(AVG(CAST(ride_distance AS FLOAT)) AS DECIMAL(6,2)) AS avg_distance_km
FROM dbo.ride_bookings_cleaned
GROUP BY vehicle_type
ORDER BY total_bookings DESC;

--Query B: overall averages, and which rows have the data
SELECT
    CAST(AVG(CAST(avg_vtat AS FLOAT))      AS DECIMAL(6,2)) AS overall_vtat,
    CAST(AVG(CAST(avg_ctat AS FLOAT))      AS DECIMAL(6,2)) AS overall_ctat,
    CAST(AVG(CAST(ride_distance AS FLOAT)) AS DECIMAL(6,2)) AS overall_distance
FROM dbo.ride_bookings_cleaned;

SELECT
    booking_status,
    COUNT(avg_vtat)      AS rows_with_vtat,
    COUNT(avg_ctat)      AS rows_with_ctat,
    COUNT(ride_distance) AS rows_with_distance
FROM dbo.ride_bookings_cleaned
GROUP BY booking_status
ORDER BY booking_status;

--SQL Question 16: What are the total revenue and the average fare?
--Query A: the headline numbers in one row
USE ride_dataset;
GO

SELECT
    COUNT(*)                                          AS completed_rides,
    CAST(SUM(booking_value) AS DECIMAL(14,0))         AS total_revenue,
    CAST(AVG(booking_value) AS DECIMAL(8,2))          AS avg_fare,
    MIN(booking_value)                                AS lowest_fare,
    MAX(booking_value)                                AS highest_fare,
    CAST(AVG(ride_distance) AS DECIMAL(6,1))          AS avg_distance_km,
    CAST(SUM(booking_value) / SUM(ride_distance) AS DECIMAL(8,2)) AS revenue_per_km,
    CAST(SUM(booking_value) / COUNT(DISTINCT CAST([date] AS DATE)) AS DECIMAL(12,0)) AS revenue_per_day
FROM dbo.ride_bookings_cleaned
WHERE booking_status = 'Completed';

--Query B: the median fare
SELECT DISTINCT
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY booking_value) OVER () AS median_fare
FROM dbo.ride_bookings_cleaned
WHERE booking_status = 'Completed';

--Query C: revenue by month
SELECT
    MONTH(CAST([date] AS DATE))                  AS month_no,
    DATENAME(MONTH, CAST([date] AS DATE))        AS month_name,
    COUNT(*)                                     AS completed_rides,
    CAST(SUM(booking_value) AS DECIMAL(14,0))    AS revenue,
    CAST(SUM(booking_value) / 1000000.0 AS DECIMAL(5,2)) AS revenue_millions
FROM dbo.ride_bookings_cleaned
WHERE booking_status = 'Completed'
GROUP BY MONTH(CAST([date] AS DATE)), DATENAME(MONTH, CAST([date] AS DATE))
ORDER BY month_no;

--SQL Question 17: Which payment method do customers use most?
--Query A: rides, revenue and average fare by payment method
USE ride_dataset;
GO

SELECT
    payment_method,
    COUNT(*) AS rides,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,1)) AS rides_pct,
    CAST(SUM(booking_value) AS DECIMAL(14,0)) AS revenue,
    CAST(100.0 * SUM(booking_value) / SUM(SUM(booking_value)) OVER () AS DECIMAL(5,1)) AS revenue_pct,
    CAST(AVG(booking_value) AS DECIMAL(8,1)) AS avg_fare
FROM dbo.ride_bookings_cleaned
WHERE booking_status = 'Completed'
GROUP BY payment_method
ORDER BY rides DESC;

--Query B: cash versus digital
SELECT
    payment_group,
    COUNT(*) AS rides,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,1)) AS rides_pct
FROM (
    SELECT
        CASE
            WHEN payment_method = 'UPI'  THEN 'UPI'
            WHEN payment_method = 'Cash' THEN 'Cash'
            ELSE 'Other digital (wallet + cards)'
        END AS payment_group
    FROM dbo.ride_bookings_cleaned
    WHERE booking_status = 'Completed'
) AS grouped
GROUP BY payment_group
ORDER BY rides DESC;

--SQL Question 18: Does a longer ride mean a higher fare?
--Query A: average fare by distance band
USE ride_dataset;
GO

SELECT
    distance_band,
    COUNT(*) AS rides,
    CAST(AVG(booking_value) AS DECIMAL(8,1)) AS avg_fare
FROM (
    SELECT
        booking_value,
        CASE
            WHEN ride_distance <= 10 THEN '1: 0-10 km'
            WHEN ride_distance <= 20 THEN '2: 10-20 km'
            WHEN ride_distance <= 30 THEN '3: 20-30 km'
            WHEN ride_distance <= 40 THEN '4: 30-40 km'
            ELSE '5: 40-50 km'
        END AS distance_band
    FROM dbo.ride_bookings_cleaned
    WHERE booking_status = 'Completed'
) AS banded
GROUP BY distance_band
ORDER BY distance_band;

--Query B: the correlation, calculated by hand
WITH rides AS (
    SELECT
        CAST(ride_distance AS FLOAT) AS x,     -- distance
        CAST(booking_value AS FLOAT) AS y      -- fare
    FROM dbo.ride_bookings_cleaned
    WHERE booking_status = 'Completed'
),
sums AS (
    SELECT
        COUNT(*) * 1e0 AS n,
        SUM(x)     AS sx,
        SUM(y)     AS sy,
        SUM(x * y) AS sxy,
        SUM(x * x) AS sxx,
        SUM(y * y) AS syy
    FROM rides
)
SELECT
    CAST((n * sxy - sx * sy) / SQRT((n * sxx - sx * sx) * (n * syy - sy * sy)) AS DECIMAL(6,4)) AS correlation,
    CAST((n * sxy - sx * sy) / (n * sxx - sx * sx) AS DECIMAL(8,3)) AS fare_increase_per_km
FROM sums;

--SQL Question 19: Are customers repeat users or one-time users?
--Query A: how many bookings does each customer make?
USE ride_dataset;
GO

WITH per_customer AS (
    SELECT customer_id, COUNT(*) AS bookings
    FROM dbo.ride_bookings_cleaned
    GROUP BY customer_id
)
SELECT
    bookings AS bookings_per_customer,
    COUNT(*) AS customers,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(6,3)) AS percent_of_customers
FROM per_customer
GROUP BY bookings
ORDER BY bookings;

--Query B: one-time versus repeat customers
WITH per_customer AS (
    SELECT customer_id, COUNT(*) AS bookings
    FROM dbo.ride_bookings_cleaned
    GROUP BY customer_id
)
SELECT
    CASE WHEN bookings = 1 THEN 'One-time' ELSE 'Repeat' END AS customer_type,
    COUNT(*)      AS customers,
    SUM(bookings) AS total_bookings,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS pct_of_customers,
    CAST(100.0 * SUM(bookings) / SUM(SUM(bookings)) OVER () AS DECIMAL(5,2)) AS pct_of_bookings
FROM per_customer
GROUP BY CASE WHEN bookings = 1 THEN 'One-time' ELSE 'Repeat' END
ORDER BY customers DESC;

--Query C: the most frequent customers
SELECT TOP 8
    customer_id,
    COUNT(*) AS bookings,
    SUM(CASE WHEN booking_status = 'Completed' THEN 1 ELSE 0 END) AS completed
FROM dbo.ride_bookings_cleaned
GROUP BY customer_id
HAVING COUNT(*) > 1
ORDER BY bookings DESC, customer_id;

--SQL Question 20: What are the average customer and driver ratings?
--Query A: overall averages and the lowest and highest scores
USE ride_dataset;
GO

SELECT
    COUNT(*)                                       AS rated_rides,
    CAST(AVG(customer_rating) AS DECIMAL(4,2))     AS avg_customer_rating,
    CAST(AVG(driver_ratings)  AS DECIMAL(4,2))     AS avg_driver_rating,
    MIN(customer_rating) AS lowest_customer,
    MIN(driver_ratings)  AS lowest_driver,
    MAX(customer_rating) AS highest_customer,
    MAX(driver_ratings)  AS highest_driver
FROM dbo.ride_bookings_cleaned
WHERE booking_status = 'Completed';

--Query B: how the ratings are spread
SELECT
    rating_band,
    SUM(CASE WHEN rated = 'customer' THEN 1 ELSE 0 END) AS customer_ratings,
    SUM(CASE WHEN rated = 'driver'   THEN 1 ELSE 0 END) AS driver_ratings
FROM (
    SELECT 'customer' AS rated,
           CASE WHEN customer_rating < 3.5 THEN '3.0 - 3.4'
                WHEN customer_rating < 4.0 THEN '3.5 - 3.9'
                WHEN customer_rating < 4.5 THEN '4.0 - 4.4'
                ELSE '4.5 - 5.0' END AS rating_band
    FROM dbo.ride_bookings_cleaned
    WHERE booking_status = 'Completed'

    UNION ALL

    SELECT 'driver',
           CASE WHEN driver_ratings < 3.5 THEN '3.0 - 3.4'
                WHEN driver_ratings < 4.0 THEN '3.5 - 3.9'
                WHEN driver_ratings < 4.5 THEN '4.0 - 4.4'
                ELSE '4.5 - 5.0' END
    FROM dbo.ride_bookings_cleaned
    WHERE booking_status = 'Completed'
) AS bands
GROUP BY rating_band
ORDER BY rating_band;

--Query C: ratings by vehicle type
SELECT
    vehicle_type,
    COUNT(*) AS rides,
    CAST(AVG(customer_rating) AS DECIMAL(4,2)) AS avg_customer_rating,
    CAST(AVG(driver_ratings)  AS DECIMAL(4,2)) AS avg_driver_rating
FROM dbo.ride_bookings_cleaned
WHERE booking_status = 'Completed'
GROUP BY vehicle_type
ORDER BY avg_driver_rating DESC, vehicle_type;

--SQL Question 21: Which pickup and drop locations are busiest?
--Query A: top 10 pickup locations
USE ride_dataset;
GO

SELECT TOP 10
    pickup_location,
    COUNT(*) AS bookings
FROM dbo.ride_bookings_cleaned
GROUP BY pickup_location
ORDER BY bookings DESC, pickup_location;

--Query B: top 10 drop locations
SELECT TOP 10
    drop_location,
    COUNT(*) AS bookings
FROM dbo.ride_bookings_cleaned
GROUP BY drop_location
ORDER BY bookings DESC, drop_location;

--Query C: how much do the top locations really stand out?
WITH per_location AS (
    SELECT pickup_location, COUNT(*) AS bookings
    FROM dbo.ride_bookings_cleaned
    GROUP BY pickup_location
)
SELECT
    COUNT(*)                                 AS pickup_locations,
    MIN(bookings)                            AS lowest,
    MAX(bookings)                            AS highest,
    CAST(AVG(bookings * 1.0) AS DECIMAL(6,1)) AS average,
    (SELECT SUM(bookings) FROM (SELECT TOP 10 bookings FROM per_location ORDER BY bookings DESC) AS t) AS top10_bookings
FROM per_location;

--SQL Question 22: Which pickup areas have the lowest completion rates?
--Query A: the 10 lowest and 10 highest completion rates
USE ride_dataset;
GO

WITH loc AS (
    SELECT
        pickup_location,
        COUNT(*) AS bookings,
        AVG(CASE WHEN booking_status = 'Completed' THEN 100e0 ELSE 0e0 END) AS completion_pct
    FROM dbo.ride_bookings_cleaned
    GROUP BY pickup_location
),
ranked AS (
    SELECT
        pickup_location,
        bookings,
        completion_pct,
        RANK() OVER (ORDER BY completion_pct ASC)  AS rank_lowest,
        RANK() OVER (ORDER BY completion_pct DESC) AS rank_highest
    FROM loc
)
SELECT
    pickup_location,
    bookings,
    CAST(completion_pct AS DECIMAL(5,2)) AS completion_pct,
    rank_lowest,
    rank_highest
FROM ranked
WHERE rank_lowest <= 10 OR rank_highest <= 10
ORDER BY completion_pct;

--Query B: how much variation is just chance?
WITH loc AS (
    SELECT
        pickup_location,
        COUNT(*) AS bookings,
        AVG(CASE WHEN booking_status = 'Completed' THEN 100e0 ELSE 0e0 END) AS completion_pct
    FROM dbo.ride_bookings_cleaned
    GROUP BY pickup_location
),
stats AS (
    SELECT
        (SELECT AVG(CASE WHEN booking_status = 'Completed' THEN 100e0 ELSE 0e0 END)
         FROM dbo.ride_bookings_cleaned)  AS overall_pct,
        AVG(bookings * 1e0)               AS avg_bookings
    FROM loc
),
band AS (
    SELECT
        overall_pct,
        1.96 * SQRT(overall_pct / 100 * (1 - overall_pct / 100) / avg_bookings) * 100 AS margin
    FROM stats
)
SELECT
    CAST(MAX(b.overall_pct) AS DECIMAL(5,2)) AS overall_completion_pct,
    CAST(MAX(b.margin)      AS DECIMAL(5,2)) AS margin_points,
    COUNT(*)                                 AS locations,
    SUM(CASE WHEN ABS(l.completion_pct - b.overall_pct) <= b.margin THEN 1 ELSE 0 END) AS inside_band,
    CAST(100.0 * SUM(CASE WHEN ABS(l.completion_pct - b.overall_pct) <= b.margin THEN 1 ELSE 0 END)
         / COUNT(*) AS DECIMAL(5,1)) AS pct_inside_band
FROM loc AS l
CROSS JOIN band AS b;

--Query C: what is different about the worst location?
SELECT
    booking_status,
    COUNT(*) AS bookings,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,1)) AS vinobapuri_pct
FROM dbo.ride_bookings_cleaned
WHERE pickup_location = 'Vinobapuri'
GROUP BY booking_status
ORDER BY bookings DESC


--SQL Question 23: Which routes earn the most?
--Query A: top 10 routes by revenue
USE ride_dataset;
GO

WITH routes AS (
    SELECT
        CONCAT(pickup_location, ' -> ', drop_location) AS route,
        COUNT(*)           AS rides,
        SUM(booking_value) AS revenue
    FROM dbo.ride_bookings_cleaned
    WHERE booking_status = 'Completed'
    GROUP BY pickup_location, drop_location
)
SELECT TOP 10
    route,
    rides,
    CAST(revenue AS DECIMAL(12,0))         AS revenue,
    CAST(revenue / rides AS DECIMAL(8,1))  AS avg_fare
FROM routes
ORDER BY revenue DESC, route;

--Query B: top 10 routes by number of rides
WITH routes AS (
    SELECT
        CONCAT(pickup_location, ' -> ', drop_location) AS route,
        COUNT(*)           AS rides,
        SUM(booking_value) AS revenue
    FROM dbo.ride_bookings_cleaned
    WHERE booking_status = 'Completed'
    GROUP BY pickup_location, drop_location
)
SELECT TOP 10
    route,
    rides,
    CAST(revenue AS DECIMAL(12,0)) AS revenue
FROM routes
ORDER BY rides DESC, revenue DESC, route;

--Query C: how concentrated is the business on its best routes?
WITH routes AS (
    SELECT
        pickup_location, drop_location,
        COUNT(*)           AS rides,
        SUM(booking_value) AS revenue
    FROM dbo.ride_bookings_cleaned
    WHERE booking_status = 'Completed'
    GROUP BY pickup_location, drop_location
)
SELECT
    COUNT(*)                                       AS unique_routes,
    MAX(rides)                                     AS most_rides_on_a_route,
    CAST(AVG(rides * 1.0) AS DECIMAL(5,2))         AS avg_rides_per_route,
    SUM(CASE WHEN rides = 1 THEN 1 ELSE 0 END)     AS routes_with_one_ride,
    CAST(100.0 * SUM(CASE WHEN rides = 1 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,1)) AS pct_one_ride_routes,
    CAST(100.0 * (SELECT SUM(revenue) FROM (SELECT TOP 10 revenue FROM routes ORDER BY revenue DESC) AS t)
         / SUM(revenue) AS DECIMAL(5,2))           AS top10_revenue_share_pct
FROM routes;

--Query D: why is the #1 route on top?
SELECT booking_id, booking_value, ride_distance, booking_datetime
FROM dbo.ride_bookings_cleaned
WHERE booking_status = 'Completed'
  AND pickup_location = 'Nirman Vihar'
  AND drop_location   = 'Vatika Chowk'
ORDER BY booking_value DESC;

--SQL Question 24: Rank vehicle types by revenue within each month
--Query A: the full ranking, every month and every vehicle
USE ride_dataset;
GO

WITH monthly AS (
    SELECT
        MONTH(CAST([date] AS DATE))           AS month_no,
        DATENAME(MONTH, CAST([date] AS DATE)) AS month_name,
        vehicle_type,
        SUM(booking_value)                    AS revenue
    FROM dbo.ride_bookings_cleaned
    WHERE booking_status = 'Completed'
    GROUP BY MONTH(CAST([date] AS DATE)), DATENAME(MONTH, CAST([date] AS DATE)), vehicle_type
)
SELECT
    month_no,
    month_name,
    vehicle_type,
    CAST(revenue AS DECIMAL(12,0)) AS revenue,
    RANK() OVER (PARTITION BY month_no ORDER BY revenue DESC) AS rank_in_month
FROM monthly
ORDER BY month_no, rank_in_month;

--Query B: the #1 vehicle in each month, and its share
WITH monthly AS (
    SELECT
        MONTH(CAST([date] AS DATE))           AS month_no,
        DATENAME(MONTH, CAST([date] AS DATE)) AS month_name,
        vehicle_type,
        SUM(booking_value)                    AS revenue
    FROM dbo.ride_bookings_cleaned
    WHERE booking_status = 'Completed'
    GROUP BY MONTH(CAST([date] AS DATE)), DATENAME(MONTH, CAST([date] AS DATE)), vehicle_type
),
ranked AS (
    SELECT
        month_no, month_name, vehicle_type, revenue,
        RANK() OVER (PARTITION BY month_no ORDER BY revenue DESC) AS rank_in_month,
        100.0 * revenue / SUM(revenue) OVER (PARTITION BY month_no) AS share_of_month
    FROM monthly
)
SELECT
    month_name,
    vehicle_type,
    CAST(revenue AS DECIMAL(12,0))        AS revenue,
    CAST(share_of_month AS DECIMAL(5,1))  AS share_of_month_pct
FROM ranked
WHERE rank_in_month = 1
ORDER BY month_no;

--Query C: does any vehicle’s rank ever change?
USE ride_dataset;
GO

WITH monthly AS (
    SELECT
        MONTH(CAST([date] AS DATE))           AS month_no,
        DATENAME(MONTH, CAST([date] AS DATE)) AS month_name,
        vehicle_type,
        SUM(booking_value)                    AS revenue
    FROM dbo.ride_bookings_cleaned
    WHERE booking_status = 'Completed'
    GROUP BY MONTH(CAST([date] AS DATE)), DATENAME(MONTH, CAST([date] AS DATE)), vehicle_type
),
ranked AS (
    SELECT
        month_no, month_name, vehicle_type, revenue,
        RANK() OVER (PARTITION BY month_no ORDER BY revenue DESC) AS rank_in_month
    FROM monthly
)
SELECT
    vehicle_type,
    MIN(rank_in_month) AS best_rank,
    MAX(rank_in_month) AS worst_rank
FROM ranked
GROUP BY vehicle_type
ORDER BY best_rank;

--SQL Question 25: Running (cumulative) revenue by month
--Query A: monthly revenue and running total
USE ride_dataset;
GO

WITH monthly AS (
    SELECT
        MONTH(CAST([date] AS DATE))           AS month_no,
        DATENAME(MONTH, CAST([date] AS DATE)) AS month_name,
        SUM(booking_value)                    AS revenue
    FROM dbo.ride_bookings_cleaned
    WHERE booking_status = 'Completed'
    GROUP BY MONTH(CAST([date] AS DATE)), DATENAME(MONTH, CAST([date] AS DATE))
)
SELECT
    month_name,
    CAST(revenue AS DECIMAL(12,0)) AS revenue,
    CAST(SUM(revenue) OVER (ORDER BY month_no
                            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
         AS DECIMAL(12,0))          AS running_revenue,
    CAST(100e0 * SUM(revenue) OVER (ORDER BY month_no
                            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
         / SUM(revenue) OVER () AS DECIMAL(5,1)) AS running_pct_of_year
FROM monthly
ORDER BY month_no;

--Query B: add a 3-month moving average
WITH monthly AS (
    SELECT
        MONTH(CAST([date] AS DATE))           AS month_no,
        DATENAME(MONTH, CAST([date] AS DATE)) AS month_name,
        SUM(booking_value)                    AS revenue
    FROM dbo.ride_bookings_cleaned
    WHERE booking_status = 'Completed'
    GROUP BY MONTH(CAST([date] AS DATE)), DATENAME(MONTH, CAST([date] AS DATE))
)
SELECT
    month_name,
    CAST(revenue AS DECIMAL(12,0)) AS revenue,
    CAST(AVG(revenue) OVER (ORDER BY month_no
                            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
         AS DECIMAL(12,0))          AS moving_avg_3m
FROM monthly
ORDER BY month_no;

--SQL Question 26: Which hours have above-average bookings?
--Query A: the CTE version, showing every hour
USE ride_dataset;
GO

WITH hourly AS (
    SELECT
        DATEPART(HOUR, CAST(booking_datetime AS DATETIME2)) AS booking_hour,
        COUNT(*)                                            AS bookings
    FROM dbo.ride_bookings_cleaned
    GROUP BY DATEPART(HOUR, CAST(booking_datetime AS DATETIME2))
),
avg_hour AS (
    SELECT AVG(bookings * 1.0) AS avg_bookings
    FROM hourly
)
SELECT
    h.booking_hour,
    h.bookings,
    CAST(a.avg_bookings AS DECIMAL(8,1))                        AS avg_per_hour,
    CAST(100.0 * (h.bookings - a.avg_bookings) / a.avg_bookings
         AS DECIMAL(6,1))                                       AS pct_vs_avg,
    CASE WHEN h.bookings > a.avg_bookings THEN 'Above' ELSE 'Below' END AS vs_average
FROM hourly h
CROSS JOIN avg_hour a
ORDER BY h.booking_hour;

--Query B: the subquery version, only the above-average hours
SELECT
    DATEPART(HOUR, CAST(booking_datetime AS DATETIME2)) AS booking_hour,
    COUNT(*)                                            AS bookings
FROM dbo.ride_bookings_cleaned
GROUP BY DATEPART(HOUR, CAST(booking_datetime AS DATETIME2))
HAVING COUNT(*) > (
        SELECT AVG(cnt * 1.0)
        FROM (
            SELECT COUNT(*) AS cnt
            FROM dbo.ride_bookings_cleaned
            GROUP BY DATEPART(HOUR, CAST(booking_datetime AS DATETIME2))
        ) AS x
)
ORDER BY bookings DESC;


--SQL Question 27: Month-over-month revenue change with LAG
--Query A: month-over-month change in revenue
USE ride_dataset;
GO

WITH monthly AS (
    SELECT
        MONTH(CAST([date] AS DATE))           AS month_no,
        DATENAME(MONTH, CAST([date] AS DATE)) AS month_name,
        SUM(booking_value)                    AS revenue
    FROM dbo.ride_bookings_cleaned
    WHERE booking_status = 'Completed'
    GROUP BY MONTH(CAST([date] AS DATE)), DATENAME(MONTH, CAST([date] AS DATE))
),
with_prev AS (
    SELECT
        month_no, month_name, revenue,
        LAG(revenue, 1) OVER (ORDER BY month_no) AS prev_revenue
    FROM monthly
)
SELECT
    month_name,
    CAST(revenue AS DECIMAL(12,0))                      AS revenue,
    CAST(prev_revenue AS DECIMAL(12,0))                 AS prev_month_revenue,
    CAST(revenue - prev_revenue AS DECIMAL(12,0))       AS change_amount,
    CAST(100e0 * (revenue - prev_revenue) / NULLIF(prev_revenue, 0)
         AS DECIMAL(6,1))                               AS change_pct
FROM with_prev
ORDER BY month_no;


--Query B: the best and worst month-over-month changes
USE ride_dataset;
GO

WITH monthly AS (
    SELECT
        MONTH(CAST([date] AS DATE))           AS month_no,
        DATENAME(MONTH, CAST([date] AS DATE)) AS month_name,
        SUM(booking_value)                    AS revenue
    FROM dbo.ride_bookings_cleaned
    WHERE booking_status = 'Completed'
    GROUP BY MONTH(CAST([date] AS DATE)), DATENAME(MONTH, CAST([date] AS DATE))
),
with_prev AS (
    SELECT
        month_no, month_name, revenue,
        LAG(revenue, 1) OVER (ORDER BY month_no) AS prev_revenue
    FROM monthly
)
SELECT TOP 2 WITH TIES
    month_name,
    CAST(100e0 * (revenue - prev_revenue) / NULLIF(prev_revenue, 0) AS DECIMAL(6,1)) AS change_pct
FROM with_prev
WHERE prev_revenue IS NOT NULL
ORDER BY ABS(100e0 * (revenue - prev_revenue) / NULLIF(prev_revenue, 0)) DESC;

--Query C: month-over-month change in bookings, to explain the swings
WITH monthly AS (
    SELECT
        MONTH(CAST([date] AS DATE)) AS month_no,
        DATENAME(MONTH, CAST([date] AS DATE)) AS month_name,
        COUNT(*) AS bookings
    FROM dbo.ride_bookings_cleaned
    GROUP BY MONTH(CAST([date] AS DATE)), DATENAME(MONTH, CAST([date] AS DATE))
)
SELECT
    month_name,
    bookings,
    LAG(bookings) OVER (ORDER BY month_no) AS prev_bookings,
    CAST(100e0 * (bookings - LAG(bookings) OVER (ORDER BY month_no))
         / NULLIF(LAG(bookings) OVER (ORDER BY month_no), 0) AS DECIMAL(6,1)) AS change_pct
FROM monthly
ORDER BY month_no;