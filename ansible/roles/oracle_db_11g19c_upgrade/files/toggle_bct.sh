#!/bin/bash
# Enable or Disable Block Change Tracking

BCTSTATE=$1

sqlplus /nolog <<EOSQL
WHENEVER SQLERROR EXIT FAILURE
connect / as sysdba
alter database ${BCTSTATE} block change tracking;
EOSQL