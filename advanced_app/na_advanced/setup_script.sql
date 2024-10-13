--******************* WARNING *********************
--not production-ready and hasn't undergone thorough testing. This code is intended solely for learning and demonstration purposes.
--******************* WARNING *********************

CREATE APPLICATION ROLE IF NOT EXISTS app_admin;
CREATE SCHEMA IF NOT EXISTS app_public;
GRANT USAGE ON SCHEMA app_public TO APPLICATION ROLE app_admin;


-- Configuration and Callback functions 
EXECUTE IMMEDIATE FROM 'config.sql';
-- Support functions
EXECUTE IMMEDIATE FROM 'support.sql';