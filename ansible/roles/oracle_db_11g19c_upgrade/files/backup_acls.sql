-- =============================================
-- ACL Backup Script (11g → 19c compatible)
-- =============================================

-- SQL*Plus settings
SET SERVEROUTPUT ON SIZE UNLIMITED
SET PAGESIZE 0
SET LINESIZE 200
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING OFF
SET TRIMSPOOL ON



SPOOL acl_backup_restore.sql

DECLARE
    v_host      VARCHAR2(4000);
    v_low_port  NUMBER;
    v_up_port   NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('-- =============================================');
    DBMS_OUTPUT.PUT_LINE('-- 11g Network ACL Backup Script');
    DBMS_OUTPUT.PUT_LINE('-- Generated on: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('-- Run this in target database (e.g. 19c)');
    DBMS_OUTPUT.PUT_LINE('-- =============================================');
    DBMS_OUTPUT.NEW_LINE;

    FOR r IN (
        SELECT DISTINCT acl 
        FROM dba_network_acls 
        ORDER BY acl
    ) LOOP

        DBMS_OUTPUT.PUT_LINE('BEGIN');

        -- Create ACL
        DBMS_OUTPUT.PUT_LINE(
            '  DBMS_NETWORK_ACL_ADMIN.CREATE_ACL(''' ||
            r.acl || ''', ''Migrated ACL from 11g'', '''', FALSE);'
        );

        -- Add privileges
        FOR p IN (
            SELECT principal, privilege, is_grant
            FROM dba_network_acl_privileges
            WHERE acl = r.acl
            ORDER BY principal, privilege
        ) LOOP
            DBMS_OUTPUT.PUT_LINE(
                '  DBMS_NETWORK_ACL_ADMIN.ADD_PRIVILEGE(''' ||
                r.acl || ''', ''' ||
                p.principal || ''', ' ||
                CASE 
                    WHEN p.is_grant = 'TRUE' THEN 'TRUE' 
                    ELSE 'FALSE' 
                END ||
                ', ''' || p.privilege || ''');'
            );
        END LOOP;

        -- Assign ACL to hosts and ports
        FOR h IN (
            SELECT host, lower_port, upper_port
            FROM dba_network_acls
            WHERE acl = r.acl
        ) LOOP
            v_host     := h.host;
            v_low_port := h.lower_port;
            v_up_port  := h.upper_port;

            DBMS_OUTPUT.PUT_LINE(
                '  DBMS_NETWORK_ACL_ADMIN.ASSIGN_ACL(''' ||
                r.acl || ''', ''' ||
                v_host || ''', ' ||
                CASE 
                    WHEN v_low_port IS NOT NULL THEN TO_CHAR(v_low_port) 
                    ELSE 'NULL' 
                END || ', ' ||
                CASE 
                    WHEN v_up_port IS NOT NULL THEN TO_CHAR(v_up_port) 
                    ELSE 'NULL' 
                END || ');'
            );
        END LOOP;

        DBMS_OUTPUT.PUT_LINE('END;');
        DBMS_OUTPUT.PUT_LINE('/');
        DBMS_OUTPUT.NEW_LINE;

    END LOOP;
END;
/

SPOOL OFF

