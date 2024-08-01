use retailsalesdata;

### CUSTOMER KEY INSIGHTS
#How many unique customers are there?
SELECT COUNT(DISTINCT customer_id) AS unique_customer
FROM overall_data;
# Number of unique customers are 6,884.

#What is the average transaction amount per customer? 
SELECT AVG(tran_amount) AS avg_transaction_amount
FROM overall_data;
# Average transaction amount is 64.9951

#What is the average spend per customer? 
SELECT AVG(total_spent) AS average_spend
FROM (
    SELECT customer_id, SUM(tran_amount) AS total_spent
    FROM overall_data
    GROUP BY customer_id
) AS customer_totals;
# Average spend per customer is 1179.9

#Top 5 customers who made highest number of transactions? 
SELECT customer_id, COUNT(*) AS transaction_count
FROM overall_data
GROUP BY customer_id
ORDER BY 2 DESC
LIMIT 5;
# Customer CS4424(39), CS4320(38), CS3799(36), CS5109(35) & CS3013(35) has highest orders number of orders.

#Top 5 customers who have spent the most money? 
SELECT customer_id, SUM(tran_amount) AS total_spent
FROM overall_data
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5;
/*Customer CS4424(2933), CS4320(2647), CS5752(2612), CS4660(2527) & CS3799(2513) spend the most. 
Customers CS4424 and CS4320 have the highest number of orders and the highest spending, 
indicating strong engagement and consistent high-value purchases. Customers CS5752 and CS4660, 
despite having fewer transactions, have high order values, leading to significant total spending. 
This suggests varied purchasing patterns, with some customers making frequent smaller purchases and others
 making infrequent but large purchases.*/

### RFM ANALYSIS
/* Where the segments are divided as follows:
The categorization of recency, frequency, and monetary is as follows:

Recency:
- Recent: Customers whose last transaction was within the last 200 days.
- Medium:Customers whose last transaction was between 201 and 400 days ago.
- Old: Customers whose last transaction was more than 400 days ago.

### Frequency:
- Frequent: Customers with 25 or more transactions.
- Medium: Customers with 10 to 24 transactions.
- Infrequent: Customers with fewer than 10 transactions.

### Monetary:
- High Value: Customers whose total spending is 2000 or more.
- Medium: Customers whose total spending is between 1000 and 1999.
- Low Value: Customers whose total spending is less than 1000.
*/
#How do different customer segments behave? 
WITH Latest_date as(
SELECT MAX(trans_date) as latest_date
FROM overall_data)

SELECT
    recency_segment,
    frequency_segment,
    monetary_segment,
    COUNT(*) AS customer_count
FROM (
    SELECT
        o.customer_id,
        CASE
            WHEN DATEDIFF(lt.latest_date, MAX(o.trans_date)) <= 200 THEN 'Recent'
            WHEN DATEDIFF(lt.latest_date, MAX(o.trans_date)) <= 400 THEN 'Medium'
            ELSE 'Old'
        END AS recency_segment,
        CASE
            WHEN rfm.frequency >= 25 THEN 'Frequent'
            WHEN rfm.frequency >= 10 THEN 'Medium'
            ELSE 'Infrequent'
        END AS frequency_segment,
        CASE
            WHEN rfm.monetary >= 2000 THEN 'High Value'
            WHEN rfm.monetary >= 1000 THEN 'Medium'
            ELSE 'Low Value'
        END AS monetary_segment
    FROM overall_data o
    JOIN rfm ON rfm.customer_id = o.customer_id
    CROSS JOIN Latest_date lt
    GROUP BY o.customer_id
) AS segments
GROUP BY 1,2,3
ORDER BY 4 DESC;
 /*The Recent-Medium-Medium Value segment is the largest, indicating a significant number
 of customers with moderate spending and recent transactions. The Recent-Medium-Low Value and 
 Recent-Frequent-Medium Value segments also show substantial customer counts, suggesting a mix of 
 medium and high-frequency customers with varying spending levels. Medium and Old segments have fewer 
 customers, especially in high-value categories, highlighting a decline in engagement and spending over time. 
 Overall, recent and medium-frequency customers dominate, with a notable presence in medium spending categories.*/

