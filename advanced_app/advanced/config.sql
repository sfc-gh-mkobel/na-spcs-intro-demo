CREATE OR ALTER VERSIONED SCHEMA config;
GRANT USAGE ON SCHEMA config TO APPLICATION ROLE app_admin;

-- CALLBACKS
CREATE OR REPLACE PROCEDURE config.reference_callback(ref_name STRING, operation STRING, ref_or_alias STRING)
 RETURNS STRING
 LANGUAGE SQL
 AS $$
    DECLARE
        retstr STRING;
    BEGIN
        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: reference_callback: ref_name=' || ref_name || ' operation=' || operation);
        CASE (operation)
            WHEN 'ADD' THEN
                SELECT system$set_reference(:ref_name, :ref_or_alias);
                -- When references are added, see if we can start services that aren't started already
                CALL config.create_all_services() INTO :retstr;
            WHEN 'REMOVE' THEN
                SELECT system$remove_reference(:ref_name);
                retstr := 'Reference removed';
            WHEN 'CLEAR' THEN
                SELECT system$remove_reference(:ref_name);
                retstr := 'Reference cleared';
            ELSE
                retstr := 'Unknown operation: ' || operation;
        END;
        RETURN retstr;
    END;
   $$;
    GRANT USAGE ON PROCEDURE config.reference_callback(STRING,  STRING,  STRING) TO APPLICATION ROLE app_admin;


    -- Prefix to use for all global objects created (e.g., COMPUTE POOLS, WAREHOUSES, etc)
    CREATE OR REPLACE FUNCTION config.app_prefix(root STRING)
        RETURNS string
        AS $$
        UPPER(current_database() || '__' || root)
        $$;
    CREATE OR REPLACE PROCEDURE config.permissions_and_references(perms ARRAY, refs ARRAY)
    RETURNS boolean
    LANGUAGE sql
    AS $$
    DECLARE
        i INTEGER;
        len INTEGER;
    BEGIN
        FOR i IN 0 TO ARRAY_SIZE(perms)-1 DO
            LET p VARCHAR := GET(perms, i)::VARCHAR;
            IF (NOT SYSTEM$HOLD_PRIVILEGE_ON_ACCOUNT(:p)) THEN
                RETURN false;
            END IF;
        END FOR;

        FOR i IN 0 TO ARRAY_SIZE(refs)-1 DO
            LET p VARCHAR := GET(refs, i)::VARCHAR;
            SELECT ARRAY_SIZE(PARSE_JSON(SYSTEM$GET_ALL_REFERENCES(:p))) INTO :len;
            IF (len < 1) THEN
                RETURN false;
            END IF;
        END FOR;

        RETURN true;
    END
    $$;


    CREATE OR REPLACE PROCEDURE config.grant_callback(privs ARRAY)
    RETURNS string
    LANGUAGE SQL
    AS $$
    DECLARE
        retstr STRING;
    BEGIN
        IF (ARRAY_CONTAINS('CREATE COMPUTE POOL'::VARIANT, :privs)) THEN
            SYSTEM$LOG_INFO('NA_SPCS_PYTHON: grant_callback: creating all compute pools');
            CALL config.create_compute_pool() INTO :retstr;
            SYSTEM$LOG_INFO('NA_SPCS_PYTHON: grant_callback: compute pools: ' || :retstr);
        END IF;
        IF (ARRAY_CONTAINS('CREATE WAREHOUSE'::VARIANT, :privs)) THEN
            SYSTEM$LOG_INFO('NA_SPCS_PYTHON: grant_callback: creating all warehouses');
            CALL config.create_warehouse_nawh() INTO :retstr;
            SYSTEM$LOG_INFO('NA_SPCS_PYTHON: grant_callback: warehouses: ' || :retstr);
        END IF;
        -- Whenever grants are added, see if we can start services that aren't started already
        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: grant_callback: creating all services');
        CALL config.create_all_services() INTO :retstr;
        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: grant_callback: services: ' || :retstr);
        RETURN retstr;
    EXCEPTION WHEN OTHER THEN
        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: grant_callback: EXCEPTION: ' || SQLERRM);
    END;
    $$;
    GRANT USAGE ON PROCEDURE config.grant_callback(ARRAY) TO APPLICATION ROLE app_admin;

    CREATE OR REPLACE PROCEDURE config.create_warehouse_nawh()
    RETURNS boolean
    LANGUAGE sql
    AS $$
    DECLARE
        name STRING DEFAULT config.app_prefix('nawh');
        b BOOLEAN;
    BEGIN
        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: create_warehouse_nawh: creating warehouse ' || name);
        CALL config.permissions_and_references(ARRAY_CONSTRUCT('CREATE WAREHOUSE'),
                                            ARRAY_CONSTRUCT()) INTO :b;
        IF (NOT b) THEN 
            SYSTEM$LOG_INFO('NA_SPCS_PYTHON: create_warehouse_nawh: Insufficient privileges');
            RETURN false;
        END IF;

        CREATE WAREHOUSE IF NOT EXISTS Identifier(:name) WITH WAREHOUSE_SIZE='XSMALL';
        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: create_warehouse_nawh: warehouse ' || name || ' created');
        RETURN true;
    EXCEPTION WHEN OTHER THEN
        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: create_warehouse_nawh: ERROR: ' || SQLERRM);
        RETURN false;
    END
    $$;
    GRANT USAGE ON PROCEDURE config.create_warehouse_nawh() TO APPLICATION ROLE app_admin;




