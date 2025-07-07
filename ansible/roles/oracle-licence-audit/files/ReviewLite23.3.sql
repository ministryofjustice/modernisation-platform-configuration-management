SET ECHO OFF
SET PAUSE OFF
SET TERMOUT OFF
REM     ORACLE - Review Lite Script
REM
REM     Usage:
REM
REM        - Use SQL*Plus to connect to the database (locally or remotely) with any user with following privileges
REM               - CREATE SESSION
REM               - SELECT ANY TABLE
REM               - for database version 9.1 and higher: SELECT ANY DICTIONARY
REM               - when DATABASE VAULT is in use:
REM                   - PARTICIPANT or OWNER authorization on 'Oracle Data Dictionary' realm
REM                   - PARTICIPANT or OWNER authorization on 'Oracle Database Vault' realm
REM                   - DV_SECANALYST role - for querying Oracle Database Vault-supplied views
REM          Hint: SYS or SYSTEM are good choices if DATABASE VAULT is not in use
REM          Example:
REM               sqlplus system/password@orcl1prod
REM
REM        - Run the script:
REM               @ReviewLite23.3.sql
REM
REM        - Where to run the script?
REM               - for RAC databases, connect and run the script on each instance
REM               - for Container Databases (CDBs), connect and run the script on CDB$ROOT container and on each open Pluggable Database (PDB)
REM               - run the script on OEM Grid/Cloud Control Repository databases
REM               - run the script on all the database targets managed by OEM Grid/Cloud Control
REM               - run the script on all standby databases, ignoring errors caused by these being open in MOUNTED mode
REM               - do not run the script on Automatic Storage Management (ASM) instances
REM
REM
REM     This script checks for the Oracle database edition and version installed.
REM     It also checks for the options installed and verifies what options and OEM packs are being used:
REM      * OLAP                  * SPATIAL
REM      * PARTITIONING          * RAC (Real Application Clusters)
REM      * LABEL SECURITY        * OEM (Oracle Enterprise Manager) PACKS
REM      * DATA MINING           * AUDIT VAULT
REM      * DATABASE VAULT        * CONTENT DATABASE
REM      * RECORDS DATABASE      * ADVANCED SECURITY
REM      * ACTIVE DATA GUARD     * ADVANCED COMPRESSION
REM      * MULTITENANT           * DATABASE IN-MEMORY

define SCRIPT_RELEASE=23.3

SET DEFINE ON
SET MARKUP HTML OFF
SET COLSEP ' '

-- Settings for customized functionality - the last definition of each parameter will dictate the customization
-- Set SCRIPT_OO to collect all information or options only
define SCRIPT_OO=_OO_IGNORE_THIS_ERR  -- collect only options information
define SCRIPT_OO=''                   -- collect all information [default behavior]
-- Set SCRIPT_TS to generate filenames with or without timestamp
define SCRIPT_TS=_TS_IGNORE_THIS_ERR  -- include timestamp in names of the output directory and output files: YYYY.MM.DD.HH24.MI.SS
define SCRIPT_TS=''                   -- standard names for output directory and output files [default behavior]

-- Set SCRIPT_LA set license agreement prompt behavior
define SCRIPT_LA=_LA_IGNORE_THIS_ERR  -- script does not prompt for license agreement
-- define SCRIPT_LA=''                   -- script prompts for license agreement [default behavior]
-- Set SCRIPT_SI to run in interactive or in silent mode
define SCRIPT_SI=_SI_IGNORE_THIS_ERR  -- script does not prompt for privilege check confirmation
define SCRIPT_SI=''                   -- script prompts for privilege check confirmation [default behavior]
-- Set SCRIPT_SD to create output subdirectory
define SCRIPT_SD=DB                   -- create output subdirectory
define SCRIPT_SD=''                   -- no output subdirectory


-- PROMT FOR LICENSE AGREEMENT ACCEPTANCE
DEFINE LANSWER=N
SET TERMOUT ON
ACCEPT&SCRIPT_LA LANSWER FORMAT A1 PROMPT 'Accept License Agreement? (y\n): '

HOST&SCRIPT_LA rm   license_agreement.txt   2> fii_err.txt
HOST&SCRIPT_LA del  license_agreement.txt   2> fii_err.txt

SET TERMOUT OFF
WHENEVER SQLERROR EXIT
SET TERMOUT ON
prompt Checking agreement acceptance ...
SET TERMOUT OFF
-- FORCE "divisor is equal to zero" AND SQLERROR EXIT IF NOT ACCEPTED
-- WILL ALSO CONTINUE IF SCRIPT_LA SUBSTITUTION VARIABLE IS NOT NULL
select 1/decode('&LANSWER', 'Y', null, 'y', null, decode('&SCRIPT_LA', null, 0, null)) as " " from DUAL;
WHENEVER SQLERROR CONTINUE
SET TERMOUT ON

alter session set NLS_LANGUAGE='AMERICAN';
alter session set NLS_TERRITORY='AMERICA';
alter session set NLS_DATE_FORMAT='YYYY-MM-DD_HH24:MI:SS';
alter session set NLS_TIMESTAMP_FORMAT='YYYY-MM-DD_HH24:MI:SS';
alter session set NLS_TIMESTAMP_TZ_FORMAT='YYYY-MM-DD_HH24:MI:SS_TZH:TZM';

SET TERMOUT OFF
SET TAB OFF
SET TRIMOUT ON
SET TRIMSPOOL ON
SET PAGESIZE 5000
SET LINESIZE 300
SET SERVEROUTPUT ON
col DESCRIPTION format A65 wrap


-- Get host_name and instance_name
prompt Getting HOST_NAME and INSTANCE_NAME ...
define INSTANCE_NAME=UNKNOWN
define HOST_NAME=UNKNOWN
col C1 new_val INSTANCE_NAME
col C2 new_val HOST_NAME
-- Oracle7
SELECT min(machine) C2 FROM v$session WHERE type = 'BACKGROUND';
SELECT name    C1 FROM v$database;
-- Oracle8 and higher
SELECT instance_name C1, nvl(host_name, 'unknown') C2 FROM v$instance;
SELECT instance_name C1, nvl(host_name, sys_context('USERENV', 'SERVER_HOST')) C2 FROM v$instance;
-- Oracle12 and higher
define INSTANCE_NAME_0=&INSTANCE_NAME
select '&&INSTANCE_NAME' || decode(VALUE, 'TRUE', '~' || replace(sys_context('USERENV', 'CON_NAME'), '$', '_'), '') C1
  from V$PARAMETER where name = 'enable_pluggable_database';

define LOGS=''
col C3 new_val LOGS
select replace(sys_context('USERENV', 'CON_NAME'), '$', '_') || '_' as C3 from V$PARAMETER where NAME = 'enable_pluggable_database' and VALUE = 'TRUE';




-- Check Privileges BEGIN
SET FEEDBACK OFF
SET VERIFY OFF

PROMPT Checking for required select privileges.
select PRIVILEGE FROM USER_SYS_PRIVS  where PRIVILEGE in ('SELECT ANY TABLE', 'SELECT ANY DICTIONARY')
union
select PRIVILEGE FROM ROLE_SYS_PRIVS  where PRIVILEGE in ('SELECT ANY TABLE', 'SELECT ANY DICTIONARY');

-- Check if database is open
define SEL_PRIV=N
col SEL_PRIV_ new_val SEL_PRIV noprint
col C noprint
select 'Y' as SEL_PRIV_, count(*) as C from ROLE_SYS_PRIVS;
col SEL_PRIV_ clear
col C clear

-- Get database version
define SEL_VER=UNKNOWN
col SEL_VER_ new_val SEL_VER noprint
select trim(substr(VERSION, 1, instr(VERSION, '.')-1)) as SEL_VER_ from V$INSTANCE;
col SEL_VER_ clear

-- Get O7_DICTIONARY_ACCESSIBILITY parameter
define SEL_O7=UNKNOWN
col SEL_O7_ new_val SEL_O7 noprint
select VALUE as SEL_O7_ from V$PARAMETER where upper(NAME) = 'O7_DICTIONARY_ACCESSIBILITY';
col SEL_O7_ clear

variable MIS_PRIV VARCHAR2(100)
BEGIN
  :MIS_PRIV := 'N';
END;
/

SET TERMOUT ON
--prompt [&SEL_PRIV][&SEL_VER][&SEL_O7]
DECLARE
  SEL_DICT_REQUIRED VARCHAR2(3)    := 'N';
  MISSING_PRIVS     VARCHAR2(200)  := '';
  SEL_AT            VARCHAR2(3)    := 'N';
  SEL_AD            VARCHAR2(3)    := 'N';
  ERR_C             number;
  AUTH_REALMS       VARCHAR2(500)  := 'N';
  MIS_AUTH_TEXT     VARCHAR2(4000) := '';
  MIS_AUTH          VARCHAR2(3)    := 'N';
BEGIN
  if    '&SEL_VER' = 'UNKNOWN' then
    dbms_output.put_line('DB: CT-02014: ERROR: [&&INSTANCE_NAME]: Current database user ' || USER || ' does not have the privilege to query V$INSTANCE. Cannot continue.');
    dbms_output.put_line('Exiting...');
    :MIS_PRIV := 'X';
    return;
  elsif '&SEL_PRIV' = 'N' then
    dbms_output.put_line('DB: CT-02802: WARNING: [&&INSTANCE_NAME]: Cannot check privileges. Continuing anyway. Errors expected.');
    dbms_output.put_line('.');
    :MIS_PRIV := 'N';
    return;
  elsif '&SEL_VER' = '8' and '&SEL_O7' = 'UNKNOWN' then
    dbms_output.put_line('DB: CT-02803: WARNING: [&&INSTANCE_NAME]:  Current database user ' || USER || ' does NOT have the privilege to query V$PARAMETER. Continuing anyway. Errors expected.');
    SEL_DICT_REQUIRED := 'N';
  elsif '&SEL_VER' = '8' and '&SEL_O7' = 'FALSE' then
    dbms_output.put_line('DB: CT-02804: WARNING: [&&INSTANCE_NAME]: O7_DICTIONARY_ACCESSIBILITY=FALSE. Access to the data dictionary views requires explicit object privilege. Errors expected.');
    SEL_DICT_REQUIRED := 'N';
  elsif '&SEL_VER' in ('7', '8') then
    SEL_DICT_REQUIRED := 'N';
  elsif to_number('&SEL_VER') >= '9' and '&SEL_O7' = 'TRUE' then
    -- SELECT ANY TABLE is enough
    SEL_DICT_REQUIRED := 'N';
  elsif to_number('&SEL_VER') >= '9' and '&SEL_O7' = 'FALSE' then
    -- SELECT ANY DICTIONARY privilege (introduced in 9.0.1) is required
    SEL_DICT_REQUIRED := 'Y';
  else
    SEL_DICT_REQUIRED := 'Y';
  end if;

  for C in
    (
      select PRIVILEGE FROM USER_SYS_PRIVS  where PRIVILEGE in ('SELECT ANY TABLE', 'SELECT ANY DICTIONARY')
      union
      select PRIVILEGE FROM ROLE_SYS_PRIVS  where PRIVILEGE in ('SELECT ANY TABLE', 'SELECT ANY DICTIONARY')
    )
  loop
      if    c.PRIVILEGE = 'SELECT ANY TABLE' then
        SEL_AT := 'Y';
      elsif c.PRIVILEGE = 'SELECT ANY DICTIONARY' then
        SEL_AD := 'Y';
      end if;
  end loop;

  if SEL_AT = 'N' then
    MISSING_PRIVS := 'SELECT ANY TABLE';
  end if;

  if    SEL_AD = 'N' and SEL_DICT_REQUIRED = 'Y' and MISSING_PRIVS is null then
    MISSING_PRIVS := 'SELECT ANY DICTIONARY privilege';
    :MIS_PRIV := 'Y';
  elsif SEL_AD = 'N' and SEL_DICT_REQUIRED = 'Y' then
    MISSING_PRIVS := MISSING_PRIVS || ' and ' || 'SELECT ANY DICTIONARY privileges';
    :MIS_PRIV := 'Y';
  elsif SEL_AD = 'Y' and MISSING_PRIVS is not null then
    MISSING_PRIVS := MISSING_PRIVS || ' privilege';
    :MIS_PRIV := 'Y';
  end if;

  for C in
    (select distinct 1 as DV from V$OPTION where PARAMETER = 'Oracle Database Vault' and VALUE = 'TRUE')
  loop
    -- Database Vault is enabled. Need to check realm authorizations
    begin
      -- Check user authorizations on 'Oracle Database Vault' realm, DVSYS schema containing Oracle Database Vault-supplied views
      execute immediate 'select count(*) from DVSYS.DBA_DV_REALM' into AUTH_REALMS;
      execute immediate
        'select min(REALM_NAME) || max(REALM_NAME) || count(*) from DVSYS.DBA_DV_REALM_AUTH where GRANTEE=USER and REALM_NAME in (''Oracle Data Dictionary'', ''Oracle Database Vault'')'
        into AUTH_REALMS;

      -- build list of realms missing authorization
      if    AUTH_REALMS not like '%Oracle Database Vault%' and AUTH_REALMS not like '%Oracle Data Dictionary%' then
        MIS_AUTH_TEXT := 'Oracle Database Vault and Oracle Data Dictionary realms';
      elsif AUTH_REALMS not like '%Oracle Database Vault%' then
        MIS_AUTH_TEXT := 'Oracle Database Vault realm';
      elsif AUTH_REALMS not like '%Oracle Data Dictionary%' then
        MIS_AUTH_TEXT := 'Oracle Data Dictionary realm';
      end if;

      -- build message about missing realm authorizations
      if    MIS_AUTH_TEXT is not null then
        MIS_AUTH_TEXT := 'DB: CT-02016: ERROR: [&&INSTANCE_NAME]: Current database user ' || USER || ' does NOT have authorization on ' || MIS_AUTH_TEXT;
        MIS_AUTH := 'Y';
       :MIS_PRIV := 'Y';
      elsif MIS_AUTH_TEXT is null then
        -- Doublecheck user authorizations on 'Oracle Database Vault' realm, LBACSYS schema containing Lable Security objects
        execute immediate 'select count(*) from LBACSYS.LBAC$POLT' into AUTH_REALMS;
      end if;

    exception
      when others then
        ERR_C := SQLCODE;
        if     ERR_C = -01031 then
          MIS_AUTH_TEXT := 'DB: CT-02017: ERROR: [&&INSTANCE_NAME]: Current database user ' || USER || ' does NOT have authorization on Oracle Database Vault realm';
          MIS_AUTH := 'Y';
         :MIS_PRIV := 'Y';
        else
          dbms_output.put_line('SQLCODE:' || to_char(ERR_C));
        end if;
    end;
  end loop;

  if   :MIS_PRIV = 'Y' and MISSING_PRIVS is not null then
    dbms_output.put_line('DB: CT-02015: ERROR: [&&INSTANCE_NAME]: Current database user ' || USER || ' does NOT have ' || MISSING_PRIVS);
  end if;
  if MIS_AUTH = 'Y' then
    dbms_output.put_line(MIS_AUTH_TEXT);
  end if;

  if :MIS_PRIV = 'Y' or MIS_AUTH = 'Y' then
    dbms_output.put_line('!');
    dbms_output.put_line('!        If you are sure that the current database user ' || USER || ' is granted with the required privileges,');
    dbms_output.put_line('!        continue with yes(y), otherwise select No(n) and please log on with a database user with sufficient privileges.');
    dbms_output.put_line('!        ---');
    dbms_output.put_line('!        Running Review Lite with insufficient privileges may have a significant impact on the quality of the data');
    dbms_output.put_line('!        and information collected from this environment. Due to this, Oracle may have to get back to you');
    dbms_output.put_line('!        and ask for additional items, or to execute again.');
    dbms_output.put_line('!');
  end if;

  if    '&SCRIPT_SI' is not null and :MIS_PRIV = 'Y' then
    dbms_output.put_line('DB: CT-02807: WARNING: [&&INSTANCE_NAME]:  Running in silent mode. Continuing with missing privileges. Errors expected.');
  end if;

END;
/
PROMPT
PROMPT



SET TERMOUT OFF
WHENEVER SQLERROR EXIT
-- FORCE "divisor is equal to zero" AND SQLERROR EXIT IF DB VERSION CANNOT BE READ
select 1/decode(:MIS_PRIV, 'X', 0, null) as " " from DUAL;
WHENEVER SQLERROR CONTINUE

DEFINE PROMPT_PRIV=NO
col PROMPT_PRIV_ new_val PROMPT_PRIV noprint
select '' PROMPT_PRIV_ from DUAL where :MIS_PRIV='Y';
col PROMPT_PRIV_ clear

DEFINE LANSWER=N
SET TERMOUT ON
ACCEPT&SCRIPT_SI&PROMPT_PRIV LANSWER FORMAT A1 PROMPT 'Do you wish to continue anyway? (y\n): '

SET TERMOUT OFF
WHENEVER SQLERROR EXIT
-- FORCE "divisor is equal to zero" AND SQLERROR EXIT IF NOT ACCEPTED
-- WILL ALSO CONTINUE IF PROMPT_PRIV SUBSTITUTION VARIABLE IS NOT NULL
select 1/0 as " " from DUAL where not (nvl('&LANSWER', 'N') in ('Y', 'y') or '&PROMPT_PRIV' is not null or '&SCRIPT_SI' is not null);
WHENEVER SQLERROR CONTINUE

-- Check Privileges END

SET TERMOUT ON
SET FEEDBACK ON
SET VERIFY ON

-- Get SYSDATE
define SYSDATE_START=UNKNOWN
col C0 new_val SYSDATE_START
select SYSDATE C0 from dual;

-- Set output location
define OUTPUT_PATH=***
col C3 new_val OUTPUT_PATH
select '&&HOST_NAME._&&INSTANCE_NAME.' ||
       decode('&SCRIPT_TS', null, null, '_'||to_char(to_date('&SYSDATE_START', 'YYYY-MM-DD_HH24:MI:SS'), 'YYYY.MM.DD.HH24.MI.SS')) C3 from DUAL;

define GREP_PREFIX=***
col C4 new_val GREP_PREFIX noprint
SELECT 'GREP'||'ME>>,&&HOST_NAME.,&&INSTANCE_NAME.,' || '&SYSDATE_START' || ',&&HOST_NAME.,' || name as C4 FROM v$database;

--{
--Detect SQL*Plus client path separator
--Using some Unix/Linux specific syntax
host echo select \'$PWD\' as PWD_, \'rm\' as RMDEL_, \'/\' as PSEP_ from dual where \'$PWD\' like \'%/%\'\; > psep.sql 2> fii_err.txt

define PWD=*
define RMDEL=del
define PSEP=\
col PWD_   new_val PWD   noprint
col RMDEL_ new_val RMDEL noprint
col PSEP_  new_val PSEP  noprint
-- The query syntax is correct only on Unix/Linux
SET TERMOUT OFF
@psep.sql
SET TERMOUT ON
-- Cleanup
host &RMDEL psep.sql   2> fii_err.txt
--}

HOST mkdir &SCRIPT_SD   2> fii_err.txt

define OUTPUT_PATH_SD=***
col C3 new_val OUTPUT_PATH_SD
select decode('&&SCRIPT_SD', null, '&&OUTPUT_PATH', '&&SCRIPT_SD&&PSEP&&OUTPUT_PATH') C3 from DUAL;

HOST mkdir &&OUTPUT_PATH_SD

col C3 new_val OUTPUT_PATH
select decode(instr('&&OUTPUT_PATH_SD', '&&PSEP', -1),
              length('&&OUTPUT_PATH_SD'), '&&OUTPUT_PATH_SD',   -- if terminated by path separator, do not prefix the files
                                          '&&OUTPUT_PATH_SD&&PSEP&&OUTPUT_PATH._') as C3
  from dual;
col C3 clear

SET VERIFY OFF


PROMPT *****  Collecting information ... *****

spool&SCRIPT_OO &&OUTPUT_PATH.summary.csv
SET HEADING OFF
SET FEEDBACK OFF
SET LINESIZE 1000

COL VALUE FORMAT A30 WRAP

PROMPT HOST_NAME: &&HOST_NAME.
PROMPT INSTANCE_NAME(~PDB_NAME): &&INSTANCE_NAME.
SHOW USER

PROMPT
PROMPT OUTPUT PATH AND FILENAME PATTERN IS is &&OUTPUT_PATH*.csv

REM Setting Format output...

PROMPT
PROMPT ReviewLite &SCRIPT_RELEASE. output file created at &SYSDATE_START
PROMPT
PROMPT
PROMPT DB CPU COUNT
PROMPT ==========================================================
select 'DATABASE CPU COUNT: ' || VALUE ||
       decode(ISDEFAULT, 'TRUE', ' (ISDEFAULT)', ' (IS NOT DEFAULT !!!: '|| ISDEFAULT ||')')
       from V$PARAMETER where upper(NAME) like '%CPU_COUNT%';
PROMPT
PROMPT CPU Count as set on the database, could have been modified manually.
PROMPT Please verify using CPU Query and also check for Hyper Threading and
PROMPT Multi-core technology in the server.

SET HEADING ON
PROMPT
PROMPT
PROMPT STAND BY SERVER CONFIGURATION
PROMPT ==========================================================
col FAL_COMPONENT format A96 wrap
col VALUE         format A36 wrap
select distinct
    decode( upper(NAME), 'FAL_SERVER', 'FAL_SERVER = FAL (fetch archive log) server for a standby database - an Oracle Net service name',
                                       'FAL_CLIENT = FAL (fetch archive log) client (standby database) - an Oracle Net service name'
         ) as FAL_COMPONENT,
    VALUE
  from GV$PARAMETER
  where upper(NAME) in ('FAL_CLIENT', 'FAL_SERVER');
col VALUE format A30 wrap
PROMPT
PROMPT If not null information is shown then the database is part of a Data Guard (Standby) configuration
PROMPT

select DATABASE_ROLE, OPEN_MODE, DBID
  from V$DATABASE;
-- More details from 11.1 and higher
select DATABASE_ROLE, OPEN_MODE, DBID, DB_UNIQUE_NAME, PRIMARY_DB_UNIQUE_NAME, DATAGUARD_BROKER
  from V$DATABASE;


SET FEEDBACK ON
COL USERNAME FORMAT A30 WRAP
PROMPT
PROMPT
PROMPT
PROMPT USERS CREATED AND CREATION DATE
PROMPT ==========================================================

SELECT&SCRIPT_OO USERNAME, CREATED FROM DBA_USERS ORDER BY CREATED, USERNAME;


PROMPT
PROMPT BASIC INFORMATION
PROMPT ==========================================================
PROMPT
PROMPT V$VERSION
PROMPT ==========================================================
select * from V$VERSION;
PROMPT
PROMPT V$DATABASE;
PROMPT ==========================================================
COL FS_FAILOVER_OBSERVER_HOST FORMAT A30 WRAP
select * from V$DATABASE;
PROMPT
PROMPT GV$INSTANCE
PROMPT ==========================================================
select * from GV$INSTANCE order by INSTANCE_NAME;
PROMPT
PROMPT GV$PARAMETER
PROMPT ==========================================================
col NAME_  format a40  wrap
col VALUE_ format a60  wrap
select INST_ID, NAME as NAME_, VALUE as VALUE_, ISDEFAULT, DESCRIPTION
  from GV$PARAMETER
  where  upper(NAME) like '%CPU_COUNT%'
      or upper(NAME) like '%FAL_CLIENT%'
      or upper(NAME) like '%FAL_SERVER%'
      or upper(NAME) like '%CLUSTER%'
      or upper(NAME) like '%CONTROL_MANAGEMENT_PACK_ACCESS%'
      or upper(NAME) like '%ENABLE_DDL_LOGGING%'
      or upper(NAME) like '%COMPATIBLE%'
      or upper(NAME) like '%LOG_ARCHIVE_DEST%'
      or upper(NAME) like '%O7_DICTIONARY_ACCESSIBILITY%'
      or upper(NAME) like '%ENABLE_PLUGGABLE_DATABASE%'
      or upper(NAME) like '%INMEMORY%'
      or upper(NAME) like '%DB_UNIQUE_NAME%'
      or upper(NAME) like '%LOG_ARCHIVE_CONFIG%'
      or upper(NAME) like '%HEAT_MAP%'
      or upper(NAME) like '%SPATIAL_VECTOR_ACCELERATION%'
      or upper(NAME) like '%ENCRYPT_NEW_TABLESPACES%'
  order by NAME, INST_ID;
col NAME_  clear
col VALUE_ clear
PROMPT
PROMPT V$CONTAINERS
PROMPT ==========================================================
select * from V$CONTAINERS;
PROMPT
PROMPT DBA_PDBS
PROMPT ==========================================================
select * from DBA_PDBS;
PROMPT
PROMPT SYS_CONTEXT INFO ABOUT CDB AND PDB
PROMPT ==========================================================
col CDB_NAME format A30 WRAP
col CON_ID   format A10 WRAP
col CON_NAME format A30 WRAP
select
       SYS_CONTEXT('USERENV', 'CDB_NAME') as CDB_NAME,
       SYS_CONTEXT('USERENV', 'CON_ID'  ) as CON_ID,
       SYS_CONTEXT('USERENV', 'CON_NAME') as CON_NAME
  from dual;

PROMPT
PROMPT CHECKING CONNECTION
PROMPT ==========================================================
PROMPT
prompt Checking if database is open ...
select USER from USER_OBJECTS where rownum=1;

prompt Checking basic SELECT privileges ...
select USER from DBA_OBJECTS, V$SESSION, V$DATABASE where rownum=1;

prompt Listing required SELECT privileges ...
select PRIVILEGE FROM USER_SYS_PRIVS  where PRIVILEGE in ('SELECT ANY TABLE', 'SELECT ANY DICTIONARY');

select PRIVILEGE FROM ROLE_SYS_PRIVS  where PRIVILEGE in ('SELECT ANY TABLE', 'SELECT ANY DICTIONARY');

PROMPT
PROMPT PLUGGABLE DATABASES INFORMATION
PROMPT ==========================================================
PROMPT SHOW CON_ID
SHOW CON_ID
PROMPT SHOW CON_NAME
SHOW CON_NAME
PROMPT SHOW PDBS
SHOW PDBS
PROMPT
PROMPT SQL*Plus SETTINGS
PROMPT ==========================================================
SHOW ALL
PROMPT ==========================================================
SPOOL OFF


SPOOL &&OUTPUT_PATH.version.csv

SET HEADING OFF
SET FEEDBACK OFF
SET LINESIZE 300

PROMPT DATABASE VERSION
PROMPT -------------------------------------------

PROMPT AUDIT_ID,BANNER,HOST_NAME,INSTANCE_NAME,SYSDATE

SELECT
0                  ||','||
'"'||BANNER||'"'   ||','||
'&&HOST_NAME'      ||','||
'&&INSTANCE_NAME'  ||','||
'&SYSDATE_START'   ||','
FROM V$VERSION;


prompt DATABASE PATCHES
prompt -------------------------------------------;
prompt AUDIT_ID,ACTION_TIME#ACTION#NAMESPACE#VERSION#ID#COMMENTS,HOST_NAME,INSTANCE_NAME,SYSDATE
select
      '0,"'              ||
      ACTION_TIME        ||'#'||
      ACTION             ||'#'||
      NAMESPACE          ||'#'||
      VERSION            ||'#'||
      ID                 ||'#'||
      COMMENTS           ||
      '"'                ||','||
      '&&HOST_NAME'      ||','||
      '&&INSTANCE_NAME'  ||','||
      '&SYSDATE_START'   ||','
  from SYS.REGISTRY$HISTORY
  order by ACTION_TIME;

SPOOL OFF


-- Prepare dynamic select for DBA_USERS columns
define EXPIRY_DATE_DYN=''''''
col C4 new_val EXPIRY_DATE_DYN
SELECT min(EXPIRY_DATE    /*introduced in  8.0*/) C, 'EXPIRY_DATE'    C4 FROM DBA_USERS;
define ACCOUNT_STATUS_DYN=''''''
col C4 new_val ACCOUNT_STATUS_DYN
SELECT min(ACCOUNT_STATUS /*introduced in  8.0*/) C, 'ACCOUNT_STATUS' C4 FROM DBA_USERS;
define COMMON_DYN=''''''
col C4 new_val COMMON_DYN
SELECT min(COMMON         /*introduced in 12.1*/) C, 'COMMON'         C4 FROM DBA_USERS;
define LAST_LOGIN_DYN=''''''
col C4 new_val LAST_LOGIN_DYN
SELECT min(LAST_LOGIN     /*introduced in 12.1*/) C, 'LAST_LOGIN'     C4 FROM DBA_USERS;
col C4 clear

SPOOL&SCRIPT_OO &&OUTPUT_PATH.users.csv

SET HEADING OFF
SET FEEDBACK ON
SET LINESIZE 300

PROMPT
PROMPT USERS CREATED
PROMPT -------------------------------------------

col USERNAME             format a18
col USERID               format a7
col DEFAULT_TABLESPACE   format a13
col TEMPORARY_TABLESPACE format a13
col profile              format a10

PROMPT AUDIT_ID,USERNAME,USER_ID,DEFAULT_TABLESPACE,TEMPORARY_TABLESPACE,CREATED,PROFILE,EXPIRY_DATE,ACCOUNT_STATUS,COMMON,LAST_LOGIN,HOST_NAME,INSTANCE_NAME,SYSDATE

SELECT&SCRIPT_OO DISTINCT
0                     ||','||
USERNAME              ||','||
USER_ID               ||','||
DEFAULT_TABLESPACE    ||','||
TEMPORARY_TABLESPACE  ||','||
CREATED               ||','||
PROFILE               ||','||
&EXPIRY_DATE_DYN.     ||','||
&ACCOUNT_STATUS_DYN.  ||','||
&COMMON_DYN.          ||','||
&LAST_LOGIN_DYN.      ||','|| -- TIMESTAMP(9) WITH TIME ZONE
'&&HOST_NAME'         ||','||
'&&INSTANCE_NAME'     ||','||
'&SYSDATE_START'      ||','
FROM DBA_USERS;

SPOOL OFF

SPOOL&SCRIPT_OO &&OUTPUT_PATH.parameter.csv
SET HEADING OFF
SET FEEDBACK ON
SET LINESIZE 300

col VALUE       format a10
col ISDEFAULT   format a7

PROMPT
PROMPT DATABASE PARAMETER
PROMPT -------------------------------------------

PROMPT AUDIT_ID,NAME,VALUE,ISDEFAULT,DESCRIPTION,HOST_NAME,INSTANCE_NAME,SYSDATE

SELECT&SCRIPT_OO
0                  ||','||
NAME               ||','||
VALUE              ||','||
ISDEFAULT          ||','||
DESCRIPTION        ||','||
'&&HOST_NAME'      ||','||
'&&INSTANCE_NAME'  ||','||
'&SYSDATE_START'   ||','
FROM V$PARAMETER
WHERE UPPER(NAME) = 'CPU_COUNT';

SPOOL OFF

SPOOL &&OUTPUT_PATH.segments.csv
SET HEADING OFF
SET FEEDBACK OFF
SET LINESIZE 300

col SEGMENT_TYPE   format a10
col SEGMENT_NAME   format a30
col OWNER          format a10 wrap
col PARTITION_NAME format a15

PROMPT
PROMPT PARTITIONED DBA SEGMENTS (not applicable for release 7)
PROMPT -------------------------------------------------------

PROMPT AUDIT_ID,OWNER,SEGMENT_TYPE,SEGMENT_NAME,PARTITION_COUNT,PARTITION_MIN,PARTITION_MAX,HOST_NAME,INSTANCE_NAME,SYSDATE

SELECT
0                    ||','||
OWNER                ||','||
OBJECT_TYPE          ||','||
OBJECT_NAME          ||','||
COUNT(*)             ||','||
MIN(SUBOBJECT_NAME)  ||','||
MAX(SUBOBJECT_NAME)  ||','||
'&&HOST_NAME'        ||','||
'&&INSTANCE_NAME'    ||','||
'&SYSDATE_START'     ||','
FROM DBA_OBJECTS
WHERE OBJECT_TYPE LIKE '%PARTITION%'
GROUP BY OWNER, OBJECT_TYPE, OBJECT_NAME
ORDER BY 1;

