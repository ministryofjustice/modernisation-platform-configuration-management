#!/bin/bash

# When running the upgrade do not use Oracle Restart to start the database
# as it will not yet be configured to use the Oracle 18c home.  Instead
# run the startup using SQL*Plus.

# The database may be running if the normal shutdown failed from the 11g home
# So check if PMON is still running and if so stop the database from the 18c home
if [ $( ps -ef | grep pmon | grep ${ORACLE_SID} | grep -v grep | wc -l) -eq 1 ];
then
date
echo "Database Not Already Stopped - Attempting Stop from 19c Home"
sqlplus -s /  as sysdba <<EOF
WHENEVER SQLERROR EXIT SUCCESS
SHUTDOWN IMMEDIATE;
 EXIT
EOF
fi

# If that did not work, try shutting it down from the 11g home
if [ $( ps -ef | grep pmon | grep ${ORACLE_SID} | grep -v grep | wc -l) -eq 1 ];
then
date 
echo "Database Not Already Stopped e"
# export ORACLE_HOME=/u01/app/oracle/product/11.2.0.4/db_1
$ORACLE_HOME/bin/sqlplus -s /  as sysdba <<EOF
WHENEVER SQLERROR EXIT SUCCESS
SHUTDOWN IMMEDIATE;
 EXIT
EOF
fi

# As a last resort kill the database PMON process at the OS level to abort
if [ $( ps -ef | grep pmon | grep ${ORACLE_SID} | grep -v grep | wc -l) -eq 1 ];
then
date
echo "Database Not Already Stopped - Killing PMON to Abort"
ps -ef | grep pmon | grep ${ORACLE_SID} | grep -v grep | awk '{print $2}' | xargs kill -9
sleep 120
fi

# Ensure environment is still set for 19c
# . ~/.bash_profile

export ORACLE_SID=${ db_name }

sleep 30
date
echo "Starting in Upgrade Mode"

sqlplus -s /  as sysdba <<EOF
WHENEVER SQLERROR EXIT FAILURE
STARTUP UPGRADE;
EXIT
EOF