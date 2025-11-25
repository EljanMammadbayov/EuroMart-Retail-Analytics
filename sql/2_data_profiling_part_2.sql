-- Drop existing tables if they exist
DROP TABLE IF EXISTS order_details;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS regions;

-- Create regions table with correct data types
CREATE TABLE regions (
    region_id VARCHAR(10) PRIMARY KEY,
    country VARCHAR(100),
    region_name VARCHAR(100),
    manager VARCHAR(100)
);

-- Create customers table
CREATE TABLE customers (
    customer_id VARCHAR(20) PRIMARY KEY,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    country VARCHAR(100),
    city VARCHAR(100),
    email VARCHAR(200),
    signup_date DATE,
    loyalty_status VARCHAR(50),
    age INT
);

-- Create products table
CREATE TABLE products (
    product_id VARCHAR(10) PRIMARY KEY,
    product_name VARCHAR(200),
    category VARCHAR(100),
    subcategory VARCHAR(100),
    unit_price DECIMAL(10, 2),
    cost_price DECIMAL(10, 2),
    supplier VARCHAR(100),
    stock_status VARCHAR(50)
);

-- Create orders table
CREATE TABLE orders (
    order_id VARCHAR(50) PRIMARY KEY,
    order_date DATE,
    customer_id VARCHAR(20),
    region_id VARCHAR(10),
    ship_mode VARCHAR(50),
    payment_method VARCHAR(50),
    delivery_time_days INT,
    shipping_cost DECIMAL(10, 2),
    order_priority VARCHAR(50),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (region_id) REFERENCES regions(region_id)
);

-- Create order_details table
CREATE TABLE order_details (
    order_detail_id VARCHAR(20) PRIMARY KEY,
    order_id VARCHAR(50),
    product_id VARCHAR(10),
    quantity INT,
    discount DECIMAL(5, 2),
    tax_rate DECIMAL(5, 2),
    total_price DECIMAL(10, 2),
    profit DECIMAL(10, 2),
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- Import regions
BULK INSERT regions
FROM 'C:\Users\Eljan Mammadbayov\OneDrive\Рабочий стол\Python Practice\Euromart Claude\raw\regions.csv'
WITH (
    FIRSTROW = 2,  -- Skip header
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    TABLOCK
);

-- Import customers
BULK INSERT customers
FROM 'C:\Users\Eljan Mammadbayov\OneDrive\Рабочий стол\Python Practice\Euromart Claude\raw\customers.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    TABLOCK
);

--Import products
BULK INSERT products
FROM 'C:\Users\Eljan Mammadbayov\OneDrive\Рабочий стол\Python Practice\Euromart Claude\raw\products.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    TABLOCK
);

--Import orders
BULK INSERT orders
FROM 'C:\Users\Eljan Mammadbayov\OneDrive\Рабочий стол\Python Practice\Euromart Claude\raw\orders.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    TABLOCK
);

--Import order_details
BULK INSERT order_details
FROM 'C:\Users\Eljan Mammadbayov\OneDrive\Рабочий стол\Python Practice\Euromart Claude\raw\order_details.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    TABLOCK
);

SELECT *
FROM customers;

SELECT *
FROM order_details;

SELECT *
FROM orders;

SELECT *
FROM products;

--All worked.

--Let's finish data profiling here, in this query.

-- 4) Finding orphaned records.
-- Find orders with customer_ids that don't exist in customers table
SELECT 
    o.order_id,
    o.customer_id,
    o.order_date,
    'Customer does not exist' AS issue
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

--No orphans found

-- Find orders with region_ids that don't exist in regions table
SELECT 
    o.order_id,
    o.region_id,
    o.order_date,
    'Region does not exist' AS issue
FROM orders o
LEFT JOIN regions r ON o.region_id = r.region_id
WHERE r.region_id IS NULL;

--No orphans found

-- Find order_details with order_ids that don't exist in orders table
SELECT 
    od.order_detail_id,
    od.order_id,
    od.product_id,
    'Order does not exist' AS issue
FROM order_details od
LEFT JOIN orders o ON od.order_id = o.order_id
WHERE o.order_id IS NULL;

--No orphans found

