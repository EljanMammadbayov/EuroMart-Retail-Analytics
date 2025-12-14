
-- ============================================
-- ADD FOREIGN KEYS
-- ============================================

ALTER TABLE orders 
ADD CONSTRAINT FK_orders_customers 
FOREIGN KEY (customer_id) REFERENCES customers(customer_id);

ALTER TABLE orders 
ADD CONSTRAINT FK_orders_regions 
FOREIGN KEY (region_id) REFERENCES regions(region_id);

ALTER TABLE order_details 
ADD CONSTRAINT FK_order_details_orders 
FOREIGN KEY (order_id) REFERENCES orders(order_id);

ALTER TABLE order_details 
ADD CONSTRAINT FK_order_details_products 
FOREIGN KEY (product_id) REFERENCES products(product_id);

PRINT '✓ Foreign keys added';

-- ============================================
-- ADD INDEXES (THE KEY TO PERFORMANCE!)
-- ============================================

-- Orders indexes
CREATE INDEX IX_orders_customer ON orders(customer_id);
CREATE INDEX IX_orders_region ON orders(region_id);
CREATE INDEX IX_orders_date ON orders(order_date);

-- Order details indexes
CREATE INDEX IX_order_details_order ON order_details(order_id);
CREATE INDEX IX_order_details_product ON order_details(product_id);

-- Customer indexes
CREATE INDEX IX_customers_country ON customers(country);
CREATE INDEX IX_customers_loyalty ON customers(loyalty_status);

-- Product indexes
CREATE INDEX IX_products_category ON products(category);

PRINT '✓ Indexes added for fast queries';
PRINT '';
PRINT '✅ Base tables are ready!';


-- ============================================
-- CREATE FACT_SALES TABLE
-- ============================================

DROP TABLE IF EXISTS fact_sales;
GO

CREATE TABLE fact_sales (
    -- Primary Key
    sale_key INT IDENTITY(1,1) PRIMARY KEY,
    
    -- Date Dimensions (pre-calculated for easy filtering)
    order_date DATE NOT NULL,
    order_year INT,
    order_quarter INT,
    order_month INT,
    order_month_name VARCHAR(20),
    order_day INT,
    order_day_name VARCHAR(20),
    
    -- Foreign Keys (keep original IDs for now - no surrogate keys in this star schema)
    customer_id VARCHAR(20) NOT NULL,
    product_id VARCHAR(10) NOT NULL,
    region_id VARCHAR(10) NOT NULL,
    order_id VARCHAR(50) NOT NULL,
    
    -- Transaction Details
    order_detail_id VARCHAR(20),
    
    -- Measures (from order_details)
    quantity INT,
    discount DECIMAL(5,2),
    tax_rate DECIMAL(5,2),
    unit_price DECIMAL(10,2),
    cost_price DECIMAL(10,2),
    
    -- Financial Metrics
    revenue DECIMAL(10,2),  -- total_price (after discount, before shipping)
    cost DECIMAL(10,2),  -- cost_price * quantity
    profit DECIMAL(10,2),
    shipping_cost DECIMAL(10,2),  -- allocated per line item
    
    -- Calculated Metrics (pre-calculated for performance)
    profit_margin DECIMAL(5,4),  -- profit / revenue
    discount_amount DECIMAL(10,2),  -- revenue * discount
    gross_amount DECIMAL(10,2),  -- revenue before discount
    
    -- Order Attributes (from orders table)
    ship_mode VARCHAR(50),
    payment_method VARCHAR(50),
    order_priority VARCHAR(50),
    delivery_time_days INT,
    
    -- Flags (for easy filtering)
    is_loss_sale BIT,  -- profit < 0
    is_discounted BIT,  -- discount > 0
    is_high_value BIT,  -- revenue > 500
    is_bulk_order BIT,  -- quantity > 5
    
    -- Customer Attributes (denormalized for convenience)
    customer_country VARCHAR(100),
    customer_loyalty_status VARCHAR(50),
    
    -- Product Attributes (denormalized)
    product_category VARCHAR(100),
    product_subcategory VARCHAR(100),
    product_supplier VARCHAR(100),
    
    -- Region Attributes (denormalized)
    region_name VARCHAR(100),
    region_manager VARCHAR(100),
    
    -- Indexes for fast queries
    INDEX IX_fact_sales_date (order_date),
    INDEX IX_fact_sales_customer (customer_id),
    INDEX IX_fact_sales_product (product_id),
    INDEX IX_fact_sales_region (region_id),
    INDEX IX_fact_sales_year_month (order_year, order_month),
    INDEX IX_fact_sales_category (product_category),
    INDEX IX_fact_sales_country (customer_country)
);

PRINT '✓ fact_sales table created';
GO

-- ============================================
-- POPULATE FACT_SALES
-- ============================================