CREATE OR REPLACE PROCEDURE config.create_compute_pool()
    RETURNS boolean
    LANGUAGE sql
    AS $$
    DECLARE
        name STRING DEFAULT config.app_prefix('pool');
        b BOOLEAN;
    BEGIN
        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: create_compute_pool: creating compute pool ' || name);
        CALL config.permissions_and_references(ARRAY_CONSTRUCT('CREATE COMPUTE POOL'),
                                            ARRAY_CONSTRUCT()) INTO :b;
        IF (NOT b) THEN
            SYSTEM$LOG_INFO('NA_SPCS_PYTHON: create_compute_pool: Insufficient permissions');
            RETURN false;
        END IF;
        CREATE COMPUTE POOL IF NOT EXISTS Identifier(:name)
            MIN_NODES = 1 MAX_NODES = 1
            INSTANCE_FAMILY = CPU_X64_XS
            AUTO_RESUME = TRUE;
        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: create_compute_pool: compute pool ' || name || ' created');
        RETURN true;
    EXCEPTION WHEN OTHER THEN
        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: create_compute_pool: ERROR: ' || SQLERRM);
        RETURN false;
    END
    $$;
    GRANT USAGE ON PROCEDURE config.create_compute_pool() TO APPLICATION ROLE app_admin;


    CREATE OR REPLACE PROCEDURE config.create_all_services()
    RETURNS boolean
    LANGUAGE sql
    AS $$
    DECLARE
        b BOOLEAN;
    BEGIN
        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: create_all_services: creating all services');

        CALL config.create_service_backend() INTO :b;
        IF (NOT b) THEN
            RETURN false;
        END IF;

        -- CALL config.create_service_frontend() INTO :b;
        -- IF (NOT b) THEN
        --     RETURN false;
        -- END IF;

        RETURN true;
    END
    $$;
    GRANT USAGE ON PROCEDURE config.create_all_services() TO APPLICATION ROLE app_admin;



    CREATE OR REPLACE PROCEDURE config.create_service_backend()
    RETURNS boolean
    LANGUAGE sql
    AS $$
    DECLARE
        whname STRING DEFAULT config.app_prefix('nawh');
        poolname STRING DEFAULT config.app_prefix('pool');
        b BOOLEAN;
    BEGIN
        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: create_service_backend: starting');
 
        -- Make sure COMPUTE POOL exists
        CALL config.create_compute_pool() INTO :b;
        IF (NOT b) THEN
            RETURN false;
        END IF;

        -- Check that BIND SERVICE ENDPOINT has been granted
        -- Check that EGRESS_EAI_WIKIPEDIA reference has been set
        -- Check that ORDERS_TABLE reference has been set
        --     FOR NOW, don't check the ORDERS_TABLE, it can't be set at setup, 
        --       but this is the default_web_endpoint and MUST be created based
        --       solely on the permissions and references that can be granted at setup.
        -- CALL config.permissions_and_references(ARRAY_CONSTRUCT('BIND SERVICE ENDPOINT'),
        --                                     ARRAY_CONSTRUCT('ORDERS_TABLE', 'EGRESS_EAI_WIKIPEDIA')) INTO :b;
        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: create_service_backend: checking if we have all permissions and references');
        CALL config.permissions_and_references(ARRAY_CONSTRUCT('BIND SERVICE ENDPOINT'),
                                            ARRAY_CONSTRUCT()) INTO :b;
        IF (NOT b) THEN
            SYSTEM$LOG_INFO('NA_SPCS_PYTHON: create_service_backend: Insufficient permissions');
            RETURN false;
        END IF;

        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: create_service_backend: starting service');

        -- FOR NOW, we need to do this as EXECUTE IMMEDIATE
        --    QUERY_WAREHOUSE doesn't take Identifier()
        -- CREATE SERVICE IF NOT EXISTS app_public.backend
        --     IN COMPUTE POOL Identifier(:poolname)
        --     FROM SPECIFICATION_FILE='/backend.yaml'
        --     QUERY_WAREHOUSE=Identifier(:whname)
        -- ;
        LET q STRING := 'CREATE SERVICE IF NOT EXISTS app_public.backend
            IN COMPUTE POOL Identifier(''' || poolname || ''')
            FROM SPECIFICATION_FILE=''service/echo_spec.yaml''
            QUERY_WAREHOUSE=''' || whname || '''';
        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: create_service_backend: Command: ' || q);
        EXECUTE IMMEDIATE q;


        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: create_service_backend: waiting on service start');
        SELECT SYSTEM$WAIT_FOR_SERVICES(300, 'APP_PUBLIC.BACKEND');

        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: create_service_backend: finished!');
        RETURN true;
    EXCEPTION WHEN OTHER THEN
        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: create_service_backend: ERROR: ' || SQLERRM);
        RETURN false;
    END
    $$;
    GRANT USAGE ON PROCEDURE config.create_service_backend() TO APPLICATION ROLE app_admin;

    CREATE OR REPLACE PROCEDURE config.service_suspended(name STRING)
    RETURNS boolean
    LANGUAGE sql
    AS $$
    DECLARE
        b BOOLEAN;
    BEGIN
        SELECT BOOLOR_AGG(value:status = 'SUSPENDED') INTO :b 
            FROM TABLE(FLATTEN(
                PARSE_JSON(SYSTEM$GET_SERVICE_STATUS(UPPER(:name)))
            ))
        ;
        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: service_suspended: Service suspended? ' || b);
        RETURN b;
    EXCEPTION WHEN OTHER THEN
        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: service_suspended: ERROR: ' || SQLERRM);
        RETURN false;
    END
    $$;

    CREATE OR REPLACE PROCEDURE config.service_exists(name STRING)
    RETURNS boolean
    LANGUAGE sql
    AS $$
    DECLARE
        ct INTEGER;
    BEGIN
        SELECT ARRAY_SIZE(PARSE_JSON(SYSTEM$GET_SERVICE_STATUS(:name))) INTO ct;
        IF (ct > 0) THEN
            SYSTEM$LOG_INFO('NA_SPCS_PYTHON: service_exists: Service found');
            RETURN true;
        END IF;
        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: service_exists: Did not find service');
        RETURN false;
    EXCEPTION WHEN OTHER THEN
        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: service_exists: ERROR: ' || SQLERRM);
        RETURN false;
    END
    $$;

    CREATE OR REPLACE PROCEDURE config.resume_service_backend()
    RETURNS boolean
    LANGUAGE sql
    AS $$
    BEGIN
        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: resume_service_backend: resuming service FRONTEND');

        ALTER SERVICE IF EXISTS app_public.backend RESUME;
        RETURN true;
    EXCEPTION WHEN OTHER THEN
        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: resume_service_backend: ERROR: ' || SQLERRM);
        RETURN false;
    END
    $$;
    GRANT USAGE ON PROCEDURE config.resume_service_backend() TO APPLICATION ROLE app_admin;

    CREATE OR REPLACE PROCEDURE config.suspend_service_backend()
    RETURNS boolean
    LANGUAGE sql
    AS $$
    BEGIN
        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: suspend_service_backend: suspending service FRONTEND');

        ALTER SERVICE IF EXISTS app_public.backend SUSPEND;
        RETURN true;
    EXCEPTION WHEN OTHER THEN
        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: suspend_service_backend: ERROR: ' || SQLERRM);
        RETURN false;
    END
    $$;
    GRANT USAGE ON PROCEDURE config.suspend_service_backend() TO APPLICATION ROLE app_admin;



    CREATE OR REPLACE PROCEDURE config.upgrade_service_backend()
    RETURNS boolean
    LANGUAGE sql
    AS $$
    DECLARE
        whname STRING DEFAULT config.app_prefix('nawh');
        poolname STRING DEFAULT config.app_prefix('pool');
        b BOOLEAN;
        b2 BOOLEAN;
        suspended BOOLEAN;
        UPGRADE_ST_SERVICES_EXCEPTION EXCEPTION (-20003, 'Error upgrading BACKEND');
    BEGIN
        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: upgrade_service_backend: upgrading service BACKEND');

        -- See if service exists
        CALL config.service_exists('APP_PUBLIC.BACKEND') INTO :b;
        IF (b) THEN
            -- See if service is suspended. If so, suspend service at the end
            CALL config.service_suspended('APP_PUBLIC.BACKEND') INTO :suspended;

            -- Alter the service
            -- ALTER SERVICE app_public.backend FROM SPECIFICATION_FILE='/backend.yaml';
            EXECUTE IMMEDIATE 'ALTER SERVICE app_public.backend FROM SPECIFICATION_FILE=''service/echo_spec.yaml''';

            -- ALTER SERVICE app_public.backend SET
            --     QUERY_WAREHOUSE=Identifier(:whname)
            -- ;
            EXECUTE IMMEDIATE 'ALTER SERVICE app_public.backend SET
                QUERY_WAREHOUSE=''' || whname || '''';

            -- Resume the service (to pick up any initialization logic that might be 
            --   in the new container image)
            CALL config.resume_service_backend() INTO :b2;
            IF (NOT b2) THEN
                RAISE UPGRADE_ST_SERVICES_EXCEPTION;
            END IF;

            SYSTEM$LOG_INFO('NA_SPCS_PYTHON: upgrade_service_backend: waiting on service start');
            SELECT SYSTEM$WAIT_FOR_SERVICES(300, 'APP_PUBLIC.BACKEND');

            IF (suspended) THEN
                SYSTEM$LOG_INFO('NA_SPCS_PYTHON: upgrade_service_backend: re-suspending service');
                CALL config.suspend_service_backend() INTO :b2;
                IF (NOT b2) THEN
                    RAISE UPGRADE_ST_SERVICES_EXCEPTION;
                END IF;
            END IF;
        END IF;
    EXCEPTION WHEN OTHER THEN
        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: upgrade_service_backend: ERROR: ' || SQLERRM);
        RAISE;
    END
    $$;
    GRANT USAGE ON PROCEDURE config.upgrade_service_backend() TO APPLICATION ROLE app_admin;


    CREATE OR REPLACE PROCEDURE config.version_initializer()
    RETURNS boolean
    LANGUAGE SQL
    AS $$
    DECLARE
        b BOOLEAN;
    BEGIN
        SYSTEM$LOG_INFO('NA_SPCS_PYTHON: version_initializer: initializing');
        
        CALL config.upgrade_service_backend() INTO :b;
        IF (NOT b) THEN
            RETURN false;
        END IF;

        RETURN true;
    EXCEPTION WHEN OTHER THEN
        RAISE;
    END;
    $$;


