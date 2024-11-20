


## What you will need
### Snowflake CLI
You should have Snowflake CLI installed on your local machine.
https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation/installation

#### Authorisation
Once the Snowflake CLI is installed you will need to provide connection information for your Snowflake account through a config.toml file.  Instructions can be found [here](https://docs.snowflake.com/en/developer-guide/snowflake-cli/connecting/configure-cli) and [here](https://docs.snowflake.com/en/developer-guide/snowflake-cli/connecting/configure-connections)

The Snowflake CLI helps to automate lots of features within Snowflake.  Today we are using it for Native Apps but it can also be used for Streamlit, Notebooks, Git etc.

### Docker
This Quickstart uses Docker to deploy the container images you build locally to your Snowflake account.  Docker can be installed from [here](https://www.docker.com/products/docker-desktop/)


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


USE ROLE tutorial_role;
CREATE OR REPLACE WAREHOUSE tutorial_warehouse WITH
  WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND = 180
  AUTO_RESUME = true
  INITIALLY_SUSPENDED = false;

USE WAREHOUSE tutorial_warehouse;


-- Start from here

USE ROLE tutorial_role;
CREATE DATABASE na_spcs_tutorial_image_database;
CREATE SCHEMA na_spcs_tutorial_image_schema;
CREATE IMAGE REPOSITORY na_spcs_tutorial_image_repo;
USE DATABASE na_spcs_tutorial_image_database;
USE SCHEMA na_spcs_tutorial_image_schema;


SHOW IMAGES IN IMAGE REPOSITORY na_spcs_tutorial_image_repo;
SHOW IMAGE REPOSITORIES IN SCHEMA na_spcs_tutorial_image_schema;
```

## Step 2 SPCS image and spec file
- Update IMAGE_REGISTRY in file service_config.env
- Open terimnal 
- Run cd simple_app
- Run make all


## Step 3 Create and Deploy the application pck
Run command
```
make snow_create
```

## Step 4.0 Create Application 

```sql
SHOW APPLICATION PACKAGES;
USE ROLE tutorial_role;
DROP APPLICATION IF EXISTS na_spcs_tutorial_app CASCADE;
CREATE APPLICATION na_spcs_tutorial_app FROM APPLICATION PACKAGE na_spcs_tutorial_pkg USING VERSION v1;
SHOW APPLICATIONS;
```
## Step 4.1 Create and test the app

From snowsight open Main left panel -> Data Products -> APPS and click on na_spcs_tutorial_app.
Grant application privileges.
Activate the APP 

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

```
