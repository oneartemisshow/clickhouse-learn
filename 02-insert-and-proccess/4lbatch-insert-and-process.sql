-- запрос, чтобы узнатьтипы данных есть в Clickhouse
SELECT * FROM system.data_type_families;

-- создаём таблицу (с инкрементом)
CREATE OR REPLACE TABLE posts_full_batch (
    id Int32,
    post_type_id UInt8,
    accepted_answer_id Nullable(Int32),
    parent_id Nullable(Int32),
    creation_date DateTime,  
    deletion_date DateTime,
    score Int32,
    view_count Nullable(Int32),
    owner_user_id Nullable(Int32),
    owner_display_name String,
    last_editor_user_id Nullable(Int32),
    last_editor_display_name String,
    last_edit_date DateTime, -- колонка для инкремента
    last_activity_date DateTime,
    title String,
    tags String,
    answer_count Nullable(Int32),
    comment_count Int32,
    favorite_count Nullable(Int32),
    content_license String,
    community_owned_date DateTime,
    closed_date DateTime
)
ENGINE = MergeTree
PRIMARY KEY id;

-- Вставляем данные
INSERT INTO posts_full_batch
SELECT * FROM s3('https://learn-clickhouse.s3.us-east-2.amazonaws.com/stack-exchange/posts.parquet', 'Parquet');

-- вставляем фейковые данные дополнительно
INSERT INTO posts_full_batch (
    id,
    post_type_id,
    accepted_answer_id,
    parent_id,
    creation_date,
    deletion_date,
    score,
    view_count,
    owner_user_id,
    owner_display_name,
    last_editor_user_id,
    last_editor_display_name,
    last_edit_date,
    last_activity_date,
    title,
    tags,
    answer_count,
    comment_count,
    favorite_count,
    content_license,
    community_owned_date,
    closed_date
) VALUES (
    99999999,
    1,
    NULL,
    NULL,
    now(),
    '1970-01-01 00:00:00',
    5,
    150,
    12345678,
    'FakeUser123',
    12345678,
    'FakeUser123',
    now(),
    now(),
    'How to optimize ClickHouse queries for better performance?',
    '|clickhouse|performance|optimization|',
    0,
    0,
    NULL,
    'CC BY-SA 4.0',
    '1970-01-01 00:00:00',
    '1970-01-01 00:00:00'
);

select * from posts_full_batch pfb limit 5;

-- проверяем инкремент
SELECT * FROM posts_full_batch WHERE last_edit_date = (SELECT max(last_edit_date) FROM posts_full_batch);

-- способ через агрегатную оконку и подзапрос
select *
from (
	select *, max(last_edit_date) over() as global_max
	from posts_full_batch 
) s1
where last_edit_date = global_max;


-- способ через CTE и ранжирующую функцию
with ranked_data as (
	select *, rank() over(order by last_edit_date desc) as rn
	from posts_full_batch
)

select *
from ranked_data
where rn = 1;

-- ЗАПРОСЫ ТЯЖЕЛЫЕ!!!
SELECT * FROM badges;

SELECT * FROM s3('https://learn-clickhouse.s3.us-east-2.amazonaws.com/stack-exchange/posts.parquet', 'Parquet');

SELECT * FROM s3('https://learn-clickhouse.s3.us-east-2.amazonaws.com/stack-exchange/users.parquet', 'Parquet');

SELECT * FROM icebergS3('https://learn-clickhouse.s3.us-east-2.amazonaws.com/iceberg-tables/votes/', NOSIGN);


SELECT * FROM s3('https://learn-clickhouse.s3.us-east-2.amazonaws.com/stack-exchange/post_types.csv');

SELECT * FROM s3('https://learn-clickhouse.s3.us-east-2.amazonaws.com/stack-exchange/vote_types.csv');

DESCRIBE badges;
DESCRIBE s3('https://learn-clickhouse.s3.us-east-2.amazonaws.com/stack-exchange/posts.parquet', 'Parquet');

DESCRIBE s3('https://learn-clickhouse.s3.us-east-2.amazonaws.com/stack-exchange/users.parquet', 'Parquet');

DESCRIBE icebergS3('https://learn-clickhouse.s3.us-east-2.amazonaws.com/iceberg-tables/votes/', NOSIGN);

DESCRIBE s3('https://learn-clickhouse.s3.us-east-2.amazonaws.com/stack-exchange/post_types.csv');

DESCRIBE s3('https://learn-clickhouse.s3.us-east-2.amazonaws.com/stack-exchange/vote_types.csv');

SELECT
    uniq(name)
FROM badges;  -- 5193: кандидат для LowCardinality

