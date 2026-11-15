CREATE OR REPLACE TABLE users_cmt(
    id Int32,
    reputation Int32,
    creation_date DateTime,
    display_name String,
    last_access_date DateTime,
    website_url String,
    location String,
    about_me String,
    views Int64,
    up_votes Int32,
    down_votes Int32,
    account_id String,
    sign Int8
)
ENGINE = CollapsingMergeTree(sign)
PRIMARY KEY id;

INSERT INTO users_cmt
SELECT
    id,
    reputation,
    creation_date,
    display_name,
    last_access_date,
    website_url,
    location,
    about_me,
    views,
    up_votes,
    down_votes,
    account_id,
    1 AS sign
FROM users;

select * from users_cmt uc limit 5;

INSERT INTO users_cmt VALUES
(2848360, 3, '2013-10-04 23:01:19', 'MRBaird', '2024-04-06 21:10:08', 'http://circleprefect.com', 'US Western States', '', 27, 0, 0, 3394275, -1),
(2848360, 3, '2013-10-04 23:01:19', 'MRBaird', '2024-04-06 21:10:08', 'http://circleprefect.com', 'US Western States', '', 27, 1, 0, 3394275, 1);

select * from users_cmt where id = 2848360;  -- три строки: старое состояние, отмененное старое и новое

-- проверим итоговое кол-во строк
select count() from users_cmt uc;  -- до агрегации
select sum(sign) as result_count from users_cmt uc;  -- после

select * from users_cmt FINAL where id = 2848360;  -- только новое состояние

-- сумма по колонке
SELECT
    id,
    sum(up_votes * sign) up_votes_agg
FROM users_cmt
WHERE id = 2848360
GROUP BY id;