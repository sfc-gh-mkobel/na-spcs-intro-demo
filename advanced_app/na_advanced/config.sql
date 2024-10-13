
--******************* WARNING *********************
--not production-ready and hasn't undergone thorough testing. This code is intended solely for learning and demonstration purposes.
--******************* WARNING *********************


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
        SYSTEM$LOG_INFO('NA_SPCS_TEST: reference_callback: ref_name=' || ref_name || ' operation=' || operation);
        CASE (operation)
            WHEN 'ADD' THEN
                SELECT system$set_reference(:ref_name, :ref_or_alias);
                retstr := 'Reference added';
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
        SYSTEM$LOG_INFO('NA_SPCS_TEST: grant_callback: Start grant_callback');
        IF (ARRAY_CONTAINS('CREATE COMPUTE POOL'::VARIANT, :privs)) THEN
            SYSTEM$LOG_INFO('NA_SPCS_TEST: grant_callback: creating all compute pools');
            CALL config.create_compute_pool() INTO :retstr;
            SYSTEM$LOG_INFO('NA_SPCS_TEST: grant_callback: compute pools: ' || :retstr);
        END IF;
        IF (ARRAY_CONTAINS('CREATE WAREHOUSE'::VARIANT, :privs)) THEN
            SYSTEM$LOG_INFO('NA_SPCS_TEST: grant_callback: creating all warehouses');
            CALL config.create_warehouse_nawh() INTO :retstr;
            SYSTEM$LOG_INFO('NA_SPCS_TEST: grant_callback: warehouses: ' || :retstr);
        END IF;
         -- Whenever grants are added, see if we can start services that aren't started already
        SYSTEM$LOG_INFO('NA_SPCS_TEST: grant_callback: creating all services');
        CALL config.create_all_services() INTO :retstr;
        SYSTEM$LOG_INFO('NA_SPCS_TEST: grant_callback: services: ' || :retstr);
        SYSTEM$LOG_INFO('NA_SPCS_TEST: grant_callback: finished successfully');
        RETURN 'DONE';
    EXCEPTION WHEN OTHER THEN
        SYSTEM$LOG_FATAL('NA_SPCS_TEST: grant_callback: EXCEPTION: ' || SQLERRM);
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
        SYSTEM$LOG_INFO('NA_SPCS_TEST: create_warehouse_nawh: creating warehouse ' || name);
        CALL config.permissions_and_references(ARRAY_CONSTRUCT('CREATE WAREHOUSE'),
                                            ARRAY_CONSTRUCT()) INTO :b;
        IF (NOT b) THEN 
            SYSTEM$LOG_INFO('NA_SPCS_TEST: create_warehouse_nawh: Insufficient privileges');
            RETURN false;
        END IF;

        CREATE WAREHOUSE IF NOT EXISTS Identifier(:name) WITH WAREHOUSE_SIZE='XSMALL';
        SYSTEM$LOG_INFO('NA_SPCS_TEST: create_warehouse_nawh: warehouse ' || name || ' created');
        RETURN true;
    EXCEPTION WHEN OTHER THEN
        SYSTEM$LOG_INFO('NA_SPCS_TEST: create_warehouse_nawh: EXCEPTION: ' || SQLERRM);
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
        SYSTEM$LOG_INFO('NA_SPCS_TEST: create_compute_pool: starting');
        SYSTEM$LOG_INFO('NA_SPCS_TEST: create_compute_pool: creating compute pool ' || name);
        CALL config.permissions_and_references(ARRAY_CONSTRUCT('CREATE COMPUTE POOL'),
                                            ARRAY_CONSTRUCT()) INTO :b;
        IF (NOT b) THEN
            SYSTEM$LOG_INFO('NA_SPCS_TEST: create_compute_pool: Insufficient permissions');
            RETURN false;
        END IF;
        CREATE COMPUTE POOL IF NOT EXISTS Identifier(:name)
            MIN_NODES = 1 
            MAX_NODES = 1
            INSTANCE_FAMILY = CPU_X64_XS
            AUTO_RESUME = TRUE;
        SYSTEM$LOG_INFO('NA_SPCS_TEST: create_compute_pool: compute pool ' || name || ' created');
        RETURN true;
    EXCEPTION WHEN OTHER THEN
        SYSTEM$LOG_INFO('NA_SPCS_TEST: create_compute_pool: EXCEPTION: ' || SQLERRM);
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
        SYSTEM$LOG_INFO('NA_SPCS_TEST: create_all_services: creating all services');
        CALL config.create_service_backend() INTO :b;
        IF (NOT b) THEN
            SYSTEM$LOG_INFO('NA_SPCS_TEST: create_all_services: creating all services failed going to return false');
            RETURN false;
        END IF;
        SYSTEM$LOG_INFO('NA_SPCS_TEST: create_all_services: create all services ended successfully going to return true');
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
        SYSTEM$LOG_INFO('NA_SPCS_TEST: create_service_backend: starting');
 
        -- Make sure COMPUTE POOL exists
        CALL config.create_compute_pool() INTO :b;
        IF (NOT b) THEN
            SYSTEM$LOG_INFO('NA_SPCS_TEST: create_service_backend: create compute pool failed going to return false');
            RETURN false;
        END IF;

    
        SYSTEM$LOG_INFO('NA_SPCS_TEST: create_service_backend: checking if we have all permissions and references');
        CALL config.permissions_and_references(ARRAY_CONSTRUCT('BIND SERVICE ENDPOINT'),
                                            ARRAY_CONSTRUCT()) INTO :b;
        IF (NOT b) THEN
            SYSTEM$LOG_INFO('NA_SPCS_TEST: create_service_backend: Insufficient permissions going to return false');
            RETURN false;
        END IF;

        SYSTEM$LOG_INFO('NA_SPCS_TEST: create_service_backend: starting service');

        LET q STRING := 'CREATE SERVICE IF NOT EXISTS app_public.backend
            IN COMPUTE POOL Identifier(''' || poolname || ''')
            FROM SPECIFICATION_FILE=''service_advanced/echo_spec.yaml''
            QUERY_WAREHOUSE=''' || whname || '''';
        SYSTEM$LOG_INFO('NA_SPCS_TEST: create_service_backend: Going to run command: ' || q);
        EXECUTE IMMEDIATE q;


        SYSTEM$LOG_INFO('NA_SPCS_TEST: create_service_backend: waiting on service start');
        SELECT SYSTEM$WAIT_FOR_SERVICES(300, 'APP_PUBLIC.BACKEND');
        SYSTEM$LOG_INFO('NA_SPCS_TEST: create_service_backend: finished successfully going to return true');
        RETURN true;
    EXCEPTION WHEN OTHER THEN
        SYSTEM$LOG_FATAL('NA_SPCS_TEST: create_service_backend: EXCEPTION: ' || SQLERRM);
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
        SYSTEM$LOG_INFO('NA_SPCS_TEST: service_suspended: Service suspended? ' || b);
        RETURN b;
    EXCEPTION WHEN OTHER THEN
        SYSTEM$LOG_FATAL('NA_SPCS_TEST: service_suspended: EXCEPTION: ' || SQLERRM);
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
            SYSTEM$LOG_INFO('NA_SPCS_TEST: service_exists: Service found');
            RETURN true;
        END IF;
        SYSTEM$LOG_INFO('NA_SPCS_TEST: service_exists: Did not find service');
        RETURN false;
    EXCEPTION WHEN OTHER THEN
        SYSTEM$LOG_FATAL('NA_SPCS_TEST: service_exists: EXCEPTION: ' || SQLERRM);
        RETURN false;
    END
    $$;

    CREATE OR REPLACE PROCEDURE config.resume_service_backend()
    RETURNS boolean
    LANGUAGE sql
    AS $$
    BEGIN
        SYSTEM$LOG_INFO('NA_SPCS_TEST: resume_service_backend: resuming service FRONTEND');

        ALTER SERVICE IF EXISTS app_public.backend RESUME;
        RETURN true;
    EXCEPTION WHEN OTHER THEN
        SYSTEM$LOG_FATAL('NA_SPCS_TEST: resume_service_backend: EXCEPTION: ' || SQLERRM);
        RETURN false;
    END
    $$;
    GRANT USAGE ON PROCEDURE config.resume_service_backend() TO APPLICATION ROLE app_admin;

    CREATE OR REPLACE PROCEDURE config.suspend_service_backend()
    RETURNS boolean
    LANGUAGE sql
    AS $$
    BEGIN
        SYSTEM$LOG_INFO('NA_SPCS_TEST: suspend_service_backend: suspending service FRONTEND');

        ALTER SERVICE IF EXISTS app_public.backend SUSPEND;
        RETURN true;
    EXCEPTION WHEN OTHER THEN
        SYSTEM$LOG_FATAL('NA_SPCS_TEST: suspend_service_backend: EXCEPTION: ' || SQLERRM);
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
        SYSTEM$LOG_INFO('NA_SPCS_TEST: upgrade_service_backend: upgrading service BACKEND');

        -- See if service exists
        CALL config.service_exists('APP_PUBLIC.BACKEND') INTO :b;
        IF (b) THEN
            SYSTEM$LOG_INFO('NA_SPCS_TEST: upgrade_service_backend: Service exists');
            -- See if service is suspended. If so, suspend service at the end
            CALL config.service_suspended('APP_PUBLIC.BACKEND') INTO :suspended;

            -- Alter the service
            -- ALTER SERVICE app_public.backend FROM SPECIFICATION_FILE='/backend.yaml';
            EXECUTE IMMEDIATE 'ALTER SERVICE app_public.backend FROM SPECIFICATION_FILE=''service_advanced/echo_spec.yaml''';

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

            SYSTEM$LOG_INFO('NA_SPCS_TEST: upgrade_service_backend: waiting on service start');
            SELECT SYSTEM$WAIT_FOR_SERVICES(300, 'APP_PUBLIC.BACKEND');

            IF (suspended) THEN
                SYSTEM$LOG_INFO('NA_SPCS_TEST: upgrade_service_backend: re-suspending service');
                CALL config.suspend_service_backend() INTO :b2;
                IF (NOT b2) THEN
                    RAISE UPGRADE_ST_SERVICES_EXCEPTION;
                END IF;
            END IF;
        ELSE
            SYSTEM$LOG_INFO('NA_SPCS_TEST: upgrade_service_backend: Service doesnt exist going to continue');
        END IF;
        RETURN true;
    EXCEPTION WHEN OTHER THEN
        SYSTEM$LOG_FATAL('NA_SPCS_TEST: upgrade_service_backend: EXCEPTION: ' || SQLERRM);
        RAISE;
    END
    $$;
    GRANT USAGE ON PROCEDURE config.upgrade_service_backend() TO APPLICATION ROLE app_admin;


    CREATE OR REPLACE PROCEDURE config.version_initializer()
        RETURNS boolean
        LANGUAGE SQL
        AS $$
        DECLARE
            ret_upgrade BOOLEAN;
        BEGIN
            SYSTEM$LOG_INFO('NA_SPCS_TEST: version_initializer: Start initializing');
            SYSTEM$LOG_INFO('NA_SPCS_TEST: version_initializer: going to upgrade all services');
            CALL config.upgrade_service_backend() INTO :ret_upgrade;
            IF (NOT ret_upgrade) THEN
                SYSTEM$LOG_INFO('NA_SPCS_TEST: version_initializer: upgrade failed going to return false');
                RETURN false;
            END IF;
            SYSTEM$LOG_INFO('NA_SPCS_TEST: version_initializer: upgrade ended successfully going to return true');
            RETURN true;
            EXCEPTION WHEN OTHER THEN
                SYSTEM$LOG_FATAL('NA_SPCS_TEST: version_initializer: EXCEPTION: ' || SQLERRM);
                RAISE;
        END;
        $$;
    GRANT USAGE ON PROCEDURE config.version_initializer() TO APPLICATION ROLE app_admin;

