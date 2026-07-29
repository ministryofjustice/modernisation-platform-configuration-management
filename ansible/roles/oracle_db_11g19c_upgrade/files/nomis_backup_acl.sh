#!/bin/bash

# Starting with Oracle Database 12c, the OLAP Catalog (OLAP AMD) is
# desupported and will be automatically marked as OPTION OFF during the
# database upgrade if present. Oracle recommends removing OLAP Catalog
# (OLAP AMD) before database upgrade.  This step can be manually performed
# before the upgrade to reduce downtime.


sqlplus -s / as sysdba <<EOSQL

WHENEVER SQLERROR EXIT FAILURE

@/u01/app/oracle/product/11.2.0.4/db_1/olap/admin/catnoamd.sql

EXIT

EOSQL
