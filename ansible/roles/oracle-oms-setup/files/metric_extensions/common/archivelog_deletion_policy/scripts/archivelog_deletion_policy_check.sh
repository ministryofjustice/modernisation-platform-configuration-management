#!/bin/bash
#
# Check that RMAN Policy does not require archivelogs to be backed up on
# instance where backups are not being run.
#

#  When the agent runs on engineering hosts the open file limit is set by the root user at boot time
#  (unless agent is restarted manually), so the process limit may be less than that specified in .bash_profile.
#  Check if this is the case and override the process limit if required to prevent an error being thrown.
PROC_HARD_LIMIT=$(ulimit -Hn)
PROFILE_PROC_LIMIT=$(grep -E "ulimit.*-u.*-n" ~/.bash_profile | sed -r 's/.*-n ([[:digit:]]+).*/\1/')

if [[ ${PROFILE_PROC_LIMIT} -gt ${PROC_HARD_LIMIT} ]];
then
   source <(sed -r "s/ulimit -u ([[:digit:]]+) -n ([[:digit:]]+)/ulimit -u \1 -n ${PROC_HARD_LIMIT}/" ~/.bash_profile)
else
   . ~/.bash_profile
fi

# Check if Archivelog Deletion Policy requires a backup
if [[ $(echo "show archivelog deletion policy;" | rman target / | grep -E "ARCHIVELOG DELETION POLICY.*BACKED UP.*") ]];
then
   if [[ $(echo "list backup summary completed after \"SYSDATE-7\";" | rman target / | grep "specification does not match any backup in the repository") ]];
   then
      echo "Archivelog deletion policy requires backups but no backups taken in the last 7 days"
   fi
fi