/* ============================================================================
   RETAIL SALES ANALYSIS - SQL
   Rupsa Chaudhuri

   Transaction and campaign-response analysis of a retail customer base.
   124,969 transactions, 6,884 customers, 16 May 2011 to 16 March 2015.
   MySQL 8.0+ (CTEs and window functions are used throughout).

   Companion to Retail_Sales_Analysis.ipynb. The notebook handles cleaning,
   clustering and the statistical tests; this script answers the business
   questions and carries the SQL working.

   ----------------------------------------------------------------------------
   THE ONE RULE THIS SCRIPT FOLLOWS

   overall_data holds one row per TRANSACTION. customer_id repeats, and so do
   every customer attribute joined onto it: segment, response, frequency,
   monetary, recency_days, clv_12m, the RFM scores.

   So AVG(response) straight off this table is not the response rate. It is the
   response rate weighted by how often each customer bought, and customers who
   respond buy more often, which pushes it up. The same trap applies to every
   customer-level column.

   Every query below that asks a question about PEOPLE aggregates to one row
   per customer first, then averages. Queries about PURCHASES - average
   transaction amount, revenue by month - read the transaction rows directly,
   which is correct for those.

   Each section ends in a CONCLUSION block.
   ============================================================================ */


/* ============================================================================
   0. SETUP
   ============================================================================ */

-- 0.1 Create the schema and select it.
CREATE DATABASE IF NOT EXISTS retail_sales;
USE retail_sales;


-- 0.2 Table definition.
-- Column order matches the header of overall_data.csv exactly, which is what
-- LOAD DATA relies on - it maps by position, not by name.
DROP TABLE IF EXISTS overall_data;

CREATE TABLE overall_data (
    customer_id   VARCHAR(10),
    trans_date    DATE,
    tran_amount   INT,
    response      TINYINT,
    segment       VARCHAR(4),       -- k-means tier, P0 highest
    frequency     INT,              -- purchases by this customer
    monetary      INT,              -- total spend by this customer
    aov           DECIMAL(10,4),    -- their average order value
    recency_days  INT,              -- days from their last purchase to 2015-03-16
    tenure_days   INT,              -- days from their first purchase to 2015-03-16
    clv_12m       DECIMAL(12,4),    -- projected 12-month value
    R             TINYINT,          -- recency quintile, 5 = most recent
    F             TINYINT,          -- frequency quintile, 5 = most frequent
    M             TINYINT,          -- monetary quintile, 5 = highest spend
    RFM_score     SMALLINT,         -- R, F and M concatenated
    RFM_total     TINYINT,          -- R + F + M
    rfm_tier      VARCHAR(20),
    INDEX idx_customer (customer_id),
    INDEX idx_date (trans_date),
    INDEX idx_segment (segment)
);


-- 0.3 Load the data.
-- Only overall_data.csv is needed. Every query in this file reads that one
-- table; main_data.csv and customers.csv belong to the Python stage.
-- server-side load. Faster, but MySQL reads only from one folder:
     SHOW VARIABLES LIKE 'secure_file_priv';
--   copy the CSV into whatever path that returns, then:
      LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/overall_data.csv'
      INTO TABLE overall_data
      FIELDS TERMINATED BY ',' ENCLOSED BY '"'
      LINES TERMINATED BY '\r\n'
      IGNORE 1 ROWS;

-- 0.4 Verify the load before running anything else.
SELECT COUNT(*)                    AS rows_loaded,
       COUNT(DISTINCT customer_id) AS customers,
       MIN(trans_date)             AS first_day,
       MAX(trans_date)             AS last_day,
       SUM(tran_amount)            AS total_revenue,
       SUM(trans_date IS NULL)     AS null_dates,
       SUM(segment IS NULL)        AS null_segments
FROM overall_data;
-- Expect exactly: 124,969 | 6,884 | 2011-05-16 | 2015-03-16 | 8,122,378 | 0 | 0

-- The customer attributes above are produced by the notebook. The clustering
-- cannot be reproduced in SQL, so `segment` is read rather than computed.
-- Everything else in this script is derived from customer_id, trans_date,
-- tran_amount and response, so the RFM work below is recomputed from scratch
-- rather than reading the stored quintiles.


/* ============================================================================
   1. DATA OVERVIEW AND QUALITY
   ============================================================================ */

-- 1.1 Size and span
SELECT COUNT(*)                     AS transactions,
       COUNT(DISTINCT customer_id)  AS customers,
       SUM(tran_amount)             AS total_revenue,
       MIN(tran_amount)             AS min_amount,
       MAX(tran_amount)             AS max_amount,
       MIN(trans_date)              AS first_day,
       MAX(trans_date)              AS last_day
FROM overall_data;
-- 124,969 | 6,884 | 8,122,378 | 10 | 105 | 2011-05-16 | 2015-03-16


-- 1.2 Exact duplicate transactions
SELECT COUNT(*) AS duplicate_rows
FROM (
    SELECT customer_id, trans_date, tran_amount, COUNT(*) AS n
    FROM overall_data
    GROUP BY customer_id, trans_date, tran_amount
    HAVING COUNT(*) > 1
) AS d;
-- 6 groups.


-- 1.3 Month coverage
SELECT DATE_FORMAT(trans_date, '%Y-%m')      AS month,
       COUNT(*)                              AS transactions,
       COUNT(DISTINCT trans_date)            AS days_with_activity,
       DAY(LAST_DAY(MIN(trans_date)))        AS days_in_calendar_month
FROM overall_data
GROUP BY 1
ORDER BY 1
LIMIT 3;
-- 2011-05 holds 1,484 transactions across 16 days; a full month holds ~2,729.
-- The same applies at the far end: 2015-03 covers 1 to 16 March only.


/* ----------------------------------------------------------------------------
   CONCLUSION

   124,969 transactions, 6,884 customers, 8,122,378 in total value. Transaction
   amounts run 10 to 105 with nothing outside that band. Six exact duplicates,
   too few to move any figure.

   The file opens on 16 May 2011 and closes on 16 March 2015, so the first and
   last months each cover 16 days. Any monthly total has to be divided by days
   covered before it can be compared with another month. Section 7 depends on
   this entirely.

   The dataset carries no currency label, so all money figures are unlabelled
   units.
   ---------------------------------------------------------------------------- */


/* ============================================================================
   2. CUSTOMER KEY INSIGHTS
   ============================================================================ */

-- 2.1 Average transaction amount
-- Transaction level is correct here: the question is about purchases.
SELECT ROUND(AVG(tran_amount), 2) AS avg_transaction_amount
FROM overall_data;
-- 65.00


-- 2.2 Average spend per customer
-- Customer level, so aggregate per customer first.
SELECT ROUND(AVG(total_spent), 2) AS avg_spend_per_customer,
       ROUND(MIN(total_spent), 2) AS min_spend,
       ROUND(MAX(total_spent), 2) AS max_spend
