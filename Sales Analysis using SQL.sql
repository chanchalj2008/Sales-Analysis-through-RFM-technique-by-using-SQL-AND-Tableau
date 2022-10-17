Use [Portfolio DB];

-- Inspecting the data
select * from [dbo].[sales_data_sample]; 

-- Checking unique Values
select distinct STATUS from [dbo].[sales_data_sample]; -- to be plotted in Tableau
select distinct YEAR_ID  from [dbo].[sales_data_sample];
select distinct PRODUCTLINE from [dbo].[sales_data_sample]; -- to be plotted in Tableau
select distinct COUNTRY from [dbo].[sales_data_sample]; -- to be plotted in Tableau
select distinct DEALSIZE from [dbo].[sales_data_sample]; -- to be plotted in Tableau
select distinct TERRITORY from [dbo].[sales_data_sample]; 

-- ANALYSIS

-- First let's group sales data by product line to know which product sold the most
SELECT PRODUCTLINE, SUM(SALES) AS Revenue
FROM   [dbo].[sales_data_sample]
GROUP BY PRODUCTLINE
ORDER BY 2 DESC;


-- grouping sales data by year_id
SELECT YEAR_ID, SUM(SALES) AS Revenue
FROM  [dbo].[sales_data_sample]
GROUP BY YEAR_ID
ORDER BY 2 DESC;

-- grouping sales data by dealsize
SELECT DEALSIZE, SUM(SALES) AS Revenue
FROM  [dbo].[sales_data_sample]
GROUP BY DEALSIZE
ORDER BY 2 DESC;

---What is the best product in United States?
select country, YEAR_ID, PRODUCTLINE, sum(sales) Revenue
from sales_data_sample
where country = 'USA'
group by  country, YEAR_ID, PRODUCTLINE
order by 4 desc

-- best month for sales in a specific year (including revenue generated and orders count)
SELECT MONTH_ID, SUM(SALES) AS Revenue, COUNT(ORDERNUMBER) AS Frequency
FROM  [dbo].[sales_data_sample]
WHERE YEAR_ID = 2003 -- change year to see sales for rest of the years
GROUP BY MONTH_ID
ORDER BY 2 DESC;

--OR

SELECT MONTH_ID, YEAR_ID, SUM(SALES) AS Revenue, COUNT(ORDERNUMBER) AS Frequency
FROM  [dbo].[sales_data_sample]
GROUP BY YEAR_ID, MONTH_ID
ORDER BY 3 DESC;


-- November has been the best month for sales so far, Find out what product was sold the most in November
SELECT MONTH_ID, PRODUCTLINE, SUM(SALES) AS Revenue, COUNT(ORDERNUMBER) AS Frequency
FROM  [dbo].[sales_data_sample]
WHERE YEAR_ID = 2003 and MONTH_ID = 11 --change year to see the rest
GROUP BY MONTH_ID, PRODUCTLINE
ORDER BY 3 DESC;
 
 -- OR

SELECT YEAR_ID, PRODUCTLINE, SUM(SALES) AS Revenue, COUNT(ORDERNUMBER) AS Frequency
FROM     sales_data_sample
WHERE  MONTH_ID = 11
GROUP BY YEAR_ID, PRODUCTLINE
ORDER BY 3 DESC

--Customers who have brought classic cars but not vintage cars
SELECT
    DISTINCT CUSTOMERNAME
FROM sales_data_sample
WHERE CUSTOMERNAME IN (SELECT CUSTOMERNAME FROM sales_data_sample WHERE productline = 'Classic Cars')
AND CUSTOMERNAME NOT IN (SELECT CUSTOMERNAME FROM sales_data_sample WHERE productline = 'Vintage Cars') 

-- Selecting the product line, product code, year, quantity, and price for the first year of every product sold (without specifying year number)
SELECT
    PRODUCTLINE,
    YEAR_ID as first_year,
    QUANTITYORDERED, PRICEEACH
