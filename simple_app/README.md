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
GRANT INSTALL ON APPLICATION PACKAGE na_spcs_tutorial_pkg
  TO ROLE TUTORIAL_ROLE;
```
## Step 4.1 Create and test the app

```sql
------------------------------------- STEP 2 Create and test the app ------------------------------------------------------

SHOW APPLICATION PACKAGES;
SHOW APPLICATIONS;


--Grant the CREATE COMPUTE POOL privilege to the app by running the following:
grant create compute pool on account to application na_spcs_tutorial_app;
grant bind service endpoint on account to application na_spcs_tutorial_app;

--Run the app_public.start_app procedure we defined in the setup_script.sql file.
CALL na_spcs_tutorial_app.app_public.start_app();



--To verify that the service has been created and healthy, run the following command:
--This command calls the app_public.service_status procedure you defined in the setup script:
--When this procedure returns READY, you proceed to the next step.
CALL na_spcs_tutorial_app.app_public.service_status();

-- Get service URL
CALL na_spcs_tutorial_app.app_public.app_url();

--Confirm the function was created by running the following:
SHOW FUNCTIONS LIKE '%my_echo_udf%' IN APPLICATION na_spcs_tutorial_app;


--To call the service function to send a request to the service and verify the response, run the following command:
SELECT na_spcs_tutorial_app.core.my_echo_udf('hello');


-- SPCS MONITORING

SHOW services;
SHOW COMPUTE POOLS; -- this one is working!
show endpoints in service core.echo_service;
SELECT SYSTEM$GET_SERVICE_STATUS('core.echo_service');
```
