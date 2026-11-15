CREATE OR REPLACE TABLE votes_rmt (
    id UInt32,
    post_id UInt32,
    vote_type LowCardinality(String),
    user_id Int32,
    creation_date DateTime,
    bounty_amount UInt16
)
ENGINE = ReplacingMergeTree
PRIMARY KEY (id);

INSERT INTO votes_rmt
SELECT
    id,
    post_id,
    vote_type_id as vote_type,
    user_id,
    creation_date,
    bounty_amount
FROM icebergS3('https://learn-clickhouse.s3.us-east-2.amazonaws.com/iceberg-tables/votes/', NOSIGN);

select count(*) from votes_rmt;

-- встваляем данные
INSERT INTO votes_rmt (id, post_id, vote_type, user_id, creation_date, bounty_amount) VALUES
(275489850, 77953001, 2, 458923, '2024-02-07 10:15:30', NULL),
(275489851, 77945123, 8, 392847, '2024-02-07 11:22:45', 50),
(275489852, 77952899, 9, 521034, '2024-02-07 12:05:15', 100),
(275489853, 77950445, 2, 673921, '2024-02-07 13:40:20', NULL),
(275489854, 77948776, 8, 245678, '2024-02-07 14:30:00', 250);

-- выполняем три селекта: без FINAL, с FINAL, с argMax
select * from votes_rmt WHERE id = 275489851;
SELECT
    id,
    argMax(post_id, creation_date) AS post_id,
    argMax(vote_type, creation_date) AS vote_type,
    argMax(user_id, creation_date) AS user_id,
    max(creation_date) AS latest_creation_date,
    argMax(bounty_amount, creation_date) AS bounty_amount
FROM votes_rmt
WHERE id = 275489851
GROUP BY id;  -- через argMax

select * from votes_rmt FINAL WHERE id = 275489851;  -- форсим merge через FINAL

select * from system.parts
where table = 'votes_rmt' and active = 1;

-- пробуем с составным sorting key
CREATE OR REPLACE TABLE votes_rmt (
    id UInt32,
    post_id UInt32,
    vote_type LowCardinality(String),
    user_id Int32,
    creation_date DateTime,
    bounty_amount UInt16
)
ENGINE = ReplacingMergeTree
PRIMARY KEY (vote_type, creation_date, id);

INSERT INTO votes_rmt
SELECT
    id,
    post_id,
    vote_type_id as vote_type,
    user_id,
    creation_date,
    bounty_amount
FROM icebergS3('https://learn-clickhouse.s3.us-east-2.amazonaws.com/iceberg-tables/votes/', NOSIGN);

INSERT INTO votes_rmt (id, post_id, vote_type, user_id, creation_date, bounty_amount) VALUES
(275489850, 77953001, 2, 458923, '2024-02-07 10:15:30', NULL),
(275489851, 77945123, 8, 392847, '2024-02-07 11:22:45', 50),
(275489852, 77952899, 9, 521034, '2024-02-07 12:05:15', 100),
(275489853, 77950445, 2, 673921, '2024-02-07 13:40:20', NULL),
(275489854, 77948776, 8, 245678, '2024-02-07 14:30:00', 250);

-- выполняем три селекта: без FINAL, с FINAL, с argMax
select * from votes_rmt WHERE id = 275489851;  -- так же две записи
SELECT
    id,
    argMax(post_id, creation_date) AS post_id,
    vote_type,
    argMax(user_id, creation_date) AS user_id,
    creation_date,
    argMax(bounty_amount, creation_date) AS bounty_amount
FROM votes_rmt
WHERE id = 275489851
GROUP BY vote_type, creation_date, id
order by vote_type, creation_date, id;  -- через argMax

select * from votes_rmt FINAL WHERE id = 275489851;  -- нет дедупликации