#!/bin/bash

. ~/.bash_profile

sqlplus -s / as sysdba <<EOF
SET HEADING OFF
SET FEEDBACK OFF
SET PAGESIZE 0
SET VERIFY OFF

SET SERVEROUT ON

DECLARE
    l_enabled dba_advisor_parameters.parameter_value%TYPE;
BEGIN
    SELECT parameter_value
    INTO l_enabled
    FROM dba_advisor_parameters
    WHERE task_name = 'SYS_AUTO_SPM_EVOLVE_TASK'
    AND   parameter_name = 'ACCEPT_PLANS';

    IF l_enabled = 'TRUE' THEN
        DBMS_SPM.SET_EVOLVE_TASK_PARAMETER(
            task_name => 'SYS_AUTO_SPM_EVOLVE_TASK',
            parameter => 'ACCEPT_PLANS',
            value     => 'FALSE'
        );
        DBMS_OUTPUT.PUT_LINE('SYS_AUTO_SPM_EVOLVE_TASK has been disabled.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('SYS_AUTO_SPM_EVOLVE_TASK is already disabled.');
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('SYS_AUTO_SPM_EVOLVE_TASK not found.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/
EXIT
EOF
