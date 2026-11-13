-- lab 4: 2-3
SELECT
    count() AS post_count,
    avg(score) AS avg_score
FROM posts
WHERE creation_date >= '2024-01-01'
AND creation_date < '2024-01-02';

select
	toYYYYMM(creation_date) as month,
    count() AS post_count,
    avg(score) AS avg_score
FROM posts
group by month
order by month;

-- создаём target table
create or replace table posts_by_month
(
	id Int32,
	post_type_id UInt8,
	creation_date DateTime,
	score Int32,
	view_count Nullable(Int32),
	owner_user_id Nullable(Int32),
	title String,
	tags String,
	answer_count Nullable(Int32),
	comment_count Int32
)
engine = MergeTree
partition by (toYYYYMM(creation_date))
primary key (post_type_id, creation_date);

-- создаём MV
create materialized view posts_by_month_view
to posts_by_month  -- target
as
select
	id,
    post_type_id,
    creation_date,
    score,
    view_count,
    owner_user_id,
    title,
    tags,
    answer_count,
    comment_count
from posts;  -- source

-- backfill данных из posts
INSERT INTO posts_by_month
SELECT 
   id,
   post_type_id,
   creation_date,
   score,
   view_count,
   owner_user_id,
   title,
   tags,
   answer_count,
   comment_count
FROM posts;

SELECT count() FROM posts_by_month;
SELECT count() FROM posts;

SELECT 
   count() AS num_posts,
   avg(score) AS avg_score
FROM posts_by_month
WHERE toYYYYMM(creation_date) = 202401;

SELECT 
   count() AS num_questions,
   avg(score) AS avg_score,
   sum(view_count) AS total_views,
   avg(answer_count) AS avg_answers
FROM posts_by_month
WHERE post_type_id = 1
 AND toYYYYMM(creation_date) = 202402;

-- доп вставка
INSERT INTO posts (
   id, post_type_id, creation_date, score, view_count, 
   owner_user_id, title, tags, answer_count, comment_count
) VALUES
(99999991, 1, '2024-04-15 10:00:00', 5, 150, 12345678, 
'How to optimize ClickHouse materialized views?', 
'|clickhouse|materialized-views|performance|', 2, 3),
(99999992, 2, '2024-04-15 11:30:00', 10, 0, 87654321, 
'', '', 0, 1),
(99999993, 1, '2024-04-20 09:45:00', 0, 25, 11223344, 
'Understanding incremental materialized views', 
'|clickhouse|database|', 0, 0);

SELECT 
   id,
   post_type_id,
   creation_date,
   title,
   score,
   view_count
FROM posts_by_month
WHERE toYYYYMM(creation_date) = 202404
ORDER BY creation_date;

SELECT * FROM system.parts
WHERE table='posts_by_month';

-- refresh MV
create or replace table posts_daily_stats
(
	post_date Date,
	num_posts UInt32,
	avg_score Float64,
	total_views UInt64,
	num_questions UInt32,
   	num_answers UInt32
)
engine = MergeTree
order by post_date;

create materialized view posts_daily_stats_mv
refresh every 12 hour
to posts_daily_stats
as
select
	toDate(creation_date) as post_date,
	count() as num_posts,
	avg(score) as avg_score,
	sum(view_count) as total_views,
	countIf(post_type_id = 1) as num_questions,  -- вопросы
	countIf(post_type_id = 2) as num_answers  -- ответы
from posts
where toDate(creation_date) >= '2024-01-01'
group by post_date

SELECT 
   post_date,
   num_posts,
   round(avg_score, 2) AS avg_score,
   total_views,
   num_questions,
   num_answers
FROM posts_daily_stats
ORDER BY post_date;

INSERT INTO posts (
   id, post_type_id, creation_date, score, view_count, 
   owner_user_id, title, tags, answer_count, comment_count
) VALUES
(99999994, 1, '2024-01-19 23:00:00', 15, 500, 11111111, 
'How to use refreshable materialized views?', 
'|clickhouse|materialized-views|', 3, 2),
(99999995, 2, '2024-01-19 23:15:00', 8, 0, 22222222, 
'', '', 0, 0),
(99999996, 1, '2024-01-19 23:30:00', 3, 100, 33333333, 
'Understanding refresh intervals in ClickHouse', 
'|clickhouse|performance|', 1, 0);

SYSTEM REFRESH view posts_daily_stats_mv;

SELECT 
   post_date,
   num_posts,
   round(avg_score, 2) AS avg_score,
   total_views,
   num_questions,
   num_answers
FROM posts_daily_stats
WHERE post_date = '2024-01-19';

SELECT 
   database,
   view,
   status,
   last_refresh_time,
   next_refresh_time,
   exception
FROM system.view_refreshes
WHERE view = 'posts_daily_stats_mv';