FROM (
    SELECT customer_id, SUM(tran_amount) AS total_spent
    FROM overall_data
    GROUP BY customer_id
) AS c;
-- 1,179.89 | 149 | 2,933


-- 2.3 Top customers by spend
SELECT customer_id,
       SUM(tran_amount) AS total_spent,
       COUNT(*)         AS purchases
FROM overall_data
GROUP BY customer_id
ORDER BY total_spent DESC
LIMIT 5;
-- CS4424 (2,933 / 39), CS4320 (2,647 / 38), CS5752 (2,612 / 33),
-- CS4660 (2,527 / 33), CS3799 (2,513 / 36)


-- 2.4 Top customers by purchase count
-- Note the ties before quoting a top five.
SELECT purchases,
       COUNT(*) AS customers_tied,
       GROUP_CONCAT(customer_id ORDER BY customer_id) AS customer_ids
FROM (
    SELECT customer_id, COUNT(*) AS purchases
    FROM overall_data
    GROUP BY customer_id
) AS c
WHERE purchases >= 35
GROUP BY purchases
ORDER BY purchases DESC;
-- 39  1  CS4424
-- 38  1  CS4320
-- 36  1  CS3799
-- 35  5  CS1215, CS2620, CS3013, CS3805, CS5109   <- five customers tie
--
-- The inner query counts purchases per customer; the outer one groups those
-- counts so ties surface instead of being hidden by a LIMIT.


/* ----------------------------------------------------------------------------
   CONCLUSION

   The average purchase is 65.00 and the average customer has spent 1,179.89
   across the four years, ranging from 149 to 2,933.

   Three customers lead on purchase count at 39, 38 and 36, and then five tie at
   35. A LIMIT 5 on purchase count would return two of those five arbitrarily,
   so the honest statement is "three leaders, then a five-way tie" rather than a
   ranked list of five names.
   ---------------------------------------------------------------------------- */


/* ============================================================================
   3. RFM SCORING

   Quintiles rather than fixed thresholds. Median recency here is 53 days, so a
   threshold set in the hundreds of days would put almost the whole base into a
   single bucket. Section 4 shows exactly that happening.
   ============================================================================ */

-- 3.1 Score every customer 1-5 on each dimension
WITH customer_rfm AS (
    SELECT customer_id,
           DATEDIFF('2015-03-16', MAX(trans_date)) AS recency_days,
           COUNT(*)                                AS frequency,
           SUM(tran_amount)                        AS monetary,
           MAX(response)                           AS response
    FROM overall_data
    GROUP BY customer_id
),
scored AS (
    SELECT *,
           6 - NTILE(5) OVER (ORDER BY recency_days, customer_id) AS R,
           NTILE(5) OVER (ORDER BY frequency, customer_id)        AS F,
           NTILE(5) OVER (ORDER BY monetary,  customer_id)        AS M
    FROM customer_rfm
)
SELECT CONCAT(R, F, M)              AS rfm_score,
       R + F + M                    AS rfm_total,
       COUNT(*)                     AS customers,
       ROUND(AVG(monetary), 2)      AS avg_monetary,
       ROUND(AVG(response)*100, 2)  AS response_rate
FROM scored
GROUP BY 1, 2
ORDER BY customers DESC
LIMIT 8;
-- 111 and 555 are the largest cells at 376 and 317 customers.
--
-- The customer_id tiebreak in each ORDER BY is deliberate. frequency is a small
-- integer with thousands of customers sharing each value, and NTILE forces
-- equal bucket sizes by splitting tied groups wherever the boundary falls.
-- Without a tiebreak the assignment is not reproducible between runs.


-- 3.2 Named tiers
WITH customer_rfm AS (
    SELECT customer_id,
           DATEDIFF('2015-03-16', MAX(trans_date)) AS recency_days,
           COUNT(*)                                AS frequency,
           SUM(tran_amount)                        AS monetary,
           MAX(response)                           AS response
    FROM overall_data
    GROUP BY customer_id
),
scored AS (
    SELECT *,
           6 - NTILE(5) OVER (ORDER BY recency_days, customer_id) AS R,
           NTILE(5) OVER (ORDER BY frequency, customer_id)        AS F
    FROM customer_rfm
)
SELECT CASE WHEN R >= 4 AND F >= 4 THEN 'Champions'
            WHEN R >= 3 AND F >= 3 THEN 'Loyal'
            WHEN R >= 4 AND F <= 2 THEN 'New / Promising'
            WHEN R <= 2 AND F >= 4 THEN 'At Risk'
            WHEN R <= 2 AND F <= 2 THEN 'Hibernating'
            ELSE 'Needs Attention' END          AS rfm_tier,
       COUNT(*)                                 AS customers,
       ROUND(COUNT(*)*100.0 / SUM(COUNT(*)) OVER (), 1) AS pct_base,
       ROUND(AVG(monetary), 2)                  AS avg_monetary,
       SUM(monetary)                            AS revenue,
       ROUND(AVG(response)*100, 2)              AS response_rate
FROM scored
GROUP BY 1
ORDER BY revenue DESC;
/*                  customers  pct_base   avg_monetary     revenue  response_rate
   Champions            1,332     19.3%       1,628.45   2,169,098       11.64%
   Loyal                1,411     20.5%       1,373.16   1,937,532       10.49%
   At Risk                815     11.8%       1,580.77   1,288,329       23.07%
   Needs Attention      1,085     15.8%         987.34   1,071,259        7.28%
   Hibernating          1,366     19.8%         712.99     973,950        4.83%
   New / Promising        875     12.7%         779.67     682,210        1.26%  */


-- 3.3 Does recency behave the way RFM practice assumes?
WITH customer_rfm AS (
    SELECT customer_id,
           DATEDIFF('2015-03-16', MAX(trans_date)) AS recency_days,
           MAX(response) AS response
    FROM overall_data
    GROUP BY customer_id
),
scored AS (
    SELECT response,
           6 - NTILE(5) OVER (ORDER BY recency_days, customer_id) AS R_quintile
    FROM customer_rfm
)
SELECT R_quintile,
       COUNT(*)                      AS customers,
       ROUND(AVG(response)*100, 2)   AS response_rate
FROM scored
GROUP BY R_quintile
ORDER BY R_quintile;
-- 1 (least recent) 11.19% |9 2  12.13% | 3  9.08% | 4  8.42% | 5 (most recent) 6.17%


/* ----------------------------------------------------------------------------
   CONCLUSION

   Champions and Loyal together are 40% of the base and just over half of
   revenue. Hibernating is a fifth of the base and 12% of revenue.

   Recency runs backwards against campaign response in this dataset. The least
   recent quintile responds at 11.19% and the most recent at 6.17%, and the gap
   is wider still once frequency is held constant. That is why At Risk carries
   the highest response rate of any tier at 23.07%, ahead of Champions at
   11.64%.

   Standard RFM practice assumes the opposite ordering, so this is reported as a
   property of this dataset rather than as a general finding. Frequency is the
   dimension that actually separates response here.
   ---------------------------------------------------------------------------- */


