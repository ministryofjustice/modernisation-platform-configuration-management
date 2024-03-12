#!/bin/bash

. ~/.bash_profile

echo -e "show database ${ORACLE_SID};" | dgmgrl / | awk -v ORACLE_SID=${ORACLE_SID} -F: '/Intended State/{printf("%s|%s\n",ORACLE_SID,$2)}' | sed 's/ //g'