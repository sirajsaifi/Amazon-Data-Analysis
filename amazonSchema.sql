create database amazonDb;

use amazonDb;

create table category (
	category_id int,
    category_name varchar(20),
    primary key(category_id)
);

create table customers (
	Customer_id int,
    first_name varchar(15),
    last_name varchar(15),
    state varchar(20),
    address varchar(5) default ("xxxx"),
    primary key (Customer_id)
);

create table sellers (
	seller_id INT,
	seller_name	VARCHAR(25),
	origin VARCHAR(10),
    primary key (seller_id)
);

create table products (
	product_id int,	
	product_name varchar(50),	
	price float,
	cogs float,
	category_id int,
    primary key (product_id),
	foreign key(category_id) references category(category_id)
);

create table orders (
	order_id int, 	
	order_date date,
	customer_id int,
	seller_id int,
	order_status varchar(15),
    primary key (order_id),
	foreign key (customer_id) references customers(customer_id),
	foreign key (seller_id) references sellers(seller_id)
);

create table order_items (
	order_item_id int,
	order_id int,
	product_id int,
	quantity int,
	price_per_unit float,
    primary key (order_item_id),
	foreign key (order_id) references orders(order_id),
	foreign key (product_id) references products(product_id)
);

create table payments (
	payment_id int,
	order_id int,
	payment_date date,
	payment_status varchar(20),
    primary key (payment_id),
	foreign key (order_id) references orders(order_id)
);

create table shippings (
	shipping_id	int,
	order_id int,
	shipping_date date,
	return_date date,
	shipping_providers	varchar(15),
	delivery_status varchar(15),
    primary key (shipping_id),
	foreign key (order_id) references orders(order_id)
);

create table inventory (
	inventory_id int,
	product_id int,
	stock int,
	warehouse_id int,
	last_stock_date date,
    primary key (inventory_id),
	foreign key (product_id) references products(product_id)
);


load data infile 'orders.csv'
into table orders
fields terminated by ','
enclosed by '"'
lines terminated by '\r\n'
ignore 1 rows;

load data infile 'order_items.csv'
into table order_items
fields terminated by ','
enclosed by '"'
lines terminated by '\r\n'
ignore 1 rows;

load data infile 'payments.csv'
into table payments
fields terminated by ','
enclosed by '"'
lines terminated by '\r\n'
ignore 1 rows;

load data infile 'shipping.csv'
into table shippings
fields terminated by ','
enclosed by '"'
lines terminated by '\r\n'
ignore 1 rows
(shipping_id, order_id,	shipping_date, @return_date, shipping_providers, delivery_status)
set return_date = nullif(@return_date, '');

select * from shippings limit 10;

