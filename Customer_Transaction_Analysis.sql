SELECT *
FROM data_bank.regions;

SELECT *
FROM data_bank.customer_nodes;


SELECT *
FROM data_bank.customer_transactions;

Q1--What is the unique count and total amount for each transaction type?
SELECT 
	COUNT(DISTINCT txn_type) 
FROM data_bank.customer_transactions;

SELECT
	txn_type, 
	SUM(txn_amount) 
FROM data_bank.customer_transactions
GROUP BY txn_type;


Q2--What is the average total historical deposit counts and amounts for all customers?

SELECT
	SUM(txn_amount) 
FROM data_bank.customer_transactions;

SELECT
	AVG(txn_amount) AS average_total
FROM data_bank.customer_transactions;


Q3--For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?


-- the number of individual months the transactions spanned
SELECT
	DISTINCT(EXTRACT (MONTH FROM txn_date)) as month
FROM data_bank.customer_transactions;



SELECT 
     m_month,
    COUNT(DISTINCT customer_id) AS customers_per_month  
FROM(
    SELECT 
        customer_id, 
        EXTRACT(MONTH FROM txn_date) AS m_month,
        SUM(CASE WHEN txn_type = 'deposit' THEN 1 ELSE 0 END) AS total_deposits,
        MAX(CASE WHEN txn_type = 'purchase' THEN 1 ELSE 0 END) AS made_purchase, 
        MAX(CASE WHEN txn_type = 'withdrawal' THEN 1 ELSE 0 END) AS made_withdrawal
    FROM 
        data_bank.customer_transactions ct
    GROUP BY 
        customer_id, EXTRACT(MONTH FROM txn_date)
)
WHERE 
    total_deposits > 1 
    AND (made_purchase = 1 OR made_withdrawal = 1) 
GROUP BY 
    m_month
ORDER BY 
    m_month;



Q4--What is the closing balance for each customer at the end of the month?

SELECT
	customer_id,
	SUM(txn_amount)OVER(PARTITION BY customer_id ORDER BY txn_date ROWS BETWEEN
   			   UNBOUNDED PRECEDING AND CURRENT ROW)  AS closing_bal
FROM data_bank.customer_transactions
GROUP BY customer_id, txn_amount,txn_date
ORDER BY customer_id, closing_bal;



WITH monthly_transactions AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', txn_date) AS month,
        SUM(CASE 
            WHEN txn_type = 'deposit' THEN txn_amount
            WHEN txn_type = 'withdrawal' THEN txn_amount
            WHEN txn_type = 'purchase' THEN txn_amount
            ELSE 0
        END) AS monthly_net_change
    FROM 
       data_bank.customer_transactions
    GROUP BY 
        customer_id, DATE_TRUNC('month', txn_date)
),
running_balance AS (
    SELECT 
        customer_id,
        month,
        SUM(monthly_net_change) OVER (
            PARTITION BY customer_id
            ORDER BY month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS closing_balance
    FROM 
        monthly_transactions
)
SELECT 
    customer_id,
    month,
    closing_balance
FROM 
    running_balance
ORDER BY 
    customer_id, month;



SELECT 
	customer_id, 
	SUM(txn_amount) AS closing_bal
FROM data_bank.customer_transactions
GROUP BY customer_id
ORDER BY closing_bal;

Q5--What is the percentage of customers who increase their closing balance by more than 5%?


  -- Calculate closing balances for each customer and month
WITH closing_balances AS (
        SELECT 
        	customer_id,
       		 DATE_TRUNC('month', txn_date) AS month,
        	SUM(CASE 
				WHEN txn_type = 'deposit' THEN txn_amount
				WHEN txn_type IN ('withdrawal', 'purchase') THEN txn_amount
				ELSE 0
			END) OVER (
				PARTITION BY customer_id
				ORDER BY DATE_TRUNC('month', txn_date)
				ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
			) AS closing_balance
 		FROM 
	data_bank.customer_transactions
),
balance_changes AS (               -- Comparing current and previous month's closing balances
    SELECT 
        customer_id,
        month,
        closing_balance,
        LAG(closing_balance) OVER (PARTITION BY customer_id ORDER BY month) AS previous_balance,
        CASE 
            WHEN LAG(closing_balance) OVER (PARTITION BY customer_id ORDER BY month) > 0 THEN
                ((closing_balance - LAG(closing_balance) OVER (PARTITION BY customer_id ORDER BY month)) / 
                 LAG(closing_balance) OVER (PARTITION BY customer_id ORDER BY month)) * 100
            ELSE 0
        END AS percent_change
    FROM 
        closing_balances
),
qualified_customers AS (           -- Identify customers with more than 5% increase in any month
    SELECT DISTINCT customer_id
    FROM balance_changes
    WHERE percent_change > 5
),
total_customers AS (               --  Count the total number of unique customers
    SELECT COUNT(DISTINCT customer_id) AS total_customer_count
   FROM data_bank.customer_transactions
)
                                    --  Calculate the percentage of qualifying customers
SELECT 
    COUNT(qc.customer_id) / tc.total_customer_count * 100 AS percent_customers
FROM 
    qualified_customers qc
CROSS JOIN 
    total_customers tc
		GROUP BY tc.total_customer_count;


