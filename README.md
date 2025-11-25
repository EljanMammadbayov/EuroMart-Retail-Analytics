# 🛒 EuroMart Retail Analytics

> **End-to-end business intelligence project analyzing 3 years of European retail operations**

[![Python](https://img.shields.io/badge/Python-3.9+-blue.svg)](https://www.python.org/)
[![SQL Server](https://img.shields.io/badge/SQL%20Server-2019+-red.svg)](https://www.microsoft.com/sql-server)
[![Power BI](https://img.shields.io/badge/Power%20BI-Desktop-yellow.svg)](https://powerbi.microsoft.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 📖 Project Overview

**EuroMart** is a fictional European retail company operating across Belgium, Netherlands, France, Germany, and Luxembourg. This project simulates real-world data analyst work: transforming messy transactional data into actionable business insights through data cleaning, warehouse design, SQL analysis, and interactive dashboards.

### 🎯 Business Context

EuroMart's leadership needed answers to critical questions:
- What are EuroMart's revenue trends over the last 3 years? What is the top-performing market?
- Which products are most/least profitable?
- Are customers churning—and can we predict who's at risk?
- Do we manage to consistently attract new customers every month?
- How can we optimize inventory and pricing strategies?

### 📊 Dataset Scope

- **Time Period:** November 2022 - November 2025 (3 years)
- **Records:** 10,320 transactions across 5,000 orders
- **Customers:** 783 registered (780 active purchasers)
- **Products:** 60 SKUs across 5 categories
- **Regions:** 5 countries, 3 regional managers

### 🚀 Project Goals

1. **Data Quality:** Clean and standardize messy retail data with real-world issues
2. **Data Warehouse:** Design a performant star schema for analytical queries
3. **Business Analysis:** Answer strategic questions using SQL
4. **Visualization:** Build executive-ready dashboards in Power BI
5. **Insights:** Deliver actionable recommendations backed by data

---

## 🎬 Quick Demo

### Dashboard Preview
![Executive Summary Dashboard](screenshots/1_executive_summary.png)
*Real-time KPIs tracking revenue, profit, orders, and customer metrics*

![Time Series Analysis](screenshots/7_time_series.png)
*Seasonal trends and growth patterns with 3 & 6-month moving averages*

[📺 Watch 2-minute walkthrough video](#)

---

## 💡 Key Insights Discovered

### 🔴 Critical Issues Identified

1. **Inventory Crisis**
   - 66% of historical revenue (€15.3M) comes from items currently low/out of stock
   - 14 products need **urgent restocking** (each generated €500K+)
   - **Recommendation:** Emergency purchase orders for top performers

2. **Belgium Market Saturation**
   - Accounts for 28% of total revenue but showing -16% YoY decline in 2025 so far.
   - Still reasonable chances to finish off the year with positive growth numbers with 2 months to go
   - **Recommendation:** Diversify growth into Germany (24%) and France (24%)

3. **Customer Churn Risk**
   - 299 customers (38%) haven't purchased in 6+ months
   - Represents €2M+ in dormant lifetime value
   - **Recommendation:** Win-back campaign targeting at-risk segments

### 🟢 Positive Findings

4. **Exceptional Customer Loyalty**
   - 96.4% repeat purchase rate (industry average: 20-40%)
   - Strong product-market fit validated
   - **Recommendation:** Leverage loyalty for referral programs

5. **Pricing Strategy Opportunity**
   - Discounts >20% reduce profit margin from 26% (no discount) → 7%
   - No correlation between high discounts and order quantity
   - **Recommendation:** Cap standard discounts at 10%

[📄 See full analysis report →](docs/business_insights.md)

---

## 🏗️ Project Architecture
```
┌─────────────────┐
│   Raw CSV Data  │  ← Generated synthetic retail data
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Python Cleaning │  ← pandas: Fix duplicates, nulls, formatting
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  SQL Server DW  │  ← Star schema: fact_sales + dimensions
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  SQL Analysis   │  ← 50+ queries: KPIs, trends, segmentation
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Power BI       │  ← 8-page dashboard with 40+ visuals
└─────────────────┘
```
---
## 📊 Dashboard Pages

| **Page**                  | **Focus**                                    | **Key Visuals**                              |
|---------------------------|----------------------------------------------|----------------------------------------------|
| 1. Executive Summary      | High-level KPIs and alerts                   | Revenue, profit, orders, top products        |
| 2. Sales Performance      | Revenue trends and growth analysis           | YoY/MoM growth, category breakdown           |
| 3. Product Analysis       | Product profitability and inventory          | Scatter plot, stock alerts, top/bottom 5     |
| 4. Customer Insights      | Customer segmentation and behavior           | Loyalty analysis, value segments, geography  |
| 5. Operational Metrics    | Delivery and shipping efficiency             | Delivery times by ship mode, cost analysis   |
| 6. Regional Performance   | Country/region comparison                    | Revenue by country, manager performance      |
| 7. Time Series Analysis   | Seasonal patterns and forecasting            | Monthly trends, moving averages, QoQ growth  |
| 8. Final Overview         | Supplementary revenue summary                | Revenue tree, payment method preference      |


---

## 🛠️ Technologies Used

| **Category**          | **Tools & Libraries**                    |
|-----------------------|------------------------------------------|
| **Data Generation**   | Claude, Python 3.9+, pandas, numpy, faker        |
| **Data Cleaning**     | Jupyter Notebook, pandas                 |
| **Database**          | SQL Server 2019+, T-SQL                  |
| **Analysis**          | SQL (window functions, CTEs, aggregations) |
| **Visualization**     | Power BI Desktop, DAX                    |
| **Version Control**   | Git, GitHub                              |

---

## 🎓 Learning Outcomes

This project demonstrates proficiency in:

✅ **Data Engineering**
- Data profiling and quality assessment
- ETL pipeline development (Python → SQL)
- Database design (star schema, indexing)

✅ **SQL & Analysis**
- Complex queries (joins, CTEs, window functions)
- Time series analysis (YoY, MoM, moving averages)
- Customer segmentation (RFM, cohort analysis)

✅ **Business Intelligence**
- KPI definition and tracking
- Dashboard design principles
- Data storytelling and insight generation

✅ **Tools & Technologies**
- Python data manipulation (pandas)
- SQL Server database management
- Power BI advanced features (DAX, relationships, drill-through)

---

## 📂 Repository Structure
```
euromart-analytics/
│
├── 📂 data/
│   ├── 📂 raw/                          # Original CSVs (generated)
│   │   ├── regions.csv
│   │   ├── customers.csv
│   │   ├── products.csv
│   │   ├── orders.csv
│   │   └── order_details.csv
│   │
│   └── 📂 cleaned/                      # Post-Python cleaning
│       ├── regions_cleaned.csv
│       ├── customers_cleaned.csv
│       ├── customer_id_mapping.csv
│       ├── region_id_mapping.csv
│       ├── products_cleaned.csv
│       ├── orders_cleaned.csv
│       └── order_details_cleaned.csv
│
├── 📂 notebooks/                        # Jupyter notebooks (cleaning)
│   ├── customers_cleaning.ipynb
│   ├── regions_cleaning.ipynb
│   ├── orders_cleaning.ipynb
│   ├── order_details_cleaning.ipynb
│   └── products_cleaning.ipynb
│
├── 📂 scripts/                          # Python scripts
│   ├── generate_euromart_data.py        # Data generation script
│
├── 📂 sql/                              # SQL scripts
│   ├── 1_data_profiling_part_1.sql      # Initial data quality checks
│   ├── 2_data_profiling_part_2.sql      # Table creation & import
│   ├── 3_schema_and_analysis.sql         # Star schema + fact_sales + business analysis
│
├── 📂 powerbi/                          # Power BI files
│   ├── euromart_dashboard.pbix         # Main dashboard file
│   └── data_model_diagram.png          # Screenshot of data model
│
├── 📂 screenshots/                      # Dashboard images for README
│   ├── 1_executive_summary.png
│   ├── 2_sales_performance.png
│   ├── 3_product_analysis.png
│   ├── 4_customer_insights.png
│   ├── 5_operational_metrics.png
│   ├── 6_regional_performance.png
│   └── 7_time_series.png
│   └── 8_final_overview.png
│
├── 📄 README.md                         # Main project documentation
├── 📄 LICENSE                           # MIT License
└── 📄 .gitignore                        # Git ignore file
```

**Key files:**
- `scripts/generate_euromart_data.py` - Creates synthetic dataset
- `notebooks/*_cleaning.ipynb` - Python data cleaning pipeline
- `sql/3_schema_and_analysis.sql` - Star schema + fact_sales + business analysis
- `powerbi/euromart_dashboard.pbix` - Interactive dashboard

---

## 👤 About

**Eljan Mammadbayov**
- 📍 Brussels, Belgium
- 📧 eljanmammadbayov03@gmail.com
- 🔗 [LinkedIn](https://www.linkedin.com/in/eljan-mammadbayov-538348231/)

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- Dashboard design influenced by modern BI best practices
- Built as a portfolio project to demonstrate real-world data analyst skills

---

## ⭐ Support

For questions or collaboration opportunities, feel free to reach out via [LinkedIn](https://www.linkedin.com/in/eljan-mammadbayov-538348231/) or email.