SPOOL OFF

SPOOL&SCRIPT_OO &&OUTPUT_PATH.license.csv
SET HEADING OFF
SET FEEDBACK ON
SET LINESIZE 300

PROMPT
PROMPT
PROMPT LICENSE INFORMATION
PROMPT -------------------------------------------

PROMPT
PROMPT AUDIT_ID,SESSIONS_MAX,SESSIONS_WARNING,SESSIONS_CURRENT,SESSIONS_HIGHWATER,USERS_MAX,HOST_NAME,INSTANCE_NAME,SYSDATE

select&SCRIPT_OO
0                     ||','||
SESSIONS_MAX          ||','||
SESSIONS_WARNING      ||','||
SESSIONS_CURRENT      ||','||
SESSIONS_HIGHWATER    ||','||
USERS_MAX             ||','||
'&&HOST_NAME'         ||','||
'&&INSTANCE_NAME'     ||','||
'&SYSDATE_START'      ||','
FROM V$LICENSE;

SPOOL OFF


SPOOL&SCRIPT_OO &&OUTPUT_PATH.session.csv
SET HEADING OFF
SET FEEDBACK ON
SET LINESIZE 800

define LOGON_TIME_=NULL
col LOGON_TIME_ new_val LOGON_TIME_
select LOGON_TIME, 'LOGON_TIME' as LOGON_TIME_ from V$SESSION where rownum=1;

PROMPT
PROMPT
PROMPT SESSIONS INFORMATION
PROMPT -------------------------------------------

PROMPT
PROMPT AUDIT_ID,SID,USER#,USERNAME,COMMAND,S.STATUS,SERVER,SCHEMANAME,OSUSER,PROCESS,MACHINE,TERMINAL,PROGRAM,TYPE,MODULE,ACTION,CLIENT_INFO,LAST_CALL_ET,LOGON_TIME,HOST_NAME,INSTANCE_NAME,SYSDATE

select&SCRIPT_OO
0                     || ',' ||
SID                   || ',' ||
SERIAL#               || ',"'||
USERNAME              ||'","'||
COMMAND               ||'","'||
STATUS                ||'","'||
SERVER                ||'","'||
SCHEMANAME            ||'","'||
OSUSER                ||'","'||
PROCESS               ||'","'||
MACHINE               ||'","'||
TERMINAL              ||'","'||
PROGRAM               ||'","'||
TYPE                  ||'","'||
MODULE                ||'","'||
ACTION                ||'","'||
CLIENT_INFO           ||'","'||
LAST_CALL_ET          ||'","'||
&LOGON_TIME_          ||'",' ||
'&&HOST_NAME'         || ',' ||
'&&INSTANCE_NAME'     || ',' ||
'&SYSDATE_START'      || ','
FROM V$SESSION;

SPOOL OFF

SPOOL &&OUTPUT_PATH.v_option.csv
SET HEADING OFF
SET FEEDBACK OFF
SET LINESIZE 300

PROMPT
PROMPT DATABASE OPTIONS
PROMPT -------------------------------------------

PROMPT AUDIT_ID,PARAMETER,VALUE,HOST_NAME,INSTANCE_NAME,SYSDATE

select distinct
    0                 ||','||
    PARAMETER         ||','||
    VALUE             ||','||
    '&&HOST_NAME'     ||','||
    '&&INSTANCE_NAME' ||','||
    '&SYSDATE_START'  ||','
  from V$OPTION;

SPOOL OFF

SPOOL &&OUTPUT_PATH.dba_feature.csv

SET HEADING OFF
SET FEEDBACK OFF
SET LINESIZE 500

Column name format a45
Column detected_usages format 9999

PROMPT
PROMPT
PROMPT 10g DBA_FEATURE_USAGE_STATISTICS
PROMPT -------------------------------------------

PROMPT

PROMPT AUDIT_ID,DBID,NAME,VERSION,DETECTED_USAGES,TOTAL_SAMPLES,CURRENTLY_USED,FIRST_USAGE_DATE,LAST_USAGE_DATE,AUX_COUNT,FEATURE_INFO,LAST_SAMPLE_DATE,LAST_SAMPLE_PERIOD,SAMPLE_INTERVAL,DESCRIPTION,HOST_NAME,INSTANCE_NAME,SYSDATE

SELECT
0                     ||',"' ||
DBID                  ||'","'||
NAME                  ||'","'||
VERSION               ||'","'||
DETECTED_USAGES       ||'","'||
TOTAL_SAMPLES         ||'","'||
CURRENTLY_USED        ||'","'||
FIRST_USAGE_DATE      ||'","'||
LAST_USAGE_DATE       ||'","'||
AUX_COUNT             ||'","'||
''                    ||'","'|| -- skip FEATURE_INFO clob
LAST_SAMPLE_DATE      ||'","'||
LAST_SAMPLE_PERIOD    ||'","'||
SAMPLE_INTERVAL       ||'","'||
DESCRIPTION           ||'","'||
'&&HOST_NAME'         ||'","'||
'&&INSTANCE_NAME'     ||'","'||
'&SYSDATE_START'      ||'",'
from DBA_FEATURE_USAGE_STATISTICS
where   detected_usages > 0 and (
        name like '%ADDM%'
    or  name like '%Automatic Database Diagnostic Monitor%'
    or  name like '%Automatic Workload Repository%'
    or  name like '%AWR%'
    or  name like '%Baseline%'
    or  name like '%Compression%' -- 16.2
    or  name like '%Data Guard%'
    or  name like '%Data Mining%'
    or  name like '%Database Replay%'
    or  name like '%EM%'
    or  name like '%Encrypt%'
    or  name like '%Exadata%'
    or  name like '%Flashback Data Archive%'
    or  name like '%Label Security%'
    or  name like '%OLAP%'
    or  name like '%Pack%'
    or  name like '%Partitioning%'
    or  name like '%Real Application Cluster%' -- 16.2
    or  name like '%SecureFile%'
    or  name like '%Spatial%'
    or  name like '%SQL Monitoring%'
    or  name like '%SQL Performance%'
    or  name like '%SQL Profile%'
    or (name like '%SQL Tuning%' and name not like 'Automatic SQL Tuning Advisor') -- Automatic SQL Tuning Advisor is configured by default
    or  name like '%SQL Access Advisor%'
    or  name like '%Vault%'
    or (name like '%Datapump%' and (regexp_like(lower(to_char(feature_info)), '*compression used: [1-9]* times*') or regexp_like(lower(to_char(feature_info)), 'compression used: *true')))
    or (name like '%Datapump%' and (regexp_like(lower(to_char(feature_info)), '*encryption used: [1-9]* times*' ) or regexp_like(lower(to_char(feature_info)), 'encryption used: *true' )))
    or  name like '%Flashback Data Archive%'
    or  name like '%Data Redaction%'
    or  name like '%Global Data Services%'
    or  name like '%Heat Map%'
    or  name like '%In-Memory%'
    or  name like '%Information Lifecycle Management%'
    or  name like '%Oracle Multitenant%'
    or  name like '%Oracle Pluggable Databases%'
    or  name like '%Privilege Capture%'
    or  name like '%Quality of Service Management%'
    or  name like '%Zone maps%'
)
order by name, version;

SPOOL OFF



SPOOL &&OUTPUT_PATH.options.csv
SET HEADING OFF
SET FEEDBACK OFF
SET LINESIZE 200

SET HEADING OFF

PROMPT
PROMPT *** PARTITIONING
PROMPT ======================================================================

select 'ORACLE PARTITIONING INSTALLED: ' || VALUE from V$OPTION where PARAMETER='Partitioning';

SET FEEDBACK ON
SET HEADING ON
COL OWNER        FORMAT A20 WRAP
COL SEGMENT_TYPE FORMAT A18 WRAP
COL SEGMENT_NAME FORMAT A30 WRAP

SELECT distinct OWNER, OBJECT_TYPE as SEGMENT_TYPE, OBJECT_NAME as SEGMENT_NAME, min(created) min_created, min(last_ddl_time) min_last_dll_time
  FROM DBA_OBJECTS
  WHERE OBJECT_TYPE LIKE '%PARTITION%'
  group by OWNER, OBJECT_TYPE, OBJECT_NAME
  ORDER BY 1, 2, 3;

PROMPT IF NO ROWS ARE RETURNED, THEN PARTITIONING IS NOT BEING USED.
PROMPT
PROMPT IF ROWS ARE RETURNED, CHECK THAT BOTH OWNER AND SEGMENT ARE
PROMPT ORACLE CREATED. IF NOT, THEN PARTITIONING IS BEING USED.
PROMPT

PROMPT * Partitioned objects on RECYCLEBIN

select OWNER, ORIGINAL_NAME, OBJECT_NAME, TYPE, CREATETIME, DROPTIME, PARTITION_NAME, SPACE, CAN_UNDROP
  from DBA_RECYCLEBIN
  where TYPE not like '%Partition%'
    and (OWNER, OBJECT_NAME) in (select OWNER, OBJECT_NAME from DBA_RECYCLEBIN where TYPE like '%Partition%')
union all
select OWNER, ORIGINAL_NAME, OBJECT_NAME, TYPE, CREATETIME, DROPTIME, PARTITION_NAME, SPACE, CAN_UNDROP
  from DBA_RECYCLEBIN
  where TYPE like '%Partition%';

SET HEADING OFF
SET FEEDBACK OFF

PROMPT
PROMPT
PROMPT *** RAC (REAL APPLICATION CLUSTERS)
PROMPT ======================================================================

select 'ORACLE RAC INSTALLED: ' || VALUE from V$OPTION where PARAMETER in ('Real Application Clusters', 'Parallel Server');

SET HEADING ON

PROMPT
PROMPT CHECKING TO SEE IF RAC IS INSTALLED AND BEING USED...
PROMPT RAC (Real Application Clusters) = Former OPS (Oracle Parallel Server)
PROMPT
PROMPT * Check cluster_database initialization parameter (for DB version 9.0.1 and higher)

select INST_ID, NAME, VALUE
  from GV$PARAMETER
  where NAME = 'cluster_database'
  order by INST_ID;

PROMPT
PROMPT If the value returned is TRUE, then RAC/OPS is being used.
PROMPT even if the following query only returns one row.
PROMPT
PROMPT * Check database instances

select INSTANCE_NAME, HOST_NAME, INST_ID, STATUS
  from GV$INSTANCE
  order by INST_ID;

PROMPT
PROMPT If only one row is returned and DB version is 11.2 or higher, then it might be an Oracle RAC One Node configuration.
PROMPT In some cases, for limited time periods, Oracle RAC One Node can be running Online Database Relocation
PROMPT and 2 instances are legally running for the Oracle RAC One Node database.
PROMPT
PROMPT In all the other cases, if more than one row is returned, then RAC/OPS IS being used for this database.

SET HEADING ON
SET FEEDBACK ON

PROMPT
PROMPT
PROMPT
PROMPT *** MULTITENANT (introduced in 12c_r1)
PROMPT ======================================================================

PROMPT * Looking for pluggable databases (PDB)
col OPEN_TIME format a20 wrap

select
       b.CDB,
       a.CON_ID,
       a.NAME,
       a.OPEN_MODE,
       a.OPEN_TIME,
       decode(a.CON_ID, 0, 'entire CDB or non-CDB', 1, 'ROOT', 2, 'SEED', 'PDB') as CONTAINER
  from V$CONTAINERS a, V$DATABASE b
  order by a.CON_ID;

PROMPT If more than one PDB container is returned, then Multitenant Option is in use

col OPEN_TIME clear

PROMPT
PROMPT
PROMPT
PROMPT *** ACTIVE DATA GUARD (introduced in 11.1)
PROMPT ======================================================================

PROMPT * Checking for "Physical Standby with Real-time Query" feature usage

select a.dest_id, a.dest_name, a.status, a.type, a.database_mode, a.recovery_mode, a.destination, a.db_unique_name, b.value as compatible
  from v$archive_dest_status a, v$parameter b
  where b.name = 'compatible' and b.value like '1%' and b.value not like '10%'
    and a.recovery_mode like 'MANAGED%' and a.status = 'VALID' and a.database_mode = 'OPEN_READ-ONLY'
  order by a.dest_id;

SET LINESIZE 300

PROMPT If any rows are returned, then Active Data Guard is in use

PROMPT
PROMPT Gathering information about the LOCAL database open_mode
PROMPT
col PLATFORM_NAME format a40 wrap

select dbid, name, db_unique_name, open_mode, database_role, remote_archive, dataguard_broker, guard_status, platform_name
  from v$database;

SET LINESIZE 200

PROMPT
PROMPT * Checking for "Fast Incremental Backup on Physical Standby" feature usage
col FILENAME format a40 wrap

select
    b.DATABASE_ROLE,
    a.STATUS,
    a.FILENAME,
    a.BYTES
  from V$BLOCK_CHANGE_TRACKING a, V$DATABASE b
    where b.DATABASE_ROLE like 'PHYSICAL STANDBY'
      and a.STATUS = 'ENABLED'
;

PROMPT If any rows are returned, then Active Data Guard is in use

col PLATFORM_NAME clear
col FILENAME clear


SET HEADING OFF
SET FEEDBACK OFF

PROMPT
PROMPT *** OLAP
PROMPT ======================================================================

select 'ORACLE OLAP INSTALLED: ' || VALUE from V$OPTION where PARAMETER='OLAP';

PROMPT
PROMPT If the value is TRUE then the OLAP option IS INSTALLED
PROMPT If the value is FALSE then the OLAP option IS NOT INSTALLED
PROMPT If NO rows are selected then the option is NOT being used.

PROMPT
PROMPT
PROMPT CHECKING TO SEE IF THE OLAP OPTION IS BEING USED...
PROMPT
PROMPT CHECKING FOR OLAP CUBES...
PROMPT

SET HEADING ON
SET FEEDBACK OFF

select
    count(*) "DBA$ OLAP CUBES"
  from  OLAPSYS.DBA$OLAP_CUBES
  where OWNER <> 'SH';

select
    count(*) "DBA_ OLAP CUBES"
  from  DBA_CUBES
  where OWNER <> 'SH';

PROMPT
PROMPT IF THE COUNT IS > 0 THEN CHECK THE WORKSPACES BEING USED
PROMPT IF THE COUNT IS = 0 THEN THE OLAP OPTION IS NOT BEING USED
PROMPT IF THE TABLE DOES NOT EXIST (ORA-00942) ...THEN THE OLAP CUBES ARE NOT BEING USED
PROMPT

PROMPT CHECKING FOR ANALYTICAL WORK SPACES...
PROMPT

select count(*) "Analytical Workspaces"
  from DBA_AWS;

PROMPT
PROMPT IF THE COUNT IS >1 THEN CHECK WORKSPACES AND ITS OWNER
PROMPT IF THE COUNT IS 0 OR 1 THEN ANALYTICAL WORKSPACES ARE NOT BEING USED
PROMPT IF THE TABLE DOES NOT EXIST (ORA-00942) ...THEN ANALYTICAL WORKSPACES ARE NOT BEING USED

PROMPT
PROMPT CHECKING FOR ANALYTICAL WORKSPACE OWNERS...
PROMPT

SET HEADING ON
SET FEEDBACK ON

select OWNER, AW_NUMBER, AW_NAME, PAGESPACES, GENERATIONS
  from DBA_AWS;

PROMPT
PROMPT NOTE: A positive result FROM either QUERY indicates the use of the OLAP option.
PROMPT    Check the Workspace owners to detemine if Workspaces are Oracle created.
PROMPT


SET HEADING OFF
SET FEEDBACK OFF

PROMPT
PROMPT
PROMPT *** DATA MINING (ADVANCED ANALYTICS FEATURE)
PROMPT ======================================================================
PROMPT
PROMPT NOTE: Data Mining is currently component of
PROMPT .     Advanced Analytics Enterprise Edition Option

select 'ORACLE DATA MINING INSTALLED: ' || VALUE from V$OPTION where PARAMETER like '%Data Mining';

SET HEADING ON
SET FEEDBACK ON

PROMPT
PROMPT CHECKING TO SEE IF DATA MINING IS BEING USED:
PROMPT

PROMPT * FOR 9i DATABASE:
PROMPT
select count(*) "Data_Mining_Model" from odm.odm_mining_model;

PROMPT
PROMPT * FOR 10g r1 DATABASE:

PROMPT
select count(*) "Data_Mining_Objects" from dmsys.dm$object;
select count(*) "Data_Mining_Models" from dmsys.dm$model;

PROMPT
PROMPT * FOR 10g r2 DATABASE:
PROMPT
select count(*) "Data_Mining_Objects" from dmsys.dm$p_model;

PROMPT
PROMPT * FOR 11g DATABASE:
PROMPT
select count(*) from SYS.MODEL$;

PROMPT If no rows are returned, then Data Mining is NOT being used.
PROMPT If rows are returned then Data Mining IS being used.

PROMPT
PROMPT
PROMPT * Gathering Data Mining Models details (11.1 and higher)
select OWNER, MODEL_NAME, MINING_FUNCTION, ALGORITHM, CREATION_DATE, BUILD_DURATION, MODEL_SIZE
  from SYS.DBA_MINING_MODELS
  order by OWNER, MODEL_NAME;


SET HEADING OFF
SET FEEDBACK OFF

PROMPT
PROMPT
PROMPT *** SPATIAL
PROMPT ======================================================================

select 'ORACLE SPATIAL INSTALLED: ' || VALUE from V$OPTION where PARAMETER='Spatial';

SET HEADING ON
SET FEEDBACK ON

PROMPT
PROMPT CHECKING TO SEE IF SPATIAL FUNCTIONS ARE BEING USED...
PROMPT

select count(*) as SDO_GEOM_METADATA_TABLE
  from MDSYS.SDO_GEOM_METADATA_TABLE;

PROMPT If value returned is 0, then SPATIAL is NOT being used.
PROMPT If value returned is > 0, then SPATIAL OR LOCATOR IS being used.
PROMPT
PROMPT Confirm with the customer whether SPATIAL OR LOCATOR is being used.


SET HEADING OFF
SET FEEDBACK OFF

PROMPT
PROMPT
PROMPT *** LABEL SECURITY
PROMPT ======================================================================

select 'ORACLE LABEL SECURITY INSTALLED: ' || VALUE from V$OPTION where PARAMETER like '%Label Security%';

SET HEADING ON

PROMPT
PROMPT CHECKING TO SEE IF THE LABEL SECURITY OPTION IS BEING USED....

select count(*) as COUNT from LBACSYS.LBAC$POLT where OWNER <> 'SA_DEMO';
select count(*) as COUNT from LBACSYS.OLS$POLT  where OWNER <> 'SA_DEMO';

PROMPT If the COUNT > 0 then the LABEL SECURITY OPTION IS being used
PROMPT If the COUNT IS = 0 then the LABEL SECURITY OPTION IS NOT being used
PROMPT If TABLE DOES NOT EXIST (ORA-00942) ...Then LABEL SECURITY OPTION IS NOT being used


PROMPT
PROMPT
PROMPT *** ADVANCED SECURITY
PROMPT ======================================================================
PROMPT
PROMPT CHECKING FOR ADVANCED SECURITY FEATURES USAGE

SET HEADING ON
SET FEEDBACK ON

PROMPT
PROMPT * Looking for tablespaces using Transparent Data Encryption (TDE) - 11.1 and higher
PROMPT
select TABLESPACE_NAME, ENCRYPTED from DBA_TABLESPACES where ENCRYPTED='YES';

PROMPT If rows are returned, then ADVANCED SECURITY is IN USE

PROMPT
PROMPT
PROMPT * Checking for "SecureFiles Transparent Data Encryption (TDE)" feature usage

col COLUMN_NAME format a30

select
    'DBA_LOBS'               as DATA_DICTIONARY_VIEW,
    OWNER                    as TABLE_OWNER,
    TABLE_NAME ,
    COLUMN_NAME,
    ENCRYPT,
    SECUREFILE
  from DBA_LOBS
  where ENCRYPT not in ('NO', 'NONE')
union all
select
    'DBA_LOB_PARTITIONS'     as DATA_DICTIONARY_VIEW,
    TABLE_OWNER,
    TABLE_NAME ,
    COLUMN_NAME,
    ENCRYPT,
    SECUREFILE
  from DBA_LOB_PARTITIONS
  where ENCRYPT not in ('NO', 'NONE')
union all
select
    'DBA_LOB_SUBPARTITIONS'  as DATA_DICTIONARY_VIEW,
    TABLE_OWNER,
    TABLE_NAME ,
    COLUMN_NAME,
    ENCRYPT,
    SECUREFILE
  from DBA_LOB_SUBPARTITIONS
  where ENCRYPT not in ('NO', 'NONE')
order by 1, 2, 3, 4;

PROMPT If non-system rows are returned, then ADVANCED SECURITY is IN USE
col COLUMN_NAME clear

PROMPT
PROMPT
PROMPT *** ADVANCED COMPRESSION (introduced in 11.1)
PROMPT ======================================================================
PROMPT
PROMPT CHECKING FOR ADVANCED COMPRESSION FEATURES USAGE

SET HEADING ON
SET FEEDBACK ON

prompt
prompt * Checking for "OLTP Table Compression" feature usage

COL OWNER          FORMAT A20 WRAP
COL TABLE_NAME     FORMAT A30 WRAP
COL PARTITION_NAME FORMAT A20 WRAP

select 'DBA_TABLES' as source_, a.owner, a.table_name, '' as partition_name, a.compression, a.compress_for
  from dba_tables a
  where a.compress_for in ('FOR ALL OPERATIONS', 'OLTP', 'ADVANCED')
union all
select 'DBA_TAB_PARTITIONS' as source_, a.table_owner, a.table_name, partition_name, a.compression, a.compress_for
  from dba_tab_partitions a
  where a.compress_for in ('FOR ALL OPERATIONS', 'OLTP', 'ADVANCED')
union all
select 'DBA_TAB_SUBPARTITIONS' as source_, a.table_owner, a.table_name, partition_name, a.compression, a.compress_for
  from dba_tab_subpartitions a
  where a.compress_for in ('FOR ALL OPERATIONS', 'OLTP', 'ADVANCED')
order by 1, 2, 3, 4;

prompt If non-system rows are returned, then ADVANCED COMPRESSION OPTION is in use

prompt
prompt
prompt * Checking for "SecureFiles Compression and Deduplication" feature usage

col COLUMN_NAME format a30

select 'DBA_LOBS' as SOURCE_, a.owner, a.table_name, a.column_name, a.compression, a.deduplication
  from dba_lobs a
  where a.compression   not in ('NO', 'NONE')
     or a.deduplication not in ('NO', 'NONE')
union all
select 'DBA_LOB_PARTITIONS' as SOURCE_, a.table_owner, a.table_name, a.column_name, a.compression, a.deduplication
  from dba_lob_partitions a
  where a.compression   not in ('NO', 'NONE')
     or a.deduplication not in ('NO', 'NONE')
union all
select 'DBA_LOB_SUBPARTITIONS' as SOURCE_, a.table_owner, a.table_name, a.column_name, a.compression, a.deduplication
  from dba_lob_subpartitions a
  where a.compression   not in ('NO', 'NONE')
     or a.deduplication not in ('NO', 'NONE')
order by 1, 2, 3, 4;

prompt If non-system rows are returned, then ADVANCED COMPRESSION OPTION is in use
col COLUMN_NAME clear

prompt
prompt
prompt * Checking for "Data Guard Network Compression" feature usage

SET LINESIZE 500
col FEATURE_INFO_ format a350 wrap

select
       VERSION,
       NAME,
       CURRENTLY_USED,
       LAST_USAGE_DATE,
       LAST_SAMPLE_DATE,
       to_char(FEATURE_INFO) feature_info_
from dba_feature_usage_statistics
where name = 'Data Guard'
  order by 1, 2;

SET LINESIZE 200

prompt If FEATURE_INFO column contains "Compression used: TRUE" then ADVANCED COMPRESSION OPTION is in use
prompt

col FEATURE_INFO_ clear

col VALUE_ format a100 wrap
col NAME_  format a30  wrap

select name NAME_, value as value_, isdefault
  from V$PARAMETER
  where UPPER(name)  like '%LOG_ARCHIVE_DEST%'
    and UPPER(value) like '%COMPRESSION=ENABLE%'
  order by 1;

prompt If any rows are returned, then ADVANCED COMPRESSION OPTION is in use
prompt

col VALUE_ clear
col NAME_  clear

prompt
prompt
prompt * Checking for "Data Pump Compression" feature usage

SET LINESIZE 500
col FEATURE_INFO_ format a350 wrap

select
       VERSION,
       NAME,
       CURRENTLY_USED,
       LAST_USAGE_DATE,
       LAST_SAMPLE_DATE,
       to_char(FEATURE_INFO) feature_info_
from dba_feature_usage_statistics
where name = 'Oracle Utility Datapump (Export)'
  order by 1, 2;

SET LINESIZE 200

prompt If FEATURE_INFO column contains "Compression used: N times" and N is not 0 (zero) then ADVANCED COMPRESSION OPTION is in use
prompt

col FEATURE_INFO_ clear


prompt
prompt
prompt * Checking for "Flashback Data Archive (Total Recall)" feature usage

col FLASHBACK_ARCHIVE_NAME format a30 wrap
col TABLESPACE_NAME        format a30 wrap
col QUOTA_IN_MB            format a12 wrap
col CREATE_TIME            format a21 wrap
col LAST_PURGE_TIME        format a21 wrap
col STATUS                 format a8  wrap
col OWNER_NAME             format a30 wrap
col TABLE_NAME             format a30 wrap
col ARCHIVE_TABLE_NAME     format a30 wrap

select
      a.FLASHBACK_ARCHIVE_NAME,
      b.TABLESPACE_NAME,
      b.QUOTA_IN_MB,
      a.RETENTION_IN_DAYS,
      a.CREATE_TIME,
      a.LAST_PURGE_TIME,
      a.STATUS -- DEFAULT or not (NULL)
  from        DBA_FLASHBACK_ARCHIVE    a
    left join DBA_FLASHBACK_ARCHIVE_TS b on a.FLASHBACK_ARCHIVE# = b.FLASHBACK_ARCHIVE#
  order by 1, 2;

select
      FLASHBACK_ARCHIVE_NAME,
      OWNER_NAME,
      TABLE_NAME,
      ARCHIVE_TABLE_NAME
  from DBA_FLASHBACK_ARCHIVE_TABLES
  order by 1, 2, 3;

prompt If any rows are returned, then ADVANCED COMPRESSION OPTION is in use
prompt

col FLASHBACK_ARCHIVE_NAME clear
col TABLESPACE_NAME        clear
col QUOTA_IN_MB            clear
col CREATE_TIME            clear
col LAST_PURGE_TIME        clear
col STATUS                 clear
col OWNER_NAME             clear
col TABLE_NAME             clear
col ARCHIVE_TABLE_NAME     clear


PROMPT
PROMPT
PROMPT *** DATABASE VAULT
PROMPT ======================================================================

PROMPT
PROMPT CHECKING TO SEE IF DATABASE VAULT SCHEMAS ARE CREATED...

SET HEADING OFF
SET FEEDBACK OFF

select decode(upper(max(username)), 'DVSYS', 'Database Vault Schema DVSYS exists', 'Database Vault schema DVSYS does not exist')
  from dba_users where UPPER(username)='DVSYS';

select decode(upper(max(username)), 'DVF', 'Database Vault Schema DVF exists', 'Database Vault schema DVF does not exist')
  from dba_users where UPPER(username)='DVF';

SET FEEDBACK ON

PROMPT
PROMPT Checking if there are Database Vault Realms created...
PROMPT
SELECT NAME, ENABLED
FROM DVSYS.DBA_DV_REALM;

PROMPT If non default Database Vault Realms are created
PROMPT then DATABASE VAULT is in use
PROMPT
PROMPT NOTE:
PROMPT If Database Vault is enabled, user running Review Lite
PROMPT must have authorization on "Oracle Database Vault Realm"
PROMPT Otherwise the following error is produced: ORA-01031: insufficient privileges

PROMPT
PROMPT
PROMPT *** DATABASE IN-MEMORY
PROMPT ======================================================================
PROMPT
PROMPT CHECKING FOR DATABASE IN-MEMORY FEATURES USAGE

SET HEADING ON
SET FEEDBACK ON

prompt
prompt * Checking for "In-Memory Column Store" feature usage
prompt
prompt   Checking for tables configured to use In-Memory Column Store (INMEMORY='ENABLED')

COL OWNER          FORMAT A20 WRAP
COL TABLE_NAME     FORMAT A30 WRAP
COL PARTITION_NAME FORMAT A20 WRAP

select 'DBA_TABLES' as source_,            a.owner,       a.table_name, '' as partition_name, a.inmemory, a.inmemory_priority
  from dba_tables a
    where inmemory in ('ENABLED')
union all
select 'DBA_TAB_PARTITIONS' as source_,    a.table_owner, a.table_name, partition_name,       a.inmemory, a.inmemory_priority
  from dba_tab_partitions a
    where inmemory in ('ENABLED')
union all
select 'DBA_TAB_SUBPARTITIONS' as source_, a.table_owner, a.table_name, partition_name,       a.inmemory, a.inmemory_priority
  from dba_tab_subpartitions a
    where inmemory in ('ENABLED')
union all
select 'DBA_OBJECT_TABLES,' as source_,    a.owner,       a.table_name, '' as partition_name, a.inmemory, a.inmemory_priority
  from dba_object_tables a
  where inmemory in ('ENABLED')
order by 1, 2, 3, 4;

prompt   Checking for initialization parameter inmemory_size

COL DISPLAY_VALUE  FORMAT A30 WRAP

select name, value, display_value, description
  from v$parameter
  where name = 'inmemory_size';

prompt If tables or partitions with INMEMORY enabled are returned and
prompt inmemory_size parameter is set to a value different from zero
prompt then DATABASE IN-MEMORY is in use

prompt
prompt * Checking for "In-Memory Aggregation" feature usage

select
       DBID,
       VERSION,
       NAME,
       CURRENTLY_USED,
       FIRST_USAGE_DATE,
       LAST_USAGE_DATE,
       LAST_SAMPLE_DATE
from DBA_FEATURE_USAGE_STATISTICS
where name = 'In-Memory Aggregation'
  order by LAST_SAMPLE_DATE;

prompt If DBA_FEATURE_USAGE_STATISTICS indicates feature usage, then DATABASE IN-MEMORY is in use
prompt


PROMPT
PROMPT
PROMPT *** OEM (ORACLE ENTERPRISE MANAGER)
PROMPT =====================================================================*

PROMPT
PROMPT CHECKING FOR OEM VERSIONS PRIOR TO 10.1
PROMPT -------------------------------------------

SET HEADING ON
SET FEEDBACK OFF

PROMPT
PROMPT CHECKING TO SEE IF OEM PROGRAMS ARE RUNNING
PROMPT DURING THE MEASUREMENT PERIOD...
PROMPT

SET FEEDBACK ON

SELECT DISTINCT
   program
FROM
   v$session
WHERE
   upper(program) LIKE '%XPNI.EXE%'
   OR upper(program) LIKE '%VMS.EXE%'
   OR upper(program) LIKE '%EPC.EXE%'
   OR upper(program) LIKE '%TDVAPP.EXE%'
   OR upper(program) LIKE 'VDOSSHELL%'
   OR upper(program) LIKE '%VMQ%'
   OR upper(program) LIKE '%VTUSHELL%'
   OR upper(program) LIKE '%JAVAVMQ%'
   OR upper(program) LIKE '%XPAUTUNE%'
   OR upper(program) LIKE '%XPCOIN%'
   OR upper(program) LIKE '%XPKSH%'
   OR upper(program) LIKE '%XPUI%';

PROMPT
PROMPT CHECKING FOR OEM REPOSITORIES...
PROMPT

