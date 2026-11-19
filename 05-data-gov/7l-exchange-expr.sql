show create table gold.dim_user_activity_marketing;

--CREATE TABLE gold.dim_user_activity_marketing
--(
--    `user_id` Int64,
--    `display_name` String,
--    `reputation` UInt32,
--    `user_created_at` DateTime,
--    `last_access_at` DateTime,
--    `days_since_last_access` Int32,
--    `location` String,
--    `website_url` String,
--    `profile_views` UInt32,
--    `up_votes_given` UInt32,
--    `down_votes_given` UInt32,
--    `total_questions_asked` UInt64,
--    `total_answers_posted` UInt64,
--    `total_posts` UInt64,
--    `avg_question_score` Float64,
--    `avg_answer_score` Float64,
--    `total_accepted_answers` UInt64,
--    `total_post_views` UInt64,
--    `total_votes_received` UInt64,
--    `upvotes_received` UInt64,
--    `downvotes_received` UInt64,
--    `total_badges` UInt64,
--    `gold_badges` UInt64,
--    `silver_badges` UInt64,
--    `bronze_badges` UInt64,
--    `is_active_user` UInt8,
--    `is_power_user` UInt8,
--    `last_refreshed` DateTime DEFAULT now()
--)
--ENGINE = MergeTree
--ORDER BY (user_created_at, is_active_user, is_power_user, user_id)
--SETTINGS index_granularity = 8192

-- создаём новую таблицу и меняем ключи сортировки
CREATE TABLE gold.dim_user_activity_marketing_new
(
    `user_id` Int64,
    `display_name` String,
    `reputation` UInt32,
    `user_created_at` DateTime,
    `last_access_at` DateTime,
    `days_since_last_access` Int32,
    `location` String,
    `website_url` String,
    `profile_views` UInt32,
    `up_votes_given` UInt32,
    `down_votes_given` UInt32,
    `total_questions_asked` UInt64,
    `total_answers_posted` UInt64,
    `total_posts` UInt64,
    `avg_question_score` Float64,
    `avg_answer_score` Float64,
    `total_accepted_answers` UInt64,
    `total_post_views` UInt64,
    `total_votes_received` UInt64,
    `upvotes_received` UInt64,
    `downvotes_received` UInt64,
    `total_badges` UInt64,
    `gold_badges` UInt64,
    `silver_badges` UInt64,
    `bronze_badges` UInt64,
    `is_active_user` UInt8,
    `is_power_user` UInt8,
    `last_refreshed` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree()
ORDER BY (user_id, reputation);

-- делаем backfill
insert into gold.dim_user_activity_marketing_new
select * from gold.dim_user_activity_marketing;

-- проверка
select count() from gold.dim_user_activity_marketing;
select count() from gold.dim_user_activity_marketing_new;

EXCHANGE tables gold.dim_user_activity_marketing and gold.dim_user_activity_marketing_new;

show create table gold.dim_user_activity_marketing;  -- order by user_id and reputation