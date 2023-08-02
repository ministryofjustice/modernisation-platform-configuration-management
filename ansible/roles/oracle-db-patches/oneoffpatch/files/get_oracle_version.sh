#!/bin/bash

# Determining the exact Oracle version requires querying V$VERSION
# so that both major and minor release numbers can be found.
#
# This view has itself changed between versions.  Assume the newer
# version first which has the information in the BANNER_FULL column.
# If this fails then revert to using the BANNER column.
#

export ORACLE_SID=$1
export PARAMETERS_CSV=$2

# Check Oracle SID exists
/usr/local/bin/dbhome ${ORACLE_SID} >/dev/null
if [[ $? -gt 0 ]]
then
echo "Invalid Oracle SID"
exit 123
fi

export PATH=$PATH:/usr/local/bin;
export ORAENV_ASK=NO ;
. oraenv >/dev/null;

# First, try for version numbers in BANNER_FULL of the format:
# Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production Version 19.7.0.0.0
# (There is only one row in this view)
ORAVERSION=$(
sqlplus -s / as sysdba <<EOF
SET LINES 1000
SET PAGES 0
SET FEEDBACK OFF
SET HEADING OFF
SET ECHO OFF
WHENEVER SQLERROR EXIT FAILURE
SELECT    TRIM(regexp_substr(banner_full, ' [\.0123456789]+\$'))
FROM      v\$version;
exit
EOF
)
RC=$?
if [[ RC -eq 0 ]];
then
   echo $ORAVERSION
   exit 0
fi

# If the previous step failed then we may be on an earlier release of
# the database, so look in the BANNER column for version of the format:
# Oracle Database 11g Enterprise Edition Release 11.2.0.4.0 - 64bit Production
# (Only check first row)
ORAVERSION=$(
sqlplus -s / as sysdba <<EOF
SET LINES 1000
SET PAGES 0
SET FEEDBACK OFF
SET HEADING OFF
SET ECHO OFF
WHENEVER SQLERROR EXIT FAILURE
SELECT    TRIM(regexp_substr(banner, ' [\.0123456789]+ '))
FROM      v\$version
WHERE     ROWNUM=1;
exit
EOF
)
RC=$?

echo $ORAVERSION

exit $RC