-- изначально id по UInt128, user_id Int128
SELECT max(id) FROM badges;
SELECT max(user_id) FROM badges;  -- оба надо заменить на Int32 (< 2147483647)

-- создаём таблицу с корректными типами данных
CREATE TABLE badges_good_data_type (
    id UInt32,  -- меняем на основе docs
    user_id Int32,  -- меняем на основе docs
    name LowCardinality(String),  -- меняем на основе docs
    date DateTime,
    class Enum('Gold' = 1, 'Silver' = 2, 'Bronze' = 3),
    tag_based Bool
)
ENGINE = MergeTree
PRIMARY KEY (name, user_id, date);

INSERT INTO badges_good_data_type
SELECT * FROM s3('https://learn-clickhouse.s3.us-east-2.amazonaws.com/stack-exchange/badges.parquet', 'Parquet');

-- проверяем сжатие
SELECT
    table,
    formatReadableSize(sum(data_compressed_bytes)) AS compressed_size,
    formatReadableSize(sum(data_uncompressed_bytes)) AS uncompressed_size
FROM system.parts
WHERE table ilike 'badges%' AND active = 1
GROUP BY table
ORDER BY table;  -- разница ~5 мб

-- дропаем таблицы и оставляем одну
DROP TABLE badges;
DROP TABLE badges_good_data_type;

CREATE TABLE badges (
    id UInt32,
    user_id Int32,
    name LowCardinality(String),
    date DateTime,
    class Enum('Gold' = 1, 'Silver' = 2, 'Bronze' = 3),
    tag_based Bool
)
ENGINE = MergeTree
PRIMARY KEY (name, user_id, date);

INSERT INTO badges
SELECT * FROM s3('https://learn-clickhouse.s3.us-east-2.amazonaws.com/stack-exchange/badges.parquet', 'Parquet');

CREATE OR REPLACE TABLE votes (
    id UInt32,
    post_id UInt32,
    vote_type LowCardinality(String),
    user_id Int32,
    creation_date DateTime,
    bounty_amount UInt16
)
ENGINE = MergeTree
PRIMARY KEY (vote_type, post_id, creation_date);

INSERT INTO votes
SELECT 
    id,
    post_id,
    vote_type_id as vote_type,
    user_id,
    creation_date,
    bounty_amount
FROM iceberg('https://learn-clickhouse.s3.us-east-2.amazonaws.com/iceberg-tables/votes/', NOSIGN);

CREATE  OR REPLACE TABLE post_types (
  post_type_id Int16,
  post_type_name String
)
ENGINE = MergeTree
PRIMARY KEY post_type_id;

INSERT INTO post_types
SELECT 
    post_type_id,
    post_type_name
FROM s3('https://learn-clickhouse.s3.us-east-2.amazonaws.com/stack-exchange/post_types.csv', 'CSVWithNames');

CREATE  OR REPLACE TABLE vote_types (
  vote_type_id Int16,
  vote_type_name String
)
ENGINE = MergeTree
PRIMARY KEY vote_type_id;

INSERT INTO vote_types
SELECT 
    vote_type_id,
    vote_type_name
FROM s3('https://learn-clickhouse.s3.us-east-2.amazonaws.com/stack-exchange/vote_types.csv', 'CSVWithNames');

CREATE OR REPLACE TABLE posts_2 (
    id Int32,
    post_type_id UInt8,
    accepted_answer_id Nullable(Int32),
    parent_id Nullable(Int32),
    creation_date DateTime,
    deletion_date DateTime,
    score Int32,
    view_count Nullable(Int32),
    owner_user_id Nullable(Int32),
    owner_display_name String,
    last_editor_user_id Nullable(Int32),
    last_editor_display_name String,
    last_edit_date DateTime,
    last_activity_date DateTime,
    title String,
    tags String,
    answer_count Nullable(Int32),
    comment_count Int32,
    favorite_count Nullable(Int32),
    content_license String,
    community_owned_date DateTime,
    closed_date DateTime
)
ENGINE = MergeTree
PRIMARY KEY (creation_date, id);

-- ещё раз тестируем инкремент
INSERT INTO posts_2
VALUES (
    99999999,
    1,
    NULL,
    NULL,
    now(),
    '1970-01-01 00:00:00',
    5,
    150,
    12345678,
    'FakeUser123',
    12345678,
    'FakeUser123',
    now(),
    now(),
    'How to optimize ClickHouse queries for better performance?',
    '|clickhouse|performance|optimization|',
    0,
    0,
    NULL,
    'CC BY-SA 4.0',
    '1970-01-01 00:00:00',
    '1970-01-01 00:00:00'
);

select *
from 
(
	select *, max(last_edit_date) over() as max_dt
	from posts_2
) s2
where last_edit_date = max_dt;