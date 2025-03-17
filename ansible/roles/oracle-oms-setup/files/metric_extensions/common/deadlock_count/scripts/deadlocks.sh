#!/bin/bash

ALERT_LOG="$ORACLE_BASE/diag/rdbms/${ORACLE_SID,,}/$ORACLE_SID/trace/alert_$ORACLE_SID.log"
DEADLOCK_PATTERN="ORA-00060: Deadlock detected"
DEADLOCK_COUNT=$(grep -c "$DEADLOCK_PATTERN" "$ALERT_LOG" 2>/dev/null)
BEGINEPOCH=$(date "+%s" --date='- 15  minutes')
FIRST_SQL_TO_MATCH="UPDATE OFFENDER O SET O.CURRENT_TIER = PKG_LOOKUPS.FUNCGETTABRECORD( P_TABLE => 'MANAGEMENT_TIER', P_REF_COL => 'offender_id', P_REF_VAL => :B1 , P_DATA_FLD => 'tier_id', P_ORDER_BY => 'date_changed DESC, tier_id DESC') WHERE OFFENDER_ID = :B1"
SECOND_SQL_TO_MATCH="DELETE FROM OFFENDER WHERE ROWID = :p_row_id"

if [[ $DEADLOCK_COUNT -ge 1 ]]
then
  DEADLOCK_DATES=$(grep -B 1 "$DEADLOCK_PATTERN" "$ALERT_LOG" | grep -v "$DEADLOCK_PATTERN")

  # Check whether they are greater than begin epoch date specified

  for d in ${DEADLOCK_DATES[@]}
  do
    DEADLOCK_DATE=$(echo $d | cut -d'.' -f1)
    if [[ `date "+%s" -d "$DEADLOCK_DATE"` -ge $BEGINEPOCH ]]
    then
      # Read the trace file associated with the deadlock
      TRACEFILE=$(grep -A 1 "$d" $ALERT_LOG | grep -v "$d" | awk '{print $NF}' | sed -e 's/\.//2')
      if [[ -f $TRACEFILE ]]
      then
        # Get certain client details which have identified to be conflict between  
        # Delius API testing (scheduled in the evenings) and the Tiering Service
        # when testing attempting to delete an offender record which is being processed by the tiering service.
        FIRST_USER=$(grep -A1 'client details:' $TRACEFILE |egrep -v 'client details:' | awk '{print $4}' | grep -v "^$" | head -1 | sed -e s/,//)
        FIRST_SQL=$(grep -A1 'current SQL:' $TRACEFILE |egrep -v 'current SQL:' | head -1 | sed -e 's/^ *//; s/ *$//')
        SECOND_USER=$(grep -A1 'client details:' $TRACEFILE |egrep -v 'client details:' | awk '{print $4}' | grep -v "^$" | head -2 | tail -1 | sed -e s/,//)
        SECOND_SQL=$(grep -A1 'current SQL:' $TRACEFILE |egrep -v 'current SQL:' | tail -1 | sed -e 's/^ *//; s/ *$//')

        if [[ "$FIRST_USER" == "appuser" && "$FIRST_SQL" == "$FIRST_SQL_TO_MATCH"
              && "$SECOND_USER" == "root" && "$SECOND_SQL" == "$SECOND_SQL_TO_MATCH" ]]
        then
          STATUS="DISCARD"
        else
          DEADLOCK_KEEP+=( ${d} )
        fi
      fi
    fi
  done
fi

# Output number of occurrences in deadlock epochs which we want to keep
echo ${#DEADLOCK_KEEP[@]}