#Which customer segments are growing or shrinking over time? 
WITH Customer_Yearly_Transactions AS (
    SELECT 
        customer_id,
        YEAR(trans_date) AS year,
        MAX(trans_date) AS last_trans_date
    FROM overall_data
    WHERE YEAR(trans_date) < 2015
    GROUP BY customer_id, year
),
Customer_Segments AS (
    SELECT 
        c.customer_id,
        c.year,
        CASE
            WHEN rfm.frequency >= 25 THEN 'Frequent'
            WHEN rfm.frequency >= 10 THEN 'Medium'
            ELSE 'Infrequent'
        END AS frequency_segment,
        CASE
            WHEN rfm.monetary >= 2000 THEN 'High'
            WHEN rfm.monetary >= 1000 THEN 'Medium'
            ELSE 'Low'
        END AS monetary_segment
    FROM rfm
    JOIN Customer_Yearly_Transactions c ON c.customer_id = rfm.customer_id
),
Segment_Counts AS (
    SELECT
        year,
        frequency_segment,
        monetary_segment,
        COUNT(DISTINCT customer_id) AS customer_count
    FROM Customer_Segments
    GROUP BY year, frequency_segment, monetary_segment
)
SELECT
    year,
    frequency_segment,
    monetary_segment,
    customer_count,
    SUM(customer_count) OVER (PARTITION BY year ORDER BY frequency_segment, monetary_segment) AS cumulative_count
FROM Segment_Counts
WHERE year < 2015
ORDER BY year, frequency_segment, monetary_segment;
/*Excluding 2015 data, the Medium-Medium and Medium-Low Value segments showed growth from 2011 to 2013,
 with slight stabilization in 2014. The Frequent-High and Frequent-Medium Value segments remained stable
 throughout 2011-2014. The Infrequent-Low Value segment experienced minor fluctuations but overall stability. 
 Overall, medium-value segments show growth, while high-frequency segments maintain consistent engagement.
*/

#What is the response rate of each recency segment? 
WITH Latest_date AS (
    SELECT MAX(trans_date) AS latest_date
    FROM overall_data
)
SELECT recency_segment,AVG(response)*100 AS response_rate
FROM(SELECT customer_id,
    CASE
            WHEN DATEDIFF(latest_date, MAX(trans_date)) <= 200 THEN 'Recent'
            WHEN DATEDIFF(latest_date, MAX(trans_date)) <= 400 THEN 'Medium'
            ELSE 'Old'
        END AS recency_segment,
    response 
FROM overall_data
CROSS JOIN Latest_date
GROUP BY customer_id) as recency_response
GROUP BY 1
ORDER BY 1;
/*
The response rate is highest for Recent customers at 9.55%, 
followed by Medium customers at 8.54%. The Old segment has the lowest response rate at 1.52%.
Efforts should be focused on retaining and engaging Recent and Medium customers for better campaign performance. */


#Which RFM segment contributes the most to total revenue? 
WITH Latest_date as(
SELECT MAX(trans_date) as latest_date
FROM overall_data)
SELECT
    recency_segment,
    frequency_segment,
    monetary_segment,
    SUM(tran_amount) AS total_revenue
FROM(
SELECT 
    o.customer_id,
    CASE
            WHEN DATEDIFF(latest_date, MAX(trans_date)) <= 200 THEN 'Recent'
            WHEN DATEDIFF(latest_date, MAX(trans_date)) <= 400 THEN 'Medium'
            ELSE 'Old'
        END AS recency_segment,
        CASE
            WHEN rfm.frequency >= 25 THEN 'Frequent'
            WHEN rfm.frequency >= 10 THEN 'Medium'
            ELSE 'Infrequent'
        END AS frequency_segment,
        CASE
            WHEN rfm.monetary >= 2000 THEN 'High Value'
            WHEN rfm.monetary >= 1000 THEN 'Medium'
            ELSE 'Low Value'
        END AS monetary_segment,
		tran_amount
FROM overall_data o
JOIN rfm on rfm.customer_id=o.customer_id
CROSS JOIN Latest_date
GROUP BY o.customer_id) AS subquery
GROUP BY recency_segment, frequency_segment, monetary_segment
ORDER BY total_revenue DESC;
/*The 'Recent, Medium, Medium' segment generates the highest revenue(246,656), 
indicating that recent customers with medium frequency and medium monetary value are most valuable.
 The next significant segments are "Recent, Medium Frequency, Low Value" (90,596) 
 and "Recent, Frequent, Medium Value" (39,765).Medium and Old recency segments contribute comparatively less,
 with the highest among them being "Medium, Medium Frequency, Medium Value" at 14,973.
 Recent customers with medium frequency and medium value represent a key target group for maximizing revenue.*/
 