/* ============================================================================
   4. RULE-BASED RFM SEGMENTS

   Fixed thresholds, as a contrast with the quintiles above:
     Recency   - Recent <= 200 days, Medium 201-400, Old > 400
     Frequency - Frequent >= 25, Medium 10-24, Infrequent < 10
     Monetary  - High >= 2000, Medium 1000-1999, Low < 1000
   ============================================================================ */

-- 4.1 Customers and revenue per cell
WITH customer_rfm AS (
    SELECT customer_id,
           DATEDIFF('2015-03-16', MAX(trans_date)) AS recency_days,
           COUNT(*)                                AS frequency,
           SUM(tran_amount)                        AS monetary
    FROM overall_data
    GROUP BY customer_id
)
SELECT CASE WHEN recency_days <= 200 THEN 'Recent'
            WHEN recency_days <= 400 THEN 'Medium'
            ELSE 'Old' END                                  AS recency_segment,
       CASE WHEN frequency >= 25 THEN 'Frequent'
            WHEN frequency >= 10 THEN 'Medium'
            ELSE 'Infrequent' END                           AS frequency_segment,
       CASE WHEN monetary >= 2000 THEN 'High Value'
            WHEN monetary >= 1000 THEN 'Medium'
            ELSE 'Low Value' END                            AS monetary_segment,
       COUNT(*)      AS customers,
       SUM(monetary) AS total_revenue
FROM customer_rfm
GROUP BY 1, 2, 3
ORDER BY total_revenue DESC
LIMIT 6;
/* Recent-Medium-Medium        3,524 customers   4,842,332
   Recent-Medium-Low Value     1,800 customers   1,237,544
   Recent-Frequent-Medium        574 customers   1,039,277
   Recent-Frequent-High Value    198 customers     424,437
   Medium-Medium-Medium          208 customers     269,677
   Medium-Medium-Low Value       236 customers     153,890 */


-- 4.2 How evenly do the recency thresholds divide the base?
WITH customer_rfm AS (
    SELECT customer_id,
           DATEDIFF('2015-03-16', MAX(trans_date)) AS recency_days,
           MAX(response) AS response
    FROM overall_data
    GROUP BY customer_id
)
SELECT CASE WHEN recency_days <= 200 THEN 'Recent'
            WHEN recency_days <= 400 THEN 'Medium'
            ELSE 'Old' END                               AS recency_segment,
       COUNT(*)                                          AS customers,
       ROUND(COUNT(*)*100.0 / SUM(COUNT(*)) OVER (), 1)  AS pct_base,
       ROUND(AVG(response)*100, 2)                       AS response_rate
FROM customer_rfm
GROUP BY 1
ORDER BY customers DESC;
-- Recent 6,303 (91.6%) 9.55% | Medium 515 (7.5%) 8.54% | Old 66 (1.0%) 1.52%


/* ----------------------------------------------------------------------------
   CONCLUSION

   Recent-Medium-Medium is the largest cell by both customers and revenue, at
   3,524 customers and 4,842,332.

   The recency thresholds do not divide this base usefully. 91.6% of customers
   land in "Recent" and 1.0% in "Old". The apparent gradient of 9.55% / 8.54% /
   1.52% is therefore almost everybody measured against 66 lapsed customers,
   not a relationship between recency and response across the base. Section 3.3
   splits the same variable into quintiles and the direction reverses.

   Fixed thresholds carried over from another dataset are worth checking against
   the distribution before any conclusion is drawn from them.
   ---------------------------------------------------------------------------- */


/* ============================================================================
   5. BEHAVIOUR BY SEGMENT
   ============================================================================ */

-- 5.1 Segment profile
-- Every measure here describes a customer, so the subquery collapses to one row
-- per customer before any average is taken.
SELECT segment,
       COUNT(*)                                          AS customers,
       ROUND(COUNT(*)*100.0 / SUM(COUNT(*)) OVER (), 1)  AS pct_base,
       ROUND(AVG(frequency), 2)                          AS avg_purchases,
       ROUND(AVG(aov), 2)                                AS avg_basket,
       ROUND(AVG(monetary), 2)                           AS avg_total_spend,
       SUM(monetary)                                     AS revenue,
       ROUND(SUM(monetary)*100.0 / SUM(SUM(monetary)) OVER (), 1) AS pct_revenue
FROM (
    SELECT customer_id, segment,
           COUNT(*)             AS frequency,
           SUM(tran_amount)     AS monetary,
           AVG(tran_amount)     AS aov
    FROM overall_data
    GROUP BY customer_id, segment
) AS c
GROUP BY segment
ORDER BY segment;
/* P0  1,904  27.7%  24.45  70.76  1,728.28  3,290,641  40.5%
   P1  2,906  42.2%  18.19  67.61  1,226.01  3,562,799  43.9%
   P2  2,074  30.1%  12.32  49.73    611.83  1,268,938  15.6% */


-- 5.2 Average transaction amount by segment
-- Transaction level, because the question is about purchases rather than people.
SELECT segment, ROUND(AVG(tran_amount), 2) AS avg_transaction_amount
FROM overall_data
GROUP BY segment
ORDER BY 2 DESC;
-- P0 70.68 | P1 67.39 | P2 49.68

-- 5.3 Consistency of basket size within each segment
SELECT segment,
       ROUND(AVG(aov), 2)    AS avg_basket,
       ROUND(STDDEV(aov), 2) AS basket_stddev,
       ROUND(AVG(frequency), 1) AS avg_purchases
FROM (
    SELECT customer_id, segment,
           AVG(tran_amount) AS aov,
           COUNT(*)         AS frequency
    FROM overall_data
    GROUP BY customer_id, segment
) AS c
GROUP BY segment
ORDER BY basket_stddev ASC;
-- P0 70.76 / 4.25 / 24.5 | P1 67.61 / 8.36 / 18.2 | P2 49.73 / 11.70 / 12.3

/* ----------------------------------------------------------------------------
   CONCLUSION

   P0 is 27.7% of customers and 40.5% of revenue. P2 is 30.1% of customers and
   15.6% of revenue.

   P0 and P1 differ mainly in how often they buy, 24.45 purchases against 18.19,
   rather than in basket size, 70.76 against 67.61. P2 is lower on both.

   The segments come from clustering on purchase count and total spend, which
   are two views of the same behaviour. Treat them as a value ranking, which is
   what they are, rather than as three distinct kinds of customer.
   ---------------------------------------------------------------------------- */


/* ============================================================================
   6. CAMPAIGN PERFORMANCE AND LIFT

   The response flag is the only outcome variable in this dataset. It is static:
   one value per customer, with no date attached.
   ============================================================================ */