INSERT INTO fact_sales (
    -- Date dimensions
    order_date,
    order_year,
    order_quarter,
    order_month,
    order_month_name,
    order_day,
    order_day_name,
    
    -- Foreign keys
    customer_id,
    product_id,
    region_id,
    order_id,
    order_detail_id,
    
    -- Measures
    quantity,
    discount,
    tax_rate,
    unit_price,
    cost_price,
    revenue,
    cost,
    profit,
    shipping_cost,
    
    -- Calculated metrics
    profit_margin,
    discount_amount,
    gross_amount,
    
    -- Order attributes
    ship_mode,
    payment_method,
    order_priority,
    delivery_time_days,
    
    -- Flags
    is_loss_sale,
    is_discounted,
    is_high_value,
    is_bulk_order,
    
    -- Denormalized customer attributes
    customer_country,
    customer_loyalty_status,
    
    -- Denormalized product attributes
    product_category,
    product_subcategory,
    product_supplier,
    
    -- Denormalized region attributes
    region_name,
    region_manager
)
SELECT 
    -- Date dimensions (pre-calculate once!)
    o.order_date,
    YEAR(o.order_date) as order_year,
    DATEPART(QUARTER, o.order_date) as order_quarter,
    MONTH(o.order_date) as order_month,
    DATENAME(MONTH, o.order_date) as order_month_name,
    DAY(o.order_date) as order_day,
    DATENAME(WEEKDAY, o.order_date) as order_day_name,
    
    -- Foreign keys
    o.customer_id,
    od.product_id,
    o.region_id,
    o.order_id,
    od.order_detail_id,
    
    -- Measures
    od.quantity,
    od.discount,
    od.tax_rate,
    p.unit_price,
    p.cost_price,
    od.total_price as revenue,
    p.cost_price * od.quantity as cost,
    od.profit,
    
    -- Allocate shipping cost proportionally to line items
    o.shipping_cost * (od.total_price / order_totals.order_total) as shipping_cost,
    
    -- Calculated metrics
    CASE 
        WHEN od.total_price > 0 THEN od.profit / od.total_price 
        ELSE NULL 
    END as profit_margin,
    
    p.unit_price * od.quantity * od.discount as discount_amount,
    p.unit_price * od.quantity as gross_amount,
    
    -- Order attributes
    o.ship_mode,
    o.payment_method,
    o.order_priority,
    o.delivery_time_days,
    
    -- Flags
    CASE WHEN od.profit < 0 THEN 1 ELSE 0 END as is_loss_sale,
    CASE WHEN od.discount > 0 THEN 1 ELSE 0 END as is_discounted,
    CASE WHEN od.total_price > 500 THEN 1 ELSE 0 END as is_high_value,
    CASE WHEN od.quantity > 5 THEN 1 ELSE 0 END as is_bulk_order,
    
    -- Denormalized attributes (avoid JOINs in analysis)
    c.country as customer_country,
    c.loyalty_status as customer_loyalty_status,
    
    p.category as product_category,
    p.subcategory as product_subcategory,
    p.supplier as product_supplier,
    
    r.region_name,
    r.manager as region_manager

FROM order_details od
JOIN orders o ON od.order_id = o.order_id
JOIN customers c ON o.customer_id = c.customer_id
JOIN products p ON od.product_id = p.product_id
JOIN regions r ON o.region_id = r.region_id

-- Calculate order totals for shipping allocation
JOIN (
    SELECT 
        order_id, 
        SUM(total_price) as order_total
    FROM order_details
    GROUP BY order_id
) order_totals ON o.order_id = order_totals.order_id;

-- Check results
SELECT 
    COUNT(*) as total_rows,
    MIN(order_date) as earliest_date,
    MAX(order_date) as latest_date,
    SUM(revenue) as total_revenue,
    SUM(profit) as total_profit,
    ROUND(SUM(profit) / NULLIF(SUM(revenue), 0) * 100, 2) as overall_profit_margin_pct
FROM fact_sales;

PRINT '✓ fact_sales populated with ' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows';

-- ============================================
-- CREATE DATE DIMENSION
-- ============================================

DROP TABLE IF EXISTS dim_date;
GO

CREATE TABLE dim_date (
    date_key INT PRIMARY KEY,  -- Format: YYYYMMDD (e.g., 20240115)
    full_date DATE NOT NULL UNIQUE,
    
    -- Year
    year INT,
    year_name VARCHAR(10),
    
    -- Quarter
    quarter INT,
    quarter_name VARCHAR(10),
    
    -- Month
    month INT,
    month_name VARCHAR(20),
    month_name_short VARCHAR(3),
    month_year VARCHAR(20),
    
    -- Week
    week_of_year INT,
    
    -- Day
    day INT,
    day_of_week INT,
    day_name VARCHAR(20),
    day_name_short VARCHAR(3),
    
    -- Flags
    is_weekend BIT,
    is_weekday BIT,
    
    -- Indexes
    INDEX IX_date_full (full_date),
    INDEX IX_date_year_month (year, month)
);

-- Populate date dimension (2021-2025)
DECLARE @StartDate DATE = '2021-01-01';
DECLARE @EndDate DATE = '2025-12-31';

WHILE @StartDate <= @EndDate
BEGIN
    INSERT INTO dim_date VALUES (
        CAST(FORMAT(@StartDate, 'yyyyMMdd') AS INT),  -- date_key: 20210101
        @StartDate,  -- full_date
        YEAR(@StartDate),  -- year
        CAST(YEAR(@StartDate) AS VARCHAR),  -- year_name: '2021'
        DATEPART(QUARTER, @StartDate),  -- quarter: 1,2,3,4
        'Q' + CAST(DATEPART(QUARTER, @StartDate) AS VARCHAR),  -- quarter_name: 'Q1'
        MONTH(@StartDate),  -- month: 1-12
        DATENAME(MONTH, @StartDate),  -- month_name: 'January'
        LEFT(DATENAME(MONTH, @StartDate), 3),  -- month_name_short: 'Jan'
        DATENAME(MONTH, @StartDate) + ' ' + CAST(YEAR(@StartDate) AS VARCHAR),  -- 'January 2021'
        DATEPART(WEEK, @StartDate),  -- week_of_year
        DAY(@StartDate),  -- day: 1-31
        DATEPART(WEEKDAY, @StartDate),  -- day_of_week: 1=Sunday
        DATENAME(WEEKDAY, @StartDate),  -- day_name: 'Monday'
        LEFT(DATENAME(WEEKDAY, @StartDate), 3),  -- day_name_short: 'Mon'
        CASE WHEN DATEPART(WEEKDAY, @StartDate) IN (1, 7) THEN 1 ELSE 0 END,  -- is_weekend
        CASE WHEN DATEPART(WEEKDAY, @StartDate) NOT IN (1, 7) THEN 1 ELSE 0 END  -- is_weekday
    );
    
    SET @StartDate = DATEADD(DAY, 1, @StartDate);
