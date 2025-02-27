use amazondb;

/*
1. Top Selling Products
Query the top 10 products by total sales value.
Challenge: Include product name, total order id quantity, and total sales value.
*/

alter table order_items add column total_sales float;

set sql_safe_updates = 0;

update order_items set total_sales = price_per_unit * quantity;

select 
	oi.product_id, 
    p.product_name, 
    sum(oi.total_sales) as total_sales, 
    count(o.order_id) as total_orderId 
from
	order_items as oi 
join 
	products as p on oi.product_id = p.product_id 
join 
    orders as o on o.order_id = oi.order_id 
group by 1, 2 
order by 3 desc 
limit 10;


/*
2. Revenue by Category
Calculate total revenue generated by each product category.
Challenge: Include the percentage contribution of each category to total revenue.
*/

select 
	p.category_id, 
    c.category_name, 
    sum(oi.total_sales) as total_sales, 
    sum(oi.total_sales)/(select sum(total_sales) from order_items) * 100 as percentage_contribution
from 
	products as p 
join 
	order_items as oi on p.product_id = oi.product_id 
left join 
	category as c on c.category_id = p.category_id
group by 1, 2;


/*
3. Average Order Value (AOV)
Compute the average order value for each customer.
Challenge: Include only customers with more than 5 orders.
*/

select
	c.customer_id,
    concat(c.first_name, ' ', c.last_name) as Full_Name,
    count(o.order_id) as Total_orders,
    sum(oi.total_sales)/count(o.order_id) as AOV
from
	customers as c
join 
	orders as o on c.customer_id = o.customer_id
join
	order_items as oi on o.order_id = oi.order_id
group by 1 having count(o.order_id) > 5;


/*
4. Monthly Sales Trend
Query monthly total sales over the past year.
Challenge: Display the sales trend, grouping by month, return current_month sale, last month sale!
*/

select 
	year,
	month,
	total_sale as current_month_sale,
	lag(total_sale, 1) over(order by year, month) as last_month_sale
from
	(
	select 
		extract(month from o.order_date) as month,
		extract(year from o.order_date) as year,
		round(
				sum(oi.total_sales) ,2) as total_sale
	from
		orders as o
	join
		order_items as oi on oi.order_id = o.order_id
	where 
		o.order_date >= current_date - interval 1 year
	group by 1, 2
	order by year, month
	) as t1;


/*
5. Customers with No Purchases
Find customers who have registered but never placed an order.
Challenge: List customer details and the time since their registration.
*/

select * 
from 
	customers as c 
left join 
	orders as o on c.customer_id = o.customer_id 
where 
	o.customer_id is null;


/*
6. Least-Selling Categories by State
Identify the least-selling product category for each state.
Challenge: Include the total sales for that category within each state.
*/

with ranking_table as (
	select 
		c.state, 
		cat.category_name, 
		sum(oi.total_sales) as total_sale,
		rank() over(partition by c.state order by sum(oi.total_sales)) as ranks
	from
		customers as c 
	join
		orders as o on c.customer_id = o.customer_id
	join
		order_items as oi on o.order_id = oi.order_id
	join
		products as p on oi.product_id = p.product_id
	join 
		category as cat on p.category_id = cat.category_id
	group by 1, 2
)

select *
from
	ranking_table
where
	ranks = 1;


/*
7. Customer Lifetime Value (CLTV)
Calculate the total value of orders placed by each customer over their lifetime.
Challenge: Rank customers based on their CLTV.
*/

select
	c.customer_id,
    concat(c.first_name, ' ', c.last_name) as full_name,
    sum(oi.total_sales) as total_sale,
    dense_rank() over(order by sum(oi.total_sales) desc) as ranks
from 
	customers as c
join
	orders as o on c.customer_id = o.customer_id
join 
	order_items as oi on o.order_id = oi.order_id
group by 1,2;