-- 6.1 Confirm the flag is static before using it
SELECT MAX(distinct_values) AS max_distinct_response_per_customer
FROM (
    SELECT customer_id, COUNT(DISTINCT response) AS distinct_values
    FROM overall_data
    GROUP BY customer_id
) AS c;
-- 1. Every customer carries exactly one response value for all of their rows.
-- It records whether they ever responded, so it cannot be attributed to a
-- particular campaign or tracked across time.


-- 6.2 Overall response rate
SELECT ROUND(AVG(response)*100, 2) AS response_rate,
       SUM(response)               AS responders,
       COUNT(*)                    AS customers
FROM (SELECT customer_id, MAX(response) AS response
      FROM overall_data GROUP BY customer_id) AS c;
-- 9.40% | 647 | 6,884

-- 6.3 Lift by segment
SELECT segment,
       COUNT(*)                     AS customers,
       SUM(response)                AS responders,
       ROUND(AVG(response)*100, 2)  AS response_rate,
       ROUND(COUNT(*)*100.0      / SUM(COUNT(*))      OVER (), 1) AS pct_of_base,
       ROUND(SUM(response)*100.0 / SUM(SUM(response)) OVER (), 1) AS pct_of_responders,
       ROUND(AVG(response) /
             (SUM(SUM(response)) OVER () / SUM(COUNT(*)) OVER ()), 2) AS lift
FROM (SELECT customer_id, segment, MAX(response) AS response
      FROM overall_data GROUP BY customer_id, segment) AS c
GROUP BY segment
ORDER BY response_rate DESC;
/* P0  1,904  329  17.28%  27.7% of base  50.9% of responders  1.84x
   P1  2,906  273   9.39%  42.2%          42.2%                1.00x
   P2  2,074   45   2.17%  30.1%           7.0%                0.23x */


-- 6.4 Cumulative reach if segments are contacted best-first
SELECT segment,
       pct_of_base,
       pct_of_responders,
       SUM(pct_of_base)       OVER (ORDER BY response_rate DESC) AS cum_pct_contacted,
       SUM(pct_of_responders) OVER (ORDER BY response_rate DESC) AS cum_pct_reached
FROM (
    SELECT segment,
           AVG(response)                                              AS response_rate,
           ROUND(COUNT(*)*100.0      / SUM(COUNT(*))      OVER (), 1) AS pct_of_base,
           ROUND(SUM(response)*100.0 / SUM(SUM(response)) OVER (), 1) AS pct_of_responders
    FROM (SELECT customer_id, segment, MAX(response) AS response
          FROM overall_data GROUP BY customer_id, segment) AS c
    GROUP BY segment
) AS s
ORDER BY response_rate DESC;
-- P0 alone      : contact 27.7%, reach 50.9%
-- P0 + P1       : contact 69.9%, reach 93.1%
-- all three     : contact 100%,  reach 100%


/* ----------------------------------------------------------------------------
   CONCLUSION

   This is the section that carries a decision.

   P0 is 27.7% of the customer base and holds 50.9% of all responders, a lift of
   1.84x. A campaign restricted to P0 reaches half the responders while
   contacting roughly a quarter of the base.

   P2 is 30.1% of the base and 7.0% of responders, a lift of 0.23x. At equal
   cost per contact it returns less than a quarter of average, so including it
   in a broad mailing destroys value.

   P1 sits exactly at the base rate, 1.00x, which makes it the marginal group.
   Adding it to P0 lifts reach from 50.9% to 93.1% of responders but raises
   contact volume from 27.7% to 69.9% of the base. Whether that trade is worth
   making depends on the cost per contact and the value of a response, neither
   of which is in this dataset.
   ---------------------------------------------------------------------------- */


/* ============================================================================
   7. SALES OVER TIME

   Every query here normalises by days covered. Months are unequal, and the two
   end months of this file are half months.
   ============================================================================ */

-- 7.1 Monthly revenue per day
SELECT DATE_FORMAT(trans_date, '%Y-%m')  AS month,
       SUM(tran_amount)                  AS revenue,
       COUNT(DISTINCT trans_date)        AS days_covered,
       ROUND(SUM(tran_amount) / COUNT(DISTINCT trans_date), 0) AS revenue_per_day
FROM overall_data
GROUP BY 1
ORDER BY 1;
-- Lowest 5,470 (May 2014), highest 6,181 (May 2011, a half month).


-- 7.2 Spread of revenue per day, in one row
SELECT ROUND(AVG(revenue_per_day), 0)           AS mean_per_day,
       ROUND(STDDEV(revenue_per_day), 0)        AS sd_per_day,
       ROUND(STDDEV(revenue_per_day)
             / AVG(revenue_per_day), 3)         AS coefficient_of_variation,
       MIN(revenue_per_day)                     AS lowest,
       MAX(revenue_per_day)                     AS highest
FROM (
    SELECT DATE_FORMAT(trans_date, '%Y-%m') AS month,
           SUM(tran_amount) / COUNT(DISTINCT trans_date) AS revenue_per_day
    FROM overall_data
    GROUP BY 1
) AS m;
-- 5,802 | 133 | 0.023 | 5,470 | 6,181


-- 7.3 Seasonality by calendar month
SELECT MONTH(trans_date)                  AS month_num,
       MONTHNAME(trans_date)              AS month_name,
       COUNT(*)                           AS transactions,
       COUNT(DISTINCT YEAR(trans_date))   AS times_in_file,
       COUNT(DISTINCT trans_date)         AS days_covered,
       ROUND(COUNT(*) / COUNT(DISTINCT trans_date), 1) AS txn_per_day
FROM overall_data
GROUP BY 1, 2
ORDER BY 1;
/* raw count          per day
   Jan 11,144           89.9
   Feb  9,937           87.9
   Mar  9,751           89.5
   Apr  7,973           88.6   <- lowest raw count, but April is in the file
   May  9,688           88.9      three times while most months appear four
   Jun 10,756           89.6
   Jul 11,033           89.0
   Aug 11,195           90.3   <- highest raw count
   Sep 10,685           89.0
   Oct 11,175           90.1
   Nov 10,669           88.9
   Dec 10,963           88.4                                                  */


-- 7.4 Yearly comparison
SELECT YEAR(trans_date)                  AS year,
       COUNT(*)                          AS transactions,
       COUNT(DISTINCT trans_date)        AS days_covered,
       ROUND(COUNT(*) / COUNT(DISTINCT trans_date), 1) AS txn_per_day,
       ROUND(AVG(tran_amount), 2)        AS avg_transaction_amount
FROM overall_data
GROUP BY 1
ORDER BY 1;
-- 2011 and 2015 are partial. The three complete years hold 32,521 / 32,900 /
-- 32,226 transactions, a 2.1% spread, and average amount moves between 64.89
-- and 65.23 across all five years.


