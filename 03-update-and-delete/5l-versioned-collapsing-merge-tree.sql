CREATE OR REPLACE TABLE users_vcmt(
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
    sign Int8,
    version UInt64
)
ENGINE = VersionedCollapsingMergeTree(sign, version)
PRIMARY KEY id
ORDER BY id;

-- Initial insert
-- sign=1 and version=1
INSERT INTO users_vcmt VALUES
(2848360, 3, '2013-10-04 23:01:19', 'MRBaird', '2024-04-06 21:10:08', 'http://circleprefect.com', 'US Western States', '', 27, 0, 0, '3394275', 1, 1);

INSERT INTO users_vcmt VALUES
(2848360, 3, '2013-10-04 23:01:19', 'MRBaird', '2024-04-06 21:10:08', 'http://circleprefect.com', 'US Western States', '', 27, 0, 0, '3394275', -1, 1),
(2848360, 3, '2013-10-04 23:01:19', 'MRBaird', '2024-04-06 21:10:08', 'http://circleprefect.com', 'US Western States', '', 27, 5, 0, '3394275', 1, 2);

-- Another update. User Gets More Reputation. Reputation increases from 3 to 50
INSERT INTO users_vcmt VALUES
-- Cancel version 2
(2848360, 3, '2013-10-04 23:01:19', 'MRBaird', '2024-04-06 21:10:08', 'http://circleprefect.com', 'US Western States', '', 27, 5, 0, '3394275', -1, 2),
-- Insert version 3
(2848360, 50, '2013-10-04 23:01:19', 'MRBaird', '2024-04-06 21:10:08', 'http://circleprefect.com', 'US Western States', '', 27, 5, 0, '3394275', 1, 3);

INSERT INTO users_vcmt VALUES
(2848360, 50, '2013-10-04 23:01:19', 'MRBaird', '2024-04-06 21:10:08', 'http://circleprefect.com', 'US Western States', '', 27, 5, 0, '3394275', -1, 3);

-- все версии и все состояния
SELECT
    id,
    reputation,
    up_votes,
    sign,
    version
FROM users_vcmt
WHERE id = 2848360
ORDER BY version;

-- пустая таблица
SELECT
    id,
    reputation,
    up_votes,
    sign,
    version
FROM users_vcmt FINAL
WHERE id = 2848360
ORDER BY version;