-- RBAC
CREATE USER data_engineer_michelle
IDENTIFIED WITH sha256_password BY 'Password123!'
HOST IP '8.8.8.8';

CREATE USER data_scientist_mark
IDENTIFIED WITH sha256_password BY 'Password123!'
HOST IP '8.8.8.8';

show USERS;

create role data_engineer;

GRANT SELECT ON *.* TO data_engineer;
GRANT INSERT ON *.* TO data_engineer;
GRANT CREATE ON *.* TO data_engineer;
GRANT ALTER ON *.* TO data_engineer;
GRANT DROP ON *.* TO data_engineer;
GRANT TRUNCATE ON *.* TO data_engineer;
GRANT SHOW ON *.* TO data_engineer;
GRANT OPTIMIZE ON *.* TO data_engineer;
GRANT SYSTEM ON *.* TO data_engineer;
GRANT dictGet ON *.* TO data_engineer;

grant data_engineer to data_engineer_michelle;

CREATE ROLE data_scientist;
grant data_scientist to data_scientist_mark;

GRANT SELECT ON silver.* TO data_scientist;
GRANT SELECT ON gold.* TO data_scientist;

show ROLES;

CREATE SETTINGS PROFILE etl_profile
SETTINGS
  max_memory_usage = 20000000000, -- 20GB
  max_execution_time = 3600,      -- 1 hour
  max_threads = 8
TO data_engineer;


CREATE SETTINGS PROFILE analytics_profile
SETTINGS
  max_memory_usage = 10000000000, -- 10GB
  max_execution_time = 300,       -- 5 minutes
  max_threads = 4
TO data_scientist;

CREATE QUOTA engineer_quota
FOR INTERVAL 1 hour MAX queries = 1000,
FOR INTERVAL 1 day MAX query_selects = 5000
TO data_engineer;

CREATE QUOTA scientist_quota
FOR INTERVAL 1 hour MAX queries = 1
FOR INTERVAL 1 day MAX query_selects = 1
TO data_scientist;

-- can't query from bronze tables
SELECT * FROM bronze.stg_posts;

SELECT currentRoles();