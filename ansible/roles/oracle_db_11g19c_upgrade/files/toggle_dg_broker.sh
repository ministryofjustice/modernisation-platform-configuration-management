#!/bin/bash
# Stop or Start Data Guard Broker

BROKERSTATE=$1

sqlplus /nolog <<EOSQL
WHENEVER SQLERROR EXIT FAILURE
connect / as sysdba
alter system set dg_broker_start=${BROKERSTATE};
EOSQL