DECLARE
      cursor1 integer;
   v_count number(1);
      v_schema dba_tables.owner%TYPE;
      v_version varchar2(10);
      v_component varchar2(20);
      v_i_name varchar2(10);
      v_h_name varchar2(30);
      stmt varchar2(200);
      rows_processed integer;

      CURSOR schema_array IS
      SELECT owner
      FROM dba_tables WHERE table_name = 'SMP_REP_VERSION';

      CURSOR schema_array_v2 IS
      SELECT owner
      FROM dba_tables WHERE table_name = 'SMP_VDS_REPOS_VERSION';

BEGIN
         DBMS_OUTPUT.PUT_LINE ('.');
         DBMS_OUTPUT.PUT_LINE ('OEM REPOSITORY LOCATIONS');

         select instance_name,host_name into v_i_name, v_h_name from
            v$instance;
            DBMS_OUTPUT.PUT_LINE ('Instance: '||v_i_name||' on host: '||v_h_name);

            OPEN schema_array;
            OPEN schema_array_v2;

            cursor1:=dbms_sql.open_cursor;

            v_count := 0;

            LOOP -- this loop steps through each valid schema.
            FETCH schema_array INTO v_schema;
            EXIT WHEN schema_array%notfound;
            v_count := v_count + 1;
            dbms_sql.parse(cursor1,'select c_current_version, c_component from '||v_schema||'.smp_rep_version', dbms_sql.native);
            dbms_sql.define_column(cursor1, 1, v_version, 10);
            dbms_sql.define_column(cursor1, 2, v_component, 20);

            rows_processed:=dbms_sql.execute ( cursor1 );

            loop -- to step through cursor1 to find console version.
            if dbms_sql.fetch_rows(cursor1) >0 then
            dbms_sql.column_value (cursor1, 1, v_version);
            dbms_sql.column_value (cursor1, 2, v_component);
            if v_component = 'CONSOLE' then
            dbms_output.put_line ('Schema '||rpad(v_schema,15)||' has a repository
            version '||v_version);
            exit;

            end if;
            else
               exit;
            end if;
            end loop;

            END LOOP;

            LOOP -- this loop steps through each valid V2 schema.
            FETCH schema_array_v2 INTO v_schema;
            EXIT WHEN schema_array_v2%notfound;

            v_count := v_count + 1;
            dbms_output.put_line ( 'Schema '||rpad(v_schema,15)||' has a repository
            version 2.x' );
            end loop;

            dbms_sql.close_cursor (cursor1);
            close schema_array;
            close schema_array_v2;
            if v_count = 0 then
            dbms_output.put_line ( 'There are NO OEM repositories with version prior to 10g on this instance.');
            end if;
END;
/

prompt
prompt If NO ROWS are returned then OEM is not being used.
prompt If ROWS are returned, then OEM is being utilized.
prompt

PROMPT
PROMPT CHECKING FOR OEM VERSIONS 10.1 OR HIGHER
PROMPT -------------------------------------------

col OEM_PACK            format A40 wrap
col PACK_ACCESS_GRANTED format A19
col PACK_ACCESS_AGREED  format A19
col TABLE_NAME_         format A40 wrap
col C_                  format A24 wrap
col OEMOWNER            format a30 wrap
col OEM_PACK            format a75 wrap
select 'OEM REPOSITORY SCHEMA:' C_, owner as OEMOWNER from dba_tables where table_name = 'MGMT_ADMIN_LICENSES';


prompt
prompt GATHERING MANAGEMENT PACK ACCESS SETTINGS
prompt === OEM Database Control 10g
prompt

select distinct
       a.pack_display_label as OEM_PACK,
       decode(b.pack_name, null, 'NO', 'YES') as PACK_ACCESS_GRANTED,
       PACK_ACCESS_AGREED
  from SYSMAN.MGMT_LICENSE_DEFINITIONS a,
       SYSMAN.MGMT_ADMIN_LICENSES      b,
      (select decode(count(*), 0, 'NO', 'YES') as PACK_ACCESS_AGREED
        from SYSMAN.MGMT_LICENSES where upper(I_AGREE)='YES') c
  where a.pack_label = b.pack_name   (+)
  order by 1, 2;

col I_AGREE format a10 wrap
prompt OEM PACK ACCESS AGREEMENTS
select USERNAME, TIMESTAMP, I_AGREE
  from SYSMAN.MGMT_LICENSES
  order by TIMESTAMP;


col TARGET_NAME    format a30 wrap
prompt OEM MANAGED DATABASES
select TARGET_NAME, HOST_NAME, LOAD_TIMESTAMP
  from SYSMAN.MGMT_TARGETS
  where TARGET_TYPE like '%database%'
  order by TARGET_NAME;


prompt
prompt GATHERING MANAGEMENT PACK ACCESS SETTINGS
prompt === OEM Grid Control 10g; OEM Grid Control 11g; OEM Database Control 11g; OEM Cloud Control 12c
prompt

SET LINESIZE 314

col HOST_NAME               format A30 wrap
col TARGET_NAME             format A50 wrap
col TARGET_TYPE             format A30 wrap
col TARGET_TYPE_D           format A30 wrap
col PARENT_TARGET_NAME      format A50 wrap
col PARENT_TARGET_TYPE      format A30 wrap
col PACK_LABEL              format A20 wrap
col OEM_PACK                format A60 wrap
col PACK_ACCESS_GRANTED     format A19 wrap
col PACK_ACCESS_AGREED      format A19 wrap
col PACK_ACCESS_AGREED_DATE format A23 wrap
col PACK_ACCESS_AGREED_BY   format A21 wrap

select
       tg.host_name,
       tg.target_type,
       tt.type_display_name as target_type_d,
       tg.target_name,
       ld.pack_label,
       ld.pack_display_label as oem_pack,
       decode(lt.pack_name  , null, 'NO', 'YES') as pack_access_granted,
       decode(lc.target_guid, null, 'NO', 'YES') as pack_access_agreed,
       lc.confirmed_time                         as pack_access_agreed_date,
       lc.confirmed_by                           as pack_access_agreed_by
  from              SYSMAN.MGMT_TARGETS                  tg
    left outer join SYSMAN.MGMT_TARGET_TYPES             tt on tg.target_type = tt.target_type
         inner join SYSMAN.MGMT_LICENSE_DEFINITIONS      ld on tg.target_type = ld.target_type
    left outer join SYSMAN.MGMT_LICENSED_TARGETS         lt on tg.target_guid = lt.target_guid and ld.pack_label = lt.pack_name
    left outer join SYSMAN.MGMT_LICENSE_CONFIRMATION     lc on tg.target_guid = lc.target_guid
  order by tg.host_name, tt.type_display_name, tg.target_name, ld.pack_display_label;

SET LINESIZE 200


prompt
prompt GATHERING MANAGEMENT PACK USAGE STATISTICS
prompt === OEM 12c Cloud Control
prompt (* For readability, output is limited to 20 rows)

col PACK_NAME               format A60 wrap
col FEATURE_NAME            format A60 wrap

SELECT * FROM (
SELECT
    reg.feature_name                           as PACK_NAME,
    tgts.display_name                          as TARGET_NAME,
    tgts.type_display_name                     as TARGET_TYPE,
    tgts.host_name                             as HOST_NAME,
    DECODE(stat.isused, 1, 'TRUE', 'FALSE')    as CURRENTLY_USED,
    stat.detected_samples                      as DETECTED_USAGES
  FROM SYSMAN.mgmt_fu_registrations reg,
       SYSMAN.mgmt_fu_statistics    stat,
       SYSMAN.mgmt_targets          tgts
  WHERE (stat.isused = 1 or stat.detected_samples > 0) -- current or past usage
    AND stat.target_guid = tgts.target_guid
    AND reg.feature_id = stat.feature_id
    AND reg.collection_mode = 2
  --AND tgts.display_name = 'TARGET_NAME'
 ORDER BY decode(tgts.target_type, 'oracle_database', 1, 'rac_database', 1, 2), -- db packs first
          reg.feature_name,
          tgts.type_display_name,
          tgts.display_name,
          tgts.host_name
) WHERE rownum <= 20;


COL VALUE_ format a18
prompt
prompt CHECKING CONTROL_MANAGEMENT_PACK_ACCESS and ENABLE_DDL_LOGGING INSTANCE PARAMETERS (11.1 or higher)
prompt

select name, value as value_, isdefault
  from V$PARAMETER
  where UPPER(name) like '%CONTROL_MANAGEMENT_PACK_ACCESS%'
     or UPPER(name) like '%ENABLE_DDL_LOGGING%'                -- (#43257)
  order by 1;


PROMPT
PROMPT *** OEM TUNING PACK
PROMPT =====================================================================*

PROMPT
prompt CHECKING FOR TUNING PACK USAGE ...
PROMPT ----------------------------------
SET FEEDBACK OFF
SET FEEDBACK 5

prompt
prompt * Checking for use of SQL Profiles

select count(*)
  from DBA_SQL_PROFILES
  where lower(STATUS) = 'enabled';

prompt If the number returned is > 0, then TUNING PACK is in use

prompt
prompt * Gathering details about SQL Profiles
col CREATED       format A19 wrap
col LAST_MODIFIED format A19 wrap

select NAME, CREATED, LAST_MODIFIED, DESCRIPTION, TYPE, STATUS
  from DBA_SQL_PROFILES
  where lower(STATUS) = 'enabled';

prompt
prompt
prompt * Checking for SQL Access Advisor and SQL Tuning Advisor tasks
SET LINESIZE 340

select
    TASK_ID             ,
    OWNER               ,
    TASK_NAME           ,
    DESCRIPTION         ,
    ADVISOR_NAME        ,
    CREATED             ,
    LAST_MODIFIED       ,
    PARENT_TASK_ID      ,
    EXECUTION_START     ,
    EXECUTION_END       ,
    STATUS              ,
    SOURCE              ,
    HOW_CREATED
  from DBA_ADVISOR_TASKS
  where ADVISOR_NAME in ('SQL Tuning Advisor', 'SQL Access Advisor')
    and not (OWNER='SYS' and TASK_NAME='SYS_AUTO_SQL_TUNING_TASK' and DESCRIPTION='Automatic SQL Tuning Task') /* created by default */
  order by CREATED;

prompt If rows are returned, then TUNING PACK is in use
SET LINESIZE 200

prompt
prompt
prompt * Checking for SQL Tuning Sets

select
      ID                as SQLSET_ID   ,
      NAME              as SQLSET_NAME ,
      OWNER             as SQLSET_OWNER,
      CREATED        ,
      LAST_MODIFIED  ,
      STATEMENT_COUNT,
      DESCRIPTION
  from DBA_SQLSET
  order by ID;

prompt If rows are returned, then TUNING PACK or REAL APPLICATION TESTING license is needed - applicable only for Standard Editions

prompt
prompt * Gathering details about SQL Tuning Sets references

select
      SQLSET_ID   ,
      SQLSET_NAME ,
      SQLSET_OWNER,
      ID          ,
      OWNER       ,
      CREATED     ,
      DESCRIPTION
  from DBA_SQLSET_REFERENCES
  order by SQLSET_ID, OWNER, DESCRIPTION, ID;

PROMPT If rows are returned, then TUNING PACK or REAL APPLICATION TESTING license is needed - applicable only for Standard Editions


PROMPT
PROMPT
PROMPT *** AUDIT VAULT
PROMPT =====================================================================*
PROMPT
PROMPT NOTE: "Audit Vault Server" and "Audit Vault Collection Agent"
PROMPT .      are standalone products
PROMPT .      and not Enterprise Edition Options

SET HEADING OFF
SET FEEDBACK OFF

PROMPT
PROMPT CHECKING TO SEE IF AUDIT VAULT SCHEMAS ARE INSTALLED...

select decode(upper(max(username)), 'AVSYS', 'Audit Vault Schema AVSYS exists', 'Audit Vault schema AVSYS does not exist')
  from dba_users where UPPER(username)='AVSYS';

PROMPT
PROMPT If AVSYS schema exist,
PROMPT Then AUDIT VAULT is installed and being used.

PROMPT
PROMPT
PROMPT *** CONTENT DATABASE and RECORDS DATABASE
PROMPT ======================================================================

PROMPT
PROMPT NOTE: Content Database and Records Database
PROMPT .     are currently components of WebCenter Content
PROMPT .     and not Enterprise Edition Options

PROMPT
PROMPT CHECKING TO SEE IF SCHEMA FOR BOTH CONTENT and RECORDS DATABASE IS INSTALLED...

SET HEADING OFF
SET FEEDBACK OFF

select decode(upper(max(username)), 'CONTENT', 'CONTENT schema exist', 'CONTENT schema does not exist')
  from dba_users where UPPER(username)='CONTENT';

SET HEADING ON
SET FEEDBACK ON
PROMPT
PROMPT CHECKING TO SEE IF CONTENT DATABASE IS BEING USED...
PROMPT

SELECT (Count(*) - 9004) "ODM_Document Customer Objects"
FROM odm_document;

PROMPT If ODM_DOCUMENT table exist and number of objects are more than
PROMPT or equal to 1 then CONTENT DATABASE is installed and being used.
PROMPT
PROMPT
PROMPT CHECKING TO SEE IF RECORDS DATABASE IS BEING USED...
PROMPT

SELECT Count(*) "ODM_RECORD Customer Objects"
FROM odm_record;

PROMPT If ODM_RECORD table exist and number of objects are more than
PROMPT or equal to 1 then RECORDS DATABASE is installed and being used.


PROMPT
PROMPT
PROMPT *** OWB (ORACLE WAREHOUSE BUILDER)
PROMPT =====================================================================*

PROMPT CHECKING IF THERE ARE OWB REPOSITORIES ON THE DATABASE INSTANCE
PROMPT

DECLARE

  CURSOR schema_array IS
  SELECT owner
  FROM dba_tables WHERE table_name = 'CMPSYSCLASSES';

  c_installed_ver   integer;
  rows_processed    integer;
  v_schema          dba_tables.owner%TYPE;
  v_schema_cnt      integer;
  v_version         varchar2(15);

BEGIN
  OPEN schema_array;
  c_installed_ver := dbms_sql.open_cursor;

  <<owb_schema_loop>>
  LOOP -- For each valid schema...
    FETCH schema_array INTO v_schema;
    EXIT WHEN schema_array%notfound;

    --Determine if current schema is valid (contains CMPInstallation_V view)
    dbms_sql.parse(c_installed_ver,'select installedversion from '|| v_schema || '.CMPInstallation_v where name = ''Oracle Warehouse Builder''',dbms_sql.native);
    dbms_sql.define_column(c_installed_ver, 1, v_version, 15);

    rows_processed:=dbms_sql.execute ( c_installed_ver );

    loop -- Find OWB version.
      if dbms_sql.fetch_rows(c_installed_ver) > 0 then
        dbms_sql.column_value (c_installed_ver, 1, v_version);
        v_schema_cnt := v_schema_cnt + 1;

        dbms_output.put_line ('.');
        dbms_output.put_line ('Schema '||v_schema||' contains a version '||v_version||' repository');
      else
        exit;
      end if;
    end loop;
  end loop;
END;
/
PROMPT
PROMPT If no repository is found, OWB is not in use.
PROMPT


PROMPT
PROMPT END OF READABLE SECTION
PROMPT
PROMPT
PROMPT *****************************************************
PROMPT *****************************************************
PROMPT *****************************************************
PROMPT *****                                           *****
PROMPT *****      The section below is used            *****
PROMPT *****      for automatic processing.            *****
PROMPT *****                                           *****
PROMPT *****************************************************
PROMPT *****************************************************
PROMPT *****************************************************
PROMPT
PROMPT
PROMPT
PROMPT

-------------------------------------------
-------------------------------------------
-- Second stage, output for GREP command --
-------------------------------------------
-------------------------------------------

SET HEADING OFF
SET FEEDBACK OFF
SET LINESIZE 500

prompt &&GREP_PREFIX.,REVIEW_LITE,VERSION,,,&SCRIPT_RELEASE.,


-- V$VERSION - DB Version
-------------------------
define OPTION_NAME=V$VERSION
define OPTION_QUERY=NULL
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint
select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  FROM V$VERSION;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
        BANNER           ||'",'
  FROM V$VERSION;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


define OPTION_NAME=V$VERSION
define OPTION_QUERY=BANNER_FULL
define OPTION_QUERY_COLS=BANNER_FULL,RELEASE_UPDATE_REVISION
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint
select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from (
    select
              replace(replace(replace(        BANNER_FULL         , chr(10), '[LF]'), chr(13), '[CR]'), '"', '''')              as BANNER_FULL,
      replace(replace(replace(replace(replace(BANNER_FULL, BANNER), chr(10)        ), chr(13)        ), '"'      ), 'Version ') as RELEASE_UPDATE_REVISION
      from V$VERSION
);

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
                replace(replace(replace(        BANNER_FULL         , chr(10), '[LF]'), chr(13), '[CR]'), '"', '''')                || '","'||
        replace(replace(replace(replace(replace(BANNER_FULL, BANNER), chr(10)        ), chr(13)        ), '"'      ), 'Version ')   || '",'
  from V$VERSION;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


-- V$OPTION - DB Options Installed
----------------------------------
define OPTION_NAME=V$OPTION
define OPTION_QUERY=NULL
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint
select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  FROM V$OPTION;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
        PARAMETER    ||'","'||
        VALUE        ||'",'
  FROM V$OPTION;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


-- 10g DBA_FEATURE_USAGE_STATISTICS (10g and higher)
----------------------------------------------------
define OPTION_NAME=DBA_FEATURE_USAGE_STATISTICS
define OPTION_QUERY=10g
define OPTION_QUERY_COLS=NAME,VERSION,DETECTED_USAGES,TOTAL_SAMPLES,CURRENTLY_USED,FIRST_USAGE_DATE,LAST_USAGE_DATE,LAST_SAMPLE_DATE,SAMPLE_INTERVAL,DBID,AUX_COUNT
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint
select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  FROM DBA_FEATURE_USAGE_STATISTICS;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
        NAME               || '","'||
        VERSION            || '","'||
        DETECTED_USAGES    || '","'||
        TOTAL_SAMPLES      || '","'||
        CURRENTLY_USED     || '","'||
        FIRST_USAGE_DATE   || '","'||
        LAST_USAGE_DATE    || '","'||
        LAST_SAMPLE_DATE   || '","'||
        SAMPLE_INTERVAL    || '",' ||
        DBID               ||  ',' ||
        AUX_COUNT          ||  ','
  FROM DBA_FEATURE_USAGE_STATISTICS;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


-- Collect DBA_FEATURE_USAGE_STATISTICS.FEATURE_INFO CLOB column
----------------------------------------------------------------
define OPTION_NAME=DBA_FEATURE_USAGE_STATISTICS
define OPTION_QUERY=FEATURE_INFO
define OPTION_QUERY_COLS=FEATURE_INFO,NAME,VERSION
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from DBA_FEATURE_USAGE_STATISTICS
  where FEATURE_INFO is not null
  ;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

SET LINESIZE 1500
select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
      replace(replace(replace(to_char(substr(FEATURE_INFO, 1, 1000)), chr(10), '[LF]'), chr(13), '[CR]'),'"','''') || '","' ||
      NAME                          || '","' ||
      VERSION                       || '",'  ||
      DBID                          || ','
  from DBA_FEATURE_USAGE_STATISTICS
  where FEATURE_INFO is not null
  order by 1;
SET LINESIZE 500

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


-- DBA_REGISTRY (9i_r2 and higher)
----------------------------------
define OPTION_NAME=DBA_REGISTRY
define OPTION_QUERY=>=9i_r2
define OPTION_QUERY_COLS=COMP_NAME,VERSION,STATUS,MODIFIED,SCHEMA
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint
select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from DBA_REGISTRY;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        '"' || COMP_NAME || '",' || VERSION || ',' || STATUS || ',' || MODIFIED || ',' || SCHEMA || ','
  from DBA_REGISTRY;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


-- GV$PARAMETER
--------------------------------------------
define OPTION_NAME=GV$PARAMETER
define OPTION_QUERY=NULL
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint
select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from GV$PARAMETER
  where  upper(NAME) like '%CPU_COUNT%'
      or upper(NAME) like '%FAL_CLIENT%'
      or upper(NAME) like '%FAL_SERVER%'
      or upper(NAME) like '%CLUSTER%'
      or upper(NAME) like '%CONTROL_MANAGEMENT_PACK_ACCESS%'
      or upper(NAME) like '%ENABLE_DDL_LOGGING%'
      or upper(NAME) like '%COMPATIBLE%'
      or upper(NAME) like '%LOG_ARCHIVE_DEST%'
      or upper(NAME) like '%O7_DICTIONARY_ACCESSIBILITY%'  -- for troubleshooting access privileges issues
      or upper(NAME) like '%ENABLE_PLUGGABLE_DATABASE%'
      or upper(NAME) like '%INMEMORY%'
      or upper(NAME) like '%DB_UNIQUE_NAME%'
      or upper(NAME) like '%LOG_ARCHIVE_CONFIG%'
      or upper(NAME) like '%HEAT_MAP%'
      or upper(NAME) like '%SPATIAL_VECTOR_ACCELERATION%'
      or upper(NAME) like '%ENCRYPT_NEW_TABLESPACES%'
  ;

SET LINESIZE 5000
select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
        INST_ID      ||'","'||
        NAME         ||'","'||
        replace(VALUE,'"','''') ||'","'||
        ISDEFAULT    ||'","'||
        DESCRIPTION  ||'",'
  from GV$PARAMETER
  where  upper(NAME) like '%CPU_COUNT%'
      or upper(NAME) like '%FAL_CLIENT%'
      or upper(NAME) like '%FAL_SERVER%'
      or upper(NAME) like '%CLUSTER%'
      or upper(NAME) like '%CONTROL_MANAGEMENT_PACK_ACCESS%'
      or upper(NAME) like '%ENABLE_DDL_LOGGING%'
      or upper(NAME) like '%COMPATIBLE%'
      or upper(NAME) like '%LOG_ARCHIVE_DEST%'
      or upper(NAME) like '%O7_DICTIONARY_ACCESSIBILITY%'  -- for troubleshooting access privileges issues
      or upper(NAME) like '%ENABLE_PLUGGABLE_DATABASE%'
      or upper(NAME) like '%INMEMORY%'
      or upper(NAME) like '%DB_UNIQUE_NAME%'
      or upper(NAME) like '%LOG_ARCHIVE_CONFIG%'
      or upper(NAME) like '%HEAT_MAP%'
      or upper(NAME) like '%SPATIAL_VECTOR_ACCELERATION%'
      or upper(NAME) like '%ENCRYPT_NEW_TABLESPACES%'
  order by NAME, INST_ID;
SET LINESIZE 500

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


-- Standby Configuration
----------------------------------
define OPTION_NAME=STANDBY_CONFIG
define OPTION_QUERY=V$DATAGUARD_CONFIG
define OPTION_QUERY_COLS=DB_UNIQUE_NAME
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from V$DATAGUARD_CONFIG;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        '"' || DB_UNIQUE_NAME || '",'
  from V$DATAGUARD_CONFIG;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


define OPTION_NAME=STANDBY_CONFIG
define OPTION_QUERY=V$ARCHIVE_DEST_STATUS
define OPTION_QUERY_COLS=DEST_ID,DEST_NAME,STATUS,TYPE,DATABASE_MODE,RECOVERY_MODE,PROTECTION_MODE,DESTINATION,DB_UNIQUE_NAME
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from V$ARCHIVE_DEST_STATUS
  where TYPE!='LOCAL'
  ;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

SET LINESIZE 5000
select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        DEST_ID        ||','||
        DEST_NAME      ||','||
        STATUS         ||','||
        TYPE           ||','||
        DATABASE_MODE  ||','||
        RECOVERY_MODE  ||','||
        PROTECTION_MODE||',"'||
        DESTINATION    ||'",'||
        DB_UNIQUE_NAME ||','
  from V$ARCHIVE_DEST_STATUS
  where TYPE!='LOCAL'
  order by DEST_ID;
SET LINESIZE 500

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);



-- *** PARTITIONING
-- ====================================================================
define OPTION_NAME=PARTITIONING
define OPTION_QUERY=PARTITIONED_SEGMENTS
define OPTION_QUERY_COLS=OWNER,SEGMENT_TYPE,SEGMENT_NAME,MIN_CREATED,MIN_LAST_DLL_TIME
define OCOUNT=-942

col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(distinct OWNER||','||OBJECT_TYPE||','||OBJECT_NAME)))) as OCOUNT
  FROM DBA_OBJECTS
  WHERE OBJECT_TYPE LIKE '%PARTITION%';

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
from (
select distinct
        OWNER||','||OBJECT_TYPE||','||OBJECT_NAME||','||min(CREATED)||','||min(LAST_DDL_TIME)||','
  from  DBA_OBJECTS
  where OBJECT_TYPE LIKE '%PARTITION%'
  group by OWNER, OBJECT_TYPE, OBJECT_NAME
     );


select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select distinct
        '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        OWNER||','||OBJECT_TYPE||','||OBJECT_NAME||','||min(CREATED)||','||min(LAST_DDL_TIME)||','
  from  DBA_OBJECTS
  where OBJECT_TYPE LIKE '%PARTITION%'
  group by OWNER, OBJECT_TYPE, OBJECT_NAME
  ;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


-- List of partitioned segments to be ignored because they are automatically created with Analytical Workspaces
define OPTION_NAME=PARTITIONING
define OPTION_QUERY=OLAP_AWS_SEGMENTS
define OPTION_QUERY_COLS=AW_OWNER,AW_NAME,AW_VERSION,SEGMENT_TYPE,OWNER,SEGMENT_NAME,TABLE_NAME
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from (
select distinct
       c.owner as aw_owner,
       c.aw_name,
       'not_collected' as aw_version,
       d.object_type,
       d.owner,
       d.object_name,
       d.object_name as table_name
  from dba_aws      c
  join dba_objects  d on c.owner = d.owner and 'AW$'||c.aw_name = d.object_name
  where d.object_type like '%PARTITION%'
union all
select distinct
       e.owner as aw_owner,
       e.aw_name,
       'not_collected' as aw_version,
       g.object_type,
       g.owner,
       g.object_name,
       f.table_name
  from dba_aws            e
  join dba_lobs           f on e.owner = f.owner and 'AW$'||e.aw_name = f.table_name
  join dba_objects        g on f.owner = g.owner and f.segment_name = g.object_name
  where g.object_type like '%PARTITION%'
union all
select distinct
       e.owner as aw_owner,
       e.aw_name,
       'not_collected' as aw_version,
       g.object_type,
       g.owner,
       g.object_name,
       f.table_name
  from dba_aws            e
  join dba_indexes        f on e.owner = f.table_owner and 'AW$'||e.aw_name = f.table_name
  join dba_objects        g on f.owner = g.owner and f.index_name = g.object_name
  where g.object_type like '%PARTITION%'
  order by owner, aw_name, object_type, object_name
);

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
       aw_owner      ||','||
       aw_name       ||','||
       aw_version    ||','|| -- available only starting with version 11.1
       object_type   ||','||
       owner         ||','||
       object_name   ||','||
       table_name    ||','
from (
select distinct
       c.owner as aw_owner,
       c.aw_name,
       'not_collected' as aw_version,
       d.object_type,
       d.owner,
       d.object_name,
       d.object_name as table_name
  from dba_aws      c
  join dba_objects  d on c.owner = d.owner and 'AW$'||c.aw_name = d.object_name
  where d.object_type like '%PARTITION%'
union all
select distinct
       e.owner as aw_owner,
       e.aw_name,
       'not_collected' as aw_version,
       g.object_type,
       g.owner,
       g.object_name,
       f.table_name
  from dba_aws            e
  join dba_lobs           f on e.owner = f.owner and 'AW$'||e.aw_name = f.table_name
  join dba_objects        g on f.owner = g.owner and f.segment_name = g.object_name
  where g.object_type like '%PARTITION%'
union all
select distinct
       e.owner as aw_owner,
       e.aw_name,
       'not_collected' as aw_version,
       g.object_type,
       g.owner,
       g.object_name,
       f.table_name
  from dba_aws            e
  join dba_indexes        f on e.owner = f.table_owner and 'AW$'||e.aw_name = f.table_name
  join dba_objects        g on f.owner = g.owner and f.index_name = g.object_name
  where g.object_type like '%PARTITION%'
  order by owner, aw_name, object_type, object_name
);


select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


--Partitioned objects on RECYCLEBIN
define OPTION_NAME=PARTITIONING
define OPTION_QUERY=PARTITION_OBJ_RECYCLEBIN
define OPTION_QUERY_COLS=OWNER,ORIGINAL_NAME,OBJECT_NAME,TYPE,CREATETIME,DROPTIME,PARTITION_NAME,SPACE,CAN_UNDROP
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
from (
  select OWNER, ORIGINAL_NAME, OBJECT_NAME, TYPE, CREATETIME, DROPTIME, PARTITION_NAME, SPACE, CAN_UNDROP
    from DBA_RECYCLEBIN
    where TYPE not like '%Partition%'
      and (OWNER, OBJECT_NAME) in (select OWNER, OBJECT_NAME from DBA_RECYCLEBIN where TYPE like '%Partition%')
  union all
  select OWNER, ORIGINAL_NAME, OBJECT_NAME, TYPE, CREATETIME, DROPTIME, PARTITION_NAME, SPACE, CAN_UNDROP
    from DBA_RECYCLEBIN
    where TYPE like '%Partition%'
);

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        OWNER           ||','||
        ORIGINAL_NAME   ||','||
        OBJECT_NAME     ||','||
        TYPE            ||','||
        CREATETIME      ||','||
        DROPTIME        ||','||
        PARTITION_NAME  ||','||
        SPACE           ||','||
        CAN_UNDROP      ||','
  from (
  select OWNER, ORIGINAL_NAME, OBJECT_NAME, TYPE, CREATETIME, DROPTIME, PARTITION_NAME, SPACE, CAN_UNDROP
    from DBA_RECYCLEBIN
    where TYPE not like '%Partition%'
      and (OWNER, OBJECT_NAME) in (select OWNER, OBJECT_NAME from DBA_RECYCLEBIN where TYPE like '%Partition%')
  union all
  select OWNER, ORIGINAL_NAME, OBJECT_NAME, TYPE, CREATETIME, DROPTIME, PARTITION_NAME, SPACE, CAN_UNDROP
    from DBA_RECYCLEBIN
    where TYPE like '%Partition%'
  );

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


--Partitioned objects generated by flashback archives
define OPTION_NAME=PARTITIONING
define OPTION_QUERY=DBA_FLASHBACK_ARCHIVE_TABLES+INDEXES+LOBS
define OPTION_QUERY_COLS=ARCHIVE_TABLE_OWNER,TABLE_NAME,ARCHIVE_TABLE_NAME,OBJECT_TYPE,OWNER,OBJECT_NAME
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from (
select distinct
       c.owner_name as archive_table_owner,
       c.table_name,
       c.archive_table_name,
       d.object_type,
       d.owner,
       d.object_name
  from dba_flashback_archive_tables  c
  join dba_objects  d on c.owner_name = d.owner and c.archive_table_name = d.object_name
union all
select distinct
       e.owner_name as archive_table_owner,
       e.table_name,
       e.archive_table_name,
       g.object_type,
       g.owner,
       g.object_name
  from dba_flashback_archive_tables  e
  join dba_lobs           f on e.owner_name = f.owner and e.archive_table_name = f.table_name
  join dba_objects        g on f.owner      = g.owner and f.segment_name       = g.object_name
union all
select distinct
       e.owner_name as archive_table_owner,
       e.table_name,
       e.archive_table_name,
       g.object_type,
       g.owner,
       g.object_name
  from dba_flashback_archive_tables  e
  join dba_indexes        f on e.owner_name = f.table_owner and e.archive_table_name = f.table_name
  join dba_objects        g on f.owner      = g.owner       and f.index_name         = g.object_name
);

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
       archive_table_owner   ||','||
       table_name            ||','||
       archive_table_name    ||','||
       object_type           ||','||
       owner                 ||','||
       object_name           ||','
  from (
select distinct
       c.owner_name as archive_table_owner,
       c.table_name,
       c.archive_table_name,
       d.object_type,
       d.owner,
       d.object_name
  from dba_flashback_archive_tables  c
  join dba_objects  d on c.owner_name = d.owner and c.archive_table_name = d.object_name
union all
select distinct
       e.owner_name as archive_table_owner,
       e.table_name,
       e.archive_table_name,
       g.object_type,
       g.owner,
       g.object_name
  from dba_flashback_archive_tables  e
  join dba_lobs           f on e.owner_name = f.owner and e.archive_table_name = f.table_name
  join dba_objects        g on f.owner      = g.owner and f.segment_name       = g.object_name
union all
select distinct
       e.owner_name as archive_table_owner,
       e.table_name,
       e.archive_table_name,
       g.object_type,
       g.owner,
       g.object_name
  from dba_flashback_archive_tables  e
  join dba_indexes        f on e.owner_name = f.table_owner and e.archive_table_name = f.table_name
  join dba_objects        g on f.owner      = g.owner       and f.index_name         = g.object_name
) order by 1;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


--Partitioned objects generated by change data capture
define OPTION_NAME=PARTITIONING
define OPTION_QUERY=ALL_CHANGE_TABLES
define OPTION_QUERY_COLS=CHANGE_SET_NAME,SOURCE_SCHEMA_NAME,SOURCE_TABLE_NAME,CHANGE_TABLE_SCHEMA,CHANGE_TABLE_NAME,CREATED
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from (
select
        CHANGE_SET_NAME      ||'","'||
        SOURCE_SCHEMA_NAME   ||'","'||
        SOURCE_TABLE_NAME    ||'","'||
        CHANGE_TABLE_SCHEMA  ||'","'||
        CHANGE_TABLE_NAME    ||'",'||
        CREATED              ||','
  from SYS.CDC_CHANGE_TABLES$
);

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
        CHANGE_SET_NAME      ||'","'||
        SOURCE_SCHEMA_NAME   ||'","'||
        SOURCE_TABLE_NAME    ||'","'||
        CHANGE_TABLE_SCHEMA  ||'","'||
        CHANGE_TABLE_NAME    ||'",'||
        CREATED              ||','
  from SYS.CDC_CHANGE_TABLES$
order by 1;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


define OPTION_NAME=PARTITIONING
define OPTION_QUERY=ALL_CHANGE_TABLES+INDEXES+LOBS
define OPTION_QUERY_COLS=CHANGE_TABLE_SCHEMA,CHANGE_TABLE_NAME,OBJECT_TYPE,OWNER,OBJECT_NAME
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from (
select distinct
       c.CHANGE_TABLE_SCHEMA,
       c.CHANGE_TABLE_NAME,
       d.OBJECT_TYPE,
       d.OWNER,
       d.OBJECT_NAME
  from SYS.CDC_CHANGE_TABLES$ c
  join DBA_OBJECTS            d on c.CHANGE_TABLE_SCHEMA = d.OWNER and c.CHANGE_TABLE_NAME = d.OBJECT_NAME
union all
select distinct
       e.CHANGE_TABLE_SCHEMA,
       e.CHANGE_TABLE_NAME,
       g.OBJECT_TYPE,
       g.OWNER,
       g.OBJECT_NAME
  from SYS.CDC_CHANGE_TABLES$ e
  join DBA_LOBS               f on e.CHANGE_TABLE_SCHEMA = f.OWNER and e.CHANGE_TABLE_NAME = f.TABLE_NAME
  join DBA_OBJECTS            g on f.OWNER               = g.OWNER and f.segment_name      = g.OBJECT_NAME
union all
select distinct
       e.CHANGE_TABLE_SCHEMA,
       e.CHANGE_TABLE_NAME,
       g.OBJECT_TYPE,
       g.OWNER,
       g.OBJECT_NAME
  from SYS.CDC_CHANGE_TABLES$ e
  join DBA_INDEXES            f on e.CHANGE_TABLE_SCHEMA = f.TABLE_OWNER and e.CHANGE_TABLE_NAME = f.TABLE_NAME
  join DBA_OBJECTS            g on f.OWNER               = g.OWNER       and f.INDEX_NAME        = g.OBJECT_NAME
);

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
       CHANGE_TABLE_SCHEMA   ||'","'||
       CHANGE_TABLE_NAME     ||'","'||
       OBJECT_TYPE           ||'","'||
       OWNER                 ||'","'||
       OBJECT_NAME           ||'",'
  from (
select distinct
       c.CHANGE_TABLE_SCHEMA,
       c.CHANGE_TABLE_NAME,
       d.OBJECT_TYPE,
       d.OWNER,
       d.OBJECT_NAME
  from SYS.CDC_CHANGE_TABLES$ c
  join DBA_OBJECTS            d on c.CHANGE_TABLE_SCHEMA = d.OWNER and c.CHANGE_TABLE_NAME = d.OBJECT_NAME
union all
select distinct
       e.CHANGE_TABLE_SCHEMA,
       e.CHANGE_TABLE_NAME,
       g.OBJECT_TYPE,
       g.OWNER,
       g.OBJECT_NAME
  from SYS.CDC_CHANGE_TABLES$ e
  join DBA_LOBS               f on e.CHANGE_TABLE_SCHEMA = f.OWNER and e.CHANGE_TABLE_NAME = f.TABLE_NAME
  join DBA_OBJECTS            g on f.OWNER               = g.OWNER and f.segment_name      = g.OBJECT_NAME
union all
select distinct
       e.CHANGE_TABLE_SCHEMA,
       e.CHANGE_TABLE_NAME,
       g.OBJECT_TYPE,
       g.OWNER,
       g.OBJECT_NAME
  from SYS.CDC_CHANGE_TABLES$ e
  join DBA_INDEXES            f on e.CHANGE_TABLE_SCHEMA = f.TABLE_OWNER and e.CHANGE_TABLE_NAME = f.TABLE_NAME
  join DBA_OBJECTS            g on f.OWNER               = g.OWNER       and f.INDEX_NAME        = g.OBJECT_NAME
) order by 1;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


define OPTION_NAME=PARTITIONING
define OPTION_QUERY=ALL_CHANGE_SETS_QUEUE_TABLES+INDEXES+LOBS
define OPTION_QUERY_COLS=CHANGE_SET_NAME,PUBLISHER,QUEUE_TABLE_NAME,OBJECT_TYPE,OWNER,OBJECT_NAME
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from (
select distinct
       c.SET_NAME as CHANGE_SET_NAME,
       c.PUBLISHER,
       c.QUEUE_TABLE_NAME,
       d.OBJECT_TYPE,
       d.OWNER,
       d.OBJECT_NAME
  from SYS.CDC_CHANGE_SETS$   c
  join DBA_OBJECTS            d on c.PUBLISHER = d.OWNER and c.QUEUE_TABLE_NAME = d.OBJECT_NAME
union all
select distinct
       e.SET_NAME as CHANGE_SET_NAME,
       e.PUBLISHER,
       e.QUEUE_TABLE_NAME,
       g.OBJECT_TYPE,
       g.OWNER,
       g.OBJECT_NAME
  from SYS.CDC_CHANGE_SETS$   e
  join DBA_LOBS               f on e.PUBLISHER = f.OWNER and e.QUEUE_TABLE_NAME = f.TABLE_NAME
  join DBA_OBJECTS            g on f.OWNER     = g.OWNER and f.segment_name     = g.OBJECT_NAME
union all
select distinct
       e.SET_NAME as CHANGE_SET_NAME,
       e.PUBLISHER,
       e.QUEUE_TABLE_NAME,
       g.OBJECT_TYPE,
       g.OWNER,
       g.OBJECT_NAME
  from SYS.CDC_CHANGE_SETS$   e
  join DBA_INDEXES            f on e.PUBLISHER = f.TABLE_OWNER and e.QUEUE_TABLE_NAME = f.TABLE_NAME
  join DBA_OBJECTS            g on f.OWNER     = g.OWNER       and f.INDEX_NAME       = g.OBJECT_NAME
);

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
       CHANGE_SET_NAME       ||'","'||
       PUBLISHER             ||'","'||
       QUEUE_TABLE_NAME      ||'","'||
       OBJECT_TYPE           ||'","'||
       OWNER                 ||'","'||
       OBJECT_NAME           ||'",'
  from (
select distinct
       c.SET_NAME as CHANGE_SET_NAME,
       c.PUBLISHER,
       c.QUEUE_TABLE_NAME,
       d.OBJECT_TYPE,
       d.OWNER,
       d.OBJECT_NAME
  from SYS.CDC_CHANGE_SETS$   c
  join DBA_OBJECTS            d on c.PUBLISHER = d.OWNER and c.QUEUE_TABLE_NAME = d.OBJECT_NAME
union all
select distinct
       e.SET_NAME as CHANGE_SET_NAME,
       e.PUBLISHER,
       e.QUEUE_TABLE_NAME,
       g.OBJECT_TYPE,
       g.OWNER,
       g.OBJECT_NAME
  from SYS.CDC_CHANGE_SETS$   e
  join DBA_LOBS               f on e.PUBLISHER = f.OWNER and e.QUEUE_TABLE_NAME = f.TABLE_NAME
  join DBA_OBJECTS            g on f.OWNER     = g.OWNER and f.segment_name     = g.OBJECT_NAME
union all
select distinct
       e.SET_NAME as CHANGE_SET_NAME,
       e.PUBLISHER,
       e.QUEUE_TABLE_NAME,
       g.OBJECT_TYPE,
       g.OWNER,
       g.OBJECT_NAME
  from SYS.CDC_CHANGE_SETS$   e
  join DBA_INDEXES            f on e.PUBLISHER = f.TABLE_OWNER and e.QUEUE_TABLE_NAME = f.TABLE_NAME
  join DBA_OBJECTS            g on f.OWNER     = g.OWNER       and f.INDEX_NAME       = g.OBJECT_NAME
) order by 1;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


--Partitioned objects generated by Transactional Event Queues
define OPTION_NAME=PARTITIONING
define OPTION_QUERY=TEQ
define OPTION_QUERY_COLS=OWNER,SEGMENT_TYPE,SEGMENT_NAME
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
from (
select distinct
        OWNER           ||','||
        OBJECT_TYPE     ||','||
        OBJECT_NAME     ||','
  from DBA_OBJECTS
  where OBJECT_TYPE like '%PARTITION%'
    and OBJECT_ID in
       (select o.OBJECT_ID
          from DBA_OBJECTS o,
            (select t.NAME, o.OBJ# OBJ
               from SYSTEM.AQ$_QUEUES q, SYSTEM.AQ$_QUEUE_TABLES t, SYS.OBJ$ o
               where q.TABLE_OBJNO = t.OBJNO
                 and t.NAME = o.NAME
                 and o.TYPE# = 2
                 and q.SHARDED >= 1
             union
             select to_char(o.OBJ#), o.OBJ# OBJ
               from SYSTEM.AQ$_QUEUES q, SYSTEM.AQ$_QUEUE_TABLES t, SYS.OBJ$ o
               where q.TABLE_OBJNO = t.OBJNO
                 and (t.NAME = o.NAME or 'AQ$_' || t.NAME || '_L' = o.NAME or 'AQ$_' || t.NAME || '_X' = o.NAME)
                 and o.TYPE# = 2
                 and q.SHARDED >= 1
            ) sq
          where o.OBJECT_NAME like '%' || sq.NAME || '%'
       )
  group by OWNER, OBJECT_TYPE, OBJECT_NAME
);

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select distinct '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        OWNER           ||','||
        OBJECT_TYPE     ||','||
        OBJECT_NAME     ||','
  from DBA_OBJECTS
  where OBJECT_TYPE like '%PARTITION%'
    and OBJECT_ID in
       (select o.OBJECT_ID
          from DBA_OBJECTS o,
            (select t.NAME, o.OBJ# OBJ
               from SYSTEM.AQ$_QUEUES q, SYSTEM.AQ$_QUEUE_TABLES t, SYS.OBJ$ o
               where q.TABLE_OBJNO = t.OBJNO
                 and t.NAME = o.NAME
                 and o.TYPE# = 2
                 and q.SHARDED >= 1
             union
             select to_char(o.OBJ#), o.OBJ# OBJ
               from SYSTEM.AQ$_QUEUES q, SYSTEM.AQ$_QUEUE_TABLES t, SYS.OBJ$ o
               where q.TABLE_OBJNO = t.OBJNO
                 and (t.NAME = o.NAME or 'AQ$_' || t.NAME || '_L' = o.NAME or 'AQ$_' || t.NAME || '_X' = o.NAME)
                 and o.TYPE# = 2
                 and q.SHARDED >= 1
            ) sq
          where o.OBJECT_NAME like '%' || sq.NAME || '%'
       )
  group by OWNER, OBJECT_TYPE, OBJECT_NAME
;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


define OPTION_NAME=PARTITIONING
define OPTION_QUERY=SCHEMA_VERSION_REGISTRY
define OPTION_QUERY_COLS=COMP_ID,COMP_NAME,MRC_NAME,MR_NAME,MR_TYPE,OWNER,VERSION,STATUS,UPGRADED,START_TIME,MODIFIED
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from SCHEMA_VERSION_REGISTRY;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
        COMP_ID     ||'","'||
        COMP_NAME   ||'","'||
        MRC_NAME    ||'","'||
        MR_NAME     ||'","'||
        MR_TYPE     ||'","'||
        OWNER       ||'","'||
        VERSION     ||'","'||
        STATUS      ||'","'||
        UPGRADED    ||'",'||
        START_TIME  || ','||
        MODIFIED    || ','
  from SCHEMA_VERSION_REGISTRY;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


-- Collect new 12.1 DBA_USERS column
define OPTION_NAME=PARTITIONING
define OPTION_QUERY=DBA_USERS.ORACLE_MAINTAINED
define OPTION_QUERY_COLS=USERNAME,ORACLE_MAINTAINED
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from DBA_USERS
  where UPPER(ORACLE_MAINTAINED) like 'Y%';

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
        USERNAME             ||'","'||
        ORACLE_MAINTAINED    ||'",'
  from DBA_USERS
  where UPPER(ORACLE_MAINTAINED) like 'Y%';

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


-- Collect new 12.2 DBA_USERS column
define OPTION_NAME=PARTITIONING
define OPTION_QUERY=DBA_USERS.IMPLICIT
define OPTION_QUERY_COLS=USERNAME,IMPLICIT
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from DBA_USERS
  where UPPER(IMPLICIT) like 'Y%';

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
        USERNAME             ||'","'||
        IMPLICIT             ||'",'
  from DBA_USERS
  where UPPER(IMPLICIT) like 'Y%';

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);



-- *** RAC (REAL APPLICATION CLUSTERS)
-- ====================================================================
define OPTION_NAME=RAC
define OPTION_QUERY=GV$INSTANCE
define OPTION_QUERY_COLS=INSTANCE_NAME,HOST_NAME,INST_ID,STATUS
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  FROM GV$INSTANCE;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        INSTANCE_NAME    ||','||
        HOST_NAME        ||','||
        INST_ID          ||','||
        STATUS           ||','
  FROM GV$INSTANCE;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);



-- *** MULTITENANT (introduced in 12c_r1)
-- ====================================================================
define OPTION_NAME=MULTITENANT
define OPTION_QUERY=V$CONTAINERS
define OPTION_QUERY_COLS=CDB,CON_ID,NAME,OPEN_MODE,OPEN_TIME,CONTAINER
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from V$CONTAINERS a, V$DATABASE b
  order by a.CON_ID;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        b.CDB            ||','||
        a.CON_ID         ||',"'||
        a.NAME           ||'",'||
        a.OPEN_MODE      ||','||
        a.OPEN_TIME      ||','||
        decode(a.CON_ID, 0, 'entire CDB or non-CDB', 1, 'ROOT', 2, 'SEED', 'PDB') ||','
  from V$CONTAINERS a, V$DATABASE b
  order by a.CON_ID;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);



-- *** ACTIVE DATA GUARD (introduced in 11.1)
-- ====================================================================
-- Checking for "Physical Standby with Real-time Query" feature usage
define OPTION_NAME=ACTIVE_DATA_GUARD
define OPTION_QUERY=11gr1
define OPTION_QUERY_COLS=COUNT,DBID,NAME,DB_UNIQUE_NAME,OPEN_MODE,DATABASE_ROLE,REMOTE_ARCHIVE,DATAGUARD_BROKER,GUARD_STATUS,PLATFORM_NAME
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from (
  select
        a.DEST_ID        ||','||
        a.DEST_NAME      ||','||
        a.STATUS         ||','||
        a.TYPE           ||','||
        a.DATABASE_MODE  ||','||
        a.RECOVERY_MODE  ||',"'||
        a.DESTINATION    ||'",'||
        a.DB_UNIQUE_NAME ||','||
        b.VALUE          ||','
  from V$ARCHIVE_DEST_STATUS a, V$PARAMETER b
  where b.NAME = 'compatible' and b.value like '1%' and b.value not like '10%'
    and a.RECOVERY_MODE like 'MANAGED%' and a.STATUS = 'VALID' and a.DATABASE_MODE = 'OPEN_READ-ONLY'
       );

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,&&OCOUNT.,'||
        a.DEST_ID        ||','||
        a.DEST_NAME      ||','||
        a.STATUS         ||','||
        a.TYPE           ||','||
        a.DATABASE_MODE  ||','||
        a.RECOVERY_MODE  ||',"'||
        a.DESTINATION    ||'",'||
        a.DB_UNIQUE_NAME ||','||
        b.VALUE          ||','
  from V$ARCHIVE_DEST_STATUS a, V$PARAMETER b
  where b.NAME = 'compatible' and b.value like '1%' and b.value not like '10%'
    and a.RECOVERY_MODE like 'MANAGED%' and a.STATUS = 'VALID' and a.DATABASE_MODE = 'OPEN_READ-ONLY'
  order by a.DEST_ID;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


define OPTION_NAME=ACTIVE_DATA_GUARD
define OPTION_QUERY=V$DATABASE
define OPTION_QUERY_COLS=DBID,NAME,DB_UNIQUE_NAME,OPEN_MODE,DATABASE_ROLE,REMOTE_ARCHIVE,DATAGUARD_BROKER,GUARD_STATUS,PLATFORM_NAME
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from V$DATABASE;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        DBID                || ',' ||
        NAME                || ',' ||
        DB_UNIQUE_NAME      || ',' ||
        OPEN_MODE           || ',"'||
        DATABASE_ROLE       ||'","'||
        REMOTE_ARCHIVE      ||'","'||
        DATAGUARD_BROKER    ||'","'||
        GUARD_STATUS        ||'","'||
        PLATFORM_NAME       ||'",' ||
        CREATED             || ',' ||
        CONTROLFILE_CREATED || ','
  from V$DATABASE;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


-- * Checking for "Fast Incremental Backup on Physical Standby" feature usage
define OPTION_NAME=ACTIVE_DATA_GUARD
define OPTION_QUERY=V$BLOCK_CHANGE_TRACKING
define OPTION_QUERY_COLS=DATABASE_ROLE,STATUS,FILENAME,BYTES
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from V$BLOCK_CHANGE_TRACKING a, V$DATABASE b
    where b.DATABASE_ROLE like 'PHYSICAL STANDBY'
      and a.STATUS = 'ENABLED'
;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        b.DATABASE_ROLE  ||','||
        a.STATUS         ||',"'||
        a.FILENAME       ||'",'||
        a.BYTES          ||','
  from V$BLOCK_CHANGE_TRACKING a, V$DATABASE b
    where b.DATABASE_ROLE like 'PHYSICAL STANDBY'
      and a.STATUS = 'ENABLED'
;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);



