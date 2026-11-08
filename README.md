# Retail Sales Analysis

Transaction and campaign-response analysis of a retail customer base.
124,969 transactions, 6,884 customers, May 2011 to March 2015.

Python (pandas, scikit-learn, matplotlib, seaborn) and MySQL.

> **Version 2.** This is a rebuild of an earlier analysis of the same dataset.
> The first version ran its segmentation and statistical tests on transaction
> rows rather than on customers, which weighted every result by how often each
> person bought, and it reported seasonal patterns that turned out to be
> calendar artifacts. Both are fixed here, and a cohort retention analysis has
> been added. [What changed and why](#what-changed-from-version-1).

---

## Contents

- [The headline findings](#the-headline-findings)
- [Files](#files)
- [Data](#data)
- [Method](#method)
- [What changed from version 1](#what-changed-from-version-1)
- [Limitations](#limitations)
- [Running it](#running-it)
- [Contact](#contact)

---

## The headline findings

**Contact P0 and skip P2.** The top customer tier is 27.7% of the base and
holds 50.9% of everyone who responded to the campaign, a lift of 1.84x. The
bottom tier is 30.1% of the base and 7.0% of responders, 0.23x. A campaign
restricted to P0 reaches half the responders for roughly a quarter of the
contact cost.

**Set the reactivation trigger at 99 days.** 75% of repeat purchases happen
within 99 days of the previous one, so a customer past that point is outside
normal behaviour for this base. Per segment it differs enough to be worth
setting separately: P0 returns in 55 days on average, P1 in 73, P2 in 104.

**There is no seasonality, no trend and no volatility.** Raw monthly revenue
looks choppy. Divided by the number of days each month actually covers, it is
5,802 per day with a standard deviation of 133 — a coefficient of variation of
2.3% across 47 months. Every apparent pattern was month length.

**The dataset is generated, not observed.** Cohort analysis shows no
acquisition and no churn: an arrival model assuming every customer already
existed before the file opened predicts 6,810 first appearances against 6,826
observed, and only 38 customers in 6,884 stop buying before 2014. Retention is
flat at 68.9% against a 68.7% base rate, so cohort membership carries no
information. The analysis is therefore written up as a demonstration of method
with its limits stated, rather than as business insight.

---

## Files

| File | What it is |
|---|---|
| `Retail_Sales_Analysis.ipynb` | The analysis. 13 sections, each ending in a conclusion. |
| `Retail_Sales_Analysis.py` | The same thing as a script (jupytext percent format). |
| `Retail_Sales_Analysis.pdf` | Read-only version with all charts and conclusions. |
| `Retail_Sales_Analysis.sql` | MySQL companion: 11 sections, 37 queries. |
| `Retail_Sales_load_data.sql` | Creates the schema and loads the data. No configuration needed. |
| `CONCEPTS.md` | Plain-language explanation of every method used that wasn't in version 1. |
| `data/` | Source CSVs and the three tables the notebook writes. |

---

## Data

[Kaggle retail transaction dataset](https://www.kaggle.com/datasets/regivm/retailtransactiondata),
two files:

- `Retail_Data_Transactions.csv` — `customer_id`, `trans_date`, `tran_amount`
- `Retail_Data_Response.csv` — `customer_id`, `response` (binary campaign flag)

125,000 rows before cleaning. 31 rows have no response value, belonging to five
customers absent from the response file; dropped, leaving 124,969.

Six exact duplicate transactions exist. Too few to move any figure, recorded
rather than silently removed.

The file opens on **16 May 2011** and closes on **16 March 2015**, so the first
and last months each cover 16 days. Every monthly figure in the analysis is
divided by days covered for that reason.

No currency is given in the source, so all money figures are unlabelled units.

---

## Method

**Customer table first.** The source is one row per transaction, but most of the
questions are about customers. Everything after the load works from a
6,884-row customer table. Mixing the two grains is the easiest way to get a
wrong answer here — a customer with 39 purchases would otherwise be counted 39
times in any average or test.

**Segmentation.** K-means on standardised purchase count and total spend,
fitted on customers. Validated rather than asserted: silhouette falls
monotonically from k=2 (0.541) to k=7 (0.398), the two features correlate at
0.93, the first principal component holds 96.7% of the variance, and against
uniform noise over the same range the real data scores only 0.46–0.54 versus
0.38–0.41. There are no natural clusters — the customers lie on a line. k=3 is
kept as a usable banding and the limitation is stated.

| Segment | Customers | % of base | Purchases | Basket | Total spend | % of revenue |
|---|---|---|---|---|---|---|
| P0 | 1,904 | 27.7% | 24.45 | 70.76 | 1,728.28 | 40.5% |
| P1 | 2,906 | 42.2% | 18.19 | 67.61 | 1,226.01 | 43.9% |
| P2 | 2,074 | 30.1% | 12.32 | 49.73 | 611.83 | 15.6% |

**RFM.** Scored by quintile rather than fixed thresholds, because the median
customer last bought 53 days ago and a 200-day cutoff puts 91.6% of the base in
one bucket. Scored that way, recency runs *backwards* against campaign
response — the least recent quintile responds at 11.25% and the most recent at
6.02%. Reported as a property of this dataset rather than explained away.

**Statistics.** Both tests run on 6,884 customers with effect sizes reported
alongside, because at that size a p-value is effectively guaranteed.

- Segment vs response: chi-square 266.15, **Cramér's V 0.197** (weak-moderate)
- Segment vs recency: F 245.04, **η² 0.066**, Kruskal-Wallis H 331.52

Recency is used for the ANOVA rather than transaction amount, because the
segments were built by clustering on spend and testing them against spend would
be circular.

**Customer value.** Average order value × the customer's own monthly purchase
rate × 12 months. No churn term, so it assumes customers continue at their
observed rate. Checked against reality before reporting: 2,237,678 projected
against 2,108,426 of revenue actually recorded in the final twelve months, a
ratio of 1.06.

**Cohort retention.** Quarterly acquisition cohorts, chosen because the median
purchase gap is 49 days and a monthly grid would measure buying rhythm rather
than retention. Four censoring diagnostics run before the triangle is read.

---

## What changed from version 1

Version 1 is kept in the repository history. The substantive changes:

| | Version 1 | Version 2 |
|---|---|---|
| Statistical grain | Tests on 124,969 transaction rows | 6,884 customers |
| Chi-square | 3,726.5 | **266.15**, with Cramér's V 0.197 |
| ANOVA | Transaction amount (circular) | Recency, with η² 0.066 |
| Clustering | Fitted on transaction rows, k=3 asserted | Fitted on customers, k validated |
| Response rate | 11% (transaction-weighted) | **9.40%** (per customer) |
| Customer value | AOV × a global constant | AOV × each customer's own rate, sanity-checked |
| Total customer value | 74,771,322 (9× actual revenue) | **2,237,678** (ratio 1.06 to observed) |
| Seasonality | April dip, August peak | None — both were month-length artifacts |
| Volatility | "Periodic dips and peaks" | None — CV of 2.3% per day |
| Campaign over time | "Improved 2011 to 2014" | Not measurable; the flag has no date |
| Retention | Not analysed | Cohort triangle, flat on the base rate |

Three other corrections worth naming:

- A SQL query grouped by customer while selecting an ungrouped transaction
  amount, so it summed one arbitrary purchase per customer. The revenue figure
  it produced came from a pool of 434,203 instead of 8,122,378.
- The conclusion claimed a linear regression result. No regression existed in
  the notebook.
- Two charts in the same notebook reported segment shares that disagreed, one
  counting transactions and one counting customers.

Full method notes for everything added are in [`CONCEPTS.md`](CONCEPTS.md).

---

## Limitations

Stated up front rather than left to be found.

- **The dataset appears to be generated.** Findings demonstrate method, not a
  real business.
- **The segments are a banding, not a discovery.** Purchase count and total
  spend are two views of the same behaviour.
- **The acquisition cohorts are fully left-censored** — not merely the early
  ones. First-transaction date is the arrival time of an already-active
  customer. The standard washout fix would leave cohorts of fewer than ten
  people, so it is stated rather than applied.
- **The far end is right-censored**, so any lifetime estimate measures the
  observation window rather than customer behaviour.
- **Both end months are partial**, 16 days each.
- **The campaign response flag has no date.** One static value per customer, so
  response cannot be tracked over time or tied to a specific campaign.
- **Recency behaves backwards against response**, the opposite of what RFM
  practice assumes.
- **The 12-month value estimate contains no churn term.**
- **No causal claims are supported.** Segment membership is derived from the
  same purchase behaviour it is then used to describe.
- **No currency is given** in the source data.

---

## Running it

**Python.** Set `DATA_DIR` in the first cell and run top to bottom. Needs
pandas, numpy, scikit-learn, scipy, matplotlib, seaborn. The last cell writes
the three CSVs the SQL stage reads.

In the `.py` version, `SHOW_CHARTS = False` runs the numbers without opening
nine plot windows.

**SQL.** Run `Retail_Sales_load_data.sql` first — File → Open SQL Script, then
Execute All. It creates the schema, builds the table and inserts all 124,969
rows with no server configuration. Then open `Retail_Sales_Analysis.sql` and
start at Section 1.

---

## Contact

**Rupsa Chaudhuri**
[LinkedIn](https://www.linkedin.com/in/rupsa-chaudhuri/) ·
[GitHub](https://github.com/rupsa723)