/* ----------------------------------------------------------------------------
   CONCLUSION

   There is no trend, no seasonality and no volatility in this dataset.

   Revenue per day holds at 5,802 with a standard deviation of 133 across 47
   months, a coefficient of variation of 2.3%.

   On raw counts August appears to peak and April to trough, a difference of
   40%. Per day of coverage every calendar month sits between 87.9 and 90.3
   transactions, a spread of under 3%. The April figure is low because April
   falls inside the file three times while most months fall inside it four
   times.

   Average transaction amount is flat at approximately 65 throughout, varying by
   half a percent across five years.

   Any planning built on a seasonal pattern in this data would be planning
   around the calendar rather than around customer behaviour.
   ---------------------------------------------------------------------------- */


/* ============================================================================
   8. CUSTOMER LIFETIME VALUE

   clv_12m is average order value multiplied by the customer's own observed
   monthly purchase rate, projected over 12 months. No churn term, so it assumes
   a customer continues at their observed rate.
   ============================================================================ */

-- 8.1 Range
SELECT ROUND(MIN(clv_12m), 2) AS min_clv,
       ROUND(AVG(clv_12m), 2) AS avg_clv,
       ROUND(MAX(clv_12m), 2) AS max_clv,
       ROUND(SUM(clv_12m), 0) AS total_clv
FROM (SELECT customer_id, MAX(clv_12m) AS clv_12m
      FROM overall_data GROUP BY customer_id) AS c;
-- 43.95 | 325.05 | 770.21 | 2,237,678


-- 8.2 Sanity check against observed revenue
-- Worth running on any projected figure before reporting it. A forward estimate
-- on a flat business should land near one year of actual revenue.
SELECT (SELECT ROUND(SUM(clv_12m), 0)
        FROM (SELECT customer_id, MAX(clv_12m) AS clv_12m
              FROM overall_data GROUP BY customer_id) AS c)   AS projected_12m,
       (SELECT SUM(tran_amount) FROM overall_data
        WHERE trans_date >= DATE_SUB('2015-03-16', INTERVAL 12 MONTH)) AS observed_last_12m;
-- 2,237,678 against 2,108,426. A ratio of 1.06.

-- 8.3 By segment
SELECT segment,
       COUNT(*)               AS customers,
       ROUND(AVG(clv_12m), 2) AS avg_clv_12m,
       ROUND(SUM(clv_12m), 0) AS total_clv_12m
FROM (SELECT customer_id, segment, MAX(clv_12m) AS clv_12m
      FROM overall_data GROUP BY customer_id, segment) AS c
GROUP BY segment
ORDER BY avg_clv_12m DESC;
-- P0 469.67 avg / 894,250 total | P1 338.20 / 982,808 | P2 173.88 / 360,620


/* ----------------------------------------------------------------------------
   CONCLUSION

   Projected 12-month value across the base is 2,237,678 against 2,108,426 of
   revenue actually recorded in the final twelve months. A ratio of 1.06, which
   is what a forward estimate should produce on a business showing no growth or
   decline.

   Mean 12-month value is 325.05, ranging from 43.95 to 770.21.

   P1 holds the largest total at 982,808 because it is the largest group, while
   P0 has the highest value per customer at 469.67. Both facts matter and they
   point at different decisions: P0 for per-customer investment, P1 for
   aggregate revenue protection.
   ---------------------------------------------------------------------------- */


/* ============================================================================
   9. PURCHASE CADENCE
   ============================================================================ */

-- 9.1 Distribution of gaps between consecutive purchases
WITH gaps AS (
    SELECT customer_id,
           segment,
           DATEDIFF(trans_date,
                    LAG(trans_date) OVER (PARTITION BY customer_id
                                          ORDER BY trans_date)) AS gap_days
    FROM overall_data
),
ranked AS (
    SELECT gap_days, PERCENT_RANK() OVER (ORDER BY gap_days) AS pct
    FROM gaps WHERE gap_days IS NOT NULL
)
SELECT COUNT(*)                AS gap_count,
       ROUND(AVG(gap_days), 2) AS mean_gap,
       MAX(CASE WHEN pct <= 0.50 THEN gap_days END) AS median_gap,
       MAX(CASE WHEN pct <= 0.75 THEN gap_days END) AS p75_gap,
       MAX(CASE WHEN pct <= 0.90 THEN gap_days END) AS p90_gap,
       MAX(gap_days)           AS max_gap
FROM ranked;
-- 118,085 gaps | mean 72.37 | median 49 | p75 99 | p90 167 | max 985


-- 9.2 Cadence by segment
WITH gaps AS (
    SELECT segment,
           DATEDIFF(trans_date,
                    LAG(trans_date) OVER (PARTITION BY customer_id
                                          ORDER BY trans_date)) AS gap_days
    FROM overall_data
)
SELECT segment,
       COUNT(*)                AS gaps,
       ROUND(AVG(gap_days), 1) AS avg_gap_days
FROM gaps
WHERE gap_days IS NOT NULL
GROUP BY segment
ORDER BY avg_gap_days;
-- P0 55.0 | P1 72.9 | P2 104.3


-- 9.3 Share of each segment that returns within 30 days at least once
-- As a share, not a raw count. A raw count across groups of different sizes
-- says more about group size than about behaviour.
SELECT c.segment,
       COUNT(DISTINCT c.customer_id)  AS segment_size,
       COUNT(DISTINCT g.customer_id)  AS returned_within_30d,
       ROUND(COUNT(DISTINCT g.customer_id) * 100.0
             / COUNT(DISTINCT c.customer_id), 1) AS pct_of_segment
FROM (SELECT DISTINCT customer_id, segment FROM overall_data) AS c
LEFT JOIN (
    SELECT customer_id
    FROM (
        SELECT customer_id,
               DATEDIFF(trans_date,
                        LAG(trans_date) OVER (PARTITION BY customer_id
                                              ORDER BY trans_date)) AS gap_days
        FROM overall_data
    ) AS x
    WHERE gap_days <= 30
    GROUP BY customer_id
) AS g ON g.customer_id = c.customer_id
GROUP BY c.segment
ORDER BY pct_of_segment DESC;
-- P0 100.0% (1,904 of 1,904) | P1 99.9% (2,903 of 2,906) | P2 92.7% (1,923 of 2,074)
--
-- Near-universal in every segment, so this measure does not discriminate.
-- Average gap in 9.2 separates the segments properly; a 30-day 'did it ever
-- happen' flag over four years does not.


/* ----------------------------------------------------------------------------
   CONCLUSION

   The median gap between purchases is 49 days, the 75th percentile is 99 days
   and the 90th is 167. The mean of 72 is pulled up by a long right tail, so the
   median is the figure to quote.

   By segment: P0 returns in 55 days on average, P1 in 73, P2 in 104.

   75% of repeat purchases happen within 99 days of the previous one, so a
   customer who has not bought in that long sits outside normal behaviour for
   this base. That makes 99 days a defensible reactivation trigger, and the
   per-segment figures argue for setting it separately by segment rather than
   globally.

   It also means a one-month window is too short to judge whether a customer is
   active. A customer buying at a normal 49-day cadence will be absent in
   roughly half of all calendar months.
   ---------------------------------------------------------------------------- */