END;

SELECT COUNT(*) as total_dates FROM dim_date;

PRINT '✓ dim_date table created and populated';


-- Let's check all our tables and start our EDA.

SELECT *
FROM customers;

SELECT *
FROM regions;

SELECT *
FROM products;

SELECT *
FROM orders;

SELECT *
FROM order_details;

SELECT *
FROM fact_sales;

SELECT *
FROM dim_date;

--Everything in place.

-- ============================================
-- DATA QUALITY & SCOPE NOTES
-- ============================================
-- Date Range: Nov 1, 2022 - Nov 5, 2025
-- 2022: Incomplete (only Q4, Nov-Dec)
-- 2025: Incomplete (through Nov 5 only)
-- Full years for comparison: 2023-2024
-- Total customers registered: 783
-- Customers who placed orders: 780
-- Total orders: 5,000
-- Total line items: 10,320

--<<<<<>>>>>--

--1) Let's start by diving into revenue & profitability

--EuroMart's total revenue and profit by year
SELECT
	order_year,
	SUM(revenue) AS total_yearly_revenue,
	SUM(profit) AS total_yearly_profit,
	COUNT(DISTINCT order_id) AS order_count,
	SUM(revenue) / COUNT(DISTINCT order_id) AS avg_order_value
FROM fact_sales
GROUP BY order_year
ORDER BY order_year DESC;
--2023 with both the highest revenue and profit. 2022 with both the lowest revenue and profit. 
--Logical outcome for 2022 since there are only records for November and December.
--Remembering that sales data captures the period of Nov 2022 - Nov 2025.
--The average order value (4849.27 euros) in 2023 was noticeably higher than in other years, which helped reach the highest revenue and profit numbers.
--Other years' average order value: (2022 - 4498.09; 2024 - 4519.80; 2025 - 4594.54).

--Same by year + quarter
SELECT
	order_year,
	order_quarter,
	SUM(revenue) AS total_yearlyQ_revenue,
	SUM(profit) AS total_yearlyQ_profit
FROM fact_sales
GROUP BY order_year, order_quarter
ORDER BY order_year DESC, order_quarter DESC;
--2023, Q1 with the biggest profit. 2025, Q3 with the biggest revenue.

--Same by year + month
SELECT
	order_year,
	order_month,
	SUM(revenue) AS total_yearlyM_revenue,
	SUM(profit) AS total_yearlyM_profit
FROM fact_sales
GROUP BY order_year, order_month
ORDER BY order_year DESC, order_month DESC;
--Feb 2023 with the most revenue. Oct 2025 with the most profit.

--Profit margin by category
SELECT
	product_category,
	SUM(profit) AS total_profit,
    SUM(revenue) AS total_revenue,
    ROUND(100.0 * SUM(profit) / NULLIF(SUM(revenue), 0), 2) AS profit_margin_pct
FROM fact_sales
GROUP BY product_category
ORDER BY profit_margin_pct DESC;
--Furniture (18.96%) with the highest average profitability among categories. Home Office with the lowest (15.82%).
--The differences in profit margins are not striking.

--By product
SELECT f.product_id, f.product_category, p.product_name,
	SUM(profit) AS total_profit,
    SUM(revenue) AS total_revenue,
    ROUND(100.0 * SUM(profit) / NULLIF(SUM(revenue), 0), 2) AS profit_margin_pct
FROM fact_sales f
JOIN products p ON f.product_id = p.product_id
GROUP BY f.product_id, f.product_category, p.product_name
ORDER BY profit_margin_pct DESC;
--Coffee Maker Nespresso (Accessories) brings the best balance between sales and profit (29.38%).
--Whiteboard Magnetic 90*60 cm (Technology) with the lowest profit margin (5.40%).

--To simply avoid confusion and make data look less misleading, I will replace the customer_country column with country (from regions).
--This will simplify and ensure consistency on regional-level analysis. The rest of the data stays the same.
UPDATE f
SET f.customer_country = r.country
FROM fact_sales f
JOIN regions r
    ON f.region_id = r.region_id;

EXEC sp_rename 'fact_sales.customer_country', 'region_country', 'COLUMN';

DROP INDEX IX_fact_sales_country ON fact_sales;

CREATE INDEX IX_fact_sales_region_country ON fact_sales(region_country);

--By country (and their region id)
-- CORRECT: Aggregate first, then calculate margin
SELECT
    region_id,
    region_country,
    SUM(profit) AS total_profit,
    SUM(revenue) AS total_revenue,
    ROUND(100.0 * SUM(profit) / NULLIF(SUM(revenue), 0), 2) AS profit_margin_pct
FROM fact_sales
GROUP BY region_id, region_country
ORDER BY profit_margin_pct DESC;
--The results are all close. Netherlands (17.94%) on top. Luxembourg (17.03%) is on the bottom.

--TOP 10 most profitable products
SELECT TOP 10 f.product_id, f.product_category, f.product_supplier, p.product_name,
SUM(profit) AS total_profit_per_product
FROM fact_sales f
JOIN products p ON f.product_id = p.product_id
GROUP BY f.product_id, f.product_category, f.product_supplier, p.product_name
ORDER BY total_profit_per_product DESC;
--Seagate External HDD 2TB (Tech) from Kingston has brought the most profit over 3 years (182 733.53 euros).
--Fellowees Paper Shredder (Furniture) is a pretty close second (180 365.78 euros).