/*
8. Inventory Stock Alerts
Query products with stock levels below a certain threshold (e.g., less than 10 units).
Challenge: Include last restock date and warehouse information.
*/

select 
	i.inventory_id,
	p.product_name,
	i.stock as current_stock_left,
	i.last_stock_date,
	i.warehouse_id
from
	inventory as i
join 
	products as p on p.product_id = i.product_id
WHERE 
	stock < 10;


/*
9. Shipping Delays
Identify orders where the shipping date is later than 3 days after the order date.
Challenge: Include customer, order details, and delivery provider.
*/

select
	c.*,
	o.*,
	s.shipping_providers,
	s.shipping_date - o.order_date as days_took_to_ship
from
	orders as o
join
	customers as c on c.customer_id = o.customer_id
join
	shippings as s on o.order_id = s.order_id
where
	s.shipping_date - o.order_date > 3;


/*
10. Payment Success Rate 
Calculate the percentage of successful payments across all orders.
Challenge: Include breakdowns by payment status (e.g., failed, pending).
*/

select 
	p.payment_status,
	count(*) as total_cnt,
	count(*)/(select COUNT(*) from payments) * 100
from
	orders as o
join
	payments as p on o.order_id = p.order_id
group by 1;


/*
11. Top Performing Sellers
Find the top 5 sellers based on total sales value.
Challenge: Include both successful and failed orders, and display their percentage of successful orders.
*/

with top_sellers as
	(select
		s.seller_id,
		s.seller_name,
		SUM(oi.total_sales) as total_sale
	from 
		orders as o
	join
		sellers as s on o.seller_id = s.seller_id
	join
		order_items as oi on oi.order_id = o.order_id
	group by 1, 2
	order by 3 desc
	limit 5
	),

sellers_reports as
	(select
		o.seller_id,
		ts.seller_name,
		o.order_status,
		count(*) as total_orders
	from
		orders as o
	join
		top_sellers as ts on ts.seller_id = o.seller_id
	where
		o.order_status not in ('Inprogress', 'Returned')
	group by 1, 2, 3
	)
    
select
	seller_id,
	seller_name,
	SUM(case when order_status = 'Completed' then total_orders else 0 end) as Completed_orders,
	SUM(case when order_status = 'Cancelled' then total_orders else 0 end) as Cancelled_orders,
	SUM(total_orders) as total_orders,
	SUM(case when order_status = 'Completed' then total_orders else 0 end)/SUM(total_orders) * 100 as successful_orders_percentage
from sellers_reports
group by 1, 2;


/*
12. Product Profit Margin
Calculate the profit margin for each product (difference between price and cost of goods sold).
Challenge: Rank products by their profit margin, showing highest to lowest.
*/

select
	product_id,
	product_name,
	profit_margin,
	dense_rank() over( order by profit_margin desc) as product_ranking
from
	(SELECT 
		p.product_id,
		p.product_name,
		sum(total_sales - (p.cogs * oi.quantity))/sum(total_sales) * 100 as profit_margin
	from 
		order_items as oi
	join 
		products as p on oi.product_id = p.product_id
	group by 1,2
	) as t1;


/*
13. Most Returned Products
Query the top 10 products by the number of returns.
Challenge: Display the return rate as a percentage of total units sold for each product.
*/

select
	p.product_id, 
    p.product_name,
    count(*) as units_sold,
    sum(case when o.order_status = 'Returned' then 1 else 0 end) as total_returned,
    sum(case when o.order_status = 'Returned' then 1 else 0 end)/count(*) as return_percentage
from
	products as p
join
	order_items as oi on p.product_id = oi.product_id
join
	orders as o on oi.order_id = o.order_id
group by 1, 2
order by 5 desc 
limit 10;


/*
14. Orders Pending Shipment
Find orders that have been paid but are still pending shipment.
Challenge: Include order details, payment date, and customer information.
*/

