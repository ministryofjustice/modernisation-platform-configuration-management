#!/bin/bash

sqlplus -s / as sysdba <<EOSQL
@?/rdbms/admin/utlu122s.sql
EXIT
EOSQL
