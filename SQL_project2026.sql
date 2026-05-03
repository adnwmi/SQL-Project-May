create database project;
SET GLOBAL local_infile=1;
DROP TABLE customers;
CREATE TABLE customers (
	Id_client INT,
    Total_amount INT,
    Gender VARCHAR(50),
    Age varchar(50),
    Count_city INT,
    Response_communcation INT,
    Communication_3month INT,
    Tenure INT,
    PRIMARY KEY (Id_client)
);

-- Then import
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/customers.csv'
INTO TABLE customers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SHOW VARIABLES LIKE 'secure_file_priv';

CREATE TABLE transactions (
    date_new DATE,
    Id_check INT,
    ID_client INT,
    Count_products FLOAT,
    Sum_payment FLOAT
);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/transactions.csv' 
INTO TABLE transactions 
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\n' 
IGNORE 1 ROWS;

#task1
select ID_client, sum(Sum_payment)/count(distinct Id_check) as avg_check_amount,
sum(Sum_payment) / 12 as avg_monthly_amount,
count(distinct Id_check) as total_operations
from transactions where date_new >= '2015-06-01' and date_new < '2016-06-01'
group by ID_client
having count(distinct date_format(date_new, '%y-%m')) = 12;

select * from transactions;

#task-2
with YearlyTotals as (
select sum(Sum_payment) as total_year_amount,
count(distinct Id_check) as total_year_ops
from transactions
where date_new >= '2015-06-01' and date_new < '2016-06-01'
)
select DATE_FORMAT(t.date_new, '%Y-%m') AS report_month,
#a
sum(t.Sum_payment) / count(distinct t.Id_check) as avg_check_in_month,
#b
count(distinct t.Id_check) / count(distinct t.Id_client) as avg_ops_per_client,
#c
count(distinct t.Id_client) as active_clients,
#d
(count(distinct t.Id_check) / y.total_year_amount) * 100 as share_of_year_amount_pct,
(sum(t.Sum_payment) / y.total_year_amount) * 100 as share_of_year_amount_pct
from transactions t
cross join YearlyTotals y
where t.date_new >= '2015-06-01' and t.date_new < '2016-06-01'
group by report_month, y.total_year_ops, y.total_year_amount
order by report_month;

#task-2 part e
WITH MonthlyTotals AS (
    SELECT 
        DATE_FORMAT(date_new, '%Y-%m') AS report_month, 
        SUM(Sum_payment) AS total_month_amount,
        COUNT(DISTINCT Id_check) AS total_month_ops
    FROM transactions
    WHERE date_new >= '2015-06-01' AND date_new < '2016-06-01'
    -- FIXED: Using the exact formula instead of the alias here
    GROUP BY DATE_FORMAT(date_new, '%Y-%m') 
)
SELECT 
    DATE_FORMAT(t.date_new, '%Y-%m') AS report_month,
    IFNULL(NULLIF(TRIM(c.Gender), ''), 'NA') AS gender_group,
    
    (COUNT(DISTINCT t.Id_check) / mt.total_month_ops) * 100 AS ops_share_pct,
    (SUM(t.Sum_payment) / mt.total_month_amount) * 100 AS costs_share_pct

FROM transactions t
LEFT JOIN customers c ON t.ID_client = c.Id_client
JOIN MonthlyTotals mt ON DATE_FORMAT(t.date_new, '%Y-%m') = mt.report_month
WHERE t.date_new >= '2015-06-01' AND t.date_new < '2016-06-01'
-- FIXED: Using the exact formula instead of the alias here as well
GROUP BY 
    DATE_FORMAT(t.date_new, '%Y-%m'), 
    gender_group, 
    mt.total_month_ops, 
    mt.total_month_amount
ORDER BY report_month, gender_group;

#task-3
WITH BaseData AS (
    SELECT 
        t.ID_client,
        t.Id_check,
        t.Sum_payment,
        t.date_new,
        QUARTER(t.date_new) AS qtr,
        -- Формируем возрастные группы: если пусто/null - 'NA', иначе '20-29', '30-39' и т.д.
        CASE 
            WHEN c.Age IS NULL OR TRIM(c.Age) = '' THEN 'NA'
            ELSE CONCAT(FLOOR(CAST(c.Age AS SIGNED) / 10) * 10, '-', FLOOR(CAST(c.Age AS SIGNED) / 10) * 10 + 9)
        END AS age_group
    FROM transactions t
    LEFT JOIN customers c ON t.ID_client = c.Id_client
),
OverallStats AS (
    SELECT 
        age_group,
        SUM(Sum_payment) AS total_sum_all_time,
        COUNT(DISTINCT Id_check) AS total_ops_all_time
    FROM BaseData
    GROUP BY age_group
)
SELECT 
    b.age_group,
    o.total_sum_all_time,
    o.total_ops_all_time,
    CONCAT('Q', b.qtr) AS quarter_num,
    
    SUM(b.Sum_payment) / COUNT(DISTINCT b.Id_check) AS avg_check_in_quarter,
	(SUM(b.Sum_payment) / o.total_sum_all_time) * 100 AS sum_pct_of_total,
	(COUNT(DISTINCT b.Id_check) / o.total_ops_all_time) * 100 AS ops_pct_of_total
    
FROM BaseData b
JOIN OverallStats o ON b.age_group = o.age_group
GROUP BY b.age_group, o.total_sum_all_time, o.total_ops_all_time, b.qtr
ORDER BY b.age_group, b.qtr;
