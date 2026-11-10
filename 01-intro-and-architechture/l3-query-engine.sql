-- работаем с движком
-- 1. Find the number of badges awarded per day
SELECT
    toDate(date) as dt,
    COUNT(*) as badges_awarded
FROM
    badges
GROUP BY dt
ORDER BY dt DESC;

-- 2. What are the 5 most popular badges?
-- выполняется 0.462 секунды
SELECT
    name,
    COUNT(*) AS times_awarded,
    uniqExact(user_id) AS unique_users  -- вместо DISTINCT, дата-инженеру его лучше не писать
FROM badges
GROUP BY name
ORDER BY times_awarded DESC
LIMIT 5;

-- через DISTINCT
SELECT
    name,
    COUNT(*) as times_awarded,
    COUNT(distinct user_id) as unique_users
from badges
GROUP BY name
ORDER BY times_awarded DESC
LIMIT 5;


-- 3. Write a federated query joining the users and badges table to find all users who have no badges
CREATE OR REPLACE TABLE users
(
    id UInt32,
    reputation UInt32,
    creation_date Date,
    display_name String,
    last_access_date DateTime,
    website_url String,
    location String,
    about_me String,
    views Int32,
    up_votes Int32,
    down_votes Int32,
    account_id Int32
)
ENGINE = MergeTree
PRIMARY KEY (creation_date)
PARTITION BY (toYear(creation_date));

INSERT INTO users SELECT * FROM s3('https://learn-clickhouse.s3.us-east-2.amazonaws.com/stack-exchange/users.parquet', 'Parquet');

-- через Anti join
SELECT 
    u.id,
    u.display_name,
    u.reputation
FROM users AS u
LEFT ANTI JOIN badges AS b 
    ON u.id = b.user_id
WHERE b.user_id IS NOT NULL;

-- через подзапрос в where
SELECT 
    u.id,
    u.display_name,
    u.reputation
FROM users AS u
WHERE u.id NOT IN (SELECT DISTINCT user_id FROM badges);

-- аналитика по PyPi packages
SELECT
   PROJECT,
   count()
FROM s3('https://datasets-documentation.s3.eu-west-3.amazonaws.com/pypi/2023/pypi_0_0_{0..5}.snappy.parquet')
GROUP BY PROJECT
ORDER BY 2 DESC;  -- выполняется ~6 секунд

-- вставляем данные
INSERT INTO pypi
SELECT
    toDate(TIMESTAMP) AS date,
    COUNTRY_CODE AS country_code,
    PROJECT AS project,
    JSONExtractString(FILE, 'type') AS type,
    JSONExtractString(INSTALLER, 'name') AS installer,
    substring(PYTHON, 1, position(PYTHON, '.', position(PYTHON, '.') + 1) - 1) AS python_minor,
    JSONExtractString(IMPLEMENTATION, 'name') AS system,
    JSONExtractString(FILE, 'version') AS version
FROM s3('https://datasets-documentation.s3.eu-west-3.amazonaws.com/pypi/2023/pypi_0_0_{0..5}.snappy.parquet');

SELECT
   project,
   count()
FROM pypi
GROUP BY project
ORDER BY 2 DESC;  -- выполняется ~0.042