--TOP 10 least profitable products
SELECT TOP 10 f.product_id, f.product_category, f.product_supplier, p.product_name,
SUM(profit) AS total_profit_per_product
FROM fact_sales f
JOIN products p ON f.product_id = p.product_id
GROUP BY f.product_id, f.product_category, f.product_supplier, p.product_name
ORDER BY total_profit_per_product;
--We can see that EuroMart has not lost money on any single product over 3 years.
--Cumulatively, no product has generated loss for EuroMart
--Gaming Chair Racing Style (Home Office) and HDMI Cable 2m (Accessories) have generated the least profit.

--Revenue growth rate YoY
WITH cur_rev AS
(SELECT
	order_year,
	SUM(revenue) AS current_rev
FROM fact_sales
GROUP BY order_year
)
SELECT order_year, current_rev,
LAG(current_rev, 1) OVER (ORDER BY order_year) AS previous_rev,
ROUND(
	(current_rev - LAG(current_rev, 1) OVER (ORDER BY order_year))
	/ NULLIF(LAG(current_rev, 1) OVER (ORDER BY order_year),0) * 100, 2
	) AS YoY_rev_growth
FROM cur_rev;
--Huge 530% increase in revenue in 2023. Logical since year 2022 only captures data for Nov-Dec.
--Slightly decreasing each year since then. Keep incomplete 2025 in mind again (data only till Nov 5, 2025)

--<<<<<>>>>>--

--2) Customer Analysis

--Let me add customers' full names into our fact sales table first

ALTER TABLE fact_sales
ADD customer_full_name VARCHAR(50);

UPDATE f
SET customer_full_name = (c.first_name + ' ' + c.last_name)
FROM fact_sales f
JOIN customers c
ON f.customer_id = c.customer_id;

--Customer acquisition by month (cohorts)
SELECT 
	DATEPART(YEAR, signup_date) AS year_signed_up,
	DATEPART(MONTH, signup_date) AS month_signed_up,
	COUNT(DISTINCT customer_id) AS new_customers_signed_up
FROM customers
GROUP BY DATEPART(YEAR, signup_date), DATEPART(MONTH, signup_date)
ORDER BY year_signed_up, month_signed_up;
--The record is 28 new customers in January 2024. October-December consistently bring 12+ new customers.

--Repeat customer rate
SELECT
	customer_id,
	COUNT(DISTINCT order_id) AS number_of_orders
FROM fact_sales
GROUP BY customer_id
ORDER BY number_of_orders DESC;
--752 customers out of 780 who at least placed one order are repeat customers. They had 2+ orders in EuroMart. 8 customers had over 20 orders each.

WITH customer_orders AS (
    SELECT 
        customer_id,
        COUNT(DISTINCT order_id) AS order_count
    FROM fact_sales
    GROUP BY customer_id
)
SELECT 
    COUNT(CASE WHEN order_count > 1 THEN 1 END) * 1.0 / COUNT(*) AS repeat_customer_rate,
    COUNT(CASE WHEN order_count > 1 THEN 1 END) AS repeat_customers,
    COUNT(*) AS total_customers
FROM customer_orders;
--Repeat customer rate is 96.4%. It means that 96.4% of customers made more than one purchase, which should be a very positive signal for EuroMart
--Strong customer satisfaction and product-market fit. Still, 3 customers (out of 783) who signed up never purchased in EuroMart.
--Action: Investigate why they signed up but never purchased (email campaign, abandoned carts?).

--Customer lifetime value (CLV)
SELECT
	customer_id,
	customer_full_name,
	SUM(revenue) AS lifetime_cust_rev,
	SUM(profit) AS lifetime_cust_profit
FROM fact_sales
GROUP BY customer_id, customer_full_name
ORDER BY lifetime_cust_rev DESC, lifetime_cust_profit DESC;
--Chloe Michel is EuroMart's most valuable customer of all time in terms of revenue (144 619 euros).
--Arthur Dubois (2nd), Emma Bernard (3rd), and Emma Lefebvre (4th) are not far behind. 

SELECT
	customer_id,
	customer_full_name,
	SUM(revenue) AS lifetime_cust_rev,
	SUM(profit) AS lifetime_cust_profit
FROM fact_sales
GROUP BY customer_id, customer_full_name
ORDER BY lifetime_cust_profit DESC, lifetime_cust_rev DESC;
--Chloe Michel has also brought the most profit among customers (27 528 euros). Emma Bernard (2nd) falls short by only close to 300 euros.

-- Segment customers into tiers
WITH customer_value AS (
    SELECT 
        customer_id,
        SUM(revenue) AS lifetime_value,
        COUNT(DISTINCT order_id) AS order_count
    FROM fact_sales
    GROUP BY customer_id
),
customer_tiers AS (
    SELECT 
        customer_id,
        lifetime_value,
        order_count,
        NTILE(5) OVER (ORDER BY lifetime_value DESC) AS value_quintile
    FROM customer_value
)
SELECT 
    value_quintile,
    COUNT(*) AS customer_count,
    AVG(lifetime_value) AS avg_clv,
    MIN(lifetime_value) AS min_clv,
    MAX(lifetime_value) AS max_clv,
    SUM(lifetime_value) AS segment_revenue,
    SUM(lifetime_value) / (SELECT SUM(lifetime_value) FROM customer_tiers) * 100 AS pct_of_revenue
FROM customer_tiers
GROUP BY value_quintile
ORDER BY value_quintile;
--Top 20% of customers generate 42.67% of total revenue.
--Top 40% of customers generate slightly above 67% of total revenue.

--Do Platinum customers bring the most revenue (or profit), on average?
SELECT customer_loyalty_status,
AVG(revenue) AS avg_rev_per_status,
AVG(profit) AS avg_profit_per_status
FROM fact_sales
GROUP BY customer_loyalty_status
ORDER BY avg_rev_per_status DESC;
--Interestingly, the results are all close. 
--The customers that are unclassifed in terms of loyalty status actually bring the most revenue on average. However, their avg profit numbers are the lowest
--Platinum members generate just marginally higher average earnings than Gold members.
--While Silver members bring slightly lower average revenue than their counterparts, they bring the most profit on average.