-- *** OLAP
-- ====================================================================
-- CUBES IN OLAPSYS.DBA$OLAP_CUBES
define OPTION_NAME=OLAP
define OPTION_QUERY=OLAPSYS.DBA$OLAP_CUBES
define OPTION_QUERY_COLS=OWNER,CUBE_NAME,DISPLAY_NAME
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  FROM  OLAPSYS.DBA$OLAP_CUBES;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
        OWNER         || '","'  ||
        CUBE_NAME     || '","'  ||
        DISPLAY_NAME  || '",'
  FROM  OLAPSYS.DBA$OLAP_CUBES;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


-- CUBES IN DBA_CUBES (introduced in 11.1)
define OPTION_NAME=OLAP
define OPTION_QUERY=DBA_CUBES
define OPTION_QUERY_COLS=OWNER,CUBE_NAME,AW_NAME
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  FROM  DBA_CUBES;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
        OWNER         || '","'  ||
        CUBE_NAME     || '","'  ||
        AW_NAME       || '",'
  FROM  DBA_CUBES;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


-- ANALYTIC WORKSPACES
define OPTION_NAME=OLAP
define OPTION_QUERY=ANALYTIC_WORKSPACES
define OPTION_QUERY_COLS=OWNER,AW_NUMBER,AW_NAME,PAGESPACES,GENERATIONS
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  FROM DBA_AWS;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        OWNER        ||','||
        AW_NUMBER    ||','||
        AW_NAME      ||','||
        PAGESPACES   ||','||
        GENERATIONS  ||','
  FROM DBA_AWS;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);



-- *** DATA MINING (ADVANCED ANALYTICS FEATURE)
-- ====================================================================

-- 9i
define OPTION_NAME=DATA_MINING
define OPTION_QUERY=09i.ODM_MINING_MODEL
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint
select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from ODM.ODM_MINING_MODEL;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        count(*) || ','
  from ODM.ODM_MINING_MODEL;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942);


-- 10gv1
define OPTION_NAME=DATA_MINING
define OPTION_QUERY=10gv1.DM$OBJECT
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint
select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from DMSYS.DM$OBJECT;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        count(*) || ','
  from DMSYS.DM$OBJECT;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942);


define OPTION_NAME=DATA_MINING
define OPTION_QUERY=10gv1.DM$MODEL
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint
select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from DMSYS.DM$MODEL;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        count(*) || ','
  from DMSYS.DM$MODEL;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942);


-- 10gv2
define OPTION_NAME=DATA_MINING
define OPTION_QUERY=10gv2.DM$P_MODEL
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint
select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from DMSYS.DM$P_MODEL;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        count(*) || ','
  from DMSYS.DM$P_MODEL;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942);


-- 11g
define OPTION_NAME=DATA_MINING
define OPTION_QUERY=11g.DM$P_MODEL
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint
select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from SYS.MODEL$;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        count(*) || ','
  from SYS.MODEL$;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942);


-- 11g and higher
define OPTION_NAME=DATA_MINING
define OPTION_QUERY=11g+.DBA_MINING_MODELS
define OPTION_QUERY_COLS=OWNER,MODEL_NAME,MINING_FUNCTION,ALGORITHM,CREATION_DATE,BUILD_DURATION,MODEL_SIZE
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from SYS.DBA_MINING_MODELS;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        OWNER           ||','||
        MODEL_NAME      ||','||
        MINING_FUNCTION ||',"'||
        ALGORITHM       ||'",'||
        CREATION_DATE   ||','||
        BUILD_DURATION  ||','||
        MODEL_SIZE      ||','
  from SYS.DBA_MINING_MODELS
  order by OWNER, MODEL_NAME
  ;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);



-- *** SPATIAL
-- ====================================================================
define OPTION_NAME=SPATIAL
define OPTION_QUERY=ALL_SDO_GEOM_METADATA
define OPTION_QUERY_COLS=SDO_OWNER,SDO_TABLE_NAME,SDO_COLUMN_NAME
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from MDSYS.SDO_GEOM_METADATA_TABLE;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        SDO_OWNER || ',' || SDO_TABLE_NAME || ',' || substr(SDO_COLUMN_NAME, 1, 250) || ','
  from MDSYS.SDO_GEOM_METADATA_TABLE;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


define OPTION_NAME=SPATIAL
define OPTION_QUERY=SDO_FEATURE_USAGE
define OPTION_QUERY_COLS=FEATURE_NAME,USED
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from MDSYS.SDO_FEATURE_USAGE;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
        FEATURE_NAME  || '","'  ||
        USED          || '",'
  from MDSYS.SDO_FEATURE_USAGE
  order by FEATURE_NAME;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);



-- *** LABEL SECURITY
-- ====================================================================
-- For DB versions < 12.1
define OPTION_NAME=LABEL_SECURITY
define OPTION_QUERY=LBAC$POLT_COUNT
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint
select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  FROM  LBACSYS.LBAC$POLT
  WHERE OWNER <> 'SA_DEMO';

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        count(*) ||','
  FROM  LBACSYS.LBAC$POLT
  WHERE OWNER <> 'SA_DEMO';

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942);

-- For DB versions >= 12.1
define OPTION_NAME=LABEL_SECURITY
define OPTION_QUERY=OLS$POLT_COUNT
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint
select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  FROM  LBACSYS.OLS$POLT
  WHERE OWNER <> 'SA_DEMO';

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        count(*) ||','
  FROM  LBACSYS.OLS$POLT
  WHERE OWNER <> 'SA_DEMO';

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942);



-- *** ADVANCED SECURITY
-- ====================================================================
-- Check for Column Encryption
define OPTION_NAME=ADVANCED_SECURITY
DEFINE OPTION_QUERY=COLUMN_ENCRYPTION
COL    OCOUNT new_val OCOUNT noprint
select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from DBA_ENCRYPTED_COLUMNS
  where OWNER || '#' || TABLE_NAME|| '#' || COLUMN_NAME not in
        (select OWNER || '#' || TABLE_NAME|| '#' || COLUMN_NAME from DBA_LOBS)  -- eliminate SecureFiles
  ;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
       OWNER || ',' || TABLE_NAME || ',' ||COLUMN_NAME || ','
  from DBA_ENCRYPTED_COLUMNS
  where OWNER || '#' || TABLE_NAME|| '#' || COLUMN_NAME not in
        (select OWNER || '#' || TABLE_NAME|| '#' || COLUMN_NAME from DBA_LOBS)  -- eliminate SecureFiles
  order by 1;

SELECT '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);

-- Check for Tablespace Encryption
define OPTION_NAME=ADVANCED_SECURITY
DEFINE OPTION_QUERY=TABLESPACE_ENCRYPTION
COL    OCOUNT new_val OCOUNT noprint
select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  FROM DBA_TABLESPACES
 WHERE ENCRYPTED ='YES';

SELECT '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
       TABLESPACE_NAME || ',' || ENCRYPTED ||','
  FROM DBA_TABLESPACES
 WHERE ENCRYPTED ='YES';

SELECT '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
       decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);

-- Check for SecureFiles Encryption
define OPTION_NAME=ADVANCED_SECURITY
define OPTION_QUERY=SECUREFILES_ENCRYPTION
define OPTION_QUERY_COLS=DATA_DICTIONARY_VIEW,TABLE_OWNER,TABLE_NAME,COLUMN_NAME,ENCRYPT,SECUREFILE
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from (
  select 'DBA_LOBS,'              || owner       ||','|| table_name ||','|| column_name ||',"'|| encrypt ||'","'|| securefile ||'",' as csv_cols
    from dba_lobs
    where encrypt not in ('NO', 'NONE')
  union all
  select 'DBA_LOB_PARTITIONS,'    || table_owner ||','|| table_name ||','|| column_name ||',"'|| encrypt ||'","'|| securefile ||'",' as csv_cols
    from dba_lob_partitions
    where encrypt not in ('NO', 'NONE')
  union all
  select 'DBA_LOB_SUBPARTITIONS,' || table_owner ||','|| table_name ||','|| column_name ||',"'|| encrypt ||'","'|| securefile ||'",' as csv_cols
    from dba_lob_subpartitions
    where encrypt not in ('NO', 'NONE')
  );

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
   csv_cols
  from (
  select 'DBA_LOBS,'              || owner       ||','|| table_name ||','|| column_name ||',"'|| encrypt ||'","'|| securefile ||'",' as csv_cols
    from dba_lobs
    where encrypt not in ('NO', 'NONE')
  union all
  select 'DBA_LOB_PARTITIONS,'    || table_owner ||','|| table_name ||','|| column_name ||',"'|| encrypt ||'","'|| securefile ||'",' as csv_cols
    from dba_lob_partitions
    where encrypt not in ('NO', 'NONE')
  union all
  select 'DBA_LOB_SUBPARTITIONS,' || table_owner ||','|| table_name ||','|| column_name ||',"'|| encrypt ||'","'|| securefile ||'",' as csv_cols
    from dba_lob_subpartitions
    where encrypt not in ('NO', 'NONE')
  ) order by 1;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);

-- Check for Data Redaction
define OPTION_NAME=ADVANCED_SECURITY
define OPTION_QUERY=REDACTION_POLICIES
define OPTION_QUERY_COLS=OBJECT_OWNER,OBJECT_NAME,POLICY_NAME,ENABLE,POLICY_DESCRIPTION
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from REDACTION_POLICIES;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
       OBJECT_OWNER       ||'","'||
       OBJECT_NAME        ||'","'||
       POLICY_NAME        ||'","'||
       ENABLE             ||'","'||
       POLICY_DESCRIPTION ||'",'
  from REDACTION_POLICIES
  order by OBJECT_OWNER, OBJECT_NAME, POLICY_NAME;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);



-- *** ADVANCED COMPRESSION (introduced in 11.1)
-- ====================================================================

define OPTION_NAME=ADVANCED_COMPRESSION
define OPTION_QUERY=TABLE_COMPRESSION
define OPTION_QUERY_COLS=DATA_DICTIONARY_VIEW,TABLE_OWNER,TABLE_NAME,PARTITION_NAME,COMPRESSION,COMPRESS_FOR
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from (
  select 'DBA_TABLES,'            || owner       ||','|| table_name ||','                  ||',"'|| compression ||'","'|| compress_for ||'",' as csv_cols
    from dba_tables
    where compress_for in ('FOR ALL OPERATIONS', 'OLTP', 'ADVANCED')
  union all
  select 'DBA_TAB_PARTITIONS,'    || table_owner ||','|| table_name ||','|| partition_name ||',"'|| compression ||'","'|| compress_for ||'",' as csv_cols
    from dba_tab_partitions
    where compress_for in ('FOR ALL OPERATIONS', 'OLTP', 'ADVANCED')
  union all
  select 'DBA_TAB_SUBPARTITIONS,' || table_owner ||','|| table_name ||','|| partition_name ||',"'|| compression ||'","'|| compress_for ||'",' as csv_cols
    from dba_tab_subpartitions
    where compress_for in ('FOR ALL OPERATIONS', 'OLTP', 'ADVANCED')
  );

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
   csv_cols
  from (
  select 'DBA_TABLES,'            || owner       ||','|| table_name ||','                  ||',"'|| compression ||'","'|| compress_for ||'",' as csv_cols
    from dba_tables
    where compress_for in ('FOR ALL OPERATIONS', 'OLTP', 'ADVANCED')
  union all
  select 'DBA_TAB_PARTITIONS,'    || table_owner ||','|| table_name ||','|| partition_name ||',"'|| compression ||'","'|| compress_for ||'",' as csv_cols
    from dba_tab_partitions
    where compress_for in ('FOR ALL OPERATIONS', 'OLTP', 'ADVANCED')
  union all
  select 'DBA_TAB_SUBPARTITIONS,' || table_owner ||','|| table_name ||','|| partition_name ||',"'|| compression ||'","'|| compress_for ||'",' as csv_cols
    from dba_tab_subpartitions
    where compress_for in ('FOR ALL OPERATIONS', 'OLTP', 'ADVANCED')
  ) order by 1;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


