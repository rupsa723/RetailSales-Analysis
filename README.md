# README

## Contents
- [Overview](#overview)
- [Files](#files)
- [Data Overview](#data-overview)
  - [Data Cleaning](#data-cleaning)
  - [Descriptive Statistics](#descriptive-statistics)
  - [Exploratory Data Analysis (EDA)](#exploratory-data-analysis-eda)
  - [Feature Engineering](#feature-engineering)
  - [Customer Segmentation](#customer-segmentation)
  - [Time Series Analysis](#time-series-analysis)
  - [Customer Lifetime Value (CLV) Analysis](#customer-lifetime-value-clv-analysis)
  - [Hypothesis Testing](#hypothesis-testing)
- [SQL Analysis Insights](#sql-analysis-insights)
  - [Customer Key Insights](#customer-key-insights)
  - [RFM Analysis](#rfm-analysis)
  - [Behavior and Performance by Segment](#behavior-and-performance-by-segment)
  - [Campaign Performance](#campaign-performance)
  - [Trends and Seasonality](#trends-and-seasonality)
  - [Customer Lifetime Value (CLV) Insights](#customer-lifetime-value-clv-insights)
  - [Consecutive Transaction Analysis](#consecutive-transaction-analysis)
- [Conclusion](#conclusion)
- [SWOT Analysis](#swot-analysis)
- [Recommendations](#recommendations)
- [Future Steps](#future-steps)
- [Contact Information](#contact-information)
## Overview
This project analyzes retail transaction data to understand customer behavior, identify transaction trends, evaluate campaign effectiveness, and perform customer segmentation. The analysis was conducted using Python for data cleaning, feature engineering, customer segmentation, time series analysis, CLV (Customer Lifetime Value) analysis, and hypothesis testing, followed by SQL for further data manipulation and insights extraction.

## Files
- `Original Dataset`: Folder consisting of original dataset obtailed from [Retail Dataset](https://www.kaggle.com/datasets/regivm/retailtransactiondata).
- `Retailsales python script.ipynb`: Consist of .ipynb file of data cleaning and manipulation.
- `Prepared dataset`: Folder containing datasets obtained after all cleaning and manipulation which consist of `overall_data.csv`,`main_data.csv` & `rfm.csv`.
- `Retailsales sql script.sql`: Consist of .sql file of further data manipulation and insights extraction.
- `Retail Sales Data Report.pptx`: Consist of the report based on the information obtained about the dataset.
## Data Overview
The dataset contains the original dataset in `Orginal Dataset` folder:
- `Retail_Data_Transaction.csv`:
  - `customer_id`: Identifier for customers.
  - `trans_date`: Date of the transaction.
  - `tran_amount`: Amount of the transaction.
- `Retail_Data_Response.csv`:
  - `customer_id`: Identifier for customers.
  - `response`: Customer's response (binary).

**Initial Data Checks:**
- Shape: 125,000 rows and 4 columns.
- Data Types:
  - `customer_id`: Object.
  - `trans_date`: Object (converted to datetime).
  - `tran_amount`: Integer.
  - `response`: Float (converted to integer).

## Data Cleaning
**Handling Missing Values:**
- The response column had 31 null values (0.25% of the dataset), which were dropped.

**Data Type Conversions:**
- `trans_date` was converted to datetime.
- `response` was converted to integer.

**Outlier Detection:**
- **Box Plots:** No outliers detected in `tran_amount` and `response`.
  
## Descriptive Statistics
**Transaction Amount:**
- Mean: 64.99
- Standard Deviation: 22.86
- Min: 10
- Max: 105

**Response:**
- Mean: 0.11
- Standard Deviation: 0.31
- Min: 0
- Max: 1

## Exploratory Data Analysis (EDA)
- **Distribution of Transaction Amounts:** Most transactions range between 40 and 100.
- **Distribution of Response:** Binary distribution with counts for 0 and 1.
- **Distribution of Frequency:** Histogram of transaction frequencies per customer.
- **Distribution of Monetary:** Histogram of total monetary values per customer.

## Feature Engineering
A new dataset was created with:
- `customer_id`: Identifier for customers.
- `recency`: Date of the most recent transaction.
- `frequency`: Number of transactions.
- `monetary`: Total amount spent.

**Process:**
- Grouped the data by `customer_id`.
- Calculated recency as the maximum `trans_date` for each customer.
- Calculated frequency as the count of `trans_date` for each customer.
- Calculated monetary as the sum of `tran_amount` for each customer.

## Customer Segmentation
**Method:** K-means clustering on standardized features (frequency and monetary).

**Segments:**
- P0: High frequency and high monetary value.
- P1: Medium frequency and medium monetary value.
- P2: Low frequency and low monetary value.

## Time Series Analysis
**Objective:** Analyze sales trends over time.

**Findings:**
- **Overall Trend:** Relatively stable sales with minor fluctuations.
- **Seasonality:** No clear seasonal pattern; fluctuations appear random.
- **Outliers:** Drops in sales around January 2013 and May 2015.
- **End of Series:** Sharp decline in May 2015.
- **Volatility:** Periodic dips and peaks indicating some level of volatility in monthly sales figures.

## Customer Lifetime Value (CLV) Analysis
**Method:** Calculate average order value, purchase frequency, and churn rate.

**Findings:**
- **Distribution of CLV:** Two peaks indicating segments with lower and higher CLV.
- **Segment Analysis:**
  - P0: High CLV.
  - P1: Medium CLV.
  - P2: Low CLV.

## Hypothesis Testing
**Chi-Square Test for Independence**
- **Objective:** Test the relationship between customer segment and response.
- **Results:**
  - Chi-Square Statistic: 3726.525
  - P-value: 0.0
  - Conclusion: Significant relationship between customer segment and response, indicating dependency.

**ANOVA (Analysis of Variance)**
- **Objective:** Compare the means of transaction amounts across different customer segments.
- **Results:**
  - F-statistic: 7691.416
  - P-value: 0.0
  - Conclusion: Significant difference in mean transaction amount across segments.

## SQL Analysis Insights
### Customer Key Insights
- **Unique Customers:** There are 6,884 unique customers.
- **Average Transaction Amount per Customer:** 64.99
- **Average Spend per Customer:** 1,179.9
- **Top 5 Customers by Transaction Count:** Customers CS4424 (39), CS4320 (38), CS3799 (36), CS5109 (35), and CS3013 (35).
- **Top 5 Customers by Total Spend:** Customers CS4424 (2,933), CS4320 (2,647), CS5752 (2,612), CS4660 (2,527), and CS3799 (2,513).

### RFM Analysis
- **Largest Customer Segment:** The 'Recent, Medium, Medium Value' segment is the largest.
- **Customer Segment Trends:** Medium-value segments show growth, while high-frequency segments maintain consistent engagement from 2011 to 2014.
- **Response Rate by Recency Segment:** Recent customers have the highest response rate (9.55%), followed by Medium (8.54%), and Old (1.52%).
- **Revenue Contribution by RFM Segment:** The 'Recent, Medium, Medium Value' segment generates the highest revenue ($246,656).

### Behavior and Performance by Segment
- **Unique Customers by Segment:** Segment P1 has the largest unique customer base (2,493).
- **Average Transaction Amount by Segment:** Segment P0 has the highest average transaction amount (70.75).
- **Average Frequency of Purchases by Segment:** Segment P0 has the highest average frequency (25.5).
- **Average Monetary Value by Segment:** Segment P0 has the highest average monetary value (1,802.6).
- **Consistency in Average Order Value:** Segment P0 has the most consistent average order value with the lowest standard deviation (4.03).

### Campaign Performance
- **Overall Response Rate:** 11% of customers responded positively to the campaign.
- **Response Rate by Segment:** Segment P0 has the highest response rate (18%).
- **Campaign Performance Over Time:** Improved campaign performance from 2011 to 2014, with response rates consistently above 10%.

### Trends and Seasonality
- **Top Transaction Dates:** High customer activity in 2011 and mid-2014.
- **Peak Transaction Year:** 2013 has the highest transaction count (32,900).
- **Peak Transaction Month:** August has the highest transaction count (11,195).
- **Average Transaction Amount Trend:** Stable and consistent around $65 from 2011 to 2015.

### Customer Lifetime Value (CLV) Insights
- **Maximum and Minimum CLV:** Maximum CLV is 1,716, and minimum CLV is 524.23.
- **Total CLV by Segment:** Segment P1 has the highest total CLV (74,771,322.94).
- **Average CLV by Segment:** Segment P0 has the highest average CLV (1,389).

### Consecutive Transaction Analysis
- **Customers with Consecutive Transactions:** All 6,884 customers have made consecutive transactions.
- **Average Time Between Consecutive Transactions:** 72.37 days.
- **Customers with Consecutive Transactions by Segment:** Segment P1 (2,913) has the most customers with consecutive transactions.
- **Average Time Between Consecutive Transactions by Segment:** Segment P0 has the lowest average time (53 days).

## Conclusion
The analysis provided detailed insights into customer behavior, segment performance, and campaign effectiveness. It highlighted the most valuable customer segments, trends in transaction amounts, and the effectiveness of marketing campaigns. These insights can help in formulating targeted strategies to enhance customer engagement, maximize revenue, and improve campaign performance.

## SWOT Analysis
**Strengths:**
- High-value customers (P0) show strong engagement and high transaction amounts.
- Segment P0 has the shortest average time between consecutive transactions (53 days), indicating strong engagement.
- Stable average spending of around $65.
- Recent and medium-frequency segments contribute significantly to revenue and show higher engagement.

**Weaknesses:**
- Low overall campaign response rate of 11%.
- Segment P2 has low engagement and value, with the longest average time between consecutive transactions (100 days).
- Variability in CLV among segments suggests inconsistent customer value.
- April has the lowest transaction count (7,973), suggesting a potential seasonal dip.

**Opportunities:**
- Target Segment P2 with personalized marketing to boost engagement.
- Continue leveraging high-value Segment P0 and “Recent-Medium-Medium Value” customers with loyalty programs.
- Promote strategies to encourage more frequent transactions among lower-value segments.
- Develop strategies to counteract low transaction counts in April.

**Threats:**
- Vulnerability to external disruptions, as seen in sales drops in early 2013 and 2015.
- Market saturation limits growth potential without innovative strategies.
- Segment P2’s infrequent engagement poses a risk if not addressed, potentially impacting overall revenue growth.

## Recommendations
- **Enhanced Targeting for Low Spend Segments:** Develop and implement targeted campaigns to increase engagement and spending in Segment P2 and other lower-value groups.
- **Maximize High-Value Customer Potential:** Focus on retaining and growing Segment P0 through loyalty programs and personalized offers to maintain high engagement and revenue.
- **Utilize RFM Insights:** Prioritize strategies that cater to "Recent-Medium-Medium Value" and "Frequent-High" segments to optimize revenue and engagement.
- **Adapt to Sales Fluctuations:** Monitor and adapt strategies to address seasonal and external factors impacting sales trends and campaign performance, especially focusing on mitigating declines like those observed in April.

## Future Steps
- Implement Targeted Marketing: Focus on strategies to enhance engagement and spending in low-value segments, using insights from RFM analysis.
- Optimize Customer Retention: Develop programs to retain high-value customers and increase their lifetime value, particularly focusing on P0 and "Recent-Medium-Medium Value" customers.
- Monitor and Adapt Strategies: Continuously track sales trends and campaign performance, adapting strategies to address external factors and seasonal fluctuations.
- Enhance Engagement Efforts: Promote initiatives to reduce the average time between transactions across all segments, particularly targeting those with less frequent purchases.
- Revise Campaign Strategies: Adjust and personalize campaigns to better engage a broader customer base and improve overall response rates.

## Contact Information
- **Author:** Rupsa Chaudhuri
- [LinkedIn](https://www.linkedin.com/in/rupsa-chaudhuri/)
- [GitHub Repository](https://github.com/rupsa723?tab=repositories)
