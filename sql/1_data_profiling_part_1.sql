SELECT *
FROM customers;

SELECT *
FROM order_details;

SELECT *
FROM orders;

SELECT *
FROM products;

SELECT *
FROM regions;


--Let me write queries to understand the mess in the data. Checking the quality of the data and will report on it later.
--Performing initial data profiling (finding missing values, duplicates, checking data type issues, inconsistent formatting / casing, orphaned records, outliers, date ranges)

--1) Let's count nulls in each column. Finding missing values.

--DATA QUALITY PROFILE OF 'customers' table

SELECT 
    'customers' AS table_name,
    COUNT(*) AS total_rows,

    COUNT(CASE WHEN age IS NULL THEN 1 END) AS null_age_count,
    COUNT(CASE WHEN email IS NULL THEN 1 END) AS null_email_count,
    COUNT(CASE WHEN signup_date IS NULL THEN 1 END) AS null_signup_date_count,
    COUNT(CASE WHEN customer_id IS NULL THEN 1 END) AS null_custID_count,
	COUNT(CASE WHEN first_name IS NULL THEN 1 END) AS null_firstName_count,
	COUNT(CASE WHEN last_name IS NULL THEN 1 END) AS null_lastName_count,
	COUNT(CASE WHEN country IS NULL THEN 1 END) AS null_country_count,
	COUNT(CASE WHEN city IS NULL THEN 1 END) AS null_signup_date_count,
	COUNT(CASE WHEN loyalty_status IS NULL THEN 1 END) AS null_loyaltySt_count
FROM customers;

    -- Missing values in percentages
	SELECT
    ROUND(100.0 * (COUNT(*) - COUNT(email)) / COUNT(*), 1) AS pct_null_email,
    ROUND(100.0 * (COUNT(*) - COUNT(signup_date)) / COUNT(*), 1) AS pct_null_signup_date,
    ROUND(100.0 * (COUNT(*) - COUNT(age)) / COUNT(*), 1) AS pct_null_age,
	ROUND(100.0 * (COUNT(*) - COUNT(loyalty_status)) / COUNT(*), 1) AS pct_null_loyalty_status
FROM customers;
--3.4% of email, 4.1% of signup_date, 3.5% of age, and 21.6% of loyalty status values are missing.

--<<<<<<<>>>>>>>>--

--DATA QUALITY PROFILE OF 'order_details' table

SELECT
	'order_details' AS table_name,
	COUNT(*) AS total_rows,

	COUNT(CASE WHEN order_detail_id IS NULL THEN 1 END) AS null_order_detail_id_count,
	COUNT(CASE WHEN order_id IS NULL THEN 1 END) AS null_order_id_count,
	COUNT(CASE WHEN product_id IS NULL THEN 1 END) AS null_product_id_count,
	COUNT(CASE WHEN quantity IS NULL THEN 1 END) AS null_quantity_count,
	COUNT(CASE WHEN discount IS NULL THEN 1 END) AS null_discount_count,
	COUNT(CASE WHEN tax_rate IS NULL THEN 1 END) AS null_tax_rate_count,
	COUNT(CASE WHEN total_price IS NULL THEN 1 END) AS null_price_count,
	COUNT(CASE WHEN profit IS NULL THEN 1 END) AS null_profit_count
	FROM order_details;

	-- Missing values in percentages
	SELECT
	ROUND(100.0 * (COUNT(*) - COUNT(discount)) / COUNT(*), 1) AS pct_null_discount,
	ROUND(100.0 * (COUNT(*) - COUNT(profit)) / COUNT(*), 1) AS pct_null_profit
	FROM order_details;
--15.1% of discount and 11.5% of profit values are missing.

--<<<<<<<>>>>>>>>--

--DATA QUALITY PROFILE OF 'orders' table

SELECT
	'orders' AS table_name,
	COUNT(*) AS total_rows,

	COUNT(*) - COUNT(order_id) AS null_order_id_count,
	COUNT(*) - COUNT(order_date) AS null_order_date_count,
	COUNT(*) - COUNT(customer_id) AS null_customer_id_count,
	COUNT(*) - COUNT(region_id) AS null_region_id_count,
	COUNT(*) - COUNT(ship_mode) AS null_ship_mode_count,
	COUNT(*) - COUNT(payment_method) AS null_payment_method_count,
	COUNT(*) - COUNT(delivery_time_days) AS null_deliveryTime_count,
	COUNT(*) - COUNT(shipping_cost) AS null_shipping_count,
	COUNT(*) - COUNT(order_priority) AS null_order_priority_count
	FROM orders;

	--Missing values in percentages
	SELECT
	ROUND(100.0 * (COUNT(*) - COUNT(delivery_time_days)) / COUNT(*), 1) AS pct_null_delivery_time_days
	FROM orders;