--Geographic distribution of customers
SELECT
	COUNT(*) AS total_customers,
	COUNT(CASE WHEN country LIKE 'Belgium' THEN 1 END) AS count_BE_customers,
	COUNT(CASE WHEN country LIKE 'Netherlands' THEN 1 END) AS count_NL_customers,
	COUNT(CASE WHEN country LIKE 'Luxembourg' THEN 1 END) AS count_LU_customers,
	COUNT(CASE WHEN country LIKE 'France' THEN 1 END) AS count_FR_customers,
	COUNT(CASE WHEN country LIKE 'Germany' THEN 1 END) AS count_DE_customers
FROM customers;

WITH count_of_customers AS
(SELECT
	COUNT(*) AS total_customers,
	COUNT(CASE WHEN country LIKE 'Belgium' THEN 1 END) AS count_BE_customers,
	COUNT(CASE WHEN country LIKE 'Netherlands' THEN 1 END) AS count_NL_customers,
	COUNT(CASE WHEN country LIKE 'Luxembourg' THEN 1 END) AS count_LU_customers,
	COUNT(CASE WHEN country LIKE 'France' THEN 1 END) AS count_FR_customers,
	COUNT(CASE WHEN country LIKE 'Germany' THEN 1 END) AS count_DE_customers
FROM customers)

SELECT
	ROUND(100.0 * count_BE_customers / total_customers, 2) AS pct_BE_customers,
	ROUND(100.0 * count_NL_customers / total_customers, 2) AS pct_NL_customers,
	ROUND(100.0 * count_LU_customers / total_customers, 2) AS pct_LU_customers,
	ROUND(100.0 * count_FR_customers / total_customers, 2) AS pct_FR_customers,
	ROUND(100.0 * count_DE_customers / total_customers, 2) AS pct_DE_customers
FROM count_of_customers;
--Customers are almost evenly spread out. Most customers from Netherlands (21.2%). Least from France (18.65%)

-- Does higher discount correlate with higher order quantity?
SELECT 
    CASE 
        WHEN discount = 0 THEN 'No Discount'
        WHEN discount <= 0.10 THEN '1-10%'
        WHEN discount <= 0.20 THEN '11-20%'
        WHEN discount <= 0.30 THEN '21-30%'
    END AS discount_range,
    COUNT(*) AS transaction_count,
    AVG(quantity) AS avg_quantity,
    AVG(revenue) AS avg_revenue,
    ROUND(SUM(profit) / SUM(revenue) * 100.0, 2) AS profit_margin_pct
FROM fact_sales
WHERE is_discounted = 1 OR discount = 0
GROUP BY 
    CASE 
        WHEN discount = 0 THEN 'No Discount'
        WHEN discount <= 0.10 THEN '1-10%'
        WHEN discount <= 0.20 THEN '11-20%'
        WHEN discount <= 0.30 THEN '21-30%'
    END;
--Orders with no discount have the smallest count but bring the highest average revenue (2556 euros) and biggest profit margin (25.69%).
--Discounts 1-10% show the 2nd-best performance in these metrics.
--The discount range of 21-30% brings down average revenue to 1905.94 and the avg profit margin to 7.03% (smallest in the discount group).
--EuroMart might adapt its discounting strategy by not crossing the 20% discount point most of the time to maintain better profitability.

-- Customers who haven't ordered in 6+ months (potential churn)
WITH last_order AS (
    SELECT 
        customer_id,
        MAX(order_date) AS last_order_date,
        DATEDIFF(DAY, MAX(order_date), '2025-11-05') AS days_since_last_order
    FROM fact_sales
    GROUP BY customer_id
)
SELECT 
    CASE 
        WHEN days_since_last_order <= 30 THEN 'Active (0-30 days)'
        WHEN days_since_last_order <= 90 THEN 'Recent (30-90 days)'
        WHEN days_since_last_order <= 180 THEN 'At Risk (90-180 days)'
        ELSE 'Churned (180+ days)'
    END AS customer_status,
    COUNT(*) AS customer_count,
    100.0 * COUNT(*) / (SELECT COUNT(DISTINCT customer_id) FROM fact_sales) AS pct_customers
FROM last_order
GROUP BY 
    CASE 
        WHEN days_since_last_order <= 30 THEN 'Active (0-30 days)'
        WHEN days_since_last_order <= 90 THEN 'Recent (30-90 days)'
        WHEN days_since_last_order <= 180 THEN 'At Risk (90-180 days)'
        ELSE 'Churned (180+ days)'
    END;
--299 customers (38.33% of those that ordered at least once) are potential churners.
--Their last order took place >=6 months ago.

--<<<<<>>>>>--

--3) Product Performance

--By revenue
SELECT f.product_id, f.product_category, p.product_name,
SUM(revenue) AS rev_per_product
FROM fact_sales f
JOIN products p ON f.product_id = p.product_id
GROUP BY f.product_id, f.product_category, p.product_name
ORDER BY rev_per_product DESC;
--Best-selling products by revenue (top 4): Wireless Mouse Pad, Table Fan Oscillating, Ethernet Cable Cat6 5m, Desk Organizer Set

--By quantity
SELECT f.product_id, f.product_category, p.product_name,
SUM(quantity) AS quantity_sold_product
FROM fact_sales f
JOIN products p ON f.product_id = p.product_id
GROUP BY f.product_id, f.product_category, p.product_name
ORDER BY quantity_sold_product DESC;
--Best-selling products by quantity sold (top 3): Wireless Mouse Pad, Whiteboard Magnetic 90x60cm, IKEA Markus Chair

