#!/bin/bash
#
#  Although Alfresco availability is monitored directly, there may be reasons that the database
#  itself cannot connect - for example incorrect wallet location or contents, or blocking access
#  control list.   This ME checks that the database can at least connect to Alfresco although it
#  does not make any attempt to retrieve valid data.

. ~/.bash_profile

sqlplus -s / as sysdba <<EOF
WHENEVER SQLERROR EXIT FAILURE;
SET FEEDBACK OFF
SET HEADING OFF
SET SERVEROUT ON
SET NEWPAGE 0
SET PAGESIZE 0
SET LINES 2000

ALTER SESSION SET CURRENT_SCHEMA=delius_app_schema;

SET SERVEROUT ON

DECLARE
    l_url             spg_control.value_string%TYPE;
    l_wallet_location spg_control.value_string%TYPE;
    l_http_request    utl_http.req;
    l_http_response   utl_http.resp;
    l_text            VARCHAR2(32767);
BEGIN
    SELECT
        value_string
    INTO l_wallet_location
    FROM
        spg_control
    WHERE
        control_code = 'ALFWALLET';

    utl_http.set_wallet(l_wallet_location, NULL);
    SELECT
        value_string
    INTO l_url
    FROM
        spg_control
    WHERE
        control_code = 'ALFURL';

                  -- Make a HTTP request and get the response.
    l_http_request := utl_http.begin_request(l_url);
    l_http_response := utl_http.get_response(l_http_request);
    utl_http.end_response(l_http_response);

                  -- If we get here then connectivity is available
                  -- (We are only checking connectivity - not fetching a valid web
                  --  page so a response code of 404 is valid).
    dbms_output.put_line('SUCCESS|HTTP Response Code: ' || l_http_response.status_code);
EXCEPTION
    WHEN OTHERS THEN
        utl_http.end_response(l_http_response);
        dbms_output.put_line(SUBSTR(translate('FAIL|' || dbms_utility.format_error_stack, '|'
                                                                                   || chr(10)
                                                                                   || chr(13), '|  '),1,1000));

END;
/
EOF