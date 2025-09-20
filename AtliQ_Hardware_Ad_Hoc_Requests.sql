# Request 1
SELECT
	DISTINCT(market)
FROM dim_customer
WHERE customer ="Atliq Exclusive" AND region ="APAC"
ORDER BY market;

#Request 2
WITH yearly_counts AS (
    SELECT
        fiscal_year,
        COUNT(DISTINCT product_code) AS unique_products
    FROM
        fact_sales_monthly
    GROUP BY
        fiscal_year
),
counts_2020 AS (
    SELECT unique_products AS unique_products_2020 FROM yearly_counts WHERE fiscal_year=2020
),
counts_2021 AS (
    SELECT unique_products AS unique_products_2021 FROM yearly_counts WHERE fiscal_year=2021
)
SELECT
    c20.unique_products_2020,
    c21.unique_products_2021,
    ROUND(((c21.unique_products_2021 - c20.unique_products_2020) / c20.unique_products_2020) * 100, 2) AS percentage_chg
FROM
    counts_2020 c20,
    counts_2021 c21;
    
# Request 3
SELECT
	segment,
	COUNT(DISTINCT product_code) AS product_count
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;

# Request 4
WITH all_segments AS (
    SELECT DISTINCT segment
    FROM dim_product
),
products_2020 AS (
    SELECT
        dp.segment,
        COUNT(DISTINCT fsm.product_code) AS product_count_2020
    FROM fact_sales_monthly fsm
    JOIN
		dim_product dp ON fsm.product_code = dp.product_code
    WHERE fsm.fiscal_year = 2020
    GROUP BY dp.segment
),
products_2021 AS (
    SELECT
        dp.segment,
        COUNT(DISTINCT fsm.product_code) AS product_count_2021
    FROM fact_sales_monthly fsm
    JOIN
        dim_product dp ON fsm.product_code = dp.product_code
    WHERE fsm.fiscal_year = 2021
    GROUP BY dp.segment
)
SELECT
    als.segment,
    p20.product_count_2020 AS product_count_2020,
    p21.product_count_2021 AS product_count_2021,
    (p21.product_count_2021 - p20.product_count_2020) AS difference
FROM all_segments als
LEFT JOIN
    products_2020 p20 ON als.segment = p20.segment
LEFT JOIN
    products_2021 p21 ON als.segment = p21.segment
ORDER BY difference DESC;

# Request 5
SELECT
    dp.product_code,
    dp.product,
    fmc.manufacturing_cost
FROM dim_product dp
JOIN
    fact_manufacturing_cost fmc ON dp.product_code = fmc.product_code
WHERE fmc.manufacturing_cost = (SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost)
UNION ALL
SELECT
    dp.product_code,
    dp.product,
    fmc.manufacturing_cost
FROM dim_product dp
JOIN
    fact_manufacturing_cost fmc ON dp.product_code = fmc.product_code
WHERE fmc.manufacturing_cost = (SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost);

# Request 6
SELECT
    dc.customer_code,
    dc.customer,
    ROUND(AVG(fpid.pre_invoice_discount_pct) * 100, 2) AS average_discount_percentage
FROM
    dim_customer dc
JOIN
    fact_pre_invoice_deductions fpid
    ON dc.customer_code = fpid.customer_code
WHERE
    fpid.fiscal_year = 2021
    AND dc.market = 'India'
GROUP BY
    dc.customer_code,
    dc.customer
ORDER BY
    average_discount_percentage
LIMIT 5;

# Request 7
SELECT
    MONTHNAME(fsm.date) AS Month,
    YEAR(fsm.date) AS Year,
    ROUND(SUM(fsm.sold_quantity * fgp.gross_price) / 1000000, 2) AS `Gross sales Amount (Millions)`
FROM
    dim_customer dc
JOIN
    fact_sales_monthly fsm
    ON dc.customer_code = fsm.customer_code
JOIN
    fact_gross_price fgp
    ON fsm.product_code = fgp.product_code
    AND fsm.fiscal_year = fgp.fiscal_year
WHERE
    dc.customer = 'Atliq Exclusive'
GROUP BY
    YEAR(fsm.date),
    MONTHNAME(fsm.date)
ORDER BY
    YEAR(fsm.date),
    MONTHNAME(fsm.date);

# Request 8
SELECT
    CASE
        WHEN MONTH(date) IN (9, 10, 11) THEN 'Q1'
        WHEN MONTH(date) IN (12, 1, 2) THEN 'Q2'
        WHEN MONTH(date) IN (3, 4, 5) THEN 'Q3'
        WHEN MONTH(date) IN (6, 7, 8) THEN 'Q4'
    END AS `Quarter`,
    FORMAT(SUM(sold_quantity) / 1000000.0, 2) AS `total_sold_quantity (mln)`
FROM
    fact_sales_monthly
WHERE
    fiscal_year = 2020
GROUP BY
    `Quarter`
ORDER BY
    `total_sold_quantity (mln)` DESC;

# Request 9
WITH ChannelGrossSales AS (
    SELECT
        c.channel,
        SUM(s.sold_quantity * gp.gross_price) AS total_gross_sales_for_channel
    FROM
        fact_sales_monthly s
    JOIN
        dim_customer c ON s.customer_code = c.customer_code
    JOIN
        fact_gross_price gp ON
            s.product_code = gp.product_code AND
            s.fiscal_year = gp.fiscal_year
    WHERE
        s.fiscal_year = 2021
    GROUP BY
        c.channel
)
SELECT
    channel,
    FORMAT(total_gross_sales_for_channel / 1000000, 2) AS gross_sales_mln,
    FORMAT((total_gross_sales_for_channel / SUM(total_gross_sales_for_channel) OVER()) * 100, 2) AS percentage
FROM
    ChannelGrossSales
ORDER BY
    total_gross_sales_for_channel DESC;

# Request 10
WITH ProductSales AS (
    SELECT
        dp.division,
        dp.product_code,
        dp.product,
        SUM(fsm.sold_quantity) AS total_sold_quantity
    FROM
        fact_sales_monthly fsm
    JOIN
        dim_product dp ON fsm.product_code = dp.product_code
    WHERE
        fsm.fiscal_year = 2021
    GROUP BY
        dp.division,
        dp.product_code,
        dp.product
),
RankedProductSales AS (
    SELECT
        division,
        product_code,
        product,
        total_sold_quantity,
        DENSE_RANK() OVER (PARTITION BY division ORDER BY total_sold_quantity DESC) AS rank_order
    FROM
        ProductSales
)
SELECT
    division,
    product_code,
    product,
    total_sold_quantity,
    rank_order
FROM
    RankedProductSales
WHERE
    rank_order <= 3
ORDER BY
    division,
    rank_order;



