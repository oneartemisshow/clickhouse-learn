/*тестируем скорость Clickhouse*/

-- создаём таблицу
CREATE OR REPLACE TABLE uk_prices
(
    id UUID,
    price UInt32,
    date DateTime,
    postcode1 LowCardinality(String),
    postcode2 LowCardinality(String),
    type Enum8('terraced' = 1, 'semi-detached' = 2, 'detached' = 3, 'flat' = 4, 'other' = 0),
    is_new UInt8,
    duration Enum8('freehold' = 1, 'leasehold' = 2, 'unknown' = 0),
    addr1 String,
    addr2 String,
    street String,
    locality LowCardinality(String),
    town LowCardinality(String),
    district LowCardinality(String),
    county LowCardinality(String)
)
ENGINE = MergeTree  -- движок
PRIMARY KEY (postcode1, postcode2, addr1, addr2);  -- ключи сортировки

-- вставляем данные
INSERT INTO uk_prices
WITH
    splitByChar(' ', assumeNotNull(postcode)) AS postcodes
SELECT
    replaceRegexpAll(id, '[{}]', '') AS id,
    toUInt32(price) AS price,
    date,
    postcodes[1] AS postcode1,
    postcodes[2] AS postcode2,
    transform(type, ['T', 'S', 'D', 'F', 'O'], ['terraced', 'semi-detached', 'detached', 'flat', 'other'], 'other') AS type,
    is_new = 'Y' AS is_new,
    transform(duration, ['F', 'L', 'U'], ['freehold', 'leasehold', 'unknown'], 'unknown') AS duration,
    addr1,
    addr2,
    street,
    locality,
    town,
    district,
    county
FROM s3('https://learn-clickhouse.s3.us-east-2.amazonaws.com/uk_property_prices/uk_prices.csv.zst', 'CSVWithNames');  -- ~2 минуты вставка на личном ПК, 30 секунд в Clickhouse cloud

/*тестируем скорость:
    - напрямую
    - через таблицу
*/
SELECT COUNT() FROM s3('https://learn-clickhouse.s3.us-east-2.amazonaws.com/uk_property_prices/uk_prices.csv.zst');  -- 1 минута 47 сек
select COUNT() from uk_prices;  -- 0.01 секунда

-- тестируем фильтрацию с/без PRIMARY
-- 0.011 секунд
SELECT AVG(toUInt32(price))
FROM uk_prices
WHERE postcode1 = 'B1';  -- входит в primary (быстрее)

-- 0.02 секунды
SELECT AVG(toUInt32(price))
FROM uk_prices
WHERE town = 'LONDON';  -- не входит в primary (медленнее)

DESCRIBE TABLE s3('https://learn-clickhouse.s3.us-east-2.amazonaws.com/stack-exchange/badges.parquet', 'Parquet');

SELECT * FROM s3('https://learn-clickhouse.s3.us-east-2.amazonaws.com/stack-exchange/badges.parquet', 'Parquet') LIMIT 100;
