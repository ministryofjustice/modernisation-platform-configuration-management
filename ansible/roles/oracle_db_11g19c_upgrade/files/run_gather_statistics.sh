#!/bin/bash

# Gather Dictionary and Fixed Object Statistics

# We need to explicitly exclude the SYS.HIST_AUD$ table if it exists in this database
# because it is huge and gathering statistics on it will take many hours.


sqlplus -s / as sysdba <<EOSQL
WHENEVER SQLERROR EXIT FAILURE
BEGIN
   DBMS_STATS.gather_dictionary_stats;
END;
/

BEGIN
   DBMS_STATS.gather_fixed_objects_stats;
END;
/
EXIT
EOSQL
