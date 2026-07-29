#!/bin/bash


# shutting down
if [ $( ps -ef | grep pmon | grep ${ORACLE_SID} | grep -v grep | wc -l) -eq 1 ];
then
date 
echo "Database Not Already Stopped"
# export ORACLE_HOME=/u01/app/oracle/product/11.2.0.4/db
export ORACLE_SID=${ db_name }
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

export ORACLE_SID=${ db_name }

sleep 30
date
echo "Starting"

sqlplus -s /  as sysdba <<EOF
WHENEVER SQLERROR EXIT FAILURE
STARTUP ;
EXIT
EOF