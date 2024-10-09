-- Break Glass Support Functions
CREATE SCHEMA IF NOT EXISTS app_internal;
CREATE SCHEMA IF NOT EXISTS support;
GRANT USAGE ON SCHEMA support TO APPLICATION ROLE app_admin;

-- CREATE OR REPLACE SECURE VIEW app_internal.feature_flags AS
--     SELECT * FROM shared_data.feature_flags_vw;
-- CREATE OR REPLACE FUNCTION app_internal.debug_flag(flag VARCHAR)
--     RETURNS BOOLEAN
-- AS $$
--     SELECT array_contains(flag::VARIANT, flags:debug::ARRAY) FROM app_internal.feature_flags
-- $$;

CREATE OR REPLACE PROCEDURE support.get_service_status(service VARCHAR)
    RETURNS VARCHAR
    LANGUAGE SQL
AS $$
DECLARE
    res VARCHAR;
BEGIN
    SELECT SYSTEM$GET_SERVICE_status(:service) INTO res;
        RETURN res;
END;
$$;
GRANT USAGE ON PROCEDURE support.get_service_status(VARCHAR) TO APPLICATION ROLE app_admin;

CREATE OR REPLACE PROCEDURE support.get_service_logs(service VARCHAR, instance INT, container VARCHAR, num_lines INT)
    RETURNS VARCHAR
    LANGUAGE SQL
AS $$
DECLARE
    res VARCHAR;
BEGIN
    SELECT SYSTEM$GET_SERVICE_LOGS(:service, :instance, :container, :num_lines) INTO res;
    RETURN res;
END;
$$;
GRANT USAGE ON PROCEDURE support.get_service_logs(VARCHAR, INT, VARCHAR, INT) TO APPLICATION ROLE app_admin;

CREATE OR REPLACE PROCEDURE support.app_url()
    RETURNS string
    LANGUAGE sql
    AS
$$
DECLARE
    ingress_url VARCHAR;
BEGIN
    SHOW ENDPOINTS IN SERVICE app_public.backend;
    SELECT "ingress_url" INTO :ingress_url FROM TABLE (RESULT_SCAN (LAST_QUERY_ID())) LIMIT 1;
    RETURN ingress_url;
END
$$;
GRANT USAGE ON PROCEDURE support.app_url() TO APPLICATION ROLE app_user;


CREATE OR REPLACE PROCEDURE support.get_service_logs(service VARCHAR, instance INT, container VARCHAR, num_lines INT)
    RETURNS VARCHAR
    LANGUAGE SQL
AS $$
DECLARE
    res VARCHAR;
BEGIN
    SELECT SYSTEM$GET_SERVICE_LOGS(:service, :instance, :container, :num_lines) INTO res;
    RETURN res;
END;
$$;
GRANT USAGE ON PROCEDURE support.get_service_logs(VARCHAR, INT, VARCHAR, INT) TO APPLICATION ROLE app_admin;
