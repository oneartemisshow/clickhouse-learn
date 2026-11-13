CREATE OR REPLACE TABLE posts (
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

INSERT INTO posts
SELECT 
    id,
    post_type_id,
    accepted_answer_id ,
    parent_id,
    creation_date,
    deletion_date,
    score,
    view_count,
    owner_user_id,
    owner_display_name,
    last_editor_user_id ,
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
	
FROM s3('https://learn-clickhouse.s3.us-east-2.amazonaws.com/stack-exchange/posts.parquet', 'Parquet');

SELECT
    count() AS post_count,
    avg(score) AS avg_score
FROM posts
WHERE creation_date >= '2024-01-01'
AND creation_date < '2024-01-02';

SELECT
    toDate(creation_date) AS date,
    count() AS total_questions,
    avg(score) AS avg_score,
    sum(view_count) AS total_views
FROM posts
WHERE post_type_id = 1
GROUP BY date
ORDER BY date DESC
LIMIT 10;

-- создаём target_table
CREATE TABLE daily_question_stats (
    date Date,
    total_questions UInt64,
    avg_score Float64,
    total_views UInt64,
    questions_with_accepted_answer UInt64,
    avg_answer_count Float64
) ENGINE = SummingMergeTree()  -- будет суммировать числовые колонки
ORDER BY date;

-- создаём MV
CREATE MATERIALIZED VIEW daily_question_stats_mv
TO daily_question_stats  -- target
AS
SELECT
    toDate(creation_date) AS date,
    count() AS total_questions,
    avg(score) AS avg_score,
    sum(view_count) AS total_views,
    countIf(accepted_answer_id > 0) AS questions_with_accepted_answer,
    avg(answer_count) AS avg_answer_count
FROM posts  -- source
WHERE post_type_id = 1
GROUP BY date;

select * from daily_question_stats_mv;  -- данных нет до insert

-- делаем вставку
INSERT INTO daily_question_stats
SELECT
    toDate(creation_date) AS date,
    count() AS total_questions,
    avg(score) AS avg_score,
    sum(view_count) AS total_views,
    countIf(accepted_answer_id > 0) AS questions_with_accepted_answer,
    avg(answer_count) AS avg_answer_count
FROM
    posts
WHERE post_type_id = 1
GROUP BY date;

select * from daily_question_stats_mv;  -- данные есть
select count() from daily_question_stats_mv dqsm;

-- вставляем фейк данные
INSERT INTO posts
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

select count() from daily_question_stats_mv dqsm;  -- было 92, стало 93

/*Теперь REFRESHABLE MV*/
-- выбираем leaderboard
SELECT
    owner_user_id,
    count() AS total_posts,
    sum(score) AS total_score,
    avg(score) AS avg_score
FROM posts
WHERE post_type_id = 1
GROUP BY owner_user_id
ORDER BY total_score DESC;

-- важно обновлять его каждые 5 минут. Создадим target table
CREATE TABLE leaderboard
(
    owner_user_id UInt64,
    total_posts UInt64,
    total_score Int64,
    avg_score Float64,
    last_post_date DateTime
) ENGINE = MergeTree()
ORDER BY (total_score, owner_user_id);

-- создаём MV
CREATE MATERIALIZED VIEW leaderboard_mv
REFRESH EVERY 5 MINUTE  -- refresh rate
TO leaderboard
AS
SELECT
    owner_user_id,
    count() AS total_posts,
    sum(score) AS total_score,
    avg(score) AS avg_score,
    max(creation_date) AS last_post_date
FROM posts
WHERE post_type_id = 1
GROUP BY owner_user_id
ORDER BY total_score DESC;

SELECT * FROM leaderboard_mv;  -- уже есть данные
SELECT * FROM leaderboard;  -- уже есть данные

SELECT
    database,
    view,
    status,
    last_success_time,
    next_refresh_time,
    read_rows,
    written_rows
FROM system.view_refreshes
WHERE view = 'leaderboard_mv';

SYSTEM REFRESH VIEW leaderboard_mv;  -- вручную обновляем

-- тестируем UPDATE
ALTER TABLE posts
UPDATE score = score + 500
WHERE post_type_id = 1
AND owner_user_id = 11699800;

SYSTEM REFRESH VIEW leaderboard_mv;  -- вручную обновляем

SELECT * from leaderboard
ORDER BY total_score desc
limit 1;  -- видим добавленный ряд