--By profit
SELECT f.product_id, f.product_category, p.product_name,
SUM(profit) AS profit_per_product
FROM fact_sales f
JOIN products p ON f.product_id = p.product_id
GROUP BY f.product_id, f.product_category, p.product_name
ORDER BY profit_per_product DESC;
--Best-selling products by profit (top 2): Seagate External HDD 2TB, Fellowes Paper Shredder

--Category Performance comparison
SELECT product_category,
SUM(quantity) AS total_qty_sold_cgy,
SUM(revenue) AS rev_cgy,
SUM(profit) AS profit_cgy,
ROUND(100.0 * SUM(profit) / NULLIF(SUM(revenue), 0), 2) AS profit_margin_pct
FROM fact_sales
GROUP BY product_category
ORDER BY profit_margin_pct DESC;
--Furniture generates the best balance between sales and costs. Home office items perform the worst in that sense, although their profitability is only 3.14% lower than those of Furniture
--Least sales and least profit come from Home Office items. Most profit from Furniture. Most sales from Accessories.

-- What % of orders contain multiple categories? (cross-selling)
WITH order_categories AS (
    SELECT 
        order_id,
        COUNT(DISTINCT product_category) AS categories_per_order
    FROM fact_sales
    GROUP BY order_id
)
SELECT 
    categories_per_order,
    COUNT(*) AS order_count,
    100.0 * COUNT(*) / (SELECT COUNT(DISTINCT order_id) FROM fact_sales) AS pct_of_orders
FROM order_categories
GROUP BY categories_per_order
ORDER BY categories_per_order;

-- Are we good at cross-selling?
-- Not ideal, as we see that only 15.84% of orders include items from 3 or more categories.
-- 40.72% of orders include only one product category. 
-- However, 43.44% include 2, indicating that customers are willing to buy items of different types in one order almost half the time.

-- Products with negative profit (investigate)
-- Find line items with negative profit
SELECT 
    product_id,
    order_id,
    revenue,
    cost,
    profit,
    discount,
    discount_amount
FROM fact_sales
WHERE profit < 0
ORDER BY profit;
--Looking at the data, discounts should not be the leading driver of losses. There are line items that have a discount of 0 but still generated losses.
--They might be data errors or the allocated shipping costs were incorrect.
--There might be some unrecorded costs with these orders that could have caused the loss.

-- Summary
SELECT 
    COUNT(*) AS total_loss_items,
    SUM(profit) AS total_losses,
    COUNT(DISTINCT product_id) AS products_with_losses,
    COUNT(DISTINCT order_id) AS orders_with_losses
FROM fact_sales
WHERE profit < 0;
--844 (individual line) items in 802 different orders caused losses.

SELECT f.product_id, f.order_id, f.product_category, p.product_name, f.profit
FROM fact_sales f
JOIN products p ON f.product_id = p.product_id
WHERE f.product_id = 'P137'
ORDER BY profit;
--Investigating Wireless Mouse Pad, EuroMart's strong performer and its profit numbers from each order.
--The product caused a loss for EuroMart in only 5 out of 196 orders.
--The loss of 3351 euros on it in the order #O202405264968 stands out as the heaviest one (also among other products).
--Need to investigate what caused this loss.

SELECT product_id, product_category, profit
FROM fact_sales
ORDER BY profit;

--Slow moving inventory (low stock turnover)
SELECT p.stock_status, SUM(f.revenue) AS rev_per_stock_status
FROM fact_sales f
JOIN products p
ON f.product_id = p.product_id
GROUP BY p.stock_status
ORDER BY rev_per_stock_status DESC;
--Products that are currently low in stock generated the most historical revenue (10 835 310 euros).

WITH rev_per_stock_st AS
(SELECT p.stock_status, SUM(f.revenue) AS rev_per_stock_status
FROM fact_sales f
JOIN products p
ON f.product_id = p.product_id
GROUP BY p.stock_status)

SELECT stock_status,
	rev_per_stock_status,
	ROUND(rev_per_stock_status / (SELECT SUM(revenue) FROM fact_sales) * 100.0, 2) AS pct_rev_stock_status
FROM rev_per_stock_st;

--SELECT
--	((SELECT rev_per_stock_status FROM rev_per_stock_st WHERE stock_status = 'Low Stock')
--	/ (SELECT SUM(revenue) FROM fact_sales) * 100.0
--	) AS pct_low_stock_rev
--46.63% of historical revenue comes from items that are currently in low stock.
--EuroMart needs to restock their best sellers. They're running out.
--Prioritize restocking items with high revenue and low stock status

-- Which low-stock items need urgent restocking?
SELECT 
    p.product_id,
    p.product_name,
    p.stock_status,
    SUM(f.revenue) AS total_revenue,
    COUNT(*) AS times_sold,
    SUM(f.quantity) AS total_quantity_sold
FROM fact_sales f
JOIN products p ON f.product_id = p.product_id
WHERE p.stock_status = 'Low Stock'
GROUP BY p.product_id, p.product_name, p.stock_status
ORDER BY total_revenue DESC;
--10 low-stock products have generated over 500K euros in revenue for EuroMart and therefore, need urgent restocking.

WITH rev_per_stock_st AS
(SELECT p.stock_status, SUM(f.revenue) AS rev_per_stock_status
FROM fact_sales f
JOIN products p
ON f.product_id = p.product_id
GROUP BY p.stock_status)

SELECT
	((SELECT rev_per_stock_status FROM rev_per_stock_st WHERE stock_status = 'Out of Stock')
	/ (SELECT SUM(revenue) FROM fact_sales) * 100.0
	) AS pct_out_of_stock_rev;
--Another 19.21% of historical revenue come from items that are out of stock at the moment.

SELECT 
    p.product_id,
    p.product_name,
    p.stock_status,
    SUM(f.revenue) AS total_revenue,
    COUNT(*) AS times_sold,
    SUM(f.quantity) AS total_quantity_sold