/* ============================================================================
   10. COHORT RETENTION ANALYSIS

   Every section so far groups customers by what they are worth. None groups
   them by WHEN THEY ARRIVED, which is the question this file has the span to
   answer: four years is long enough to follow a group for several years after
   it first appears.

   Two derived columns do the whole job:
     cohort_q  - the quarter containing a customer's first purchase. Fixed.
     k         - whole quarters between that cohort and a given transaction.

   Once those exist a retention triangle is a pivot. The hard part is never the
   pivot; it is knowing whether the cohort dates mean anything, which is what
   10.1 and 10.2 are for.

   Why quarters. Section 9 found a median gap of 49 days and a 75th percentile
   of 99 days. A calendar month is shorter than the median, so on a monthly grid
   a customer buying at a normal cadence is absent from roughly half of all
   months by construction. A quarter is 91 days, just under the 75th percentile.
   ============================================================================ */

-- 10.1 The acquisition curve
-- The first thing to look at, and on this data it does not look like acquisition.
SELECT DATE_FORMAT(first_purchase, '%Y-%m') AS cohort_month,
       COUNT(*)                             AS new_customers
FROM (
    SELECT customer_id, MIN(trans_date) AS first_purchase
    FROM overall_data
    GROUP BY customer_id
) AS c
GROUP BY 1
ORDER BY 1;
/* 1,343 / 1,804 / 1,214 / 862 / 467 / 379 / 242 / 187 / 105 / 72 / 60 / 36 ...
   and 12 customers in total first appear from 2013 onwards, out of 6,884.

   A real business keeps acquiring. A smooth geometric decay to nothing is the
   signature of a file that opened on a customer base that already existed,
   where "first purchase in the file" means the first time an existing customer
   happened to surface. That is LEFT CENSORING. 10.2 tests it properly.        */


-- 10.2 The exponential arrival test
/* Gaps BETWEEN consecutive purchases are never censored - both ends are
   observed. So estimate each customer's purchase rate from their own internal
   gaps, then ask a counterfactual with no fitted parameters:

     if all 6,884 customers already existed on day 1, how many would first
     be SEEN in month 1, month 2, and so on?

   For a customer buying at rate lambda, P(not yet seen by day t) = EXP(-lambda*t).
   Summing across customers gives the expected number still unseen at each month
   boundary; the differences give expected first appearances per month.        */
WITH RECURSIVE months AS (
    SELECT 1 AS m
    UNION ALL
    SELECT m + 1 FROM months WHERE m < 14
),
gaps AS (
    SELECT customer_id,
           DATEDIFF(trans_date,
                    LAG(trans_date) OVER (PARTITION BY customer_id
                                          ORDER BY trans_date)) AS gap_days
    FROM overall_data
),
rates AS (
    SELECT customer_id, 1.0 / AVG(gap_days) AS lambda
    FROM gaps
    WHERE gap_days IS NOT NULL
    GROUP BY customer_id
),
edges AS (
    SELECT m,
           DATEDIFF(LAST_DAY(DATE_ADD('2011-05-01', INTERVAL m - 1 MONTH)),
                    '2011-05-16') + 1 AS days_elapsed
    FROM months
),
unseen AS (
    SELECT e.m,
           e.days_elapsed,
           SUM(EXP(-r.lambda * e.days_elapsed)) AS still_unseen
    FROM edges e
    CROSS JOIN rates r
    GROUP BY e.m, e.days_elapsed
),
observed AS (
    SELECT m, COUNT(*) AS observed_new
    FROM (
        SELECT customer_id,
               TIMESTAMPDIFF(MONTH, '2011-05-01', MIN(trans_date)) + 1 AS m
        FROM overall_data
        GROUP BY customer_id
    ) AS f
    GROUP BY m
)
SELECT u.m,
       u.days_elapsed,
       o.observed_new,
       ROUND(LAG(u.still_unseen, 1, 6884) OVER (ORDER BY u.m)
             - u.still_unseen, 0) AS predicted_if_all_pre_existing
FROM unseen u
LEFT JOIN observed o ON o.m = u.m
ORDER BY u.m;
/*  m  days  observed  predicted  ratio
    1    16     1,343      1,352   0.99
    2    46     1,804      1,823   0.99
    3    77     1,214      1,221   0.99
    4   108       862        796   1.08
    5   138       467        512   0.91
    6   169       379        357   1.06
    7   199       242        235   1.03
    8   230       187        168   1.11
    9   261       105        116   0.91
   10   290        72         77   0.94
   11   321        60         59   1.02
   12   351        36         41   0.88
   13   382        27         31   0.87
   14   412        28         22   1.27
   totals: observed 6,826 against predicted 6,810

   A model whose only assumption is that every customer already existed before
   the file opened reproduces the acquisition curve almost exactly, with no
   fitted parameters. These are not acquisition cohorts. They are arrival times
   of an already-active base, sorted by how often each customer happens to buy. */


-- 10.3 Mirror test: if lapses mirror arrivals, the panel is closed at both ends
SELECT DATE_FORMAT(last_purchase, '%Y-%m') AS lapse_month,
       COUNT(*)                            AS customers_last_seen
FROM (
    SELECT customer_id, MAX(trans_date) AS last_purchase
    FROM overall_data
    GROUP BY customer_id
) AS c
GROUP BY 1
ORDER BY 1 DESC
LIMIT 8;
-- 2015-03 1,302 | 2015-02 1,679 | 2015-01 1,244 | 2014-12 807 | 2014-11 596 ...
-- Only 38 customers in 6,884 make their final purchase before 2014, and 61.4%
-- have theirs in the last three months of the file. There is no churn here
-- either, only right censoring.


-- 10.4 Do later cohorts behave like genuinely newer customers?
SELECT DATE_FORMAT(first_purchase, '%Y-%m') AS cohort_month,
       COUNT(*)                             AS customers,
       ROUND(AVG(purchases
                 / GREATEST(DATEDIFF('2015-03-16', first_purchase) / 30.44, 1)), 3)
                                            AS purchases_per_exposed_month
FROM (
    SELECT customer_id,
           MIN(trans_date) AS first_purchase,
           COUNT(*)        AS purchases
    FROM overall_data
    GROUP BY customer_id
) AS c
GROUP BY 1
ORDER BY 1
LIMIT 10;
-- 0.427, 0.418, 0.426, 0.413, 0.417, 0.419, 0.410, 0.405 across the 2011
-- cohorts, then 0.375 and 0.380 for early 2012. No ramp-up, no difference in
-- kind. The customers who "arrive" later are slower buyers who took longer to
-- surface, not newer customers.