### BEHAVIOR AND PERFORMANCE BY SEGMENT
#How many unique customers are there in each segment? 
SELECT segment, COUNT(DISTINCT customer_id) AS unique_customers
FROM Overall_data
GROUP BY segment
ORDER BY unique_customers DESC;
# P1 has bigger unique customer base of 2915 than P2(2493) and P0(1476).

#What is the average transaction amount by segment? 
SELECT segment, AVG(tran_amount) AS avg_transaction_amount
FROM overall_data
GROUP BY 1
ORDER BY 2 DESC;
# P0 has the highest average transaction amount of 70.75 followed by P1(68.5) & P2(52.23).

#Which segment has the highest average frequency of purchases? 
SELECT segment, AVG(frequency) AS avg_frequency
FROM Overall_data
JOIN rfm on overall_data.customer_id=rfm.customer_id
GROUP BY segment
ORDER BY avg_frequency DESC;
# P0 has highest average frequency of 25.5 followed by P1(19.3) & P2(13.46).

#What is the average monetary of different segments? 
SELECT segment, AVG(monetary) AS avg_monetary
FROM Overall_data
JOIN rfm on overall_data.customer_id=rfm.customer_id
GROUP BY segment
ORDER BY avg_monetary DESC;
# P0 has Higher average monetary value of 1802.6 over P1(1316.6) and p2(703.8).

#Which segment has the most consistent average order value over time? 
SELECT segment, STDDEV(Average_Order_Value) AS order_value_stddev
FROM Overall_data
GROUP BY segment
ORDER BY order_value_stddev ASC;
/* 
Segment P0 has the most consistent average order value with the lowest standard
 deviation of 4.03. Segment P1 shows moderate consistency with a standard deviation 
 of 7.24. Segment P2 has the highest standard deviation of 12.72, indicating the most
 variation in average order value.*/

/* Segment P0 is the most valuable with the highest monetary power,
 frequency of purchase, and the highest average order value. Despite its high average 
 order value, it has the most consistent spending behavior, as indicated by the lowest
 standard deviation. This suggests that customers in P0 have stable and predictable spending 
 patterns.
 Segment P1 has a medium level of monetary power and purchase frequency, with a moderate 
 average order value and consistency in spending. It has a larger customer base than P0 but
 less consistent order values than P0.
 Segment P2 has the lowest monetary power and purchase frequency, with the smallest average 
 order value and the most variability in spending. The high standard deviation reflects 
 significant fluctuations in spending among its customers.*/

### CAMPAIGN PERFORMANCE
#What is the overall response rate to the campaign? 
SELECT AVG(response)*100 AS response_rate
FROM overall_data;
# Only 11% responded positively to the campaign.

#Which customer segments respond best to campaigns? 
SELECT segment, AVG(response)*100 AS response_rate
FROM overall_data
GROUP BY segment;
/* P0 segment has higher response rate(18%) than P1(11%) and P2(3.3%). This indicates that
 the campaign resonates more with high spenders in segment P0, despite the relatively modest
 response rate, suggesting a more targeted or appealing approach could further engage this 
 valuable customer group.*/

#How has the campaign performance changed over time? 
SELECT 
    YEAR(trans_date) AS year,
    AVG(response)*100 AS response_rate
FROM overall_data
GROUP BY 1
ORDER BY 1;
/* The campaign performance significantly improved from 2011 to 2014, with response rates consistently above 10%.
Excluding 2015 data, the trend shows a positive impact of the campaigns during these years.*/

### TRENDS AND SEASONALITY
#What is the top 5 dates having highest transaction amount? 
SELECT trans_date, SUM(tran_amount) AS avg_transaction_amount
FROM overall_data
GROUP BY trans_date
ORDER BY 2 DESC
LIMIT 5;
/*The top transaction dates show high customer activity in 2011 and mid-2014,
 indicating successful campaigns or events. Analyzing these periods can help replicate 
 their success with targeted future marketing strategies.*/

#When do transactions peak(yearly)? 
SELECT year(trans_date) as Year, COUNT(*) AS transaction_count
FROM overall_data
GROUP BY 1
ORDER BY 2 DESC;
# 2013 seems to have highest transaction count(32900),followed by 2012 & 2014

#When do transactions peak(monthly)?
SELECT monthname(trans_date) as month, COUNT(*) AS transaction_count
FROM overall_data
GROUP BY month(trans_date)
ORDER BY month(trans_date) ;
/*Month of August has highest transaction count of 11195 followed by October(11175) & July(11033) 
indicating seasonal or promotional influences. April has lowest transaction count of 7973.*/

