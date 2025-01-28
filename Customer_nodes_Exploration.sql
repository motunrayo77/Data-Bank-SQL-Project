SELECT *
FROM data_bank.regions;

SELECT *
FROM data_bank.customer_nodes;

SELECT *
FROM data_bank.customer_transactions;

Q1--How many unique nodes are there on the Data Bank system?

SELECT COUNT(DISTINCT node_id) AS unique_nodes
FROM data_bank.customer_nodes;

Q2--What is the number of nodes per region?
SELECT 
	r.region_id,
	COUNT(node_id) AS nodes_per_region
FROM data_bank.customer_nodes n
JOIN data_bank.regions r
ON r.region_id = n.region_id
GROUP BY r.region_id
ORDER BY nodes_per_region DESC;
 

Q3--How many customers are allocated to each region?

SELECT 
	r.region_id,
	COUNT(DISTINCT customer_id) AS allocated_customers
FROM data_bank.customer_nodes n
JOIN data_bank.regions r
ON r.region_id = n.region_id
GROUP BY r.region_id
ORDER BY allocated_customers DESC;


Q4--How many days on average are customers reallocated to a different node?

SELECT
	customer_id,
	AVG(end_date - start_date) AS average_days
FROM data_bank.customer_nodes n
JOIN data_bank.regions r
ON r.region_id = n.region_id
WHERE end_date != '9999-12-31'
GROUP BY customer_id
ORDER BY customer_id;


Q5--What is the median, 80th and 95th percentile for this same reallocation days metric for each region?

WITH reallocation AS (
	SELECT 
		region_name, 
		r.region_id,
		AGE(end_date, start_date)AS date_diff
	FROM data_bank.customer_nodes n
	JOIN data_bank.regions r
	ON r.region_id = n.region_id
	WHERE end_date != '9999-12-31'
)
SELECT 
	DISTINCT region_name,
	(SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY date_diff) FROM reallocation AS rn WHERE rn.region_name = reallocation.region_name) AS median_days,
    (SELECT PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY date_diff )FROM reallocation rn WHERE rn.region_name = reallocation.region_name) AS p80_days,
    (SELECT PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY date_diff) FROM reallocation rn WHERE rn.region_name = reallocation.region_name) AS p95_days
FROM reallocation;
