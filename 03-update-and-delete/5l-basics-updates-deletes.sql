select id, title, score
from posts
where id = 77740681;

-- разрешаем lightweight updates
ALTER TABLE posts MODIFY SETTING enable_block_number_column = 1, enable_block_offset_column = 1;
ALTER TABLE users_temp MODIFY SETTING enable_block_number_column = 1, enable_block_offset_column = 1;

update posts
set score = 42
where id = 77740681;

select count(*) from posts;

-- lightweight delete
delete from posts
where id = 77740681;

-- lab 5.1
CREATE OR REPLACE TABLE users_temp(
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
    account_id String
)
ENGINE = MergeTree
PRIMARY KEY id;

INSERT INTO users_temp
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
    account_id
FROM users;

-- применяем мутацию
ALTER TABLE users_temp DELETE WHERE reputation < 100000;

-- удалились ли данные сразу же? Нет: is_done = 0. Но если вызвать через несколько минут, то is_done = 1
SELECT 
  command,
  is_done,
  parts_to_do,
  latest_fail_reason
FROM system.mutations
WHERE table = 'users_temp';

-- пробуем lightweight update на случайной записи
SELECT id, display_name, reputation 
FROM users_temp 
WHERE id = 67;

update users_temp
set display_name = 'Rex Matthews'
where id = 67;