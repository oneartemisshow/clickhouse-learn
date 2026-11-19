CREATE OR REPLACE TABLE posts_validated (
  id Int32,
  post_type_id Int8,
  score Int32,
  view_count Nullable(UInt32),
  owner_user_id Int32, -- NOT NULL enforced
  creation_date DateTime,
  title String, -- NOT NULL enforced
  tags String, -- NOT NULL enforced
  answer_count UInt16,
  comment_count UInt16,
  validation_timestamp DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY (post_type_id, creation_date, id);

CREATE MATERIALIZED VIEW posts_validator
TO posts_validated AS
SELECT
  id,
  post_type_id,
  score,
  view_count,
  owner_user_id,
  creation_date,
  title,
  tags,
  answer_count,
  comment_count
FROM posts
WHERE
  -- Enforce NOT NULL constraints
  owner_user_id IS NOT NULL
  AND title != '' -- Title must not be empty
  -- Enforce business rules
  AND ifNull(view_count, 0) >= 0 -- Views can't be negative
  AND creation_date >= '2008-01-01' -- Stack Exchange launch date
  AND creation_date <= now() -- Future dates not allowed
;

-- проверяем валидацию
SELECT
  id,
  owner_user_id,
  view_count,
  creation_date,
  title,
  CASE
    WHEN id IN (SELECT id FROM posts_validated) THEN 'PASSED'
    ELSE 'REJECTED'
  END as validation_status
FROM posts
ORDER BY id;

-- pass
INSERT INTO posts (id, post_type_id, accepted_answer_id, parent_id, creation_date, deletion_date, score, view_count, owner_user_id, owner_display_name, last_editor_display_name, last_editor_user_id,
    last_edit_date,
    last_activity_date,
    title,
    tags,
    answer_count,
    comment_count,
    favorite_count,
    content_license,
    community_owned_date,
    closed_date)
VALUES (
  99999991,
  1,
  77849036,
  NULL,
  '2024-01-19 10:58:34',
  NULL,
  5,
  48,
  20483834,
  '',
  20483834,
  '',
  '2024-01-19 11:15:00',
  '2024-01-19 22:04:58',
  'Javascript is really hard pls help pls',
  '|javascript|reactjs|',
  1,
  6,
  NULL,
  'CC BY-SA 4.0',
  '1970-01-01 00:00:00',
  '1970-01-01 00:00:00'
);

-- won't pass
INSERT INTO posts (id, post_type_id, accepted_answer_id, parent_id, creation_date, deletion_date, score, view_count, owner_user_id, owner_display_name, last_editor_display_name, last_editor_user_id,
    last_edit_date,
    last_activity_date,
    title,
    tags,
    answer_count,
    comment_count,
    favorite_count,
    content_license,
    community_owned_date,
    closed_date)
VALUES (
  99999992,
  1,
  NULL,
  NULL,
  '2026-12-31 23:59:59',
  NULL,
  10,
  100,
  20483834,
  '',
  20483834,
  '',
  '2026-12-31 23:59:59',
  '2026-12-31 23:59:59',
  'This post is from the future - time travel question',
  '|time-travel|future|science-fiction|',
  0,
  0,
  NULL,
  'CC BY-SA 4.0',
  '1970-01-01 00:00:00',
  '1970-01-01 00:00:00'
);

SELECT
  id,
  owner_user_id,
  view_count,
  creation_date,
  title,
  CASE
    WHEN id IN (SELECT id FROM posts_validated) THEN 'PASSED'
    ELSE 'REJECTED'
  END as validation_status
FROM posts
where id in (99999991, 99999992)
ORDER BY id;

CREATE OR REPLACE TABLE bronze.stg_badges_invalid
(
badge_id UInt64,
user_id Int64,
badge_name String,
badge_awarded_at DateTime,
badge_class UInt8,
tag_based Bool,
load_timestamp DateTime,
rejection_reason String
)
ENGINE = MergeTree()
ORDER BY (load_timestamp, badge_id);

CREATE MATERIALIZED VIEW bronze.stg_badges_invalid_mv TO bronze.stg_badges_invalid
AS
SELECT 
id AS badge_id,
user_id,
name AS badge_name,
date AS badge_awarded_at,
class AS badge_class,
tag_based,
now() AS load_timestamp,
multiIf(
  id = 0, 'Invalid badge_id: must be > 0',
  user_id <= 0, 'Invalid user_id: must be > 0',
  name = '', 'Invalid badge_name: cannot be empty',
  date < '2008-01-01 00:00:00', 'Invalid badge_awarded_at: before Stack Exchange existed',
  date > now(), 'Invalid badge_awarded_at: future date',
  class NOT IN (1, 2, 3), 'Invalid badge_class: must be 1, 2, or 3',
  'Unknown validation error'
) AS rejection_reason
FROM badges
WHERE NOT (
badge_id > 0
AND user_id > 0
AND badge_name != ''
AND badge_awarded_at >= '2008-01-01 00:00:00'
AND badge_awarded_at <= now()
AND badge_class IN (1, 2, 3)
);

describe badges;

-- вставляем данные для валидации в badges
insert into badges (id, user_id, name, date, class, tag_based)
values	
(1, 101, 'Enthusiast', '2023-05-15 14:30:00', 3, false),
(2, 102, 'Nice Answer', '2022-08-20 09:15:00', 3, false),
(14, 113, 'Pioneer', '2007-12-31 23:59:00', 1, false),
(20, 119, 'Platinum Badge', '2023-05-05 10:00:00', 2, false);

SELECT COUNT(*) as invalid_count FROM bronze.stg_badges_invalid;
select * from bronze.stg_badges_invalid;