FROM fact_sales f
JOIN products p ON f.product_id = p.product_id
WHERE p.stock_status = 'Out of Stock'
GROUP BY p.product_id, p.product_name, p.stock_status
ORDER BY total_revenue DESC;

--4 products that are currently not in the inventory have to be restocked immediately. Each of these items has brought >670K euros in revenue over 3 years.
--The products are Ethernet Cable Cat6 5m, TP-Link Wifi Router, Sony WH-1000XM4 Headphones, Extension Cord 3m.

--<<<<<>>>>>--

-- 4) Operational Metrics

--Average dellivery time by ship_mode
SELECT ship_mode,
AVG(delivery_time_days) AS avg_delivery_time_days
FROM fact_sales
GROUP BY ship_mode
ORDER BY avg_delivery_time_days;
--Logically, the overnight ship mode takes only one day to deliver an order on average. The fastest ship mode.
--Economy ship mode tends to take the longest.

--On-time delivery rate (in terms of ship mode)
SELECT
	(SELECT COUNT(*) FROM orders WHERE ship_mode LIKE 'Overnight') AS overnight_deliveries,
	(SELECT COUNT(*) FROM orders WHERE ship_mode LIKE 'Express') AS express_deliveries,
	(SELECT COUNT(*) FROM orders WHERE ship_mode LIKE 'Standard')  AS standard_deliveries,
	(SELECT COUNT(*) FROM orders WHERE ship_mode LIKE 'Economy')  AS economy_deliveries,
	COUNT(CASE WHEN ship_mode LIKE 'Overnight' AND delivery_time_days <= 1 THEN 1 END) AS on_time_overnight,
	COUNT(CASE WHEN ship_mode LIKE 'Express' AND delivery_time_days <= 3 THEN 1 END) AS on_time_express,
	COUNT(CASE WHEN ship_mode LIKE 'Standard' AND delivery_time_days <= 10 THEN 1 END) AS on_time_standard,
	COUNT(CASE WHEN ship_mode LIKE 'Economy' AND delivery_time_days <= 14 THEN 1 END) AS on_time_economy
FROM orders;
--We can see that EuroMart is doing a great job, delivering all their orders on time with respect to the customer's chosen ship mode.

--Shipping cost as % of order value
WITH order_vs_ship_cost AS 
(SELECT
	order_id,
	SUM(gross_amount) AS order_value,
	SUM(shipping_cost) AS order_shipping_cost
FROM fact_sales
GROUP BY order_id)

SELECT 
	order_id,
	order_value,
	order_shipping_cost,
	ROUND(100.0 * order_shipping_cost / order_value, 2) AS pct_ship_cost_vs_order_value
FROM order_vs_ship_cost
ORDER BY pct_ship_cost_vs_order_value DESC;
--Max shipping cost % per order value was 25.25% for order #O202303133855. The minimum %-ges go down to below 0.01.

--Global shipping cost % vs orders value
SELECT
	SUM(shipping_cost) AS global_shipping_cost,
	SUM(gross_amount) AS global_orders_value,
	ROUND(100.0 * SUM(shipping_cost) / SUM(gross_amount), 2) AS global_ship_cost_vs_orders
FROM fact_sales;
--Globally, the shipping cost is around 18% of the value of orders

--Order priority vs Actual delivery time
SELECT
	order_priority,
	AVG(delivery_time_days) AS avg_delivery_days_per_priority
FROM fact_sales
GROUP BY order_priority
ORDER BY avg_delivery_days_per_priority;
--It is quite remarkable but the average delivery duration is equal per each priority group of orders.
--Urgent, high, low, and medium-priority orders are all delivered in 4 days, on average, which is a decent performance.
--EuroMart might need to increase the delivery speed for orders of higher urgency to maintain credibility and keep customers satisfied.

--<<<<<>>>>>--

--5) Regional Analysis

--Revenue by country/region
SELECT
	region_id,
	region_country,
	SUM(revenue) AS country_rev
FROM fact_sales
GROUP BY region_id, region_country
ORDER BY country_rev DESC;
--"Belgium is EuroMart's top market with €6.1M revenue (26% of total). However, Belgium's YoY growth is slowing (→ -16% in 2025, so far).
--Awaiting the end of the year for final 2025 results.
--Action: Investigate Belgium market saturation and expansion opportunities in other regions."

--Each country's revenue shares in % over 3 years
WITH country_revs AS
(SELECT
	region_id,
	region_country,
	SUM(revenue) AS country_rev
FROM fact_sales
GROUP BY region_id, region_country)

SELECT
	region_id,
	region_country,
	country_rev,
	ROUND(100.0 * country_rev / (SELECT SUM(revenue) FROM fact_sales), 2) AS country_rev_share
FROM country_revs
ORDER BY country_rev_share;
--Countries revenue shares: NL (12.29%), LU (12.54%), FR (24.1%), DE (24.82%), BE (26.26%)

--Regional sales growth (YoY)
WITH cur_country_rev AS
(SELECT
	region_id,
	region_country,
	order_year,
	SUM(revenue) AS current_country_rev
FROM fact_sales
GROUP BY region_id, region_country, order_year
)
SELECT region_id, region_country, order_year, current_country_rev,
LAG(current_country_rev, 1) OVER (PARTITION BY region_id, region_country ORDER BY order_year) AS previous_country_rev,
ROUND(
	 100.0 * (current_country_rev - LAG(current_country_rev, 1) OVER (PARTITION BY region_id, region_country ORDER BY order_year))
	/ NULLIF(LAG(current_country_rev, 1) OVER (PARTITION BY region_id, region_country ORDER BY order_year),0), 2
	) AS YoY_country_rev_growth
FROM cur_country_rev
ORDER BY order_year DESC;