FROM (
    SELECT
        PRODUCTLINE,
        YEAR_ID,
        DENSE_RANK() OVER(PARTITION BY PRODUCTLINE ORDER BY year_ID ASC) as year,
        QUANTITYORDERED,
        PRICEEACH
    FROM sales_data_sample
    ) year
WHERE year = 1

-- Who is our best customer ?
SELECT CUSTOMERNAME, SUM(sales) AS Revenue, AVG(sales) AS Average_Revenue, COUNT(ORDERNUMBER) AS Frequency, MAX(ORDERDATE) AS last_order_date
FROM  sales_data_sample GROUP BY CUSTOMERNAME
                 
/* Though, above query is giving best customer results but it is showing an incomplete picture.
Finding answer through RFM analysis and grouping the best customers result into 4 equal data groups (Using the window functions and CTE and creating the Temp table)  is a better approach to analyze the buying behaviour of customers

RECENCY (DATE DIFF BETWEEN THE CUSTOMER'S LAST ORDER DATE AND THE MAX ORDER DATE)
FREQUENCY (COUNT OF ORDER NUMBER)
MONETARY (SUM OF SALES) */

Drop table if exists #rfm
; With rfm as 
(
SELECT CUSTOMERNAME, SUM(sales) AS MonetaryValue, AVG(sales) AS AvgMonetaryValue, COUNT(ORDERNUMBER) AS Frequency, MAX(ORDERDATE) AS last_order_date,
                      (SELECT MAX(ORDERDATE) 
                       FROM      sales_data_sample) AS max_order_date, DATEDIFF(DD, MAX(ORDERDATE),
                      (SELECT MAX(ORDERDATE) 
                       FROM      sales_data_sample)) AS Recency
FROM     sales_data_sample
GROUP BY CUSTOMERNAME 
) ,
rfm_calc as (
select r.*,
NTILE(4) Over (order by Recency desc) rfm_recency,
NTILE(4) Over (order by Frequency) rfm_frequency,
NTILE(4) Over (order by MonetaryValue) rfm_monetary
from rfm r)
select c.*, rfm_recency+rfm_frequency+ rfm_monetary as rfm_cell, cast(rfm_recency as varchar) + cast(rfm_frequency as varchar)+ cast(rfm_monetary as varchar) 
rfm_cell_string into #rfm from rfm_calc c
             
-- inspecting the temp table
select * from #rfm
                    
-- Customer Segmentation Using Case statement 
select CUSTOMERNAME , rfm_recency, rfm_frequency, rfm_monetary,
	case 
		when rfm_cell_string in (111, 112 , 121, 122, 123, 132, 211, 221, 212, 114, 141) then 'lost_customers'  --lost customers
		when rfm_cell_string in (133, 134, 143, 234, 244, 334, 343, 344, 144) then 'slipping away, cannot lose' -- (Big spenders who haven’t purchased lately) slipping away
		when rfm_cell_string in (311, 421, 411, 331) then 'new customers'
		when rfm_cell_string in (222, 223, 232, 233, 322) then 'potential churners'
		when rfm_cell_string in (323, 333,321, 422,423, 332, 432) then 'active' --(Customers who buy often & recently, but at low price points)
		when rfm_cell_string in (433, 434, 443) then 'loyal'
		when rfm_cell_string in (444) then 'Superlative'
	end rfm_segment

from #rfm

--What products are most often sold together? 
--select * from sales_data_sample where ORDERNUMBER =  10411

select distinct OrderNumber, stuff(

	(select ',' + PRODUCTCODE
	from sales_data_sample p
	where ORDERNUMBER in 
		(

			select ORDERNUMBER
			from (
				select ORDERNUMBER, count(*) rn
				FROM sales_data_sample
				where STATUS = 'Shipped'
				group by ORDERNUMBER
			)m
			where rn = 3
		)
		and p.ORDERNUMBER = s.ORDERNUMBER
		for xml path (''))

		, 1, 1, '') ProductCodes

from sales_data_sample s
order by 2 desc



