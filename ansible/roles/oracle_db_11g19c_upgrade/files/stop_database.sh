#!/bin/bash


# shutting down db
if [ $( ps -ef | grep pmon | grep ${ORACLE_SID} | grep -v grep | wc -l) -eq 1 ];
then
date 
echo "Database Not Already Stopped "
$ORACLE_HOME/bin/sqlplus -s /  as sysdba <<EOF
WHENEVER SQLERROR EXIT SUCCESS
SHUTDOWN IMMEDIATE;
 EXIT
EOF
fi

sleep 20

# As a last resort kill the database PMON process at the OS level to abort
if [ $( ps -ef | grep pmon | grep ${ORACLE_SID} | grep -v grep | wc -l) -eq 1 ];
then
date
echo "Database Not Already Stopped - Killing PMON to Abort"
ps -ef | grep pmon | grep ${ORACLE_SID} | grep -v grep | awk '{print $2}' | xargs kill -9
sleep 120
fi