-- 10.5 The retention triangle
/* MySQL has no PIVOT, so this is conditional aggregation: one CASE per column.
   Pivoting in SQL is for reading the result here. 
   PARTIAL PERIODS. 2011Q2 is covered only from 16 May and 2015Q1 only to 16
   March. A partial calendar quarter does not sit in one row of a cohort grid -
   it runs down a DIAGONAL. March 2015 is period 15 for the first cohort, 14 for
   the second, 13 for the third. Masking only the bottom row would miss almost
   all of it, so both quarters are excluded wherever they land. The filter sits
   in the `cells` CTE, before aggregation, for that reason.                    */
WITH base AS (
    SELECT customer_id,
           tran_amount,
           MAKEDATE(YEAR(trans_date), 1)
             + INTERVAL (QUARTER(trans_date) - 1) QUARTER AS order_q
    FROM overall_data
),
cohort AS (
    SELECT customer_id, MIN(order_q) AS cohort_q
    FROM base GROUP BY customer_id
),
sizes AS (
    SELECT cohort_q, COUNT(*) AS cohort_size
    FROM cohort GROUP BY cohort_q
),
cells AS (
    SELECT c.cohort_q,
           TIMESTAMPDIFF(QUARTER, c.cohort_q, b.order_q) AS k,
           COUNT(DISTINCT b.customer_id) AS actives,
           SUM(b.tran_amount)            AS revenue
    FROM base b
    JOIN cohort c ON c.customer_id = b.customer_id
    WHERE b.order_q NOT IN ('2011-04-01', '2015-01-01')   -- partial quarters
    GROUP BY c.cohort_q, k
)
SELECT DATE_FORMAT(c.cohort_q, '%Y-%m') AS cohort,
       s.cohort_size,
       ROUND(MAX(CASE WHEN k = 1 THEN actives END)*100.0 / s.cohort_size, 1) AS q1,
       ROUND(MAX(CASE WHEN k = 2 THEN actives END)*100.0 / s.cohort_size, 1) AS q2,
       ROUND(MAX(CASE WHEN k = 3 THEN actives END)*100.0 / s.cohort_size, 1) AS q3,
       ROUND(MAX(CASE WHEN k = 4 THEN actives END)*100.0 / s.cohort_size, 1) AS q4,
       ROUND(MAX(CASE WHEN k = 5 THEN actives END)*100.0 / s.cohort_size, 1) AS q5,
       ROUND(MAX(CASE WHEN k = 6 THEN actives END)*100.0 / s.cohort_size, 1) AS q6,
       ROUND(MAX(CASE WHEN k = 7 THEN actives END)*100.0 / s.cohort_size, 1) AS q7,
       ROUND(MAX(CASE WHEN k = 8 THEN actives END)*100.0 / s.cohort_size, 1) AS q8
FROM cells c
JOIN sizes s ON s.cohort_q = c.cohort_q
WHERE s.cohort_size >= 100     -- below this a single customer moves a cell by
GROUP BY 1, 2                  -- more than a percentage point
ORDER BY 1;
/* retention %, by cohort and quarters of tenure
   cohort   n      q1    q2    q3    q4    q5    q6    q7    q8
   2011-04  3,147  69.7  68.4  70.0  68.6  69.5  69.4  70.0  70.0
   2011-07  2,543  68.5  69.2  68.2  69.7  68.6  69.4  69.6  70.8
   2011-10    808  66.2  65.2  69.6  67.6  68.8  68.8  69.7  68.6
   2012-01    237  61.2  62.4  64.6  62.9  61.2  62.9  70.9  64.6
   Read across a row: no decay anywhere. 10.7 says what that means.            */
 
 
-- 10.6 Revenue per surviving customer
/* Same grid, different measure: spend in the quarter divided by the customers
   actually ACTIVE in it, not by the original cohort size. That separates
   retention from spend. Dividing by cohort size instead would fold the two
   together, which is what you want for a payback curve and not for this.      */
WITH base AS (
    SELECT customer_id,
           tran_amount,
           MAKEDATE(YEAR(trans_date), 1)
             + INTERVAL (QUARTER(trans_date) - 1) QUARTER AS order_q
    FROM overall_data
),
cohort AS (SELECT customer_id, MIN(order_q) AS cohort_q FROM base GROUP BY customer_id),
sizes  AS (SELECT cohort_q, COUNT(*) AS cohort_size FROM cohort GROUP BY cohort_q),
cells  AS (
    SELECT c.cohort_q,
           TIMESTAMPDIFF(QUARTER, c.cohort_q, b.order_q) AS k,
           COUNT(DISTINCT b.customer_id) AS actives,
           SUM(b.tran_amount)            AS revenue
    FROM base b
    JOIN cohort c ON c.customer_id = b.customer_id
    WHERE b.order_q NOT IN ('2011-04-01', '2015-01-01')
    GROUP BY c.cohort_q, k
)
SELECT DATE_FORMAT(c.cohort_q, '%Y-%m') AS cohort,
       s.cohort_size,
       ROUND(MAX(CASE WHEN k=1 THEN revenue END) / MAX(CASE WHEN k=1 THEN actives END), 1) AS q1,
       ROUND(MAX(CASE WHEN k=2 THEN revenue END) / MAX(CASE WHEN k=2 THEN actives END), 1) AS q2,
       ROUND(MAX(CASE WHEN k=3 THEN revenue END) / MAX(CASE WHEN k=3 THEN actives END), 1) AS q3,
       ROUND(MAX(CASE WHEN k=4 THEN revenue END) / MAX(CASE WHEN k=4 THEN actives END), 1) AS q4,
       ROUND(MAX(CASE WHEN k=5 THEN revenue END) / MAX(CASE WHEN k=5 THEN actives END), 1) AS q5,
       ROUND(MAX(CASE WHEN k=6 THEN revenue END) / MAX(CASE WHEN k=6 THEN actives END), 1) AS q6,
       ROUND(MAX(CASE WHEN k=7 THEN revenue END) / MAX(CASE WHEN k=7 THEN actives END), 1) AS q7,
       ROUND(MAX(CASE WHEN k=8 THEN revenue END) / MAX(CASE WHEN k=8 THEN actives END), 1) AS q8
FROM cells c
JOIN sizes s ON s.cohort_q = c.cohort_q
WHERE s.cohort_size >= 100
GROUP BY 1, 2
ORDER BY 1;
/* revenue per active customer, by cohort and quarters of tenure
   cohort   n       q1     q2     q3     q4     q5     q6     q7     q8
   2011-04  3,147  115.8  116.0  113.9  114.2  113.9  116.9  111.9  114.6
   2011-07  2,543  113.6  112.0  110.5  114.3  110.3  111.3  111.7  114.2
   2011-10    808  110.3  114.9  103.9  110.5  102.4  111.0  114.1  112.4
   2012-01    237   90.7   99.0  105.7  105.0  100.3   96.5   92.1  103.2
 
   Flat across every row, and the only real movement is DOWN the first column,
   from 116 to 91. That is not tenure. It is the slow-buyer selection the
   arrival test exposed: later "cohorts" have smaller baskets and fewer
   purchases because they were low-frequency customers all along, which is
   exactly why they surfaced later.                                            */
 
 
