# Retail Customer Analytics: Segmentation and Cohort Retention

Customer segmentation, campaign response and cohort retention for a retail customer base.
124,969 transactions, 6,884 customers, May 2011 to March 2015.

Python (pandas, scikit-learn, matplotlib, seaborn) and MySQL.

---

## Contents

- [The headline findings](#the-headline-findings)
- [Files](#files)
- [Data](#data)
- [Method](#method)
- [Cohort retention analysis](#cohort-retention-analysis)
- [Limitations](#limitations)
- [Running it](#running-it)
- [Contact](#contact)

---

## The headline findings

**Contact the top tier first and skip the bottom one.** The top customer tier (P0) is
27.7% of customers but holds 50.9% of everyone who responded to the campaign, a lift of
1.84x. The bottom tier (P2) is 30.1% of customers and 7.0% of responders, 0.23x. A
campaign sent only to P0 reaches half the responders for roughly a quarter of the
contact cost.

**Set the reactivation trigger at 99 days.** 75% of repeat purchases happen within 99
days of the previous one, so a customer past that point is outside normal behaviour.
It's worth setting per tier: P0 returns in 55 days on average, P1 in 73, P2 in 104.

**Revenue is steady once month length is accounted for.** Raw monthly revenue looks
choppy. Divided by the number of days each month covers, it is 5,802 per day with a
standard deviation of 133, a coefficient of variation of 2.3% across 47 months. The
apparent dips and peaks were month length.

**Retention is flat across cohorts, and the cohort test explains why.** Every quarterly
cohort retains about 68.9% of customers, the same as the 68.7% overall rate. An arrival
model shows customers were already active when the data starts (6,810 first purchases
predicted against 6,826 observed), so first purchase in this file is an entry date into
the data, not a signup date. Retention is read within that limit.

---

## Files

| File | What it is |
|---|---|
| `Retail_Sales_Analysis.ipynb` | The analysis, with each section ending in a conclusion |
| `Retail_Sales_Analysis.sql` | MySQL companion: 11 sections, 37 queries |
| `Retail Sales Analysis.pptx` | Presentation of the findings |
| `Original Dataset/` | The two source CSVs |
| `Derived data/` | The three tables the notebook writes: `customers.csv`, `main_data.csv`, `overall_data.csv` |

---

## Data

Two files:

- `Retail_Data_Transactions.csv`: `customer_id`, `trans_date`, `tran_amount`
- `Retail_Data_Response.csv`: `customer_id`, `response` (yes/no campaign flag)

125,000 rows before cleaning. 31 rows have no response value; they belong to five
customers missing from the response file and are dropped, leaving 124,969.

Six exact duplicate transactions exist. Too few to move any figure, so they are recorded
rather than silently removed.

The file opens on **16 May 2011** and closes on **16 March 2015**, so the first and last
months each cover 16 days. Every monthly figure is divided by days covered for that
reason.

No currency is given in the source, so money figures are unlabelled units.

---

## Method

**One row per customer first.** The source has one row per transaction, but the
questions are about customers. Everything after loading works from a 6,884-row customer
table. Otherwise a customer with 39 purchases is counted 39 times in any average or
test. Counted per transaction, the campaign response rate looks like 11%; per customer
it is **9.40%**.

**Segmentation.** K-means on standardised purchase count and total spend, fitted on
customers. Checked rather than assumed: the silhouette score falls steadily from k=2
(0.541) to k=7 (0.398), the two features correlate at 0.93, and the real data scores only
0.46–0.54 against 0.38–0.41 for random data over the same range. There are no natural
clusters, the customers lie along a line, so k=3 is kept as a usable banding and that
is stated.

| Tier | Customers | % of base | Purchases | Basket | Total spend | % of revenue |
|---|---|---|---|---|---|---|
| P0 | 1,904 | 27.7% | 24.45 | 70.76 | 1,728.28 | 40.5% |
| P1 | 2,906 | 42.2% | 18.19 | 67.61 | 1,226.01 | 43.9% |
| P2 | 2,074 | 30.1% | 12.32 | 49.73 | 611.83 | 15.6% |

**RFM.** Scored by quintile rather than fixed thresholds: the median customer last bought
53 days ago, and a 200-day cut-off puts 91.6% of customers in one bucket. Scored this
way, recency runs backwards against campaign response. The least recent quintile
responds at 11.25% and the most recent at 6.02%. Reported as it is.

**Statistics.** Tests run on 6,884 customers with effect sizes alongside, because at this
size a p-value is almost guaranteed.

- Tier vs response: chi-square 266.15, **Cramér's V 0.197** (weak to moderate)
- Tier vs recency: F 245.04, **η² 0.066**, Kruskal-Wallis H 331.52

Recency is tested rather than spend, because the tiers were built from spend and testing
them against it would be circular.

**Customer value (CLV).** Average order value × the customer's own monthly purchase rate
× 12 months. No churn term, so it assumes customers carry on at their current rate.
Checked before reporting: 2,237,678 projected against 2,108,426 recorded in the final
twelve months, a ratio of 1.06.

---

## Cohort retention analysis

**Building the cohorts.** Each customer is assigned to the quarter of their first
purchase. Quarters rather than months, because the median gap between purchases is 49
days; on a monthly grid a normal customer would look absent half the time.

**The retention triangle.** Rows are cohorts, columns are quarters since first purchase,
and each cell is the share of the cohort that bought in that quarter. Retention sits at
about **68.9%** in every cohort and every quarter.

**Comparing with the base rate.** A retention figure means little on its own, so it is
compared with the share of all customers active in any quarter: **68.7%**. Cohort
retention matches it, which means the cohort a customer belongs to tells you nothing
extra about whether they buy.

**Testing the cohorts.** Flat retention raises the question of whether first purchase in
the file is really when a customer started. Using each customer's own purchase rate, an
arrival model predicts how many customers would first appear each month if all of them
were already active on the first day. It predicts **6,810** first appearances against
**6,826** observed. So the cohorts reflect when customers entered the data window, not
when they started buying (left censoring). At the other end, 61.4% of customers made
their last purchase in the final three months, so lifetimes are cut off by the end of
the window (right censoring).

**What that means.** Retention here describes buying within the window. A real signup
date from another source would be needed to read it as customer loyalty.

---

## Limitations

- **Cohorts are left-censored.** First purchase in the file marks entry into the data,
  not a signup date. Starting the analysis later to fix this would leave cohorts of
  fewer than ten people, so the limit is stated instead.
- **The far end is right-censored**, so any lifetime estimate measures the observation
  window.
- **The tiers are a banding, not a discovery.** Purchase count and total spend measure
  the same behaviour.
- **Both end months are partial**, 16 days each.
- **The campaign flag has no date.** One value per customer, so response can't be tracked
  over time or tied to a specific campaign.
- **Recency runs backwards against response**, the opposite of what RFM practice assumes.
- **The 12-month value estimate has no churn term.**
- **No causal claims.** Tier membership comes from the same purchase behaviour it is used
  to describe.
- **No currency** is given in the source data.

---

## Running it

**Python.** Set `DATA_DIR` in the first cell and run top to bottom. Needs pandas, numpy,
scikit-learn, scipy, matplotlib and seaborn. The last cell writes the three CSVs in
`Derived data/`.

**SQL.** Create a schema in MySQL, import the two source CSVs (and the derived CSVs for
the later sections) with the Table Data Import Wizard, then open
`Retail_Sales_Analysis.sql` and start at Section 1.

---

## Contact

**Rupsa Chaudhuri**
[LinkedIn](https://www.linkedin.com/in/rupsa-chaudhuri/) ·
[GitHub](https://github.com/rupsa723)
