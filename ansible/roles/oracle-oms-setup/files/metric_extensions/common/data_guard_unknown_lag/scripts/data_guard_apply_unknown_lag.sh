#!/bin/bash
#
# The EM built in metrics for Transport Lag and Apply Lag can only detect numeric values of lag, so no incident is
# raised if the lag is unknown.  This metric is intended to address these cases.

. ~/.bash_profile

for DB in $(ps -ef | grep -i pmon | grep -v grep | awk -F\_ '{print $NF}' | grep -v +ASM)
do
	export ORAENV_ASK=NO
	export ORACLE_SID=$DB
	. oraenv >/dev/null
	echo "show database $DB" | dgmgrl / | grep "Lag" | sed 's/:/|/' | sed 's/|[[:space:]]*/|/g' | awk -v DATABASE=$DB '{printf("%s|%s\n",DATABASE,$0)}'
done