#What is the trend in average transaction amounts?
SELECT 
    YEAR(trans_date) AS year,
    AVG(tran_amount) AS average_transaction_amount
FROM overall_data
GROUP BY 1
ORDER BY 1;
/* The average transaction amount exhibits a stable and consistent trend around 65 from 2011 to 2015.
The spending behavior of customers remains steady without significant fluctuations throughout the years analyzed.*/

### CLV INSIGHTS
#1What is the maximum and minimum customer lifetime value? 
SELECT max(lifetime_value)as max_lifetime_value,
min(lifetime_value)as min_lifetime_value 
FROM(
SELECT customer_id, clv AS lifetime_value
FROM overall_data
GROUP BY customer_id
ORDER BY lifetime_value DESC) as lifetime_value;
# Maximum CLV is 1716 and minimum clv is 524.23

#What is the total customer lifetime value (CLV) for each segment? 
SELECT segment, SUM(clv) AS total_clv
FROM Overall_data
GROUP BY segment
ORDER BY total_clv DESC;
# P1 has the highest total CLV of 74,771,322.94 followed by P0(51,770,937.67) & P2(32,932,226.57).

#Which segment has the highest average CLV? 
SELECT segment, AVG(clv) AS avg_clv
FROM Overall_data
GROUP BY segment
ORDER BY avg_clv DESC;
# P0 has the highest average CLV of 1389 followed by P1(1345.27) & P2(1025.42).
/* P1 customers, with the highest total CLV, significantly contribute to overall revenue
 due to their medium monetary power and frequency. P0 customers, despite being fewer,
 have the highest average CLV, indicating high individual value and loyalty. 
 P2 customers, with the lowest total and average CLV, offer growth opportunities 
 through engagement and targeted strategies.*/

### CONSECUTIVE TRANSACTION ANALYSIS
#How many customers have made consecutive transactions ?
SELECT COUNT(customer_id)  AS customers_with_consecutive_orders 
FROM(
SELECT customer_id, COUNT(*) AS consecutive_transactions
FROM (
    SELECT customer_id, trans_date,
           LAG(trans_date) OVER (PARTITION BY customer_id ORDER BY trans_date) AS prev_trans_date
    FROM Overall_data
) AS subquery
GROUP BY customer_id
ORDER BY consecutive_transactions DESC) AS C;
# Total number of customers with consecutive transactions is 6884.

#What is the average time between consecutive transactions for each segment?
SELECT AVG(DATEDIFF(trans_date, prev_trans_date)) AS avg_days_between
FROM (
    SELECT customer_id, segment, trans_date,
           LAG(trans_date) OVER (PARTITION BY customer_id ORDER BY trans_date) AS prev_trans_date
    FROM Overall_data
) AS subquery
WHERE prev_trans_date IS NOT NULL;
# Average time between consecutive transaction is 72.3736.

#How many customers in each segment have made at least one consecutive transaction?
SELECT segment, COUNT(DISTINCT customer_id) AS no_customers_with_consecutive_txn
FROM (
    SELECT customer_id, segment, trans_date,
           LAG(trans_date) OVER (PARTITION BY customer_id ORDER BY trans_date) AS prev_trans_date
    FROM Overall_data
) AS subquery
WHERE DATEDIFF(trans_date, prev_trans_date) <= 30
GROUP BY segment
ORDER BY 2 DESC;
# P1(2913) has most customers with consecutive transaction followed by P2(2341) & P0(1476).

# What is the average time between consecutive transactions for each segment?
SELECT segment, AVG(DATEDIFF(trans_date, prev_trans_date)) AS avg_days_between
FROM (
    SELECT customer_id, segment, trans_date,
           LAG(trans_date) OVER (PARTITION BY customer_id ORDER BY trans_date) AS prev_trans_date
    FROM Overall_data
) AS subquery
WHERE prev_trans_date IS NOT NULL
GROUP BY segment
ORDER BY avg_days_between ASC;
# P0(53) has lowest average time between consecutive transactions followed by P1(70) & P2(100).

/* Segment P0 has highly engaged customers who make repeat purchases more frequently and
consistently, as reflected by the lowest average time between transactions.
Segment P1 has the most customers with consecutive transactions but with a moderate average
time between transactions, indicating somewhat less frequent repeat purchases compared to P0.
Segment P2 has fewer customers with consecutive transactions and a longer average time between
transactions, suggesting less frequent repeat purchases and possibly lower engagement compared to P0 and P1.*/