define OPTION_NAME=ADVANCED_COMPRESSION
define OPTION_QUERY=SECUREFILES_COMPRESSION_AND_DEDUPLICATION
define OPTION_QUERY_COLS=DATA_DICTIONARY_VIEW,TABLE_OWNER,TABLE_NAME,COLUMN_NAME,COMPRESSION,DEDUPLICATION
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from (
  select 'DBA_LOBS,'              || owner       ||','|| table_name ||','|| column_name ||',"'|| compression ||'","'|| deduplication ||'",' as csv_cols
    from dba_lobs
    where compression   not in ('NO', 'NONE')
       or deduplication not in ('NO', 'NONE')
  union all
  select 'DBA_LOB_PARTITIONS,'    || table_owner ||','|| table_name ||','|| column_name ||',"'|| compression ||'","'|| deduplication ||'",' as csv_cols
    from dba_lob_partitions
    where compression   not in ('NO', 'NONE')
       or deduplication not in ('NO', 'NONE')
  union all
  select 'DBA_LOB_SUBPARTITIONS,' || table_owner ||','|| table_name ||','|| column_name ||',"'|| compression ||'","'|| deduplication ||'",' as csv_cols
    from dba_lob_subpartitions
    where compression   not in ('NO', 'NONE')
       or deduplication not in ('NO', 'NONE')
  );

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
   csv_cols
  from (
  select 'DBA_LOBS,'              || owner       ||','|| table_name ||','|| column_name ||',"'|| compression ||'","'|| deduplication ||'",' as csv_cols
    from dba_lobs
    where compression   not in ('NO', 'NONE')
       or deduplication not in ('NO', 'NONE')
  union all
  select 'DBA_LOB_PARTITIONS,'    || table_owner ||','|| table_name ||','|| column_name ||',"'|| compression ||'","'|| deduplication ||'",' as csv_cols
    from dba_lob_partitions
    where compression   not in ('NO', 'NONE')
       or deduplication not in ('NO', 'NONE')
  union all
  select 'DBA_LOB_SUBPARTITIONS,' || table_owner ||','|| table_name ||','|| column_name ||',"'|| compression ||'","'|| deduplication ||'",' as csv_cols
    from dba_lob_subpartitions
    where compression   not in ('NO', 'NONE')
       or deduplication not in ('NO', 'NONE')
  ) order by 1;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


define OPTION_NAME=ADVANCED_COMPRESSION
define OPTION_QUERY=DBA_FLASHBACK_ARCHIVE
define OPTION_QUERY_COLS=FLASHBACK_ARCHIVE_NAME,TABLESPACE_NAME,QUOTA_IN_MB,RETENTION_IN_DAYS,CREATE_TIME,LAST_PURGE_TIME,STATUS
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from (
  select
        a.FLASHBACK_ARCHIVE_NAME,
        b.TABLESPACE_NAME,
        b.QUOTA_IN_MB,
        a.RETENTION_IN_DAYS,
        a.CREATE_TIME,
        a.LAST_PURGE_TIME,
        a.STATUS -- DEFAULT or not (NULL)
  from        DBA_FLASHBACK_ARCHIVE    a
    left join DBA_FLASHBACK_ARCHIVE_TS b on a.FLASHBACK_ARCHIVE# = b.FLASHBACK_ARCHIVE#
  );

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
        a.FLASHBACK_ARCHIVE_NAME ||'","'||
        b.TABLESPACE_NAME        ||'","'||
        b.QUOTA_IN_MB            ||'",' ||
        a.RETENTION_IN_DAYS      ||','  ||
        a.CREATE_TIME            ||','  ||
        a.LAST_PURGE_TIME        ||',"' ||
        a.STATUS                 ||'",'
  from        DBA_FLASHBACK_ARCHIVE    a
    left join DBA_FLASHBACK_ARCHIVE_TS b on a.FLASHBACK_ARCHIVE# = b.FLASHBACK_ARCHIVE#
  order by 1;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


define OPTION_NAME=ADVANCED_COMPRESSION
define OPTION_QUERY=DBA_FLASHBACK_ARCHIVE_TABLES
define OPTION_QUERY_COLS=FLASHBACK_ARCHIVE_NAME,OWNER_NAME,TABLE_NAME,ARCHIVE_TABLE_NAME
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from (
  select
        FLASHBACK_ARCHIVE_NAME,
        OWNER_NAME,
        TABLE_NAME,
        ARCHIVE_TABLE_NAME
    from DBA_FLASHBACK_ARCHIVE_TABLES
  );

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
        FLASHBACK_ARCHIVE_NAME ||'","'||
        OWNER_NAME             ||'","'||
        TABLE_NAME             ||'","'||
        ARCHIVE_TABLE_NAME     ||'",'
    from DBA_FLASHBACK_ARCHIVE_TABLES
  order by 1;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


-- Check for Advanced Index Compression
define OPTION_NAME=ADVANCED_COMPRESSION
define OPTION_QUERY=DBA_INDEXES.COMPRESSION
define OPTION_QUERY_COLS=OWNER,INDEX_NAME,TABLE_OWNER,TABLE_NAME,COMPRESSION
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from DBA_INDEXES
  where COMPRESSION like '%ADVANCED%';

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
       OWNER        ||'","'||
       INDEX_NAME   ||'","'||
       TABLE_OWNER  ||'","'||
       TABLE_NAME   ||'","'||
       COMPRESSION  ||'",'
  from DBA_INDEXES
  where COMPRESSION like '%ADVANCED%'
  order by OWNER, INDEX_NAME;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);



-- *** DATABASE VAULT
-- ====================================================================
select '&&GREP_PREFIX.,DATABASE_VAULT,DVSYS_SCHEMA,'||count(*)||',count,'||MAX(username)||','
  from dba_users where UPPER(username)='DVSYS';

select '&&GREP_PREFIX.,DATABASE_VAULT,DVF_SCHEMA,'||count(*)||',count,'||MAX(username)||','
  from dba_users where UPPER(username)='DVF';


define OPTION_NAME=DATABASE_VAULT
define OPTION_QUERY=DVSYS.DBA_DV_REALM
define OPTION_QUERY_COLS=NAME,DESCRIPTION,ENABLED
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from DVSYS.DBA_DV_REALM;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
        NAME         ||'","'||
        DESCRIPTION  ||'",'||
        ENABLED      ||','
  from DVSYS.DBA_DV_REALM
  order by NAME;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);



-- *** DATABASE IN-MEMORY (introduced in 12.1.0.2.0)
-- ====================================================================
define OPTION_NAME=DB_IN_MEMORY
define OPTION_QUERY=INMEMORY_ENABLED_TABLES
define OPTION_QUERY_COLS=DATA_DICTIONARY_VIEW,TABLE_OWNER,TABLE_NAME,PARTITION_NAME,INMEMORY,INMEMORY_PRIORITY
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from (
  select 'DBA_TABLES,'            || owner       ||','|| table_name ||','                  ||',"'|| inmemory ||'","'|| inmemory_priority ||'",' as csv_cols
    from dba_tables
    where inmemory in ('ENABLED')
  union all
  select 'DBA_TAB_PARTITIONS,'    || table_owner ||','|| table_name ||','|| partition_name ||',"'|| inmemory ||'","'|| inmemory_priority ||'",' as csv_cols
    from dba_tab_partitions
    where inmemory in ('ENABLED')
  union all
  select 'DBA_TAB_SUBPARTITIONS,' || table_owner ||','|| table_name ||','|| partition_name ||',"'|| inmemory ||'","'|| inmemory_priority ||'",' as csv_cols
    from dba_tab_subpartitions
    where inmemory in ('ENABLED')
  union all
  select 'DBA_OBJECT_TABLES,'     || owner       ||','|| table_name ||','|| object_id_type ||',"'|| inmemory ||'","'|| inmemory_priority ||'",' as csv_cols
    from dba_object_tables
    where inmemory in ('ENABLED')
  );

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
   csv_cols
  from (
  select 'DBA_TABLES,'            || owner       ||','|| table_name ||','                  ||',"'|| inmemory ||'","'|| inmemory_priority ||'",' as csv_cols
    from dba_tables
    where inmemory in ('ENABLED')
  union all
  select 'DBA_TAB_PARTITIONS,'    || table_owner ||','|| table_name ||','|| partition_name ||',"'|| inmemory ||'","'|| inmemory_priority ||'",' as csv_cols
    from dba_tab_partitions
    where inmemory in ('ENABLED')
  union all
  select 'DBA_TAB_SUBPARTITIONS,' || table_owner ||','|| table_name ||','|| partition_name ||',"'|| inmemory ||'","'|| inmemory_priority ||'",' as csv_cols
    from dba_tab_subpartitions
    where inmemory in ('ENABLED')
  union all
  select 'DBA_OBJECT_TABLES,'     || owner       ||','|| table_name ||','|| object_id_type ||',"'|| inmemory ||'","'|| inmemory_priority ||'",' as csv_cols
    from dba_object_tables
    where inmemory in ('ENABLED')
  ) order by 1;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


define OPTION_NAME=DB_IN_MEMORY
define OPTION_QUERY=GV$IM_SEGMENTS
define OPTION_QUERY_COLS=INST_ID,CON_ID,SEGMENT_TYPE,OWNER,SEGMENT_NAME,PARTITION_NAME,POPULATE_STATUS,INMEMORY_PRIORITY,INMEMORY_COMPRESSION
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from GV$IM_SEGMENTS;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
       a.CON_ID                || ',' ||
       a.INST_ID               || ',"'||
       a.SEGMENT_TYPE          ||'","'||
       a.OWNER                 ||'","'||
       a.SEGMENT_NAME          ||'","'||
       a.PARTITION_NAME        ||'","'||
       a.POPULATE_STATUS       ||'","'||
       a.INMEMORY_PRIORITY     ||'","'||
       a.INMEMORY_COMPRESSION  ||'",'
  from GV$IM_SEGMENTS a
  order by a.SEGMENT_TYPE, a.OWNER, a.SEGMENT_NAME, a.PARTITION_NAME;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);



-- *** OEM (ORACLE ENTERPRISE MANAGER)
-- ===================================================================*
-- Check for running known OEM Programs
define OPTION_NAME=OEM
define OPTION_QUERY=RUNNING_PROGRAMS
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint
select ltrim(rtrim(to_char(count(distinct program)))) as OCOUNT
  FROM V$SESSION
  WHERE
      upper(program) LIKE '%XPNI.EXE%'
   OR upper(program) LIKE '%VMS.EXE%'
   OR upper(program) LIKE '%EPC.EXE%'
   OR upper(program) LIKE '%TDVAPP.EXE%'
   OR upper(program) LIKE 'VDOSSHELL%'
   OR upper(program) LIKE '%VMQ%'
   OR upper(program) LIKE '%VTUSHELL%'
   OR upper(program) LIKE '%JAVAVMQ%'
   OR upper(program) LIKE '%XPAUTUNE%'
   OR upper(program) LIKE '%XPCOIN%'
   OR upper(program) LIKE '%XPKSH%'
   OR upper(program) LIKE '%XPUI%';

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
        PROGRAM   ||'",'
  FROM V$SESSION
  WHERE
      upper(program) LIKE '%XPNI.EXE%'
   OR upper(program) LIKE '%VMS.EXE%'
   OR upper(program) LIKE '%EPC.EXE%'
   OR upper(program) LIKE '%TDVAPP.EXE%'
   OR upper(program) LIKE 'VDOSSHELL%'
   OR upper(program) LIKE '%VMQ%'
   OR upper(program) LIKE '%VTUSHELL%'
   OR upper(program) LIKE '%JAVAVMQ%'
   OR upper(program) LIKE '%XPAUTUNE%'
   OR upper(program) LIKE '%XPCOIN%'
   OR upper(program) LIKE '%XPKSH%'
   OR upper(program) LIKE '%XPUI%';

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);

-- PL/SQL anonymous block to Check for known OEM tables
DECLARE
    cursor1 integer;
    v_count number(1);
    v_schema dba_tables.owner%TYPE;
    v_version varchar2(10);
    v_component varchar2(20);
    v_i_name varchar2(10);
    v_h_name varchar2(30);
    stmt varchar2(200);
    rows_processed integer;

    CURSOR schema_array IS
    SELECT owner
    FROM dba_tables WHERE table_name = 'SMP_REP_VERSION';

    CURSOR schema_array_v2 IS
    SELECT owner
    FROM dba_tables WHERE table_name = 'SMP_VDS_REPOS_VERSION';

BEGIN
    --DBMS_OUTPUT.PUT_LINE ('.');
    --DBMS_OUTPUT.PUT_LINE ('OEM REPOSITORY LOCATIONS');

    SELECT instance_name,host_name INTO v_i_name, v_h_name FROM v$instance;

    --DBMS_OUTPUT.PUT_LINE ('Instance: '||v_i_name||' on host: '||v_h_name);

    OPEN schema_array;
    OPEN schema_array_v2;

    cursor1 := dbms_sql.open_cursor;
    v_count := 0;

    LOOP -- this loop steps through each valid schema.
       FETCH schema_array INTO v_schema;
       EXIT WHEN schema_array%notfound;
       v_count := v_count + 1;
       dbms_sql.parse(cursor1,'select c_current_version, c_component from '||v_schema||'.smp_rep_version', dbms_sql.native);
       dbms_sql.define_column(cursor1, 1, v_version, 10);
       dbms_sql.define_column(cursor1, 2, v_component, 20);

       rows_processed:=dbms_sql.execute ( cursor1 );

       loop -- to step through cursor1 to find console version.
          if dbms_sql.fetch_rows(cursor1) >0 then
             dbms_sql.column_value (cursor1, 1, v_version);
             dbms_sql.column_value (cursor1, 2, v_component);
             if v_component = 'CONSOLE' then
                dbms_output.put_line ('&&GREP_PREFIX.,OEM,REPOSITORY1,'||v_count||',dbms_output,Schema '||rpad(v_schema,15)||' has a repository version '||v_version||',');
                exit;
             end if;
          else
             exit;
          end if;
       end loop;
    END LOOP;

    LOOP -- this loop steps through each valid V2 schema.
       FETCH schema_array_v2 INTO v_schema;
       EXIT WHEN schema_array_v2%notfound;
       v_count := v_count + 1;
       dbms_output.put_line ('&&GREP_PREFIX.,OEM,REPOSITORY2,'||v_count||',dbms_output,Schema '||rpad(v_schema,15)||' has a repository version 2.x,');
    end loop;
    dbms_sql.close_cursor (cursor1);
    close schema_array;
    close schema_array_v2;
    if v_count = 0 then
       dbms_output.put_line ('&&GREP_PREFIX.,OEM,NO_REPOSITORY,'||v_count||',dbms_output,There are NO OEM repositories with version prior to 10g on this instance - '||v_i_name||' on host '||v_h_name||',');
    end if;
END;
/

--- OEM 10G AND HIGHER --- version and installation type (database control or grid/cloud control)
----------------------
define OPTION_NAME=OEM
define OPTION_QUERY=MGMT_VERSIONS
define OPTION_QUERY_COLS=COMPONENT_NAME,VERSION,COMPAT_CORE_VERSION,COMPONENT_MODE,STATUS
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint
select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from SYSMAN.MGMT_VERSIONS;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
    COMPONENT_NAME           || '","' || -- 'CORE'
    VERSION                  || '","' ||
    COMPAT_CORE_VERSION      || '","' ||
    COMPONENT_MODE           || '","' || -- 'SYSAUX'='DB Control','CENTRAL'='Grid/Cloud Control'
    STATUS                   || '",'
  from SYSMAN.MGMT_VERSIONS
  order by 1;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


--- OEM 10G AND HIGHER --- components
----------------------
define OPTION_NAME=OEM
define OPTION_QUERY=MGMT_INV_COMPONENT
define OPTION_QUERY_COLS=CONTAINER_TYPE,CONTAINER_NAME,CONTAINER_LOCATION,OUI_PLATFORM,IS_CLONABLE,NAME,VERSION,DESCRIPTION,EXTERNAL_NAME,INSTALLED_LOCATION,INSTALLER_VERSION,MIN_DEINSTALLER_VERSION,IS_TOP_LEVEL,TIMESTAMP
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint
select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from            SYSMAN.MGMT_INV_CONTAINER a
  full outer join SYSMAN.MGMT_INV_COMPONENT b on a.CONTAINER_GUID = b.CONTAINER_GUID
  ;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

SET LINESIZE 1500
select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
    a.CONTAINER_TYPE        || '","' ||
    a.CONTAINER_NAME        || '","' ||
    a.CONTAINER_LOCATION    || '","' ||
    a.OUI_PLATFORM          || '","' ||
    a.IS_CLONABLE           || '","' ||
    NAME                    || '","' ||
    VERSION                 || '","' ||
    substr(replace(replace(replace(to_char(substr(b.DESCRIPTION, 1, 1000)), chr(10), '[LF]'), chr(13), '[CR]'),'"',''''), 1, 255) || '","' ||
    EXTERNAL_NAME           || '","' ||
    INSTALLED_LOCATION      || '","' ||
    INSTALLER_VERSION       || '","' ||
    MIN_DEINSTALLER_VERSION || '","' ||
    IS_TOP_LEVEL            || '","' ||
    TIMESTAMP               || '",'
  from            SYSMAN.MGMT_INV_CONTAINER a
  full outer join SYSMAN.MGMT_INV_COMPONENT b on a.CONTAINER_GUID = b.CONTAINER_GUID
  ;
SET LINESIZE 500

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);

--- OEM 10G AND HIGHER --- Pack Access
define OPTION_NAME=OEM
define OPTION_QUERY=MGMT_ADMIN_LICENSES
define OPTION_QUERY_COLS=PACK_NAME,PACK_LABEL,TARGET_TYPE,PACK_DISPLAY_LABEL,PACK_ACCESS_AGREED
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint
select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from SYSMAN.MGMT_LICENSE_DEFINITIONS a,
       SYSMAN.MGMT_ADMIN_LICENSES      b,
      (select decode(count(*), 0, 'NO', 'YES') as PACK_ACCESS_AGREED
        from SYSMAN.MGMT_LICENSES where upper(I_AGREE)='YES') c
  where a.pack_label = b.pack_name   (+);

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
       b.pack_name || ',' || a.pack_label || ',' || a.target_type || ',"' || a.pack_display_label || '","' || c.PACK_ACCESS_AGREED || '",'
  from SYSMAN.MGMT_LICENSE_DEFINITIONS a,
       SYSMAN.MGMT_ADMIN_LICENSES      b,
      (select decode(count(*), 0, 'NO', 'YES') as PACK_ACCESS_AGREED
        from SYSMAN.MGMT_LICENSES where upper(I_AGREE)='YES') c
  where a.pack_label = b.pack_name   (+)
  order by 1;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


-- OEM Grid Control 10g; OEM Grid Control 11g; OEM Database Control 11g; OEM Cloud Control 12c
define OPTION_NAME=OEM
define OPTION_QUERY=GRID_CONTROL+11g
define OPTION_QUERY_COLS=TARGET_TYPE_DISPLAY_NAME,HOST_NAME,TARGET_NAME,PACK_DISPLAY_LABEL,PACK_ACCESS_GRANTED,PACK_ACCESS_AGREED,PACK_ACCESS_AGREED_DATE,PACK_ACCESS_AGREED_BY,TARGET_TYPE,PACK_LABEL
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint
select ltrim(rtrim(to_char(count(*)))) as OCOUNT
from                SYSMAN.MGMT_TARGETS                  tg
    left outer join SYSMAN.MGMT_TARGET_TYPES             tt on tg.target_type = tt.target_type
         inner join SYSMAN.MGMT_LICENSE_DEFINITIONS      ld on tg.target_type = ld.target_type
    left outer join SYSMAN.MGMT_LICENSED_TARGETS         lt on tg.target_guid = lt.target_guid and ld.pack_label = lt.pack_name
    left outer join SYSMAN.MGMT_LICENSE_CONFIRMATION     lc on tg.target_guid = lc.target_guid;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"' ||
       tt.type_display_name                      || '","' ||
       tg.host_name                              || '",'  ||
       tg.target_name                            || ',"'  ||
       ld.pack_display_label                     || '",'  ||
       decode(lt.pack_name  , null, 'NO', 'YES') || ','   ||
       decode(lc.target_guid, null, 'NO', 'YES') || ','   ||
       lc.confirmed_time                         || ',"'  ||
       lc.confirmed_by                           || '","' ||
       tg.target_type                            || '","' ||
       ld.pack_label                             || '",'
  from              SYSMAN.MGMT_TARGETS                  tg
    left outer join SYSMAN.MGMT_TARGET_TYPES             tt on tg.target_type = tt.target_type
         inner join SYSMAN.MGMT_LICENSE_DEFINITIONS      ld on tg.target_type = ld.target_type
    left outer join SYSMAN.MGMT_LICENSED_TARGETS         lt on tg.target_guid = lt.target_guid and ld.pack_label = lt.pack_name
    left outer join SYSMAN.MGMT_LICENSE_CONFIRMATION     lc on tg.target_guid = lc.target_guid
  order by tg.host_name, tt.type_display_name, tg.target_name, ld.pack_display_label;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


-- OEM PACK ACCESS AGREEMENTS (10g or higher)
define OPTION_NAME=OEM
define OPTION_QUERY=MGMT_LICENSES
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint
select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from SYSMAN.MGMT_LICENSES
  ;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
       USERNAME || ',' || TIMESTAMP || ',"' || I_AGREE || '",'
  from SYSMAN.MGMT_LICENSES
  order by TIMESTAMP;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


-- OEM MANAGED DATABASES (10g or higher)
define OPTION_NAME=OEM
define OPTION_QUERY=MGMT_TARGETS
define OPTION_QUERY_COLS=TARGET_NAME,HOST_NAME,LOAD_TIMESTAMP,LAST_LOAD_TIME,TARGET_TYPE
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from SYSMAN.MGMT_TARGETS
  where TARGET_TYPE like '%database%'
  ;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
       TARGET_NAME    || '","' ||
       HOST_NAME      || '",'  ||
       LOAD_TIMESTAMP ||  ','  ||
       LAST_LOAD_TIME ||  ',"' ||
       TARGET_TYPE    || '",'
  from SYSMAN.MGMT_TARGETS
  where TARGET_TYPE like '%database%'
  order by TARGET_NAME;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


-- OEM MANAGED TARGETS (10g or higher)
define OPTION_NAME=OEM
define OPTION_QUERY=MGMT$TARGET
define OPTION_QUERY_COLS=TARGET_NAME,DISPLAY_NAME,HOST_NAME,TARGET_TYPE,LAST_METRIC_LOAD_TIME
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from MGMT$TARGET
  where TARGET_TYPE like '%database%'
  ;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
       TARGET_NAME           || '","' ||
       DISPLAY_NAME          || '","' ||
       HOST_NAME             || '","' ||
       TARGET_TYPE           || '",'  ||
       LAST_METRIC_LOAD_TIME ||  ','
  from MGMT$TARGET
  where TARGET_TYPE like '%database%'
  order by TARGET_NAME;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


-- OEM MGMT_LICENSE_CONFIRMATION (10g or higher)
define OPTION_NAME=OEM
define OPTION_QUERY=MGMT_LICENSE_CONFIRMATION
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint
select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from SYSMAN.MGMT_LICENSE_CONFIRMATION a,
       SYSMAN.MGMT_TARGETS b
  where a.target_guid = b.target_guid (+)
  ;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
       a.confirmation      || '","'  ||
       a.confirmed_by      || '","'  ||
       a.confirmed_time    || '","'  ||
       b.target_name       || '","'  ||
       b.target_type       || '","'  ||
       b.type_display_name || '",'
  from SYSMAN.MGMT_LICENSE_CONFIRMATION a,
       SYSMAN.MGMT_TARGETS b
  where a.target_guid = b.target_guid (+)
  order by 1;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


-- OEM PACK USAGE (12c Cloud Control)
define OPTION_NAME=OEM
define OPTION_QUERY=PACK_USAGE
define OPTION_QUERY_COLS=PACK_NAME,TARGET_NAME,TARGET_DISPLAY_NAME,TARGET_TYPE,HOST_NAME,CURRENTLY_USED,DETECTED_USAGES,TOTAL_SAMPLES,LAST_USAGE_DATE,FIRST_SAMPLE_DATE,LAST_SAMPLE_DATE,PACK_ID
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  FROM SYSMAN.mgmt_fu_registrations reg,
       SYSMAN.mgmt_fu_statistics    stat,
       SYSMAN.mgmt_targets          tgts
  WHERE (stat.isused = 1 or stat.detected_samples > 0) -- current or past usage
    AND stat.target_guid = tgts.target_guid
    AND reg.feature_id = stat.feature_id
    AND reg.collection_mode = 2
  --AND tgts.display_name = 'TARGET_NAME'
  ;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
        reg.feature_name                           || '","'  ||
        tgts.target_name                           || '","'  ||
        tgts.display_name                          || '","'  ||
        tgts.type_display_name                     || '","'  ||
        tgts.host_name                             || '","'  ||
        DECODE(stat.isused, 1, 'TRUE', 'FALSE')    || '",'   ||
        stat.detected_samples                      || ','    ||
        stat.total_samples                         || ','    ||
        stat.last_usage_date                       || ','    ||
        stat.first_sample_date                     || ','    ||
        stat.last_sample_date                      || ',"'   ||
        reg.feature_id                             || '",'
  FROM SYSMAN.mgmt_fu_registrations reg,
       SYSMAN.mgmt_fu_statistics    stat,
       SYSMAN.mgmt_targets          tgts
  WHERE (stat.isused = 1 or stat.detected_samples > 0) -- current or past usage
    AND stat.target_guid = tgts.target_guid
    AND reg.feature_id = stat.feature_id
    AND reg.collection_mode = 2
  --AND tgts.display_name = 'TARGET_NAME'
 ORDER BY decode(tgts.target_type, 'oracle_database', 1, 'rac_database', 1, 2), -- db packs first
          reg.feature_name,
          tgts.type_display_name,
          tgts.display_name,
          tgts.host_name;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


-- OEM PACK FEATURE USAGE (12c Cloud Control)
define OPTION_NAME=OEM
define OPTION_QUERY=PACK_FEATURE_USAGE
-- Incomplete string, to avoid error: string beginning "PACK_NAME,..." is too long. maximum size is 240 characters.
define OPTION_QUERY_COLS=PACK_NAME,TARGET_NAME,TARGET_DISPLAY_NAME,TARGET_TYPE,HOST_NAME,PACK_CURRENTLY_USED,FEATURE_NAME,FEAT_CURRENTLY_USED,FEAT_DETECTED_USAGES,FEAT_TOTAL_SAMPLES,FEAT_LAST_USAGE_DATE,FEAT_FIRST_SAMPLE_DATE,FEAT_LAST_SAMPLE_DATE,PACK_LABEL
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  FROM SYSMAN.mgmt_fu_registrations reg,
       SYSMAN.mgmt_fu_statistics    stat,
       SYSMAN.mgmt_targets          tgts,
       SYSMAN.mgmt_fu_statistics    f_stats,
       SYSMAN.mgmt_fu_registrations freg,
       SYSMAN.mgmt_fu_license_map   lmap
  WHERE (stat.isused = 1 or stat.detected_samples > 0 or f_stats.isused = 1 or f_stats.detected_samples > 0) -- current or past usage
    AND stat.target_guid = tgts.target_guid
    AND reg.feature_id = stat.feature_id
    AND reg.collection_mode = 2
    AND lmap.pack_id = reg.feature_id
    AND lmap.feature_id = freg.feature_id
    AND freg.feature_id = f_stats.feature_id
    AND f_stats.target_guid = tgts.target_guid
  --AND tgts.display_name = 'TARGET_NAME'
  ;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,PACK_ID,FEATURE_ID,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
        reg.feature_name                           || '","'  ||
        tgts.target_name                           || '","'  ||
        tgts.display_name                          || '","'  ||
        tgts.type_display_name                     || '","'  ||
        tgts.host_name                             || '","'  ||
        DECODE(stat.isused, 1, 'TRUE', 'FALSE')    || '","'  ||
        freg.feature_name                          || '","'  ||
        DECODE(f_stats.isused, 1, 'TRUE', 'FALSE') || '",'   ||
        f_stats.detected_samples                   || ','    ||
        f_stats.total_samples                      || ','    ||
        f_stats.last_usage_date                    || ','    ||
        f_stats.first_sample_date                  || ','    ||
        f_stats.last_sample_date                   || ',"'   ||
        lmap.pack_label                            || '","'  ||
        lmap.pack_id                               || '","'  ||
        lmap.feature_id                            || '",'
  FROM SYSMAN.mgmt_fu_registrations reg,
       SYSMAN.mgmt_fu_statistics    stat,
       SYSMAN.mgmt_targets          tgts,
       SYSMAN.mgmt_fu_statistics    f_stats,
       SYSMAN.mgmt_fu_registrations freg,
       SYSMAN.mgmt_fu_license_map   lmap
  WHERE (stat.isused = 1 or stat.detected_samples > 0 or f_stats.isused = 1 or f_stats.detected_samples > 0) -- current or past usage
    AND stat.target_guid = tgts.target_guid
    AND reg.feature_id = stat.feature_id
    AND reg.collection_mode = 2
    AND lmap.pack_id = reg.feature_id
    AND lmap.feature_id = freg.feature_id
    AND freg.feature_id = f_stats.feature_id
    AND f_stats.target_guid = tgts.target_guid
  --AND tgts.display_name = 'TARGET_NAME'
 ORDER BY decode(tgts.target_type, 'oracle_database', 1, 'rac_database', 1, 2), -- db packs first
          reg.feature_name,
          tgts.type_display_name,
          tgts.display_name,
          freg.feature_name;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",') || '&OPTION_QUERY_COLS.,PACK_ID,FEATURE_ID,'
  from dual where &&OCOUNT. in (-942, 0);


-- OEM - TUNING PACK EVIDENCES (10g or higher) - SQL Profiles usage
define OPTION_NAME=OEM
define OPTION_QUERY=SQL_PROFILES
define OPTION_QUERY_COLS=COUNT,NAME,CREATED,LAST_MODIFIED,DESCRIPTION,TYPE,STATUS
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from DBA_SQL_PROFILES
  where lower(STATUS) = 'enabled';

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        '&&OCOUNT'     ||  ',"'  || -- count is added again as a first column for backward compatibility
        NAME           || '","'  ||
        CREATED        || '","'  ||
        LAST_MODIFIED  || '","'  ||
        DESCRIPTION    || '","'  ||
        TYPE           || '","'  ||
        STATUS         || '",'
  from  DBA_SQL_PROFILES
  where lower(STATUS) = 'enabled';

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


-- OEM - TUNING PACK EVIDENCES (10g or higher) - SQL Access Advisor and SQL Tuning Advisor
define OPTION_NAME=OEM
define OPTION_QUERY=DBA_ADVISOR_TASKS
define OPTION_QUERY_COLS=TASK_ID,OWNER,TASK_NAME,DESCRIPTION,ADVISOR_NAME,CREATED,LAST_MODIFIED,PARENT_TASK_ID,EXECUTION_START,EXECUTION_END,STATUS,SOURCE,HOW_CREATED
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from DBA_ADVISOR_TASKS
  where ADVISOR_NAME in ('SQL Tuning Advisor', 'SQL Access Advisor')
  ;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        TASK_ID          ||  ',"'  ||
        OWNER            || '","'  ||
        TASK_NAME        || '","'  ||
        DESCRIPTION      || '","'  ||
        ADVISOR_NAME     || '","'  ||
        CREATED          || '","'  ||
        LAST_MODIFIED    || '",'   ||
        PARENT_TASK_ID   ||  ',"'  ||
        EXECUTION_START  || '","'  ||
        EXECUTION_END    || '","'  ||
        STATUS           || '","'  ||
        SOURCE           || '","'  ||
        HOW_CREATED      || '",'
  from DBA_ADVISOR_TASKS
  where ADVISOR_NAME in ('SQL Tuning Advisor', 'SQL Access Advisor') -- SYS_AUTO_SQL_TUNING_TASK will be ignored at the analysis time
  order by CREATED;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


-- OEM - TUNING PACK EVIDENCES (10g or higher) - SQL Tuning Sets
define OPTION_NAME=OEM
define OPTION_QUERY=DBA_SQLSET
define OPTION_QUERY_COLS=ID,NAME,OWNER,CREATED,LAST_MODIFIED,STATEMENT_COUNT,DESCRIPTION
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from DBA_SQLSET;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        ID               ||  ',"'  ||
        NAME             || '","'  ||
        OWNER            || '","'  ||
        CREATED          || '","'  ||
        LAST_MODIFIED    || '",'   ||
        STATEMENT_COUNT  ||  ',"'  ||
        DESCRIPTION      || '",'
  from DBA_SQLSET
  order by ID;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


-- OEM - TUNING PACK EVIDENCES (10g or higher) - SQL Tuning Sets references
define OPTION_NAME=OEM
define OPTION_QUERY=DBA_SQLSET_REFERENCES
define OPTION_QUERY_COLS=SQLSET_ID,SQLSET_NAME,SQLSET_OWNER,ID,OWNER,CREATED,DESCRIPTION
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from DBA_SQLSET_REFERENCES;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        SQLSET_ID        ||  ',"'  ||
        SQLSET_NAME      || '","'  ||
        SQLSET_OWNER     || '",'   ||
        ID               ||  ',"'  ||
        OWNER            || '","'  ||
        CREATED          || '","'  ||
        DESCRIPTION      || '",'
  from DBA_SQLSET_REFERENCES
  order by SQLSET_ID, OWNER, DESCRIPTION, ID;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);



-- *** AUDIT VAULT
-- ===================================================================*
select '&&GREP_PREFIX.,AUDIT_VAULT*,AVSYS_SCHEMA,'||count(*)||',count,'||MAX(username)||','
  from DBA_USERS where upper(USERNAME)='AVSYS';



-- *** CONTENT DATABASE and RECORDS DATABASE
-- ====================================================================
select '&&GREP_PREFIX.,CONTENT_AND_RECORDS,CONTENT_SCHEMA,'||count(*)||',count,'||MAX(username)||','
  from dba_users where UPPER(username)='CONTENT';

-- CONTENT
define OPTION_NAME=CONTENT_DATABASE
define OPTION_QUERY=ODM_DOCUMENT
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint
select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from ODM_DOCUMENT;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        count(*) || ','
  from ODM_DOCUMENT;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942);

-- RECORDS
define OPTION_NAME=RECORDS_DATABASE
define OPTION_QUERY=ODM_RECORD
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint
select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from ODM_RECORD;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        count(*) || ','
  from ODM_RECORD;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942);



-- *** OWB (ORACLE WAREHOUSE BUILDER)
-- ===================================================================*
-- Detect OWB repository
define OPTION_NAME=OWB
define OPTION_QUERY=REPOSITORY

DECLARE

  CURSOR schema_array IS
  SELECT owner
  FROM dba_tables WHERE table_name = 'CMPSYSCLASSES';

  c_installed_ver   integer;
  rows_processed    integer;
  v_schema          dba_tables.owner%TYPE;
  v_schema_cnt      integer;
  v_version         varchar2(15);

BEGIN
  OPEN schema_array;
  c_installed_ver := dbms_sql.open_cursor;

  <<owb_schema_loop>>
  LOOP -- For each valid schema...
    FETCH schema_array INTO v_schema;
    EXIT WHEN schema_array%notfound;

    --Determine if current schema is valid (contains CMPInstallation_V view)
    dbms_sql.parse(c_installed_ver,'select installedversion from '|| v_schema || '.CMPInstallation_v where name = ''Oracle Warehouse Builder''',dbms_sql.native);
    dbms_sql.define_column(c_installed_ver, 1, v_version, 15);

    rows_processed:=dbms_sql.execute ( c_installed_ver );

      loop -- Find OWB version.
        if dbms_sql.fetch_rows(c_installed_ver) > 0 then
          dbms_sql.column_value (c_installed_ver, 1, v_version);
          v_schema_cnt := v_schema_cnt + 1;

          dbms_output.put_line ('.');
          dbms_output.put_line ('&&GREP_PREFIX.,&&OPTION_NAME.,&&OPTION_QUERY.'||',1,1,'||'Schema '||v_schema||' contains a version '||v_version||' repository');
        else
          exit;
        end if;
      end loop;
  end loop;
END;
/



-- *** PATCHES
-- ====================================================================

define OPTION_NAME=PATCHES
define OPTION_QUERY=SYS.REGISTRY$HISTORY
define OPTION_QUERY_COLS=ACTION_TIME,ACTION,NAMESPACE,VERSION,ID,COMMENTS
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from SYS.REGISTRY$HISTORY;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        ACTION_TIME     ||','||
        ACTION          ||','||
        NAMESPACE       ||','||
        VERSION         ||','||
        ID              ||','||
        COMMENTS        ||','
  from SYS.REGISTRY$HISTORY
  order by ACTION_TIME
  ;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);