-- 10.7 The comparison that makes the triangle interpretable
/* A retention figure only means something next to the rate you would get by
   picking customers at random. If cohort retention equals the unconditional
   share of the base active in a quarter, cohort membership carries no
   information at all.                                                         */
WITH base AS (
    SELECT customer_id,
           MAKEDATE(YEAR(trans_date), 1)
             + INTERVAL (QUARTER(trans_date) - 1) QUARTER AS order_q
    FROM overall_data
),
cohort AS (SELECT customer_id, MIN(order_q) AS cohort_q FROM base GROUP BY customer_id),
sizes  AS (SELECT cohort_q, COUNT(*) AS cohort_size FROM cohort GROUP BY cohort_q),
cells  AS (
    SELECT c.cohort_q, s.cohort_size,
           TIMESTAMPDIFF(QUARTER, c.cohort_q, b.order_q) AS k,
           COUNT(DISTINCT b.customer_id) AS actives
    FROM base b
    JOIN cohort c ON c.customer_id = b.customer_id
    JOIN sizes s  ON s.cohort_q    = c.cohort_q
    WHERE b.order_q NOT IN ('2011-04-01', '2015-01-01')
      AND s.cohort_size >= 100
    GROUP BY c.cohort_q, s.cohort_size, k
),
cohort_rate AS (
    -- size-weighted mean retention across cohorts, k >= 1
    SELECT ROUND(SUM(actives) * 100.0 / SUM(cohort_size), 1) AS cohort_retention_pct
    FROM cells WHERE k >= 1
),
base_rate AS (
    -- unconditional share of the whole base active in a full quarter
    SELECT ROUND(AVG(active_share) * 100, 1) AS unconditional_active_pct
    FROM (
        SELECT MAKEDATE(YEAR(trans_date), 1)
                 + INTERVAL (QUARTER(trans_date) - 1) QUARTER AS q,
               COUNT(DISTINCT customer_id) * 1.0 / 6884 AS active_share
        FROM overall_data
        GROUP BY q
        HAVING q NOT IN ('2011-04-01', '2015-01-01')
    ) AS quarters
)
SELECT * FROM cohort_rate CROSS JOIN base_rate;
-- 68.9% against 68.7%. The two are the same number.
 
 
/* ----------------------------------------------------------------------------
   CONCLUSION
 
   Retention is flat and sits exactly on the base rate: 68.9% size-weighted
   across cohorts from the first quarter onward, against an unconditional 68.7%
   of the whole base active in any full quarter. Knowing which cohort a customer
   belongs to, and how long they have been a customer, says nothing about
   whether they buy this quarter.
 
   Revenue per active customer in 10.6 is flat within each cohort and varies
   only between them, from about 114 in the first cohort down to 91 in 2012Q1.
   That is not a tenure effect. It is the same slow-buyer selection the arrival
   test exposed: later "cohorts" have smaller baskets and fewer purchases
   because they were low-frequency customers all along, which is precisely why
   they surfaced later.
 
   The acquisition cohorts are fully left-censored - not merely the early ones.
   The usual fix is a washout period, discarding cohorts formed inside the first
   W months, where W is three to four times the typical gap. The 90th percentile
   gap here is 167 days, so W would need to be fifteen to eighteen months, which
   leaves cohorts of fewer than ten customers. The fix is correct and this data
   does not survive it. The second standard fix, using a real signup date from
   another table, has no table to draw on here.
 
   What this contributes beyond Sections 7 and 9: those showed the data is flat
   over time. This section shows something structural. There is no acquisition
   and no churn, the customer base is fixed and closed at both ends, and every
   customer is present throughout. No real retailer's data behaves that way.
   ---------------------------------------------------------------------------- */
 
 
/* ============================================================================
   11. SUMMARY
 
   Customers divide into three spending tiers. P0 is 27.7% of customers and
   40.5% of revenue, P1 is 42.2% and 43.9%, P2 is 30.1% and 15.6%. The tiers are
   a banding of a continuum rather than three distinct kinds of customer.
 
   The campaign is worth targeting. P0 contains 50.9% of responders while being
   27.7% of the base, a lift of 1.84x. P2 returns 0.23x and should be excluded
   from broad mailings.
 
   Purchase cadence gives the one directly operational number: 75% of repeat
   purchases fall within 99 days, which sets a reactivation trigger, adjusted
   per segment.
 
   Cohort retention is flat and sits on the base rate, 68.9% against an
   unconditional 68.7%. Cohort membership and tenure carry no information about
   whether a customer buys in a given quarter.
 
   Sales show no trend, no seasonality and no volatility once monthly figures
   are divided by days covered.
 
   ----------------------------------------------------------------------------
   LIMITATIONS
 
   - Revenue per day is constant to within 2.3% across 47 months, every calendar
     month falls between 87.9 and 90.3 transactions per day, and average
     transaction value moves by half a percent across five years. Section 10
     makes the case structurally rather than by flatness: there is no
     acquisition and no churn. An arrival model assuming every customer already
     existed before the file opened predicts 6,810 first appearances against
     6,826 observed, and only 38 customers in 6,884 stop buying before 2014.
     Together with the recency reversal in Section 3, this indicates the data is
     generated rather than observed. The work here demonstrates method rather
     than describing a real business.
   - The acquisition cohorts are fully left-censored, not merely the early ones.
     The standard washout fix would leave cohorts of fewer than ten customers,
     so it is stated rather than applied. The far end is right-censored for the
     same reason, so any survival estimate would measure the observation window
     rather than customer behaviour.
   - The segments are a banding, not a discovery. Purchase count and total spend
     are two views of the same behaviour.
   - Both end months are partial, covering 16 days each.
   - The campaign response flag has no date, so response cannot be tracked over
     time or attributed to a specific campaign.
   - Recency behaves backwards against response, the opposite of what RFM
     practice assumes.
   - The 12-month value estimate contains no churn term.
   - No causal claims are supported. Segment membership is derived from the same
     purchase behaviour it is then used to describe.
   - No currency or unit is given in the source data.
 
   ----------------------------------------------------------------------------
   FURTHER WORK
 
   Cohort retention split by campaign response would connect Section 10 to the
   lift work in Section 6: whether responders retain differently from
   non-responders. On this data it would show nothing, for the reasons above,
   but it is the next question the analysis invites.
 
   The diagnostics in Section 10 are reusable as they stand. On a dataset with
   genuine acquisition, the arrival test, the mirror test and the base-rate
   comparison would separate a retention problem from an acquisition problem
   rather than exposing a generated file.
   ============================================================================ */
 