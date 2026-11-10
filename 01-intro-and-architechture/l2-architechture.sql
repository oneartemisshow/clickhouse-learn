-- создаём таблицы
CREATE TABLE posts (
    post_id        UInt32,
    post_type_id   UInt8,
    creation_date  DateTime,
    score          Int32,
    view_count     UInt32,
    owner_user_id  UInt64,
    title          String,
    tags           String
)
ENGINE = MergeTree
ORDER BY (post_id, creation_date);

CREATE TABLE badges (
    id UInt128,
    user_id Int128,
    name String,
    date DateTime,
    class Enum('Gold' = 1, 'Silver' = 2, 'Bronze' = 3),
    tag_based Bool
)
ENGINE = MergeTree
PRIMARY KEY (name, user_id, date);

-- получаем метаданные о parts
select * from system.parts;  -- все
select * from system.parts where active = 1;  -- активные
select * from system.parts where table = 'uk_prices';  -- по таблице

-- работаем с индексом
SELECT avg(price) FROM uk_prices
WHERE postcode1 = 'AL1'
AND postcode2 = '1AJ';

INSERT INTO badges
SELECT * FROM s3('https://learn-clickhouse.s3.us-east-2.amazonaws.com/stack-exchange/badges.parquet', 'Parquet');  -- 9.6 секунд

-- проверяем кол-во parts
SELECT *
FROM system.parts
WHERE table = 'badges' AND database = 'default'
AND active = 1;  -- 4 parts

-- потребление дискового пространства относительно некомпрессированных данных
SELECT
   formatReadableSize(sum(data_compressed_bytes)) AS compressed_size,
   formatReadableSize(sum(data_uncompressed_bytes)) AS uncompressed_size
FROM system.parts
WHERE table = 'badges' AND active = 1 AND database = 'default';

SELECT *
FROM badges
WHERE id = 7959927;

SELECT *
FROM badges
WHERE toYYYYMM(date) = '202202'
AND name = 'Announcer';

-- тестируем на плохом PK
CREATE TABLE badges_bad_primary_key (
    id UInt128,
    user_id Int128,
    name String,
    date DateTime,
    class Enum('Gold' = 1, 'Silver' = 2, 'Bronze' = 3),
    tag_based Bool
)
ENGINE = MergeTree
PRIMARY KEY (id);

INSERT INTO badges_bad_primary_key
SELECT * FROM s3('https://learn-clickhouse.s3.us-east-2.amazonaws.com/stack-exchange/badges.parquet', 'Parquet');

SELECT *
FROM badges_bad_primary_key
WHERE toYYYYMM(date) = '202202'
AND name = 'Announcer';

-- сравним компрессию
SELECT
    formatReadableSize(sum(data_compressed_bytes)) AS compressed_size,
    formatReadableSize(sum(data_uncompressed_bytes)) AS uncompressed_size
FROM system.parts
WHERE table = 'badges_bad_primary_key' AND active = 1;  -- разница ~5 мб, но на больших данных может сильнее решать