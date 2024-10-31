#!/bin/bash
#
# Check that RMAN Policy does not require archivelogs to be backed up on
# instance where backups are not being run.
#

. ~/.bash_profile

# If run on an instance hosting OEM we need to explicitly set up the database environment
if grep "^EMREP:" /etc/oratab > /dev/null; then
        export ORAENV_ASK=NO
        export ORACLE_SID=EMREP
        . oraenv >/dev/null
fi

# Check if Archivelog Deletion Policy requires a backup
if [[ $(echo "show archivelog deletion policy;" | rman target / | grep -E "ARCHIVELOG DELETION POLICY.*BACKED UP.*") ]];
then
   if [[ $(echo "list backup summary completed after \"SYSDATE-7\";" | rman target / | grep "specification does not match any backup in the repository") ]];
   then
      echo "Archivelog deletion policy requires backups but no backups taken in the last 7 days"
   fi
fi