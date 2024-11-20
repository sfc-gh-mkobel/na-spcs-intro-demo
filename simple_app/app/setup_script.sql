CREATE APPLICATION ROLE IF NOT EXISTS app_user;

CREATE SCHEMA IF NOT EXISTS core;
GRANT USAGE ON SCHEMA core TO APPLICATION ROLE app_user;

CREATE OR ALTER VERSIONED SCHEMA app_public;
GRANT USAGE ON SCHEMA app_public TO APPLICATION ROLE app_user;

CREATE OR REPLACE PROCEDURE app_public.start_app(privs ARRAY)
   RETURNS string
   LANGUAGE sql
   AS
$$
BEGIN
   -- account-level compute pool object prefixed with app name to prevent clashes
   LET pool_name := (SELECT CURRENT_DATABASE()) || '_compute_pool';

   CREATE COMPUTE POOL IF NOT EXISTS IDENTIFIER(:pool_name)
      MIN_NODES = 1
      MAX_NODES = 1
      INSTANCE_FAMILY = CPU_X64_XS
      AUTO_RESUME = true;

   CREATE SERVICE IF NOT EXISTS core.echo_service
      IN COMPUTE POOL identifier(:pool_name)
      FROM spec='service/echo_spec.yaml';

   CREATE OR REPLACE FUNCTION core.my_echo_udf (TEXT VARCHAR)
      RETURNS varchar
      SERVICE=core.echo_service
      ENDPOINT=echoendpoint
      AS '/echo';

   GRANT USAGE ON FUNCTION core.my_echo_udf (varchar) TO APPLICATION ROLE app_user;

   GRANT service role core.echo_service!ALL_ENDPOINTS_USAGE to application role app_user;

   RETURN 'Service successfully created';
END;
$$;

GRANT USAGE ON PROCEDURE app_public.start_app(ARRAY) TO APPLICATION ROLE app_user;

CREATE OR REPLACE PROCEDURE app_public.service_status()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS $$
   DECLARE
         service_status VARCHAR;
   BEGIN
         CALL SYSTEM$GET_SERVICE_STATUS('core.echo_service') INTO :service_status;
         RETURN PARSE_JSON(:service_status)[0]['status']::VARCHAR;
   END;
$$;
GRANT USAGE ON PROCEDURE app_public.service_status() TO APPLICATION ROLE app_user;

CREATE OR REPLACE PROCEDURE app_public.app_url()
    RETURNS string
    LANGUAGE sql
    AS
$$
DECLARE
    ingress_url VARCHAR;
BEGIN
    SHOW ENDPOINTS IN SERVICE core.echo_service;
    SELECT "ingress_url" INTO :ingress_url FROM TABLE (RESULT_SCAN (LAST_QUERY_ID())) LIMIT 1;
    RETURN ingress_url;
END
$$;
GRANT USAGE ON PROCEDURE app_public.app_url() TO APPLICATION ROLE app_user;

CREATE OR REPLACE PROCEDURE app_public.get_service_logs()
    RETURNS VARCHAR
    LANGUAGE SQL
AS $$
DECLARE
    res VARCHAR;
BEGIN
      SELECT SYSTEM$GET_SERVICE_LOGS('core.echo_service',0,'echo') INTO res;
      RETURN res;
END;
$$;
GRANT USAGE ON PROCEDURE app_public.get_service_logs() TO APPLICATION ROLE app_user;