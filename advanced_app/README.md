## Step 1 Create Objects

```sql
--------------------------------------- STEP 1 -----------------------------------------

USE ROLE ACCOUNTADMIN;
CREATE ROLE tutorial_role;
GRANT ROLE tutorial_role TO USER MENY;

GRANT CREATE INTEGRATION ON ACCOUNT TO ROLE tutorial_role;
GRANT CREATE WAREHOUSE ON ACCOUNT TO ROLE tutorial_role;
GRANT CREATE DATABASE ON ACCOUNT TO ROLE tutorial_role;
GRANT CREATE APPLICATION PACKAGE ON ACCOUNT TO ROLE tutorial_role;
GRANT CREATE APPLICATION ON ACCOUNT TO ROLE tutorial_role;
GRANT CREATE COMPUTE POOL ON ACCOUNT TO ROLE tutorial_role WITH GRANT OPTION;
GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO ROLE tutorial_role WITH GRANT OPTION;


USE ROLE tutorial_role;
CREATE OR REPLACE WAREHOUSE tutorial_warehouse WITH
  WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND = 180
  AUTO_RESUME = true
  INITIALLY_SUSPENDED = false;

USE WAREHOUSE tutorial_warehouse;

CREATE DATABASE na_spcs_tutorial_image_database;
CREATE SCHEMA na_spcs_tutorial_image_schema;
CREATE IMAGE REPOSITORY na_spcs_tutorial_image_repo;

USE DATABASE na_spcs_tutorial_image_database;
USE SCHEMA na_spcs_tutorial_image_schema;

SHOW IMAGE REPOSITORIES IN SCHEMA;
```

## Step 2 SPCS image and spec file
- Update IMAGE_REGISTRY in file service_config.env
- Open terimnal and run:
- make build_docker 
- make tag_docker
- make docker_login
- make push_docker

Or run 
- make build_and_push_docker


## Step 3 Deploy the application
Run command
```
snow app run --role tutorial_role
```

## Step 4.0
Privileges Required to Create and Test an APPLICATION Object¶

```sql
USE ROLE ACCOUNTADMIN;
GRANT CREATE APPLICATION ON ACCOUNT TO ROLE TUTORIAL_ROLE;
GRANT INSTALL ON APPLICATION PACKAGE na_spcs_tutorial_pkg TO ROLE TUTORIAL_ROLE;
```
## Step 4.1 Create and test the app

```sql
------------------------------------- STEP 2 Create and test the app ------------------------------------------------------

SHOW APPLICATION PACKAGES;
SHOW APPLICATIONS;


--Grant the CREATE COMPUTE POOL privilege to the app by running the following:
USE ROLE ACCOUNTADMIN;
grant create WAREHOUSE on account to application NA_SPCS_ADVANCED_APP;
grant create compute pool on account to application NA_SPCS_ADVANCED_APP;
grant bind service endpoint on account to application NA_SPCS_ADVANCED_APP;

USE ROLE TUTORIAL_ROLE;
USE WAREHOUSE TUTORIAL_WAREHOUSE;
CALL NA_SPCS_ADVANCED_APP.config.grant_callback(ARRAY_CONSTRUCT('CREATE COMPUTE POOL','CREATE WAREHOUSE'));
CALL NA_SPCS_ADVANCED_APP.config.version_initializer();


CALL NA_SPCS_ADVANCED_APP.support.get_service_status('app_public.backend');
-- Get service URL
CALL NA_SPCS_ADVANCED_APP.support.app_url();



CALL na_spcs_tutorial_app.app_public.app_url();


-- SPCS MONITORING
USE ROLE ACCOUNTADMIN;
USE warehouse BENCHMARK_WH;
select * from EVENT_DB.DATA.event_table order by TIMESTAMP;
```