--2.1% of delivery_time_days values are missing.

--<<<<<<<>>>>>>>>--

--DATA QUALITY PROFILE OF 'products' table

SELECT
	'products' AS table_name,
	COUNT(*) AS total_rows,

	COUNT(*) - COUNT(product_id) AS null_product_id_count,
	COUNT(*) - COUNT(product_name) AS null_product_name_count,
	COUNT(*) - COUNT(category) AS null_category_count,
	COUNT(*) - COUNT(subcategory) AS null_subcategory_count,
	COUNT(*) - COUNT(unit_price) AS null_unit_price_count,
	COUNT(*) - COUNT(cost_price) AS null_cost_price_count,
	COUNT(*) - COUNT(supplier) AS null_supplier_count,
	COUNT(*) - COUNT(stock_status) AS null_stock_status_count
	FROM products;

	--Missing values in percentages
	SELECT
	ROUND(100.0 * (COUNT(*) - COUNT(cost_price)) / COUNT(*), 1) AS pct_null_cost_price
	FROM products;
--11.7% of cost price values are missing.

--2) Finding duplicate records

--DUPLICATE ANALYSIS OF 'customers' table

-- Let's find emails that appear more than once
SELECT 
    email,
    COUNT(*) AS occurrence_count,
    STRING_AGG(customer_id, ', ') AS customer_ids  -- Shows which IDs have this email
FROM customers
WHERE email IS NOT NULL  -- Exclude nulls from duplicate check
GROUP BY email
HAVING COUNT(*) > 1
ORDER BY occurrence_count DESC;

--Found duplicates. 298 email addresses appear 2-6 times.
--Could be because of multiple signups or data entry errors. 
--Later in cleaning, we can deal with this by merging duplicates and keeping the earliest signup.
--Orders from all duplicates will have to be reassigned to a customer_id that will be left.
--Therefore, create mapping when merging and implement changes with customer_ids (FK) properly in 'orders' table.

SELECT
	first_name,
	last_name,
	email,
	COUNT(*) AS occurrence_count
FROM customers
WHERE email IS NOT NULL
GROUP BY first_name, last_name, email
HAVING COUNT(*) > 1
ORDER BY first_name, last_name, email;

-- Extra check: these are the same people — the email duplicates span to first_name and last_name as well.

-- Preview: Which customer should be kept?
WITH duplicates AS (
    SELECT email
    FROM customers
    WHERE email IS NOT NULL
    GROUP BY email
    HAVING COUNT(*) > 1
)
SELECT 
    c.email,
    c.customer_id,
    c.signup_date,
    (SELECT COUNT(*) FROM orders WHERE customer_id = c.customer_id) AS order_count,
    ROW_NUMBER() OVER (PARTITION BY c.email ORDER BY c.signup_date ASC, c.customer_id ASC) AS keep_rank
FROM customers c
INNER JOIN duplicates d ON c.email = d.email
ORDER BY c.email, keep_rank;
-- keep_rank = 1 are the ones to keep.

--<<<<<<<>>>>>>>>--

--DUPLICATE ANALYSIS OF 'order_details' table

-- Same product in same order and same quantity multiple times
SELECT 
    order_id,
    product_id,
	quantity,
    COUNT(*) AS occurrence_count,
    SUM(quantity) AS total_quantity
FROM order_details
GROUP BY order_id, product_id, quantity
HAVING COUNT(*) > 1;

--Found (potential) duplicates. 124 instances of same product in same order.
--29 exact duplicates (same product + quantity).
--Revenue may be overcounted. Later, in cleaning remove exact duplicates and investigate others.

-- Are the duplicated line items EXACTLY the same?
SELECT 
    order_id,
    product_id,
    quantity,
    discount,
    total_price,
    COUNT(*) AS exact_duplicate_count
FROM order_details
GROUP BY order_id, product_id, quantity, discount, total_price
HAVING COUNT(*) > 1
ORDER BY exact_duplicate_count DESC;

--No, 29 observed duplicate records get reduced to only two.
--So, (124-29 = 95) records with same product in same order are likely legitimate. Product could be ordered multiple times in one order (e.g., 1 unit, then 3 more units). Keep
--(29-2 = 27) "Near-Duplicates" are possible legitimate cases (price changes during order, promotions applied on item but system generated new line instead of updating). Keep or remove.
--2 order lines with 100% identical customer data - delete 2 duplicate records.
--I will remove the 27 'near-duplicates' too for less complexity and more stability.

