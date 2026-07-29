#!/bin/bash

#  Remove EM Console     

sqlplus -s / as sysdba <<EOSQL

WHENEVER SQLERROR EXIT FAILURE

@?/rdbms/admin/emremove.sql

EXIT

EOSQL


