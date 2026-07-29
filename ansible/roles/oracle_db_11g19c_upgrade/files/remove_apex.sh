#!/bin/bash

#  Upgrade Oracle Application Express (APEX) manually before the database upgrade, we've droped it and reinstalled it.
      
# The database contains APEX version 3.2.1.00.12. Upgrade APEX to at least version 18.2.0.00.12.      
# Starting with Oracle Database Release 18, APEX is not upgraded automatically as part of the database upgrade. 
# Refer to My Oracle Support Note 1088970.1 for information about APEX installation and upgrades.

sqlplus -s / as sysdba <<EOSQL

WHENEVER SQLERROR EXIT FAILURE

@/u01/app/oracle/product/11.2.0.4/db_1/apex/apxremov.sql

EXIT

EOSQL