--------------------------------------------
PROMPT *** EXTRA INFO *** CPU/Cores/Sockets
--------------------------------------------

-- CPU/CORES/SOCKETS (For 10.2 and higher)
--------------------------------------------
define OPTION_NAME=CPU_CORES_SOCKETS
define OPTION_QUERY=10g_r2.V$LICENSE
define OCOUNT=-904
col OCOUNT new_val OCOUNT noprint
select ltrim(rtrim(to_char(count(CPU_CORE_COUNT_HIGHWATER||CPU_SOCKET_COUNT_HIGHWATER)))) as OCOUNT
  from V$LICENSE;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        SESSIONS_HIGHWATER         ||','||
        CPU_COUNT_CURRENT          ||','||
        CPU_CORE_COUNT_CURRENT     ||','||
        CPU_SOCKET_COUNT_CURRENT   ||','||
        CPU_COUNT_HIGHWATER        ||','||
        CPU_CORE_COUNT_HIGHWATER   ||','||
        CPU_SOCKET_COUNT_HIGHWATER ||','
  from V$LICENSE;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00904: invalid column name",')
  from dual where &&OCOUNT. in (-904, 0);


-- DBA_CPU_USAGE_STATISTICS (For 10.2 and higher)
--------------------------------------------
define OPTION_NAME=DBA_CPU_USAGE_STATISTICS
define OPTION_QUERY=DBA_CPU_USAGE_STATISTICS
define OPTION_QUERY_COLS=VERSION,TIMESTAMP,CPU_COUNT,CPU_CORE_COUNT,CPU_SOCKET_COUNT
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  FROM DBA_CPU_USAGE_STATISTICS;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        VERSION            ||','||
        TIMESTAMP          ||','||
        CPU_COUNT          ||','||
        CPU_CORE_COUNT     ||','||
        CPU_SOCKET_COUNT   ||','
  from DBA_CPU_USAGE_STATISTICS;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


--------------------------------------------
PROMPT *** EXTRA INFO *** ReviewLite_conc
--------------------------------------------

-- V$LICENSE
define OPTION_NAME=EXTRA_INFO
define OPTION_QUERY=V$LICENSE
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint
select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  FROM V$LICENSE;

select&SCRIPT_OO '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        SESSIONS_MAX          ||','||
        SESSIONS_WARNING      ||','||
        SESSIONS_CURRENT      ||','||
        SESSIONS_HIGHWATER    ||','||
        USERS_MAX             ||','
  FROM V$LICENSE;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


-- V$SESSION
define OPTION_NAME=EXTRA_INFO
define OPTION_QUERY=V$SESSION
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint
select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  FROM V$SESSION;

select&SCRIPT_OO '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        SID          || ',' ||
        SERIAL#      || ',"'||
        USERNAME     ||'","'||
        COMMAND      ||'","'||
        STATUS       ||'","'||
        SERVER       ||'","'||
        SCHEMANAME   ||'","'||
        OSUSER       ||'","'||
        PROCESS      ||'","'||
        MACHINE      ||'","'||
        TERMINAL     ||'","'||
        PROGRAM      ||'","'||
        TYPE         ||'","'||
        MODULE       ||'","'||
        ACTION       ||'","'||
        CLIENT_INFO  ||'","'||
        LAST_CALL_ET ||'","'||
        LOGON_TIME   ||'",'
  FROM V$SESSION;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


-- RC_DATABASE
define OPTION_NAME=EXTRA_INFO
define OPTION_QUERY=RCAT.RC_DATABASE
define OPTION_QUERY_COLS=DB_KEY,DBINC_KEY,DBID,NAME
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from RC_DATABASE;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,'||
        DB_KEY          ||  ','  ||
        DBINC_KEY       ||  ','  ||
        DBID            ||  ',"' ||
        NAME            || '",'
  from RC_DATABASE
  order by NAME
  ;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);


--------------------------------------------
PROMPT *** EXTRA INFO *** Troubleshooting
--------------------------------------------

-- Check User Privileges, for troubleshooting
select '&&GREP_PREFIX.,USER_PRIVS,USER,,,'||
        USER         || ','
  from DUAL;

select '&&GREP_PREFIX.,USER_PRIVS,USER_SYS_PRIVS,,,'||
        USERNAME     || ',' ||
        PRIVILEGE    || ','
  from USER_SYS_PRIVS;

select '&&GREP_PREFIX.,USER_PRIVS,USER_ROLE_PRIVS,,,'||
        USERNAME     || ',' ||
        GRANTED_ROLE || ','
  from USER_ROLE_PRIVS;

select '&&GREP_PREFIX.,USER_PRIVS,ROLE_SYS_PRIVS,,,'||
        ROLE         || ',' ||
        PRIVILEGE    || ','
  from ROLE_SYS_PRIVS;

select '&&GREP_PREFIX.,USER_PRIVS,DVSYS.DBA_DV_REALM_AUTH,,,'||
       REALM_NAME          ||  ',"' ||
       AUTH_RULE_SET_NAME  || '",'  ||
       AUTH_OPTIONS        ||  ','
  from DVSYS.DBA_DV_REALM_AUTH
  where GRANTEE=USER
  order by REALM_NAME;

select '&&GREP_PREFIX.,USER_PRIVS,CURRENT_CONTAINER,,,'||
        sys_context('USERENV', 'CON_ID'  ) || ',' ||
        sys_context('USERENV', 'CON_NAME') || ','
  FROM dual;

SPOOL OFF



SPOOL &&OUTPUT_PATH.oraproducts.csv

--------------------------------------------
PROMPT *** OTHER ORACLE PRODUCTS ***
--------------------------------------------

-- *** EBS (E-BUSINESS SUITE)
-- ===================================================================*
-- Detect EBS related schemas
define OPTION_NAME=EBS
define OPTION_QUERY=EBS_SCHEMAS
define OPTION_QUERY_COLS=OWNER,OBJECT_NAME,OBJECT_TYPE,OBJECT_CREATED,OWNER_CREATED
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from DBA_OBJECTS a
  join DBA_USERS   b on a.OWNER = B.USERNAME
  where a.OBJECT_NAME in ('FND_PRODUCT_GROUPS')
    and a.OBJECT_TYPE in ('TABLE', 'SYNONYM')
  order by a.OBJECT_NAME, a.OBJECT_TYPE, a.OWNER;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
       a.OWNER            || '","'  ||
       a.OBJECT_NAME      || '","'  ||
       a.OBJECT_TYPE      || '",'   ||
       a.CREATED          ||  ','   ||
       b.CREATED          ||  ','
  from DBA_OBJECTS a
  join DBA_USERS   b on a.OWNER = B.USERNAME
  where a.OBJECT_NAME in ('FND_PRODUCT_GROUPS')
    and a.OBJECT_TYPE in ('TABLE', 'SYNONYM')
  order by a.OBJECT_NAME, a.OBJECT_TYPE, a.OWNER;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);

-- Check if APPS schema contains FND_PRODUCT_GROUPS
define EBS_FROM=EBS_UNKNOWN
col EBS_FROM_ new_val EBS_FROM
select 'APPS' as EBS_FROM_ from APPS.FND_PRODUCT_GROUPS where rownum=1;
-- If not in APPS, check for other schemas
select OWNER as EBS_FROM_ from DBA_TABLES where TABLE_NAME='FND_PRODUCT_GROUPS' and '&EBS_FROM'='EBS_UNKNOWN' order by 1 desc;
prompt Trying to select from &EBS_FROM..FND_PRODUCT_GROUPS ...

-- Detect EBS release
define OPTION_NAME=EBS
define OPTION_QUERY=RELEASE
define OPTION_QUERY_COLS=RELEASE_NAME,APPLICATIONS_SYSTEM_NAME,APPS_USERNAME
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from &EBS_FROM..FND_PRODUCT_GROUPS;

select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
        RELEASE_NAME              || '","'  ||
        APPLICATIONS_SYSTEM_NAME  || '","'  ||
        '&EBS_FROM'               || '",'
  from &EBS_FROM..FND_PRODUCT_GROUPS;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);

-- Check if APPS schema contains AD_APPLIED_PATCHES
define EBS_FROM=EBS_UNKNOWN
col EBS_FROM_ new_val EBS_FROM
select 'APPS' as EBS_FROM_ from APPS.AD_APPLIED_PATCHES where rownum=1;
-- If not in APPS, check for other schemas
select OWNER as EBS_FROM_ from DBA_TABLES where TABLE_NAME='AD_APPLIED_PATCHES' and '&EBS_FROM'='EBS_UNKNOWN' order by 1 desc;
prompt Trying to select from &EBS_FROM..AD_APPLIED_PATCHES ...

-- Check for DDL changes in the database - for EBS versions 11.5.7 and higher
define OPTION_NAME=EBS
define OPTION_QUERY=DDL
define OPTION_QUERY_COLS=OWNER,OBJECT_NAME,OBJECT_TYPE,CREATED,LAST_DDL_TIME
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
from (
select distinct
        OWNER          || '","'  ||
        OBJECT_NAME    || '","'  ||
        OBJECT_TYPE    || '",'   ||
        CREATED        ||  ','   ||
        LAST_DDL_TIME  ||  ','
  from  DBA_OBJECTS
  where CREATED < LAST_DDL_TIME
    and CREATED not in (select distinct p.CREATION_DATE from &EBS_FROM..AD_APPLIED_PATCHES p)
    and GENERATED='N'
    and object_type in ( 'PACKAGE', 'PACKAGE BODY', 'PROCEDURE', 'TABLE',
                         'CLUSTER', 'VIEW', 'FUNCTION', 'DATABASE LINK', 'SEQUENCE',
                         'TABLE', 'TABLE PARTITION', 'TRIGGER', 'TYPE', 'TYPE BODY')
       );

select 'GREP'||'EBS>>,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select distinct
       'GREP'||'EBS>>,"'||
        OWNER          || '","'  ||
        OBJECT_NAME    || '","'  ||
        OBJECT_TYPE    || '",'   ||
        CREATED        ||  ','   ||
        LAST_DDL_TIME  ||  ','
  from  DBA_OBJECTS
  where CREATED < LAST_DDL_TIME
    and CREATED not in (select distinct p.CREATION_DATE from &EBS_FROM..AD_APPLIED_PATCHES p)
    and GENERATED='N'
    and object_type in ( 'PACKAGE', 'PACKAGE BODY', 'PROCEDURE', 'TABLE',
                         'CLUSTER', 'VIEW', 'FUNCTION', 'DATABASE LINK', 'SEQUENCE',
                         'TABLE', 'TABLE PARTITION', 'TRIGGER', 'TYPE', 'TYPE BODY')
    ;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);

-- Retrieve list of EBS Oracle Schemas (for troubleshooting)
define OPTION_NAME=EBS
define OPTION_QUERY=SYSTEM.FND_ORACLE_USERID
define OPTION_QUERY_COLS=ORACLE_ID,ORACLE_USERNAME,CREATION_DATE,DESCRIPTION,ENABLED_FLAG,USERNAME,CREATED
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from      SYSTEM.FND_ORACLE_USERID a
  left join DBA_USERS                b on a.ORACLE_USERNAME = b.USERNAME
  ;
select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
      a.ORACLE_ID         || '","'  ||
      a.ORACLE_USERNAME   || '",'   ||
      a.CREATION_DATE     || ',"'   ||
      a.DESCRIPTION       || '","'  ||
      a.ENABLED_FLAG      || '","'  ||
      b.USERNAME          || '",'   ||
      b.CREATED           || ','
  from      SYSTEM.FND_ORACLE_USERID a
  left join DBA_USERS                b on a.ORACLE_USERNAME = b.USERNAME
  order by a.ORACLE_ID;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);

-- Detect few EBS specific objects (for troubleshooting)
define OPTION_NAME=EBS
define OPTION_QUERY=EBS_SPECIFIC_OBJECTS
define OPTION_QUERY_COLS=OBJECT_NAME,OBJECT_TYPE,OWNER,CREATED
define OCOUNT=-942
col OCOUNT new_val OCOUNT noprint

select ltrim(rtrim(to_char(count(*)))) as OCOUNT
  from DBA_OBJECTS a
  where a.OBJECT_NAME in ('FND_PRODUCT_GROUPS', 'AD_APPLIED_PATCHES', 'FND_ORACLE_USERID')
  ;
select '&&GREP_PREFIX.,&OPTION_NAME.~HEADER,&OPTION_QUERY.~HEADER,&&OCOUNT.,count,&OPTION_QUERY_COLS.,'
  from dual where &&OCOUNT. > 0;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,count,"'||
      a.OBJECT_NAME       || '","'  ||
      a.OBJECT_TYPE       || '","'  ||
      a.OWNER             || '",'   ||
      a.CREATED           || ','
  from DBA_OBJECTS a
  where a.OBJECT_NAME in ('FND_PRODUCT_GROUPS', 'AD_APPLIED_PATCHES', 'FND_ORACLE_USERID')
  order by a.OBJECT_NAME, a.OBJECT_TYPE, a.OWNER;

select '&&GREP_PREFIX.,&OPTION_NAME.,&OPTION_QUERY.,&&OCOUNT.,'||
        decode(&&OCOUNT., 0, 'count,', '"ORA-00942: table or view does not exist",')
  from dual where &&OCOUNT. in (-942, 0);

PROMPT