--Each country saw decrease in revenue numbers in 2025 compared to 2024, but keep in mind the incompleteness of 2025 again.
--2023 was naturally a peak sales gowth rate for every EuroMart country compared to 2022 with data only for Nov and Dec.
--A complete comparison can be made between 2023 and 2024 though.
--We can see that Germany and France each accumulated (>11%) less sales in 2024 vs 2023, while Luxembourg saw the biggest rise in revenue (8.87%)

--Regional profit margins
SELECT
	region_id,
	region_country,
	order_year,
	SUM(profit) AS total_profit,
    SUM(revenue) AS total_revenue,
    ROUND(100.0 * SUM(profit) / NULLIF(SUM(revenue), 0), 2) AS profit_margin_pct
FROM fact_sales
GROUP BY region_id, region_country, order_year
ORDER BY order_year, profit_margin_pct DESC;
--Best profit margins each year: 2022 - France, 2023 - France, 2024 - Netherlands, 2025 - France.
--While Belgium is leading on overall sales numbers, France consistently displays strong profitability.
--All profit margins are in the range of 15.6%-19%. Consistency maintained; not much variability in profitability performance.
--Luxembourg with the lowest profit margins in 2024 and 2025.

--Let's compare manager performances
SELECT
	region_manager
	region_id,
	region_country,
	order_year,
	SUM(profit) AS total_profit,
    SUM(revenue) AS total_revenue,
    ROUND(100.0 * SUM(profit) / NULLIF(SUM(revenue), 0), 2) AS profit_margin_pct
FROM fact_sales
GROUP BY region_manager, region_id, region_country, order_year
ORDER BY order_year, profit_margin_pct DESC;
--All managers are maintaining the positive consistency in performances. The results do not fluctuate much.
--Being responsible for the entire Benelux region, Emma de Smet brings the highest revenue and keeps the profit margin levels at 15.6%-19%.
--Opportunity to implement campaigns to drive up Luxembourg's numbers and get Belgium's growth back on track.

--6) Time series analysis

--Three-month moving average sales
SELECT 
    order_year,
    order_month,
    order_month_name,
    SUM(revenue) AS monthly_revenue,
    AVG(SUM(revenue)) OVER (
        ORDER BY order_year, order_month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS three_month_moving_avg
FROM fact_sales
GROUP BY order_year, order_month, order_month_name
ORDER BY order_year, order_month;
--No 3-month period truly stands out as a clear sales leader over 2022-2025. I would point out the window of Aug-Sep-Oct

-- Seasonal patterns (Q4 spike?)
-- I will only compare complete quarters (so, I will exclude years 2022 and 2025)
SELECT 
    order_year,
    order_quarter,
    SUM(revenue) as quarterly_revenue,
    COUNT(DISTINCT order_month) AS months_in_quarter  -- Should be 3
FROM fact_sales
WHERE NOT (order_year = 2022 AND order_quarter = 4)  -- Incomplete
  AND NOT (order_year = 2025 AND order_quarter = 4)  -- Incomplete
GROUP BY order_year, order_quarter
ORDER BY order_year, order_quarter;

--MoM same month last year comparison
--Compare each month to the same month last year
--Example: Jan 2024 vs Jan 2023, Feb 2024 vs Feb 2023

-- This uses dim_date for easier date handling
SELECT 
    d.year,
    d.month_name,
    SUM(f.revenue) as revenue,
    LAG(SUM(f.revenue)) OVER (PARTITION BY d.month ORDER BY d.year) as same_month_last_year
FROM fact_sales f
JOIN dim_date d ON f.order_date = d.full_date
GROUP BY d.year, d.month, d.month_name
ORDER BY d.month, d.year;
--October sales in 2025 are impressive (over 743K euros). That is 61K euros better than October last year.
--Last year's November sales were actually the lowest among all months over 3 years (520K).
--Potential action: revise strategies implemented in October and replicate for the rest of this year to finish off 2025 strongly.
--Consider special marketing campaigns for Black Friday and Christmas.

--What is the average % growth month-over-month?
WITH monthly_revenue AS (
    SELECT 
        order_year,
        order_month,
        SUM(revenue) as monthly_revenue
    FROM fact_sales
    GROUP BY order_year, order_month
),
monthly_growth AS (
    SELECT 
        order_year,
        order_month,
        monthly_revenue,
        LAG(monthly_revenue) OVER (ORDER BY order_year, order_month) as prev_month_revenue,
        100.0 * (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY order_year, order_month))
            / LAG(monthly_revenue) OVER (ORDER BY order_year, order_month) as growth_pct
    FROM monthly_revenue
)
SELECT 
    AVG(growth_pct) as avg_monthly_growth_pct
FROM monthly_growth
WHERE growth_pct IS NOT NULL;

--The average MoM growth is -1.12%, suggesting that EuroMart's monthly revenues are more or less stable.

--Average QoQ growth %
WITH quarterly_revenue AS
(SELECT order_year, order_quarter,
	SUM(revenue) AS quarterly_rev
	FROM fact_sales
	GROUP BY order_year, order_quarter
	),
prev_qtr_revenue AS
	(SELECT order_year, order_quarter,
	quarterly_rev,
	LAG(quarterly_rev, 1) OVER (ORDER BY order_year, order_quarter) AS prev_qtr_rev,
	ROUND(
	100.0 * (quarterly_rev - LAG(quarterly_rev) OVER (ORDER BY order_year, order_quarter)) / 
	NULLIF(LAG(quarterly_rev) OVER (ORDER BY order_year, order_quarter), 0), 2) AS qoq_growth
	FROM quarterly_revenue
	)
	SELECT AVG(qoq_growth) AS avg_QoQ_growth
	FROM prev_qtr_revenue
	WHERE qoq_growth IS NOT NULL;

--Similar to MoM, average QoQ growth (0.48%) is pointing to EuroMart's stability in sales numbers over time.