-- Find order_details with product_ids that don't exist in products table
SELECT
	od.order_detail_id,
	od.order_id,
	od.product_id,
	'Product does not exist' AS issue
FROM order_details od
LEFT JOIN products p ON od.product_id = p.product_id
WHERE p.product_id IS NULL;

--No orphans found


-- 5) Checking date ranges (any future dates? Other bizarre dates?)

--Customer signup date ranges
SELECT
	MIN(signup_date) AS earliest_signup,
	MAX(signup_date) AS latest_signup
FROM customers;

--Earliest signup on Jan 1, 2021. Latest on Nov 4, 2025. No future dates here.

--<<<<<<<>>>>>>>>--

--Order date ranges
SELECT
	MIN(order_date) AS earliest_order,
	MAX(order_date) AS latest_order
FROM orders;

--Earliest order on Nov 1, 2022. Latest on Nov 5, 2025. No future dates here. No orders before signup.


--6) Finding outliers

--Customer minimum and maximum ages + average age and standard deviation
SELECT
	MIN(age) AS youngest_customer,
	MAX(age) AS oldest_customer,
	AVG(age) AS average_customer_age,
	STDEV(age) AS stdev_age,
	 -- Quartiles
    (SELECT TOP 1 PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY age) OVER() FROM customers WHERE age IS NOT NULL) AS q1_age,
    (SELECT TOP 1 PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY age) OVER() FROM customers WHERE age IS NOT NULL) AS median_age,
    (SELECT TOP 1 PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY age) OVER() FROM customers WHERE age IS NOT NULL) AS q3_age
FROM customers;

--Ages in the range of 23-70. No extreme cases found.

SELECT customer_id, first_name, last_name, country, age
FROM customers
WHERE age IS NOT NULL
ORDER BY age DESC, customer_id;

--<<<<<<<>>>>>>>>--

--Checking profits
SELECT COUNT(*) AS total_rows
FROM order_details
WHERE profit IS NOT NULL;

WITH count_of_profits AS
(SELECT
	COUNT(CASE WHEN profit < 0 THEN 1 END) AS count_neg_profits,
	COUNT(CASE WHEN profit > 0 THEN 1 END) AS count_pos_profits,
	COUNT(*) AS total_profit_rows
FROM order_details
WHERE profit IS NOT NULL)

SELECT
	total_profit_rows,
	count_neg_profits,
	count_pos_profits,
	ROUND(100.0 * count_neg_profits / total_profit_rows, 1) AS pct_of_negative_profits,
	ROUND(100.0 * count_pos_profits / total_profit_rows, 1) AS pct_of_positive_profits
FROM count_of_profits;

--We have 849 (9.3%) of negative profits. The rest known profits are positive (8307, 90.7%).

SELECT
	MIN(profit) AS lowest_profit,
	MAX(profit) AS highest_profit,
	AVG(profit) AS average_profit,
	STDEV(profit) AS stdev_profit
FROM order_details;

--<<<<<<<>>>>>>>>--

-- Price statistics
SELECT 
    COUNT(*) AS total_products,
    MIN(unit_price) AS min_price,
    MAX(unit_price) AS max_price,
    AVG(unit_price) AS avg_price,
    STDEV(unit_price) AS st_dev_price,
    (SELECT TOP 1 PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY unit_price) OVER() FROM products) AS median_price
FROM products;

-- Products with extreme prices
SELECT 
    product_id,
    product_name,
    category,
    unit_price,
    CASE 
        WHEN unit_price < 10 THEN 'Very cheap'
        WHEN unit_price > 2000 THEN 'Very expensive'
        ELSE 'Normal'
    END AS price_category
FROM products
WHERE unit_price < 10 OR unit_price > 2000
ORDER BY unit_price;

--No extreme prices found. 0 very cheap and 0 very expensive

--<<<<<<<>>>>>>>>--

--Discount stats

SELECT 
	MIN(discount) AS min_discount,
	MAX(discount) AS max_discount,
	AVG(discount) AS avg_discount,
	STDEV(discount) AS stdev_discount,
	(SELECT TOP 1 PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY discount) OVER () FROM order_details WHERE discount IS NOT NULL)
	AS median_discount
FROM order_details;

--Discounts span from 0%-30%. No extreme discounts found.