-- *** OWB (ORACLE WAREHOUSE BUILDER) DETAILS
-- ===================================================================*
-- Gather detailed information
define OPTION_NAME=OWB
define OPTION_QUERY=multiple

  DECLARE
  c_installed_ver   integer;
  c_workspaces      integer;
  c_deployment      integer;
  c_execution       integer;
  c_pluggable_map   integer;
  c_transportable   integer;
  c_schedule        integer;
  c_scd_dimension   integer;
  c_user_def_FCO    integer;
  c_user_def_SCO    integer;
  c_map_operator    integer;
  c_pf_activity     integer;
  c_icon_set        integer;
  c_streams         integer;
  c_spatial         integer;
  c_data_profile    integer;
  c_data_rule       integer;
  c_data_auditor    integer;
  c_miv_connector   integer;
  c_sap_connector   integer;
  c_loc_report      integer;
  c_hetero          integer;
  c_webservice      integer;
  c_copybook        integer;
  c_dimcube         integer;
  c_realtime         integer;
  c_chunk         integer;
  c_obiee         integer;
  v_schema_cnt      number(3);
  v_schema dba_tables.owner%TYPE;
  v_objcnt          integer;
  v_sfx             varchar2(2);
  v_suffix          varchar2(32);
  v_wksp_cond       varchar2(32);
  v_where_and       varchar2(7);
  v_product         varchar2(25);
  v_version         varchar2(15);
  v_tokyo_version   varchar2(15);
  v_paris_vers      varchar2(15);
  v_oldtahoe_vers   varchar2(15);
  v_tahoe_version   varchar2(15);
  v_i_name          v$instance.instance_name%TYPE;
  v_h_name          v$instance.host_name%TYPE;
  v_workspace_cnt   number(5);
  v_workspace_id    number(9);
  v_workspace_name  varchar2(255);
  v_workspace_owner varchar2(255);
  v_enterprise_opts integer;
  v_data_qual_opts  integer;
  v_connector_opts  integer;
  rows_processed    integer;
  v_report_details  boolean;
  v_tlo_report_details  boolean;
  v_is_cluster_db   boolean;
  -- for ReviewLite output
  v_grep_me_prefix varchar2(400) := '&&GREP_PREFIX.,';
  v_option_name varchar2(20) := 'OWB,';
  v_feature_name varchar2(100);
  v_feature_type varchar2(20);
  --
  v_locname         varchar2(255);
  v_connuser        varchar2(4000);
  v_servicename     varchar2(4000);
  v_host            varchar2(4000);
  v_port            varchar2(4000);

  CURSOR schema_array IS                                                                                                                          --=============list schemas
  SELECT owner
  FROM dba_tables WHERE table_name = 'CMPSYSCLASSES';

  BEGIN
    dbms_output.enable(1000000);
    v_report_details := true;
    v_tlo_report_details := false;
    v_tokyo_version  := '11.1';
    v_paris_vers     := '10.2';
    v_oldtahoe_vers  := '11.0';
    v_tahoe_version  := '11.2';
    v_is_cluster_db  := dbms_utility.is_cluster_database;                                                                                         --=======================check for RAC

    -- database vershion check
    for c_ in (select banner from v$version where banner like 'Oracle%')
    loop
      if instr(c_.banner, 'Release 7') > 0 or instr(c_.banner, 'Release 8') > 0 then
        dbms_output.put_line(v_grep_me_prefix || v_option_name || 'VERSION_CHECK_ERR,,,The script should be run on Oracle9 or newer.');
        return;
      end if;
    end loop;

    select instance_name,host_name into v_i_name, v_h_name
    from sys.v_$instance;

    if v_is_cluster_db = true then
      dbms_output.put_line(v_grep_me_prefix || v_option_name || 'RAC,,,YES');
    else
      dbms_output.put_line(v_grep_me_prefix || v_option_name || 'RAC,,,NO');
    end if;

    OPEN schema_array;

    c_installed_ver := dbms_sql.open_cursor;
    c_workspaces    := dbms_sql.open_cursor;
    c_deployment    := dbms_sql.open_cursor;
    c_execution     := dbms_sql.open_cursor;
    c_pluggable_map := dbms_sql.open_cursor;
    c_transportable := dbms_sql.open_cursor;
    c_schedule      := dbms_sql.open_cursor;
    c_scd_dimension := dbms_sql.open_cursor;
    c_user_def_FCO  := dbms_sql.open_cursor;
    c_user_def_SCO  := dbms_sql.open_cursor;
    c_map_operator  := dbms_sql.open_cursor;
    c_pf_activity   := dbms_sql.open_cursor;
    c_icon_set      := dbms_sql.open_cursor;
    c_streams       := dbms_sql.open_cursor;
    c_spatial       := dbms_sql.open_cursor;
    c_data_profile  := dbms_sql.open_cursor;
    c_data_rule     := dbms_sql.open_cursor;
    c_data_auditor  := dbms_sql.open_cursor;
    c_miv_connector := dbms_sql.open_cursor;
    c_sap_connector := dbms_sql.open_cursor;
    c_loc_report    := dbms_sql.open_cursor;
    c_hetero        := dbms_sql.open_cursor;
    c_webservice    := dbms_sql.open_cursor;
    c_copybook      := dbms_sql.open_cursor;
    c_dimcube       := dbms_sql.open_cursor;
    c_realtime       := dbms_sql.open_cursor;
    c_chunk       := dbms_sql.open_cursor;
    c_obiee       := dbms_sql.open_cursor;
    v_schema_cnt    := 0;

    <<owb_schema_loop>>
    LOOP -- For each valid schema...                                                                                                              ==============LOOP through schemas
      FETCH schema_array INTO v_schema;
      EXIT WHEN schema_array%notfound;

      begin
      -- Determine if current schema is valid (contains CMPInstallation_V view)
      dbms_sql.parse(c_installed_ver,
                              'select installedversion, name
                               from '|| v_schema || '.CMPInstallation_v',
                              dbms_sql.native);
      dbms_sql.define_column(c_installed_ver, 1, v_version, 15);
      dbms_sql.define_column(c_installed_ver, 2, v_product, 25);
      rows_processed := dbms_sql.execute ( c_installed_ver );
      dbms_output.put_line('');
      dbms_output.put_line(v_grep_me_prefix || v_option_name || 'REPOSITORY~HEADER,SQLCODE,SQLERRM,schema,comment,version');
      loop -- Find OWB version.
        if dbms_sql.fetch_rows(c_installed_ver) > 0 then
          dbms_sql.column_value (c_installed_ver, 1, v_version);
          dbms_sql.column_value (c_installed_ver, 2, v_product);
          v_schema_cnt := v_schema_cnt + 1;

          if v_product = 'Oracle Warehouse Builder' then
            dbms_output.put_line(v_grep_me_prefix || v_option_name || 'REPOSITORY,,,' || v_schema || ',"contains a repository version","' || v_version || '"');  --================print if schema contains repository
            exit;
          end if;
        else
          exit;
        end if;
      end loop;
      exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'REPOSITORY,' || SQLCODE || ',' || SQLERRM || ',' || v_schema);
      end;

      --
      -- Establish a loop here to iterate on workspaceID if schema is OWBSYS.
      -- If so, all feature checks compute option use per WS Owner/WS Name.
      --
      if v_schema = 'OWBSYS' then
        dbms_sql.parse(c_workspaces,
                                 'select user_name, workspace_name, workspace_Id
                                  from '|| v_schema || '.workspace_assignment
                                  where isworkspaceowner = 1
                                  and workspace_Id > 1
                                  order by user_name, workspace_name, workspace_Id',
                                 dbms_sql.native);
        dbms_sql.define_column(c_workspaces, 1, v_workspace_owner, 255);
        dbms_sql.define_column(c_workspaces, 2, v_workspace_name, 255);
        dbms_sql.define_column(c_workspaces, 3, v_workspace_id);
        rows_processed := dbms_sql.execute(c_workspaces);
        v_sfx := '_r';
        v_suffix := '_r';
        v_where_and := ' and ';
      else
        v_sfx := '_v';
        v_suffix := '_v';
        v_where_and := ' where ';
      end if;

      -- Checks for deployment
      begin
      if instr(v_version, v_paris_vers) = 1 then
        dbms_sql.parse(c_deployment,
                                'select count(*)
                                 from '|| v_schema || '.all_RT_AUDIT_DEPLOYMENTS ',
                                dbms_sql.native);
      else
        dbms_sql.parse(c_deployment,
                                'select count(*)
                                 from '|| v_schema || '.OWB$WB_RT_AUDIT_DEPLOYMENTS ',
                                dbms_sql.native);
      end if;
      dbms_sql.define_column(c_deployment, 1, v_objcnt);
      rows_processed := dbms_sql.execute(c_deployment);
      dbms_output.put_line('');
      dbms_output.put_line(v_grep_me_prefix || v_option_name || 'OBJECTS_DEPLOYED~HEADER,SQLCODE,SQLERRM,schema,comment,objects_count');
      loop -- Count deployment objects.
        if dbms_sql.fetch_rows(c_deployment) > 0 then
          dbms_sql.column_value (c_deployment, 1, v_objcnt);
            if v_report_details = true then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'OBJECTS_DEPLOYED,,,' || v_schema || ',"design-time objects deployed to this instance",' ||  v_objcnt); -- print number of objects deployed
            end if;
            exit;
        else
          exit;
        end if;
      end loop;
      exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'OBJECTS_DEPLOYED,' || SQLCODE || ',' || SQLERRM || ',' || v_schema);
      end;

      -- Checks for execution
      begin
      if instr(v_version,v_paris_vers) = 1 then
        dbms_sql.parse(c_execution,'select count(*)
                                                   from ' || v_schema || '.all_RT_AUDIT_EXECUTIONS ',
                                                   dbms_sql.native);
      else
        dbms_sql.parse(c_execution,'select count(*)
                                                   from ' || v_schema || '.OWB$WB_RT_AUDIT_EXECUTIONS ',
                                                   dbms_sql.native);
      end if;
      dbms_sql.define_column(c_execution, 1, v_objcnt);
      rows_processed := dbms_sql.execute ( c_execution );
      dbms_output.put_line('');
      dbms_output.put_line(v_grep_me_prefix || v_option_name || 'JOBS_RUN~HEADER,SQLCODE,SQLERRM,schema,comment,jobs_count');
      loop -- Count deployment objects.
        if dbms_sql.fetch_rows(c_execution) > 0 then
          dbms_sql.column_value (c_execution, 1, v_objcnt);
            if v_report_details = true then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'JOBS_RUN,,,' || v_schema || ',"job run on this instance",' || to_char(v_objcnt));  --================ print number of jobs run on instance
            end if;
            exit;
        else
          exit;
        end if;
      end loop;
      exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'JOBS_RUN,' || SQLCODE || ',' || SQLERRM || ',' || v_schema);
      end;

      v_workspace_cnt := 0;

      <<owb_workspace_loop>>
      LOOP -- For each OWB 10g R2 schema or OWB 11g workspace
        if v_schema = 'OWBSYS' then
          if dbms_sql.fetch_rows(c_workspaces) > 0 then
            dbms_sql.column_value (c_workspaces, 1, v_workspace_owner);
            dbms_sql.column_value (c_workspaces, 2, v_workspace_name);
            dbms_sql.column_value (c_workspaces, 3, v_workspace_id);
            v_wksp_cond := 'workspaceID = ' || to_char(v_workspace_id);
            v_workspace_cnt := v_workspace_cnt + 1;
            if instr(v_version, v_tokyo_version) = 1 then
              v_sfx := '';
              v_suffix := 'where ' || v_wksp_cond;
            else
              v_suffix := '_r where ' || v_wksp_cond;
            end if;
          else
            exit owb_workspace_loop;
          end if;
        elsif v_workspace_cnt = 0 then
          v_workspace_cnt := 1;
        else
          exit owb_workspace_loop;
        end if;

        v_enterprise_opts := 0;
        v_data_qual_opts  := 0;
        v_connector_opts  := 0;

        -- Detect any Enterprise ETL option features in use.EAD
         dbms_output.put_line('');
         dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES~HEADER,SQLCODE,SQLERRM,schema,workspace_owner,workspace_name,workspace_id,feature_name,feature_type,feature_usage_quantity');
        -- 1) Check for pluggable maps
        begin
        v_feature_name := '"pluggable maps"';
        v_feature_type := 'ENTERPRISE';
        if instr(v_version,v_tokyo_version) = 1 then
          dbms_sql.parse(c_pluggable_map,
                                   'select count(*)
                                   from '|| v_schema || '.CMPFCOClasses ' || v_suffix ||      --v_suffix was declared earlier and can be "where"or "_r where"
                                   ' and s2_1 = ''CMPPublicSubMap''',
                                  dbms_sql.native);
        else
          dbms_sql.parse(c_pluggable_map,
                                  'select count(*)
                                   from ' || v_schema || '.CMPPublicSubMap' || v_suffix,
                                  dbms_sql.native);
        end if;
        dbms_sql.define_column(c_pluggable_map, 1, v_objcnt);
        rows_processed := dbms_sql.execute ( c_pluggable_map );
        loop -- Count pluggable map objects.
          if dbms_sql.fetch_rows(c_pluggable_map) > 0 then
            dbms_sql.column_value (c_pluggable_map, 1, v_objcnt);
            if v_objcnt > 0 then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type || ',' || v_objcnt);
              v_enterprise_opts := v_enterprise_opts + 1;
              exit;
            end if;
          else
            exit;
          end if;
        end loop;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                     v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type);
        end;

        -- 2) Check for transportable tablespaces, and if any reference FCOs.
        begin
        v_feature_name := '"members in transportable tablespaces"';
        v_feature_type := 'ENTERPRISE';
        if instr(v_version,v_tokyo_version) = 1 then
           dbms_sql.parse(c_transportable,
                                    'select count(*)
                                     from (' || 'select workspaceid, r_11
                                                  from ' || v_schema || '.CMPSCOClasses
                                                  union all
                                                  select workspaceid, r_11
                                                  from ' || v_schema ||'.CMPSCOCfgClasses
                                                  union all
                                                  select workspaceid, r_11
                                                  from ' || v_schema ||'.CMPSCOMapClasses
                                                  union all
                                                  select workspaceid, r_11
                                                  from '|| v_schema ||'.CMPSCOPrpClasses
                                               ) sco
                                   where sco.workspaceID = ' || to_char(v_workspace_id) ||
                                   ' and sco.r_11 in (select i_1
                                                              from ' || v_schema || '.CMPFCOClasses ' || v_suffix ||
                                                             ' and s2_1 = ''CMPWBOracleTTS''
                                                             )',
                                   dbms_sql.native);
        else
          dbms_sql.parse(c_transportable,
                                  'select count(*)
                                   from ' || v_schema || '.secondclassobject' || v_suffix ||
                                   v_where_and || 'firstclassobject ' || 'in (select elementid
                                                                                          from ' || v_schema || '.CMPWBOracleTTS' || v_suffix ||
                                                                                          ')',
                                   dbms_sql.native);
        end if;
        dbms_sql.define_column(c_transportable, 1, v_objcnt);
        rows_processed := dbms_sql.execute ( c_transportable );
        loop -- Count FCO references across all transportable tablespaces.
          if dbms_sql.fetch_rows(c_transportable) > 0 then
            dbms_sql.column_value (c_transportable, 1, v_objcnt);
            if v_objcnt > 0 then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type || ',' || v_objcnt);
              v_enterprise_opts := v_enterprise_opts + 1;
              exit;
            end if;
          else
            exit;
          end if;
        end loop;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                     v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type);
        end;

        -- 3) Check for schedules (calenders)
        begin
         v_feature_name := '"schedules"';
         v_feature_type := 'ENTERPRISE';
        if instr(v_version,v_tokyo_version) = 1 then
          dbms_sql.parse(c_schedule,
                                   'select count(*)
                                   from ' || v_schema || '.CMPFCOClasses ' || v_suffix ||
                                  ' and s2_1 = ''CMPCalendar''',
                                  dbms_sql.native);
        else
          dbms_sql.parse(c_schedule,
                                  'select count(*)
                                   from ' || v_schema||'.CMPCalendar' || v_suffix,
                                  dbms_sql.native);
        end if;
        dbms_sql.define_column(c_schedule, 1, v_objcnt);
        rows_processed := dbms_sql.execute ( c_schedule );
        loop -- Count schedules.
          if dbms_sql.fetch_rows(c_schedule) > 0 then
            dbms_sql.column_value (c_schedule, 1, v_objcnt);
            if v_objcnt > 0 then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type || ',' || v_objcnt);
              v_enterprise_opts := v_enterprise_opts + 1;
              exit;
            end if;
          else
            exit;
          end if;
        end loop;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                     v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type);
        end;

        -- 4) Check for slowly changing dimensions (SCD)
        begin
         v_feature_name := '"slowly changing dimensions"';
         v_feature_type := 'ENTERPRISE';
        if instr(v_version,v_tokyo_version) = 1 then
          dbms_sql.parse(c_scd_dimension,
                                   'select count(*)
                                    from ' || v_schema || '.CMPFCOClasses ' || v_suffix ||
                                   ' and s2_1 in (''CMPDimension'',''CMPWBPsftTreeStrct'')' ||
                                   ' and i_7 in (2,3)',
                                 dbms_sql.native);
        else
          dbms_sql.parse(c_scd_dimension,
                                   'select count(*)
                                   from ' || v_schema || '.CMPDimension' || v_suffix ||
                                   v_where_and || 'slowlychangingtype in (2,3)',
                                  dbms_sql.native);
        end if;
        dbms_sql.define_column(c_scd_dimension, 1, v_objcnt);
        rows_processed := dbms_sql.execute(c_scd_dimension);
        loop -- Count slowly changing (type 2 or 3) dimensions.
          if dbms_sql.fetch_rows(c_scd_dimension) > 0 then
            dbms_sql.column_value (c_scd_dimension, 1, v_objcnt);
            if v_objcnt > 0 then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type || ',' || v_objcnt);
              v_enterprise_opts := v_enterprise_opts + 1;
              exit;
            end if;
          else
            exit;
          end if;
        end loop;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                     v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type);
        end;

        -- 5a) Check for all FCO-type user defined objects (UDOs)
        begin
        v_feature_name := '"user defined objects (weak modules, folders, and other FCOs)"';
        v_feature_type := 'ENTERPRISE';
        if instr(v_version,v_tokyo_version) = 1 then
          dbms_sql.parse(c_user_def_FCO,
                                 'select count(*)
                                 from ' || v_schema || '.CMPFCOClasses ' || v_suffix ||
                               ' and s2_1 in (''CMPWeakFirstClassObject'',''CMPWeakFolder'',''CMPWeakModule'')',
                   dbms_sql.native);
        else
          --Note: weak folders are included in the weak FCO view.
          dbms_sql.parse(c_user_def_FCO,
                                  'select count(*)
                                   from (select 1
                                            from ' || v_schema || '.CMPWeakFirstClassObject' || v_suffix ||
                                          ' union all
                                            select 1
                                            from ' || v_schema || '.CMPWeakModule' || v_suffix ||
                                            ')',
                   dbms_sql.native);
        end if;
        dbms_sql.define_column(c_user_def_FCO, 1, v_objcnt);
        rows_processed := dbms_sql.execute ( c_user_def_FCO );
        loop -- Count user defined objects (UDOs) as Weak FirstClassObjects
          if dbms_sql.fetch_rows(c_user_def_FCO) > 0 then
            dbms_sql.column_value (c_user_def_FCO, 1, v_objcnt);
            if v_objcnt > 0 then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type || ',' || v_objcnt);
              v_enterprise_opts := v_enterprise_opts + 1;
              exit;
            end if;
          else
            exit;
          end if;
        end loop;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                     v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type);
        end;

        -- 5b) Check for all SCO-type user defined objects (UDOs)
        begin
        v_feature_name := '"user defined properties (weak associations, properties, and other SCOs)"';
        v_feature_type := 'ENTERPRISE';
        if instr(v_version, v_tokyo_version) = 1 then
          dbms_sql.parse(c_user_def_SCO,
                                  'select count(*)
                                  from (' || 'select 1
                                               from ' || v_schema || '.CMPSCOClasses ' || v_suffix ||
                                             ' and s2_1 in (''CMPWeakAssociation'')
                                              union all '||
                                              'select 1
                                              from ' || v_schema || '.CMPSCOCfgClasses ' || v_suffix ||
                                              ' and s2_1 in (''CMPWeakSecondClassObject'')
                                              union all ' ||
                                              'select 1
                                               from ' || v_schema||'.CMPSCOPrpClasses '||v_suffix||
                                             ' and s2_1 in (''CMPUserDefinedProperty'')
                                             )',
                                   dbms_sql.native);
        elsif instr(v_version, v_paris_vers) = 1 then
          dbms_sql.parse(c_user_def_SCO,
                                  'select count(*)
                                  from (' || 'select 1
                                              from ' || v_schema||'.CMPWeakSecondClassObject' || v_suffix || '
                                              union all '||
                                              'select 1
                                              from ' || v_schema||'.CMPWeakAssociation' || v_suffix || '
                                              union all '||
                                              'select 1
                                              from ' || v_schema||'.CMPUserDefinedProperty' || v_suffix ||
                                           ')',
                                   dbms_sql.native);
        else
          -- Note: Tahoe no longer includes CMPUserDefinedProperty
          dbms_sql.parse(c_user_def_SCO,
                                  'select count(*)
                                   from ('|| 'select 1
                                               from ' || v_schema || '.CMPWeakSecondClassObject' || v_suffix ||
                                              ' union all ' ||
                                               'select 1
                                               from ' || v_schema || '.CMPWeakAssociation' || v_suffix || ')',
                                  dbms_sql.native);
        end if;
        dbms_sql.define_column(c_user_def_SCO, 1, v_objcnt);
        rows_processed := dbms_sql.execute ( c_user_def_SCO );
        loop -- Count user defined objects (UDOs) as Weak SCO-type objects
          if dbms_sql.fetch_rows(c_user_def_SCO) > 0 then
            dbms_sql.column_value (c_user_def_SCO, 1, v_objcnt);
            if v_objcnt > 0 then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type || ',' || v_objcnt);
              v_enterprise_opts := v_enterprise_opts + 1;
              exit;
            end if;
          else
            exit;
          end if;
        end loop;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                     v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type);
        end;

        -- 6) Check for EETL-specific map operators
        begin
        v_feature_name := '"EETL-specific map operators"';
        v_feature_type := 'ENTERPRISE';
        if instr(v_version,v_tokyo_version) = 1 then
          dbms_sql.parse(c_map_operator,
                                  'select count(*)
                                  from ' || v_schema || '.CMPSCOMapClasses '|| v_suffix ||
                                ' and s2_1 in (''CMPMapOperator'')
                                  and (instr(s2_4,''userTypes.IteratorOperator'')>0 or
                                         instr(s2_4,''userTypes.ExpandObject'')>0 or
                                         instr(s2_4,''userTypes.ConstructObject'')>0
                                         )',
                                dbms_sql.native);
        else
          dbms_sql.parse(c_map_operator,
                                 'select count(*)
                                 from ' || v_schema || '.CMPMapOperator' || v_suffix ||
                                 v_where_and || ' (instr(strongtypename,''userTypes.IteratorOperator'')>0 or
                                                         instr(strongtypename,''userTypes.ExpandObject'')>0 or
                                                         instr(strongtypename,''userTypes.ConstructObject'')>0)',
                                dbms_sql.native);
        end if;
        dbms_sql.define_column(c_map_operator, 1, v_objcnt);
        rows_processed := dbms_sql.execute ( c_map_operator );
        loop -- Count EETL-specific map operators
          if dbms_sql.fetch_rows(c_map_operator) > 0 then
            dbms_sql.column_value (c_map_operator, 1, v_objcnt);
            if v_objcnt > 0 then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type || ',' || v_objcnt);
              v_enterprise_opts := v_enterprise_opts + 1;
              exit;
            end if;
          else
            exit;
          end if;
        end loop;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                     v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type);
        end;

        -- 6a) Check for EETL-specific XML target map operators
        begin
        v_feature_name := '"EETL-specific XML target operators"';
        v_feature_type := 'ENTERPRISE';
        if instr(v_version,v_tokyo_version) = 1 then
          dbms_sql.parse(c_map_operator,
                                 'select count(*)
                                  from (select distinct r_15
                                          from ' || v_schema || '.CMPSCOPRPCLASSES ' || v_suffix ||
                                         ' and s2_1 in (''CMPStringPropertyValue'')
                                          and s4_1=''8i.MAPPING.FILE.OUTPUT_AS_XML'' and s3_4=''true''
                                         )',
                                 dbms_sql.native);
        else
          dbms_sql.parse(c_map_operator,
                                   'select count(*)
                                   from (select distinct firstclassobject
                                           from ' || v_schema || '.CMPStringPropertyvalue' || v_suffix || v_where_and ||
                                         ' logicalname=''8i.MAPPING.FILE.OUTPUT_AS_XML'' and value=''true''
                                          )',
                                   dbms_sql.native);
        end if;
        dbms_sql.define_column(c_map_operator, 1, v_objcnt);
        rows_processed := dbms_sql.execute ( c_map_operator );
        loop -- Count EETL-specific map operators
          if dbms_sql.fetch_rows(c_map_operator) > 0 then
            dbms_sql.column_value (c_map_operator, 1, v_objcnt);
            if v_objcnt > 0 then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type || ',' || v_objcnt);
              v_enterprise_opts := v_enterprise_opts + 1;
              exit;
            end if;
          else
            exit;
          end if;
        end loop;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                     v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type);
        end;

        -- 6b) Check for EETL-specific usage of target load ordering
        begin
        v_feature_name := '"EETL-specific usage of Target Load Ordering"';
        v_feature_type := 'ENTERPRISE';
        if instr(v_version,v_tokyo_version) = 1 then
          dbms_sql.parse(c_map_operator,
                                 'select count(*) from (select distinct r_11 from '||
                                 v_schema||'.CMPSCOPRPCLASSES '||v_suffix||
                                 ' and s2_1 in (''CMPStringPropertyValue'')
                                  and s4_1=''MAP.TARGET_LOAD_ORDER'' and ((s3_4 is not null) AND instr(s3_4,'','') > 0)
                                  and r_11 not in (select distinct r_15
                                                          from ' || v_schema || '.CMPSCOPRPCLASSES ' || v_suffix ||
                                                         ' and s2_1 in (''CMPPhysicalObject'')
                                                          and i_1 in (select r_11
                                                                         from ' || v_schema || '.CMPSCOPRPCLASSES '|| v_suffix ||
                                                                         ' and s2_1 in (''CMPStringPropertyValue'')
                                                                           and s4_1 like ''%USETLO'' and s3_4=''false''))
                                                                         MINUS
                                                                         select distinct r_11
                                                                         from ' || v_schema || '.CMPSCOPRPCLASSES' || v_sfx || ' pv,
                                                                                 (select i_1, s2_4
                                                                                 from ' || v_schema || '.CMPSCOMapClasses ' || v_suffix ||
                                                                                 v_where_and || ' s2_1 in (''CMPMapOperator'') and (instr(s2_4,''Dimension'')>0)) op
                                                                         where pv.r_15=op.i_1 AND s4_1 = ''SCE.PARMETERS.LOADTYPE'' and (s3_4 in (''TYPE1'',''TYPE2'',''TYPE3''))
                                                                         and s2_1 in (''CMPStringPropertyValue'')
                                                                        MINUS
                                                                        select i_1
                                                                        from ' || v_schema || '.CMPFCOClasses ' || v_suffix ||
                                                                           ' and s2_1 = ''CMPDataRuleMap''
                                                                         ) ',
                                 dbms_sql.native);
        elsif instr(v_version,v_paris_vers) = 1 then
          dbms_sql.parse(c_map_operator,
                                  'select count(*)
                                   from (select distinct firstclassobject
                                           from ' || v_schema || '.CMPStringPropertyvalue' || v_suffix ||
                                           v_where_and || ' logicalname=''MAP.TARGET_LOAD_ORDER''
                                           and ((value is not null) AND instr(value,'','') > 0)
                                           and firstclassobject not in (select firstclassobject
                                                                                    from ' || v_schema || '.cmpstringpropertyvalue' || v_suffix ||
                                                                                    v_where_and || ' logicalname like ''%USETLO''
                                                                                    and value=''false'')
                                                                                    MINUS
                                                                                    select distinct firstclassobject
                                                                                    from ' || v_schema || '.CMPStringPropertyvalue' || v_sfx || ' pv,
                                                                                    (select elementid,strongtypename
                                                                                      from ' || v_schema || '.CMPMapOperator' || v_suffix ||
                                                                                      v_where_and || ' (instr(strongtypename,''Dimension'')>0)
                                                                                      ) op
                                                                                    where pv.propertyowner=op.elementid
                                                                                    AND LOGICALNAME = ''SCE.PARMETERS.LOADTYPE''
                                                                                    and (VALUE in (''TYPE1'',''TYPE2'',''TYPE3''))
                                                                                    MINUS
                                                                                    select elementid
                                                                                    from '|| v_schema || '.CMPDataRuleMap' || v_suffix ||
                                                                                 ')',
                                   dbms_sql.native);
        else
          dbms_sql.parse(c_map_operator,
                                  'select count(*)
                                   from (select distinct firstclassobject
                                            from ' || v_schema || '.CMPStringPropertyvalue' || v_sfx || ' pv,
                                                     (select distinct logicalobject, value
                                                      from ' || v_schema || '.cmpphysicalobject_r cpo, '|| v_schema||'.cmpstringpropertyvalue_r cpv
                                                      where cpo.' || v_wksp_cond || ' and cpv.'|| v_wksp_cond ||
                                                     ' and  cpo.elementid=cpv.firstclassobject
                                                      and cpv.logicalname like ''%USETLO''
                                                      ) po,
                                                    (select value
                                                    from '|| v_schema || '.cmpprimitivemodelattribute_r
                                                    where name=''DEFAULTVALUE''
                                                    and attributetypefqn like ''%TARGET_LOAD_ORDER%''
                                                    ) dv
                                            where ' || v_wksp_cond||'
                                                  and logicalname=''MAP.TARGET_LOAD_ORDER'' and ((pv.value is not null) AND instr(pv.value,'','') > 0)
                                                  and firstclassobject = po.logicalobject(+)
                                                  and (po.value = ''true'' or dv.value=''true'')
                                            MINUS
                                            select distinct firstclassobject
                                            from ' || v_schema || '.CMPStringPropertyvalue' || v_sfx || ' pv,
                                                 (select elementid, strongtypename
                                                  from ' || v_schema || '.CMPMapOperator' || v_suffix ||
                                                  v_where_and || ' (instr(strongtypename,''Dimension'')>0)
                                                  ) op
                                             where pv.propertyowner=op.elementid
                                             AND LOGICALNAME = ''SCE.PARMETERS.LOADTYPE''
                                             and (VALUE in (''TYPE1'',''TYPE2'',''TYPE3''))
                                             MINUS
                                             select elementid from ' || v_schema || '.CMPDataRuleMap' || v_suffix ||
                                             ')',
                                  dbms_sql.native);
        end if;
        dbms_sql.define_column(c_map_operator, 1, v_objcnt);
        rows_processed := dbms_sql.execute ( c_map_operator );
        loop -- Count EETL-specific map operators
          if dbms_sql.fetch_rows(c_map_operator) > 0 then
            dbms_sql.column_value (c_map_operator, 1, v_objcnt);
            if v_objcnt > 0 then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type || ',' || v_objcnt);
              v_enterprise_opts := v_enterprise_opts + 1;
              exit;
            end if;
          else
            exit;
          end if;
        end loop;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                     v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type);
        end;

        -- 6c) Check for Multi Configuration
        begin
        v_feature_name := '"EETL-specific usage of Configurations (Multi-Config)"';
        v_feature_type := 'ENTERPRISE';
        if instr(v_version,v_tokyo_version) = 1 then
          dbms_sql.parse(c_map_operator,
                                  'select count(*)
                                   from (select r_17,count(*) c
                                            from ' || v_schema || '.CMPFCOClasses ' || v_suffix ||
                                           ' and s2_1 in (''CMPNamedConfiguration'')
                                            group by r_17
                                            )
                                    where c >1',
                                   dbms_sql.native);
        else
          dbms_sql.parse(c_map_operator,
                                  'select count(*)
                                   from (select owningproject,count(*) c
                                            from ' || v_schema || '.CMPNamedConfiguration'||v_suffix ||
                                            v_where_and || ' 1=1
                                            group by owningproject
                                          )
                                   where c >1',
                                  dbms_sql.native);
        end if;
        dbms_sql.define_column(c_map_operator, 1, v_objcnt);
        rows_processed := dbms_sql.execute ( c_map_operator );
        loop -- Count EETL-specific map operators
          if dbms_sql.fetch_rows(c_map_operator) > 0 then
            dbms_sql.column_value (c_map_operator, 1, v_objcnt);
            if v_objcnt > 0 then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type || ',' || v_objcnt);
              v_enterprise_opts := v_enterprise_opts + 1;
              exit;
            end if;
          else
            exit;
          end if;
        end loop;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                     v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type);
        end;

        -- 7) Check for EETL-specific process flow activities (exclude Tasks from Experts!)
        begin
        v_feature_name := '"EETL-specific process flow activities"';
        v_feature_type := 'ENTERPRISE';
        if instr(v_version,v_tokyo_version) = 1 then
          dbms_sql.parse(c_pf_activity,
                                  'select count(*)
                                   from ' || v_schema||'.CMPSCOCfgClasses '|| v_suffix ||
                                   ' and s2_1 in (''CMPProcessActivity'')
                                    and (instr(s2_4,''processFlow.ASSIGN'') > 0 or
                                            instr(s2_4,''processFlow.NOTIFICATION'') > 0 or
                                            instr(s2_4,''processFlow.ROUTE'') > 0 or
                                            instr(s2_4,''processFlow.FOR_LOOP'') > 0 or
                                            instr(s2_4,''processFlow.WHILE_LOOP'') > 0 or
                                            instr(s2_4,''processFlow.SET_STATUS'') > 0
                                           )',
                                   dbms_sql.native);
        else
          dbms_sql.parse(c_pf_activity,
                                  'select count(*)
                                   from ' || v_schema || '.CMPProcessActivity' || v_suffix ||
                                   v_where_and || ' classname != ''CMPTask''
                                   and (instr(strongtypename,''processFlow.ASSIGN'')>0 or
                                          instr(strongtypename,''processFlow.NOTIFICATION'')>0 or
                                          instr(strongtypename,''processFlow.ROUTE'')>0 or
                                          instr(strongtypename,''processFlow.FOR_LOOP'')>0 or
                                          instr(strongtypename,''processFlow.WHILE_LOOP'')>0 or
                                          instr(strongtypename,''processFlow.SET_STATUS'')>0
                                         )',
                   dbms_sql.native);
        end if;
        dbms_sql.define_column(c_pf_activity, 1, v_objcnt);
        rows_processed := dbms_sql.execute ( c_pf_activity );
        loop -- Count EETL-specific process flow activities
          if dbms_sql.fetch_rows(c_pf_activity) > 0 then
            dbms_sql.column_value (c_pf_activity, 1, v_objcnt);
            if v_objcnt > 0 then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type || ',' || v_objcnt);
              v_enterprise_opts := v_enterprise_opts + 1;
              exit;
            end if;
          else
            exit;
          end if;
        end loop;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                     v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type);
        end;

        -- 8) Check for IconSets
        begin
        v_feature_name := '"icon sets"';
        v_feature_type := 'ENTERPRISE';
        if instr(v_version,v_tokyo_version) = 1 then
          dbms_sql.parse(c_icon_set,'select count(*) from '||
                   v_schema||'.CMPFCOClasses '||v_suffix||
                   ' and s2_1 in (''CMPIcon'')',
                   dbms_sql.native);
        else
          dbms_sql.parse(c_icon_set,'select count(*) from '||
                   v_schema||'.CMPIcon'||v_suffix,
                   dbms_sql.native);
        end if;
        dbms_sql.define_column(c_icon_set, 1, v_objcnt);
        rows_processed := dbms_sql.execute ( c_icon_set );
        loop -- Count icon sets
          if dbms_sql.fetch_rows(c_icon_set) > 0 then
            dbms_sql.column_value (c_icon_set, 1, v_objcnt);
            if v_objcnt > 0 then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type || ',' || v_objcnt);
              v_enterprise_opts := v_enterprise_opts + 1;
              exit;
            end if;
          else
            exit;
          end if;
        end loop;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                     v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type);
        end;

        -- 9) Check for Streams functions
        begin
        v_feature_name := '"streams mapping operators"';
        v_feature_type := 'ENTERPRISE';
        if instr(v_version,v_tokyo_version) = 1 then
          dbms_sql.parse(c_streams,
                                  'select count(*)
                                  from ' || v_schema || '.CMPSCOMapClasses ' || v_suffix ||
                                ' and s2_1 = ''CMPMapOperator''
                                 and r_17 in (select i_1
                                                    from ' || v_schema || '.CMPFCOClasses ' || v_suffix ||
                                                   ' and s2_1 = ''CMPFunction''
                                                    and s2_3 = ''REPLICATE''
                                                   )',
                                 dbms_sql.native);
        else
          dbms_sql.parse(c_streams,
                                  'select count(*)
                                   from '|| v_schema||'.CMPMapOperator' || v_suffix ||
                                   v_where_and || ' referencingobject in (select elementid
                                                                                         from '|| v_schema || '.CMPFunction' || v_suffix ||
                                                                                         v_where_and || ' name = ''REPLICATE''
                                                                                        )',
                                  dbms_sql.native);
        end if;
        dbms_sql.define_column(c_streams, 1, v_objcnt);
        rows_processed := dbms_sql.execute ( c_streams );
        loop -- Count icon sets
          if dbms_sql.fetch_rows(c_streams) > 0 then
            dbms_sql.column_value (c_streams, 1, v_objcnt);
            if v_objcnt > 0 then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type || ',' || v_objcnt);
              v_enterprise_opts := v_enterprise_opts + 1;
              exit;
            end if;
          else
            exit;
          end if;
        end loop;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                     v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type);
        end;

        --10) Check for Spatial functions
        begin
        v_feature_name := '"spatial mapping operators"';
        v_feature_type := 'ENTERPRISE';
        if instr(v_version,v_tokyo_version) = 1 then
          dbms_sql.parse(c_streams,
                                  'select count(*)
                                   from ' || v_schema || '.CMPSCOMapClasses '|| v_suffix ||
                                 ' and s2_1 = ''CMPMapOperator''
                                   and r_17 in (select i_1
                                                     from '|| v_schema||'.CMPFCOClasses ' || v_suffix ||
                                                   ' and s2_1 = ''CMPFunction'''||
                                                   ' and s2_3 in (''SDO_AGGR_CENTROID'',''SDO_AGGR_CONVEXHULL'',''SDO_AGGR_MBR'',''SDO_AGGR_UNION'')
                                                   )',
                                 dbms_sql.native);
        else
          dbms_sql.parse(c_streams,
                                  'select count(*)
                                   from ' || v_schema || '.CMPMapOperator' || v_suffix ||
                                   v_where_and || ' referencingobject in (select elementid
                                                                                         from '|| v_schema || '.CMPFunction' || v_suffix ||
                                                                                         v_where_and || ' name in (''SDO_AGGR_CENTROID'',''SDO_AGGR_CONVEXHULL'',''SDO_AGGR_MBR'',''SDO_AGGR_UNION'')
                                                                                        )',
                                  dbms_sql.native);
        end if;
        dbms_sql.define_column(c_streams, 1, v_objcnt);
        rows_processed := dbms_sql.execute ( c_streams );
        loop -- Count icon sets
          if dbms_sql.fetch_rows(c_streams) > 0 then
            dbms_sql.column_value (c_streams, 1, v_objcnt);
            if v_objcnt > 0 then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type || ',' || v_objcnt);
              v_enterprise_opts := v_enterprise_opts + 1;
              exit;
            end if;
          else
            exit;
          end if;
        end loop;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                     v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type);
        end;

        --11) Check for Native support for heterogeneous database
        begin
        v_feature_name := '"heterogeneous database modules"';
        v_feature_type := 'ENTERPRISE';
        if instr(v_version,v_tahoe_version) = 1 then
          dbms_sql.parse(c_hetero,
                                  'select count(*)
                                  from '|| v_schema || '.CMPINSTALLEDMODULE' || v_suffix ||
                                  v_where_and || ' seeded=0
                                  and (instr(strongtypename,''DB2UDBNativeModule'')>0 or
                                          instr(strongtypename,''GenericNativeModule'')>0 or
                                          instr(strongtypename,''KMMapModule'')>0 or
                                          instr(strongtypename,''SQLServerNativeModule'')>0 or
                                          instr(strongtypename,''CMPKMTaskFlowInstalledModule'')>0
                                          )',
                                   dbms_sql.native);
          dbms_sql.define_column(c_hetero, 1, v_objcnt);
          rows_processed := dbms_sql.execute ( c_hetero );
          loop
            if dbms_sql.fetch_rows(c_hetero) > 0 then
              dbms_sql.column_value (c_hetero, 1, v_objcnt);
              if v_objcnt > 0 then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type || ',' || v_objcnt);
                v_enterprise_opts := v_enterprise_opts + 1;
                exit;
              end if;
            else
              exit;
            end if;
          end loop;
        end if;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                     v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type);
        end;

        --12) Check for Web Services - excluding seeded ones
        begin
        v_feature_name := '"web services"';
        v_feature_type := 'ENTERPRISE';
        if instr(v_version,v_tahoe_version) = 1 then
          dbms_sql.parse(c_webservice,
                                  'select count(*)
                                  from ' || v_schema || '.CMPWEBSERVICE' || v_suffix ||
                                  v_where_and || 'seeded=0',
                                  dbms_sql.native);
          dbms_sql.define_column(c_webservice, 1, v_objcnt);
          rows_processed := dbms_sql.execute ( c_webservice );
          loop
            if dbms_sql.fetch_rows(c_webservice) > 0 then
              dbms_sql.column_value (c_webservice, 1, v_objcnt);
              if v_objcnt > 0 then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type || ',' || v_objcnt);
                v_enterprise_opts := v_enterprise_opts + 1;
                exit;
              end if;
            else
              exit;
            end if;
          end loop;
        end if;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                     v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type);
        end;

        --13) Cobol copybooks
        begin
        v_feature_name := '"flat files imported from Cobol copybooks"';
        v_feature_type := 'ENTERPRISE';
        if instr(v_version,v_tahoe_version) = 1 then
          dbms_sql.parse(c_copybook,
                                 'select count(*)
                                 from '|| v_schema || '.cmpwbfile' || v_suffix ||
                                 v_where_and || 'length(copybooksource)>0',
                                 dbms_sql.native);
          dbms_sql.define_column(c_copybook, 1, v_objcnt);
          rows_processed := dbms_sql.execute ( c_copybook );
          loop
            if dbms_sql.fetch_rows(c_copybook) > 0 then
              dbms_sql.column_value (c_copybook, 1, v_objcnt);
              if v_objcnt > 0 then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type || ',' || v_objcnt);
                v_enterprise_opts := v_enterprise_opts + 1;
                exit;
              end if;
            else
              exit;
            end if;
          end loop;
        end if;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                     v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type);
        end;

        --14) OLAP with Cube MVs
        begin
        v_feature_name := '"Dimensions/Cubes storing data in OLAP cube-organized materialized views"';
        v_feature_type := 'ENTERPRISE';
        if instr(v_version,v_tahoe_version) = 1 then
          dbms_sql.parse(c_dimcube,
                                  'select count(1)
                                  from (select elementid
                                          from ' || v_schema || '.CMPDimension' || v_suffix ||
                                          v_where_and || 'implementation=''HOLAP''
                                         UNION
                                         select elementid
                                         from '|| v_schema || '.CMPCube' || v_suffix||
                                         v_where_and || 'implementation=''HOLAP''
                                         ) ',
                                     dbms_sql.native);
          dbms_sql.define_column(c_dimcube, 1, v_objcnt);
          rows_processed := dbms_sql.execute ( c_dimcube );
          loop
            if dbms_sql.fetch_rows(c_dimcube) > 0 then
              dbms_sql.column_value (c_dimcube, 1, v_objcnt);
              if v_objcnt > 0 then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type || ',' || v_objcnt);
                v_enterprise_opts := v_enterprise_opts + 1;
                exit;
              end if;
            else
              exit;
            end if;
          end loop;
        end if;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                     v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type);
        end;

        --15) Orphan management
        begin
        v_feature_name := '"Dimensions/Cubes defining orphan management policies"';
        v_feature_type := 'ENTERPRISE';
        if instr(v_version,v_tahoe_version) = 1 then
          dbms_sql.parse(c_dimcube,
                                  'select count(1)
                                  from (select elementid
                                          from '|| v_schema||'.CMPDimension' || v_suffix ||
                                          v_where_and || ' (LoadPolicyForInvalidKey not like ''NO_MAINTENANCE'' or
                                          LoadPolicyForNULL not like ''NO_MAINTENANCE'' or
                                          RemovePolicy not like ''NO_MAINTENANCE'')
                                          UNION
                                         select elementid
                                         from ' || v_schema||'.CMPCube'|| v_suffix ||
                                         v_where_and || ' (LoadPolicyForInvalidKey not like ''NO_MAINTENANCE'' or
                                                                  LoadPolicyForNULL not like ''NO_MAINTENANCE'' )
                                                                  ) ',
                                   dbms_sql.native);
          dbms_sql.define_column(c_dimcube, 1, v_objcnt);
          rows_processed := dbms_sql.execute ( c_dimcube );
          loop
            if dbms_sql.fetch_rows(c_dimcube) > 0 then
              dbms_sql.column_value (c_dimcube, 1, v_objcnt);
              if v_objcnt > 0 then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type || ',' || v_objcnt);
                v_enterprise_opts := v_enterprise_opts + 1;
                exit;
              end if;
            else
              exit;
            end if;
          end loop;
        end if;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                     v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type);
        end;

        --16) Real-time mappings
        begin
        v_feature_name := '"real-time mappings using advanced queues"';
        v_feature_type := 'ENTERPRISE';
        if instr(v_version,v_tahoe_version) = 1 then
          dbms_sql.parse(c_realtime,
                                  'select count(*)
                                  from ' || v_schema || '.CMPMap' || v_suffix ||
                                  v_where_and || ' instr(strongtypename,''CMPTrickleFeedMap'')>0 ',
                                  dbms_sql.native);
          dbms_sql.define_column(c_realtime, 1, v_objcnt);
          rows_processed := dbms_sql.execute ( c_realtime );
          loop
            if dbms_sql.fetch_rows(c_realtime) > 0 then
              dbms_sql.column_value (c_realtime, 1, v_objcnt);
              if v_objcnt > 0 then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type || ',' || v_objcnt);
                v_enterprise_opts := v_enterprise_opts + 1;
                exit;
              end if;
            else
              exit;
            end if;
          end loop;
        end if;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                     v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type);
        end;

        --17) Data chunking feature
        begin
        v_feature_name := '"mappings with chunking options"';
        v_feature_type := 'ENTERPRISE';
        if instr(v_version,v_tahoe_version) = 1 then
          dbms_sql.parse(c_chunk,
                                  'select count(*)
                                  from ' || v_schema || '.cmpstringpropertyvalue' || v_suffix ||
                                  v_where_and || ' logicalname like ''8i.MAPPINGS.PLSQLSTEP.PARALLELCHUNKINGPARAMS.CHUNKINGMETHOD.CHUNKBYCONTROLLER''
                                  and value not like ''NONE'' ',
                                  dbms_sql.native);
          dbms_sql.define_column(c_chunk, 1, v_objcnt);
          rows_processed := dbms_sql.execute ( c_chunk );
          loop
            if dbms_sql.fetch_rows(c_chunk) > 0 then
              dbms_sql.column_value (c_chunk, 1, v_objcnt);
              if v_objcnt > 0 then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type || ',' || v_objcnt);
                v_enterprise_opts := v_enterprise_opts + 1;
                exit;
              end if;
            else
              exit;
            end if;
          end loop;
        end if;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                     v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type);
        end;

        --18) OBIEE
        begin
        v_feature_name := '"OBIEE modules"';
        v_feature_type := 'ENTERPRISE';
        if instr(v_version,v_tahoe_version) = 1 then
          dbms_sql.parse(c_obiee,
                                  'select count(*)
                                  from '|| v_schema || '.cmpinstalledmodule' || v_suffix ||
                                  v_where_and || ' strongtypename like ''oracle.wh.repos.impl.intelligenceSchema.OBIEESchema''',
                                  dbms_sql.native);
          dbms_sql.define_column(c_obiee, 1, v_objcnt);
          rows_processed := dbms_sql.execute ( c_obiee );
          loop
            if dbms_sql.fetch_rows(c_obiee) > 0 then
              dbms_sql.column_value (c_obiee, 1, v_objcnt);
              if v_objcnt > 0 then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type || ',' || v_objcnt);
                v_enterprise_opts := v_enterprise_opts + 1;
                exit;
              end if;
            else
              exit;
            end if;
          end loop;
        end if;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                     v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type);
        end;

        -- Detect any Data Quality option features in use.
        -- 1) Check for data profiles
        begin
        v_feature_name := '"data profiles"';
        v_feature_type := 'DATA_QUALITY';
        if instr(v_version,v_tokyo_version) = 1 then
          dbms_sql.parse(c_data_profile ,
                                  'select count(*)
                                  from '|| v_schema||'.CMPFCOClasses ' || v_suffix ||
                                 ' and s2_1 = ''CMPProfile''',
                                 dbms_sql.native);
        else
          dbms_sql.parse(c_data_profile ,
                                  'select count(*)
                                  from '|| v_schema || '.CMPProfile' || v_suffix,
                                  dbms_sql.native);
        end if;
        dbms_sql.define_column(c_data_profile , 1, v_objcnt);
        rows_processed := dbms_sql.execute ( c_data_profile  );
        loop -- Count data profiles.
          if dbms_sql.fetch_rows(c_data_profile ) > 0 then
            dbms_sql.column_value (c_data_profile , 1, v_objcnt);
            if v_objcnt > 0 then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type || ',' || v_objcnt);
              v_data_qual_opts := v_data_qual_opts + 1;
              exit;
            end if;
          else
            exit;
          end if;
        end loop;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                     v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type);
        end;

        -- 2) Check for custom data rules (exclude seeded rules)
        begin
        v_feature_name := '"custom data rules"';
        v_feature_type := 'DATA_QUALITY';
        if instr(v_version,v_tokyo_version) = 1 then
          dbms_sql.parse(c_data_rule ,
                                  'select count(*)
                                  from '|| v_schema||'.CMPFCOClasses '|| v_suffix ||
                                 ' and s2_1 = ''CMPBusinessRuleDefinition'''||
                                 ' and b_11 = 0',
                                 dbms_sql.native);
        else
          dbms_sql.parse(c_data_rule ,
                                  'select count(*)
                                  from ' || v_schema||'.CMPBusinessRuleDefinition' || v_suffix ||
                                  v_where_and || 'seeded = 0',
                                  dbms_sql.native);
        end if;
        dbms_sql.define_column(c_data_rule , 1, v_objcnt);
        rows_processed := dbms_sql.execute ( c_data_rule  );
        loop -- Count custom data rules
          if dbms_sql.fetch_rows(c_data_rule ) > 0 then
            dbms_sql.column_value (c_data_rule , 1, v_objcnt);
            if v_objcnt > 0 then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type || ',' || v_objcnt);
              v_data_qual_opts := v_data_qual_opts + 1;
              exit;
            end if;
          else
            exit;
          end if;
        end loop;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                     v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type);
        end;

        -- 3) Check for data auditors
        begin
        v_feature_name := '"data auditors"';
        v_feature_type := 'DATA_QUALITY';
        if instr(v_version,v_tokyo_version) = 1 then
          dbms_sql.parse(c_data_auditor ,
                                  'select count(*)
                                   from ' || v_schema || '.CMPFCOClasses '|| v_suffix ||
                                 ' and s2_1 = ''CMPDataRuleMap''',
                                 dbms_sql.native);
        else
          dbms_sql.parse(c_data_auditor ,
                                  'select count(*)
                                  from ' || v_schema||'.CMPDataRuleMap'|| v_suffix,
                                  dbms_sql.native);
        end if;
        dbms_sql.define_column(c_data_auditor , 1, v_objcnt);
        rows_processed := dbms_sql.execute ( c_data_auditor  );
        loop -- Count data auditors
          if dbms_sql.fetch_rows(c_data_auditor ) > 0 then
            dbms_sql.column_value (c_data_auditor , 1, v_objcnt);
            if v_objcnt > 0 then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type || ',' || v_objcnt);
              v_data_qual_opts := v_data_qual_opts + 1;
              exit;
            end if;
          else
            exit;
          end if;
        end loop;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                     v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type);
        end;

        -- Detect any Connector option features in use.
        -- 1) Check for SAP modules
        begin
        v_feature_name := '"SAP application sources"';
        v_feature_type := 'CONNECTORS';
        if instr(v_version,v_tokyo_version) = 1 then
          dbms_sql.parse(c_sap_connector,
                                  'select count(*)
                                   from '|| v_schema||'.CMPFCOClasses '|| v_suffix ||
                                 ' and s2_1 = ''CMPWBSAPInstalledModule''',
                                 dbms_sql.native);
        else
          dbms_sql.parse(c_sap_connector,
                                  'select count(*)
                                   from '|| v_schema||'.CMPWBSAPInstalledModule' || v_suffix,
                                  dbms_sql.native);
        end if;
        dbms_sql.define_column(c_sap_connector, 1, v_objcnt);
        rows_processed := dbms_sql.execute ( c_sap_connector );
        loop -- Count SAP modules
          if dbms_sql.fetch_rows(c_sap_connector) > 0 then
            dbms_sql.column_value (c_sap_connector, 1, v_objcnt);
            if v_objcnt > 0 then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type || ',' || v_objcnt);
              v_connector_opts := v_connector_opts + 1;
              exit;
            end if;
          else
            exit;
          end if;
        end loop;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                     v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type);
        end;

        -- 2) Check for EBS/PSFT/SIEBEL modules
        --    In Paris/Tokyo, EBS and PSFT are (weak) MIVInstalledModules.
        --    Starting with Tahoe, they are DatabaseModules and may be
        --    distinguished by their StrongTypeName.
        --    SIEBEL modules are also DatabaseModules and first appear in Tahoe.
        begin
        v_feature_name := '"custom CMI adapters"';
        v_feature_type := 'CONNECTORS';
        if instr(v_version,v_tokyo_version) = 1 then
          dbms_sql.parse(c_miv_connector,
                                  'select count(*)
                                   from ' || v_schema || '.CMPFCOClasses '|| v_suffix ||
                                  ' and s2_1 = ''CMPWeakModule''
                                   and s2_4 = ''oracle.wh.repos.impl.application.CMPMIVInstalledModule''',
                                 dbms_sql.native);
        elsif instr(v_version,v_paris_vers) = 1 or
              instr(v_version,v_oldtahoe_vers) = 1 then
          dbms_sql.parse(c_miv_connector,
                                  'select count(*)
                                   from '|| v_schema || '.CMPWeakModule' || v_suffix ||
                                   v_where_and || 'instr(strongtypename,''CMPMIVInstalledModule'')>0',
                                  dbms_sql.native);
        else
          dbms_sql.parse(c_miv_connector,
                                  'select count(*)
                                   from ' || v_schema||'.CMPDatabaseModule' || v_suffix ||
                                   v_where_and || '(instr(strongtypename,''CMPOracleEBSInstalledModule'') > 0 or
                                                           instr(strongtypename,''CMPPeoplesoftInstalledModule'') > 0 or
                                                           instr(strongtypename,''CMPSiebelInstalledModule'') > 0
                                                          )',
                                   dbms_sql.native);
        end if;
        dbms_sql.define_column(c_miv_connector, 1, v_objcnt);
        rows_processed := dbms_sql.execute ( c_miv_connector );
        loop -- Count MIV modules.
          if dbms_sql.fetch_rows(c_miv_connector) > 0 then
            dbms_sql.column_value (c_miv_connector, 1, v_objcnt);
            if v_objcnt > 0 then
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type || ',' || v_objcnt);
              v_connector_opts := v_connector_opts + 1;
              exit;
            end if;
          else
            exit;
          end if;
        end loop;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'FEATURES,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                     v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id || ',' || v_feature_name || ',' || v_feature_type);
        end;


       --============================================================== LOCATIONS =================================================================
        -- collect even if no features have been found
        if (1=1 or v_enterprise_opts > 0  or  v_data_qual_opts > 0 or v_connector_opts  > 0) then
          begin
          dbms_output.put_line('');
          dbms_output.put_line(v_grep_me_prefix || v_option_name || 'LOCATIONS~HEADER,SQLCODE,SQLERRM,schema,workspace_owner,workspace_name,workspace_id,' ||
                                                                                                 'location_name,connection_user,host,port,service_name');
          if instr(v_version,v_tokyo_version) = 1 then
            dbms_sql.parse(c_loc_report,
                                    'select locname, connuser, host, servicename, NVL(port,''1521'') as port
                                    from (select loc.s2_3 as locname, loc.i_1 as locid, spv.s3_4 as connuser, sp1.s3_4 as host, sp2.s3_4 as servicename
                                              from '|| v_schema ||'.CMPFCOClasses loc, ' ||
                                                        v_schema ||'.CMPSCOPrpClasses spv, '||
                                                        v_schema ||'.CMPSCOPrpClasses sp1, '||
                                                        v_schema ||'.CMPSCOPrpClasses sp2 '||
                                              'where loc.' || v_wksp_cond ||
                                              '  and loc.s2_1 in (''CMPLogicalLocation'',''CMPRuntimeLocation'')
                                                and loc.i_1                       = spv.r_15(+)
                                                and spv.' || v_wksp_cond ||
                                              '  and spv.s2_1 = ''CMPStringPropertyValue''
                                                and ''CMPLocation_ConnectAsUser'' = spv.s4_1(+)
                                                and loc.i_1 = sp1.r_15(+)
                                                and sp1.' || v_wksp_cond ||
                                              '  and sp1.s2_1 = ''CMPStringPropertyValue''
                                                and ''CMPLocation_Host'' = sp1.s4_1(+)
                                                and loc.i_1 = sp2.r_15(+)
                                                and sp2.' || v_wksp_cond ||
                                              '  and sp2.s2_1 = ''CMPStringPropertyValue''
                                                and ''CMPLocation_ServiceName''   = sp2.s4_1(+)
                                              ) a,
                                    (select loc.i_1 as locid,  sp3.s3_4 as port
                                     from '|| v_schema || '.CMPFCOClasses loc, ' ||
                                               v_schema || '.CMPSCOPrpClasses sp3 '||
                                    'where loc.' || v_wksp_cond ||
                                    '  and loc.s2_1 in (''CMPLogicalLocation'',''CMPRuntimeLocation'')
                                      and loc.i_1 = sp3.r_15(+)
                                      and sp3.' || v_wksp_cond ||
                                    '  and sp3.s2_1 = ''CMPStringPropertyValue''
                                      and ''CMPLocation_Port'' = sp3.s4_1(+)
                                    ) b
                                    where a.locid = b.locid(+)
                                    order by locname ',
                                   dbms_sql.native);
          elsif instr(v_version,v_paris_vers) = 1 then
            dbms_sql.parse(c_loc_report,
                                    'select loc.name, spv.value as connuser, sp1.value as host, sp2.value as servicename, nvl(sp3.value,''1521'') as port '||
                                    'from '|| v_schema||'.cmplocation' || v_sfx || '  loc, ' ||
                                              v_schema ||'.cmpstringpropertyvalue' || v_sfx || '  spv, ' ||
                                              v_schema ||'.cmpstringpropertyvalue' || v_sfx || '  sp1, ' ||
                                              v_schema ||'.cmpstringpropertyvalue' || v_sfx || '  sp2, ' ||
                                              v_schema ||'.cmpstringpropertyvalue' || v_sfx || '  sp3  ' ||
                                    'where loc.elementid                 = spv.propertyowner(+)
                                      and ''CMPLocation_ConnectAsUser'' = spv.logicalname(+)
                                      and loc.elementid                 = sp1.propertyowner(+)
                                      and ''CMPLocation_Host''          = sp1.logicalname(+)
                                      and loc.elementid                 = sp2.propertyowner(+)
                                      and ''CMPLocation_ServiceName''   = sp2.logicalname(+)
                                      and loc.elementid                 = sp3.propertyowner(+)
                                      and ''CMPLocation_Port''          = sp3.logicalname(+)
                                    order by loc.name ',
                                    dbms_sql.native);
          else
             dbms_sql.parse(c_loc_report,
                                      'select locname, connuser, host, servicename, NVL(port,''1521'') as port
                                        from (select loc.name as locname, loc.elementid as locid, spv.value as connuser, sp1.value as host, sp2.value as servicename
                                                 from '|| v_schema || '.cmplocation' || v_sfx || '  loc
                                                  left join ' || v_schema || '.cmpstringpropertyvalue' || v_sfx || '  spv on loc.elementid  = spv.propertyowner
                                                                                                      and ''CMPLocation_ConnectAsUser'' = spv.logicalname
                                                  left join ' || v_schema || '.cmpstringpropertyvalue' || v_sfx || '  sp1 on loc.elementid  = sp1.propertyowner
                                                                                                      and ''CMPLocation_Host'' = sp1.logicalname
                                                  left join ' || v_schema || '.cmpstringpropertyvalue' || v_sfx || '  sp2 on loc.elementid  = sp2.propertyowner
                                                                                                      and ''CMPLocation_ServiceName'' = sp2.logicalname
                                                  where loc.' || v_wksp_cond || '
                                                  and spv.' || v_wksp_cond || '
                                                  and sp1.' || v_wksp_cond || '
                                                  and sp2.' || v_wksp_cond || '
                                                 ) a
                                        left join (select loc.elementid as locid, sp3.value AS port
                                                       from ' || v_schema || '.cmplocation' || v_sfx || ' loc
                                                       left join ' || v_schema || '.cmpstringpropertyvalue' || v_sfx || '  sp3 on loc.elementid = sp3.propertyowner
                                                            and ''CMPLocation_Port'' = sp3.logicalname
                                                       where loc.' || v_wksp_cond || '
                                                            and sp3.' || v_wksp_cond || '
                                                      ) b on a.locid = b.locid
                                        order by locname',
                                     dbms_sql.native);
          end if;
          dbms_sql.define_column(c_loc_report, 1, v_locname, 255);
          dbms_sql.define_column(c_loc_report, 2, v_connuser, 4000);
          dbms_sql.define_column(c_loc_report, 3, v_host, 4000);
          dbms_sql.define_column(c_loc_report, 4, v_servicename, 4000);
          dbms_sql.define_column(c_loc_report, 5, v_port,4000);
          v_objcnt := 0;
          rows_processed := dbms_sql.execute ( c_loc_report );
          loop -- Count locations
            if dbms_sql.fetch_rows(c_loc_report) > 0 then
              dbms_sql.column_value (c_loc_report, 1, v_locname);
              dbms_sql.column_value (c_loc_report, 2, v_connuser);
              dbms_sql.column_value (c_loc_report, 3, v_host);
              dbms_sql.column_value (c_loc_report, 4, v_servicename);
              dbms_sql.column_value (c_loc_report, 5, v_port);
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'LOCATIONS,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id
                                                    || ',' || v_locname || ',' || v_connuser || ',' || v_host || ',' || v_port || ',' || v_servicename);
              v_objcnt := v_objcnt + 1;
           else
              exit;
            end if;
          end loop;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'LOCATIONS,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                                 v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id);
        end;

          -- print mapings with TLO enabled --
        begin
        if v_tlo_report_details = true then
        dbms_output.put_line(v_grep_me_prefix || v_option_name || 'MAPPINGS_TLP~HEADER,SQLCODE,SQLERRM,schema,workspace_owner,workspace_name,workspace_id,
                                                                 description,location');
        if instr(v_version,v_tokyo_version) = 1 then
          dbms_sql.parse(c_map_operator,
                                  'select s2_3
                                   from ' || v_schema||'.CMPFCOClasses
                                   where i_1 in (select distinct r_11
                                                      from '|| v_schema ||'.CMPSCOPRPCLASSES '|| v_suffix ||
                                                     ' and s2_1 in (''CMPStringPropertyValue'')
                                                      and s4_1=''MAP.TARGET_LOAD_ORDER'' and ((s3_4 is not null) AND instr(s3_4,'','') > 0)'||
                                                     ' and r_11 not in (select distinct r_15
                                                                              from '|| v_schema || '.CMPSCOPRPCLASSES '||v_suffix||
                                                                             ' and s2_1 in (''CMPPhysicalObject'')
                                                                               and i_1 in (select r_11
                                                                                                  from ' || v_schema || '.CMPSCOPRPCLASSES ' || v_suffix ||
                                                                                                   ' and s2_1 in (''CMPStringPropertyValue'')
                                                                                                    and s4_1 like ''%USETLO'' and s3_4=''false''
                                                                                                    )
                                                                                    )
                                                       MINUS
                                                      select distinct r_11
                                                      from '|| v_schema || '.CMPSCOPRPCLASSES' || v_sfx||' pv,
                                                              (select i_1,s2_4
                                                              from '|| v_schema||'.CMPSCOMapClasses '|| v_suffix||
                                                              v_where_and||' s2_1 in (''CMPMapOperator'')
                                                              and (instr(s2_4,''Dimension'')>0)
                                                              ) op
                                                       where pv.r_15=op.i_1
                                                       AND s4_1 = ''SCE.PARMETERS.LOADTYPE'' and (s3_4 in (''TYPE1'',''TYPE2'',''TYPE3''))
                                                       and s2_1 in (''CMPStringPropertyValue'')
                                                      minus
                                                      select i_1
                                                      from ' || v_schema || '.CMPFCOClasses ' || v_suffix ||
                                                      ' and s2_1 = ''CMPDataRuleMap''
                                                      ) ',
                                        dbms_sql.native);
        elsif instr(v_version,v_paris_vers) = 1 then
          dbms_sql.parse(c_map_operator,
                                  'select name
                                  from '|| v_schema||'.cmpmap'|| v_suffix||
                                  v_where_and || ' elementid in (select distinct firstclassobject
                                                                              from ' || v_schema|| '.CMPStringPropertyvalue'|| v_suffix||
                                                                              v_where_and ||' logicalname=''MAP.TARGET_LOAD_ORDER''
                                                                              and ((value is not null)
                                                                              AND instr(value,'','') > 0
                                                                              )
                                   and firstclassobject not in (select firstclassobject
                                                                          from ' || v_schema || '.cmpstringpropertyvalue'|| v_suffix ||
                                                                          v_where_and || ' logicalname like ''%USETLO'' and value=''false''
                                                                          )
                                    MINUS
                                    select distinct firstclassobject
                                    from '|| v_schema ||'.CMPStringPropertyvalue' || v_sfx || ' pv,
                                            (select elementid, strongtypename
                                             from '|| v_schema || '.CMPMapOperator' || v_suffix ||
                                             v_where_and || ' (instr(strongtypename,''Dimension'')>0)
                                             ) op
                                     where pv.propertyowner=op.elementid AND LOGICALNAME = ''SCE.PARMETERS.LOADTYPE'' and (VALUE in (''TYPE1'',''TYPE2'',''TYPE3''))
                                     MINUS
                                    select elementid
                                     from ' || v_schema || '.CMPDataRuleMap'|| v_suffix || ')',
                                    dbms_sql.native);
        else
          dbms_sql.parse(c_map_operator,
                                  'select name
                                  from '|| v_schema || '.cmpmap_r
                                  where elementid in (select distinct firstclassobject
                                                               from '|| v_schema || '.CMPStringPropertyvalue'|| v_sfx || ' pv,
                                                                       (select distinct logicalobject,value
                                                                        from '|| v_schema || '.cmpphysicalobject_r cpo, ' || v_schema ||'.cmpstringpropertyvalue_r cpv
                                                                        where cpo.'|| v_wksp_cond ||'
                                                                            and cpv. '||v_wksp_cond ||
                                                                          ' and  cpo.elementid=cpv.firstclassobject
                                                                            and cpv.logicalname like ''%USETLO''
                                                                       ) po,
                                                                       (select value from ' || v_schema || '.cmpprimitivemodelattribute_r
                                                                        where name=''DEFAULTVALUE''
                                                                        and attributetypefqn like ''%TARGET_LOAD_ORDER%''
                                                                        ) dv
                                                                where ' || v_wksp_cond || '
                                                                and logicalname=''MAP.TARGET_LOAD_ORDER'' and ((pv.value is not null) AND instr(pv.value,'','') > 0)
                                                                and firstclassobject = po.logicalobject(+) and (po.value = ''true'' or dv.value=''true'')
                                                                MINUS
                                                                 select distinct firstclassobject
                                                                 from '|| v_schema ||'.CMPStringPropertyvalue' || v_sfx ||' pv,
                                                                         (select elementid,strongtypename
                                                                          from '|| v_schema || '.CMPMapOperator'|| v_suffix ||
                                                                          v_where_and || ' (instr(strongtypename,''Dimension'')>0)
                                                                          ) op
                                                                where pv.propertyowner=op.elementid AND LOGICALNAME = ''SCE.PARMETERS.LOADTYPE'' and (VALUE in (''TYPE1'',''TYPE2'',''TYPE3''))
                                                                MINUS
                                                                select elementid
                                                                from ' || v_schema || '.CMPDataRuleMap' || v_suffix ||
                                                                ')',
                                                   dbms_sql.native);
        end if;
          dbms_sql.define_column(c_map_operator, 1, v_locname, 255);
          rows_processed := dbms_sql.execute ( c_map_operator );
          loop -- Count locations
            if dbms_sql.fetch_rows(c_map_operator) > 0 then
              dbms_sql.column_value (c_map_operator, 1, v_locname);
              dbms_output.put_line(v_grep_me_prefix || v_option_name || 'MAPPINGS_TLO,,,' || v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id ||
                                                                        ',"Mapping with Target Load Order options",' || v_locname);
           else
              exit;
            end if;
          end loop;
        end if;
        exception when others then dbms_output.put_line(v_grep_me_prefix || v_option_name || 'MAPPINGS_TLO,' || SQLCODE || ',' || SQLERRM || ',' ||
                                                                                                 v_schema || ',' || v_workspace_owner || ',' || v_workspace_name || ',' || v_workspace_id);
        end;
        end if;

    END LOOP owb_workspace_loop;
    END LOOP owb_schema_loop;

    dbms_sql.close_cursor (c_installed_ver);
    dbms_sql.close_cursor (c_workspaces);
    dbms_sql.close_cursor (c_deployment);
    dbms_sql.close_cursor (c_execution);
    dbms_sql.close_cursor (c_pluggable_map);
    dbms_sql.close_cursor (c_transportable);
    dbms_sql.close_cursor (c_schedule);
    dbms_sql.close_cursor (c_scd_dimension);
    dbms_sql.close_cursor (c_user_def_FCO);
    dbms_sql.close_cursor (c_user_def_SCO);
    dbms_sql.close_cursor (c_map_operator);
    dbms_sql.close_cursor (c_pf_activity);
    dbms_sql.close_cursor (c_icon_set);
    dbms_sql.close_cursor (c_streams);
    dbms_sql.close_cursor (c_spatial);
    dbms_sql.close_cursor (c_data_profile);
    dbms_sql.close_cursor (c_data_rule);
    dbms_sql.close_cursor (c_data_auditor);
    dbms_sql.close_cursor (c_miv_connector);
    dbms_sql.close_cursor (c_sap_connector);
    dbms_sql.close_cursor (c_loc_report);
    dbms_sql.close_cursor (c_hetero);
    dbms_sql.close_cursor (c_webservice);
    dbms_sql.close_cursor (c_copybook);
    dbms_sql.close_cursor (c_dimcube);
    dbms_sql.close_cursor (c_realtime);
    dbms_sql.close_cursor (c_chunk);
    dbms_sql.close_cursor (c_obiee);
    close schema_array;
    if v_schema_cnt = 0 then
      dbms_output.put_line('');
      dbms_output.put_line(v_grep_me_prefix || v_option_name || 'OWB_REPOS,,,NO,There are NO OWB repositories on this instance,');
    end if;

  END;
/


PROMPT

select 'Review Lite Script runtime:' " ",
       (sysdate - to_date('&SYSDATE_START', 'YYYY-MM-DD_HH24:MI:SS'))*24*60*60 " ",
       'seconds' " "
  from dual;

PROMPT END OF SCRIPT
SPOOL OFF

PROMPT ===================================================================================================*
PROMPT CAPTURING FILE INTEGRITY INFORMATION

define OUTF=*
define SUMF=*
col OUTF_ new_val OUTF noprint
col SUMF_ new_val SUMF noprint
select replace('&&OUTPUT_PATH.*.csv'      , decode('&PSEP', '/', '\', '/'), '&PSEP') as OUTF_,
       replace('&&OUTPUT_PATH.summary.csv', decode('&PSEP', '/', '\', '/'), '&PSEP') as SUMF_
  from dual;

SET TERMOUT OFF
-- prepare powershell scripts to generate md5 digest
SPOOL md5.ps1
PROMPT $v_path = $args[0]
PROMPT cd $v_path
PROMPT
PROMPT Get-ChildItem *.csv |
PROMPT Foreach-Object {
PROMPT
PROMPT $expHWfilename=$_.FullName
PROMPT $fullPath = Resolve-Path $expHWfilename
PROMPT $md5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
PROMPT $hash = ([System.BitConverter]::ToString($md5.ComputeHash([System.IO.File]::ReadAllBytes($fullPath))))
PROMPT $hash=$hash.ToLower()
PROMPT $hash -replace "-", "" | Add-Content *summary.csv
PROMPT
PROMPT }
PROMPT
SPOOL OFF
-- prepare powershell scripts to generate sha1 digest
SPOOL sha1.ps1
PROMPT $v_path = $args[0]
PROMPT cd $v_path
PROMPT
PROMPT Get-ChildItem *.csv |
PROMPT Foreach-Object {
PROMPT
PROMPT $expHWfilename=$_.FullName
PROMPT $fullPath = Resolve-Path $expHWfilename
PROMPT $sha1 = New-Object -TypeName System.Security.Cryptography.SHA1CryptoServiceProvider
PROMPT $sha1hash = ([System.BitConverter]::ToString($sha1.ComputeHash([System.IO.File]::ReadAllBytes($fullPath))))
PROMPT $sha1hash=$sha1hash.ToLower()
PROMPT $sha1hash -replace "-", "" | Add-Content *summary.csv
PROMPT
PROMPT }
SPOOL OFF
SET TERMOUT ON

host echo ==========================================================  >            fii_err.txt
host echo File Integrity Information                                 >> &&SUMF
host echo ========================================================== >> &&SUMF
host echo === File size                                              >> &&SUMF
host echo ========================================================== >> &&SUMF
host echo === dir                                                    >> &&SUMF
host dir /o:n          &&OUTF ReviewLite*.*                          >> &&SUMF 2>> fii_err.txt
host echo === ls -l                                                  >> &&SUMF
host ls -l             &&OUTF ReviewLite*.*                          >> &&SUMF 2>> fii_err.txt

host echo ========================================================== >> &&SUMF
host echo === MD5 and SHA-1 checksums - if possible                  >> &&SUMF
host echo === Please ignore errors                                   >> &&SUMF
host echo ========================================================== >> &&SUMF
host echo === md5sum                                                 >> &&SUMF
host /usr/bin/md5sum   &&OUTF ReviewLite*.*                          >> &&SUMF 2>> fii_err.txt
host powershell.exe  -ExecutionPolicy Bypass -F "md5.ps1" ".\&&SCRIPT_SD\&&HOST_NAME._&&INSTANCE_NAME." >> &&SUMF 2>> fii_err.txt
host echo === sha1sum                                                >> &&SUMF
host /usr/bin/sha1sum  &&OUTF ReviewLite*.*                          >> &&SUMF 2>> fii_err.txt
host powershell.exe  -ExecutionPolicy Bypass -F "sha1.ps1" ".\&&SCRIPT_SD\&&HOST_NAME._&&INSTANCE_NAME." >> &&SUMF 2>> fii_err.txt
host echo ========================================================== >> &&SUMF
host echo Debug Info: '&PWD' '&RMDEL' '&PSEP' '&OUTF'                >> &&SUMF
host echo ========================================================== >> &&SUMF
host &RMDEL fii_err.txt md5.ps1 sha1.ps1


PROMPT ===================================================================================================*
PROMPT THIS SECTION IS NOT SPOOLED INTO ANY FILE
PROMPT CHECKING DEPENDENCIES ...

SET HEADING ON
col P noprint
col IMPORTANT format a100

select * from
(
select
       -1 as P,
       'Please make sure that CDB$ROOT container and all the open PLUGGABLE DATABASES (PDBs) are collected' as IMPORTANT
  from dual
union all
select a.CON_ID,
       '    - ' || a.NAME || ' with SERVICE_NAME=' || b.NETWORK_NAME
  from V$CONTAINERS a
  join CDB_SERVICES b on a.CON_ID = b.CON_ID and b.NETWORK_NAME is not null and b.NETWORK_NAME not like '%XDB'
  where a.NAME!='PDB$SEED'                               -- seed PDB is not needed
    and a.OPEN_MODE in ('READ WRITE', 'READ ONLY')       -- PDB is open
    and sys_context('USERENV', 'CON_NAME')='CDB$ROOT'    -- PDB list is visible only from CDB$ROOT
)
  where exists (select 1 from V$DATABASE where CDB = 'YES') -- must be a container database
  order by 1, 2;

PROMPT ...

select * from
(
select
       -2 as P,
       'Please make sure that all the DATABASE TARGETS are collected:' as IMPORTANT
  from dual
union all
select
       -1 as P,
       '    - ' || TARGET_NAME || ' on host ' || HOST_NAME
  from SYSMAN.MGMT_TARGETS
  where TARGET_TYPE like '%database%'
)
  where 1 < (select count(*) from SYSMAN.MGMT_TARGETS where TARGET_TYPE like '%database%') -- not needed for OEM database control
  order by 1, 2;

PROMPT
PROMPT ===================================================================================================*


EXIT