with pending_shipment as (
	select
		o.order_id,
        o.order_date,
        o.order_status,
        c.customer_id,
        concat(c.first_name, ' ', c.last_name) as full_name,
        p.payment_status,
        p.payment_date,
        s.delivery_status
	from
		orders as o
	join
		shippings as s on o.order_id = s.order_id
	join
		payments as p on o.order_id = p.order_id
	join
		customers as c on c.customer_id = o.customer_id
	where
		p.payment_status like 'Payment Successed'
)

select *
from
	pending_shipment
where
	delivery_status like 'Shipped';


/*
15. Inactive Sellers
Identify sellers who haven’t made any sales in the last 6 months.
Challenge: Show the last sale date and total sales from those sellers.
*/

with inactive_sellers as (
	select *
	from
		sellers
	where 
		seller_id not in
			(select seller_id from orders where order_date >= current_date - interval 6 month)
)

select
	o.seller_id,
	max(o.order_date) as last_sale_date,
	max(oi.total_sales) as last_sale_amount
from
	orders as o
join
	inactive_sellers on inactive_sellers.seller_id = o.seller_id
join
	order_items as oi on o.order_id = oi.order_id
group by 1;


/*
16. IDENTITY customers into returning or new
if the customer has done more than 5 return categorize them as returning otherwise new
Challenge: List customers id, name, total orders, total returns
*/

with customer_category as (
	select
		c.customer_id,
		concat(c.first_name, ' ', c.last_name) as full_name,
		count(o.order_id) as total_orders,
		sum(case when o.order_status = 'Returned' then 1 else 0 end) as total_returns
	from
		customers as c 
	join
		orders as o on c.customer_id = o.customer_id
	group by 1
)

select *,
	case 
		when total_returns > 5 then 'returning' else 'new'
	end as customer_categories
from 
	customer_category;


/*
17. Top 5 Customers by Orders in Each State
Identify the top 5 customers with the highest number of orders for each state.
Challenge: Include the number of orders and total sales for each customer.
*/

select * 
from
	(select
		c.state,
		concat(c.first_name, ' ', c.last_name) as customers,
		count(o.order_id) as total_orders,
		sum(total_sales) as total_sale,
	dense_rank() over(partition by c.state order by COUNT(o.order_id) desc) as ranks
	from
		orders as o
	join
		order_items as oi on oi.order_id = o.order_id
	join 
		customers as c on c.customer_id = o.customer_id
	group by 1, 2
) as t1
where ranks <=5;


/*
18. Top 10 product with highest decreasing revenue ratio compare to last year(2022) and current_year(2023)
Challenge: Return product_id, product_name, category_name, 2022 revenue and 2023 revenue decrease ratio at end Round the result
Note: Decrease ratio = cr-ls/ls* 100 (cs = current_year ls=last_year)
*/

with last_year_sale as
	(
	select 
		p.product_id,
		p.product_name,
		sum(oi.total_sales) as revenue
	from 
		orders as o
	join 
		order_items as oi on oi.order_id = o.order_id
	join 
		products as p on p.product_id = oi.product_id
	where 
		extract(year from o.order_date) = 2022
	group by 1, 2
),

current_year_sale as
	(
	select
		p.product_id,
		p.product_name,
		sum(oi.total_sales) as revenue
	from 
		orders as o
	join
		order_items as oi on oi.order_id = o.order_id
	join 
		products as p on p.product_id = oi.product_id
	where
		extract(year from o.order_date) = 2023
	group by 1, 2
)

select
	cs.product_id,
	ls.revenue as last_year_revenue,
	cs.revenue as current_year_revenue,
	ls.revenue - cs.revenue as rev_diff,
	ROUND((cs.revenue - ls.revenue)/ls.revenue * 100, 2) as reveneue_dec_ratio
from 
	last_year_sale as ls
join
	current_year_sale as cs on ls.product_id = cs.product_id
where 
	ls.revenue > cs.revenue
order by 5 desc
limit 10;
