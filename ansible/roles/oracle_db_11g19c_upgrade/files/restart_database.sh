#!/bin/bash


# shutting it down from the 11g home
if [ $( ps -ef | grep pmon | grep ${ORACLE_SID} | grep -v grep | wc -l) -eq 1 ];
then
date 
echo "Database Not Already Stopped - Stop from 11g Home"
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
sleep 20
fi

export ORACLE_SID=${ db_name }

sleep 30
date
echo "Starting in Upgrade Mode"

sqlplus -s /  as sysdba <<EOF
WHENEVER SQLERROR EXIT FAILURE
STARTUP ;
EXIT
EOF