-- Complete breakdown of all product duplicates in orders
WITH all_duplicates AS (
    SELECT 
        order_id,
        product_id,
        COUNT(*) AS line_count,
        COUNT(DISTINCT quantity) AS distinct_quantities,
        COUNT(DISTINCT discount) AS distinct_discounts,
        COUNT(DISTINCT total_price) AS distinct_prices,
        SUM(quantity) AS total_quantity,
        STRING_AGG(CAST(quantity AS VARCHAR), ', ') AS quantities,
        STRING_AGG(CAST(ISNULL(discount, 0) AS VARCHAR), ', ') AS discounts
    FROM order_details
    GROUP BY order_id, product_id
    HAVING COUNT(*) > 1
)
SELECT 
    CASE 
        WHEN distinct_quantities = 1 AND distinct_discounts = 1 AND distinct_prices = 1 
            THEN 'Exact Duplicate (ERROR)'
        WHEN distinct_quantities = 1 AND distinct_discounts > 1 
            THEN 'Same Qty, Different Discount'
        WHEN distinct_quantities = 1 AND distinct_prices > 1 
            THEN 'Same Qty, Different Price'
        WHEN distinct_quantities > 1 
            THEN 'Different Quantities (Likely Legitimate)'
        ELSE 'Other'
    END AS duplicate_type,
    COUNT(*) AS group_count,
    SUM(line_count) AS total_records
FROM all_duplicates
GROUP BY 
    CASE 
        WHEN distinct_quantities = 1 AND distinct_discounts = 1 AND distinct_prices = 1 
            THEN 'Exact Duplicate (ERROR)'
        WHEN distinct_quantities = 1 AND distinct_discounts > 1 
            THEN 'Same Qty, Different Discount'
        WHEN distinct_quantities = 1 AND distinct_prices > 1 
            THEN 'Same Qty, Different Price'
        WHEN distinct_quantities > 1 
            THEN 'Different Quantities (Likely Legitimate)'
        ELSE 'Other'
    END
ORDER BY group_count DESC;

--<<<<<<<>>>>>>>>--

--DUPLICATE ANALYSIS OF 'orders' table

-- Check for duplicate order_ids (PK)
SELECT
	order_id,
	COUNT(*) AS occurrence_count
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;

--none found

--<<<<<<<>>>>>>>>--

--DUPLICATE ANALYSIS OF 'products' table

-- Products with same name (potential duplicates)
SELECT 
    product_name,
    COUNT(*) AS occurrence_count,
    STRING_AGG(product_id, ', ') AS product_ids
FROM products
GROUP BY product_name
HAVING COUNT(*) > 1;

--none found

--<<<<<<<>>>>>>>>--

--DUPLICATE ANALYSIS OF 'regions' table

SELECT *
FROM regions;

--Regions 06-08 are redundant, they have to be merged with their respective region_ids from R01-R05.
--As region_id is a foreign key for orders, we will need to create the changes mapping when merging and match new region_ids correctly in 'orders' table.

--3) Checking data type issues
--Data type issues with email in 'customers'. Formatting is not consistent: missing @. Some emails are all caps.

SELECT email, COUNT(email) OVER () AS missing_@_emails
FROM customers
WHERE email NOT LIKE '%@%';

--@ is missing in 60 emails in 'customers'

SELECT 
    customer_id,
    email,
    CASE 
        WHEN email NOT LIKE '%@%' THEN 'Missing @'
        WHEN email NOT LIKE '%@%.%' THEN 'Missing domain'
        WHEN email LIKE '%@@%' THEN 'Double @'
        WHEN email LIKE '% %' THEN 'Contains space'
        WHEN LEN(email) < 5 THEN 'Too short'
        ELSE 'Valid format'
    END AS email_issue
FROM customers
WHERE email IS NOT NULL
    AND (
        email NOT LIKE '%@%' 
        OR email NOT LIKE '%@%.%'
        OR email LIKE '%@@%'
        OR email LIKE '% %'
        OR LEN(email) < 5
    );

--In addition to @ missing in 60 of emails, there are some that are cased as all caps. They all need to be standardized.

--In 'order_details', product_id is in the wrong format (float), discount and tax rate are recorded as time
--In 'orders', region_id is in the wrong format (float)
--In 'products', product_id is in the wrong format (float)
--Happened due to incorrect import Wizard data type assignments.
--Fixed in the second raw database.
--The casing in the following columns is inconsistent:
--email(customers), ship_mode(orders), payment_method(orders), order_priority(orders), stock_status(products), country(regions), region_name(regions), and manager(regions)
--Standardize all of them