#!/bin/bash
# Managed in code modernisation-platform-configuration-management repo, ncr-bip role
# NOTE: this script is redundant, "systemctl restart sapbobj" will do the same thing
. /home/bobj/.bash_profile

BOBJEDIR={{ sap_bip_installation_directory }}/sap_bobj/
LOGDIR=${BOBJEDIR}logging/Tomcat_Restart_Logs/
BOBJUSER=bobj
BOXNAME={{ ec2.tags['Name'] }}
CURRENTUSER=`id | sed -e 's|).*$||' -e 's|^.*(||' `
DATESTAMP=`date +%Y%m%d_%H%M`
LOGFILE=${LOGDIR}TomcatRestart_${BOXNAME}_${DATESTAMP}.log
ARCHLOGDIR={{ sap_web_archived_logs_directory }}/Archived_Logs_${DATESTAMP}/
export LOGDIR BOBJEDIR BOXNAME LOGFILE BOBJUSER

mkdir -p $LOGDIR 2>&1 | tee -a $LOGFILE
mkdir -p $ARCHLOGDIR 2>&1 | tee -a $LOGFILE

echo "Restarting Tomcat on server -" $BOXNAME | tee -a $LOGFILE
echo "Log file:" $LOGFILE
echo "Current user:" $CURRENTUSER | tee -a $LOGFILE

if [ "$BOBJUSER" -a "$BOBJUSER" != "$CURRENTUSER" ]; then
        echo "ERROR: This script must be run as" $BOBJUSER  | tee -a $LOGFILE
        exit 1
fi

TOMCATPID=`ps -aux | grep tomcat | grep -v grep | grep -v $(basename -- "$0") | awk '{print $2}'`
if [ -n "$TOMCATPID" ]; then
        echo "Stopping Tomcat (PID = ${TOMCATPID})..." | tee -a $LOGFILE
        exec ${BOBJEDIR}tomcatshutdown.sh | tee -a $LOGFILE

        TOMCATPID=`ps -aux | grep tomcat | grep -v grep | grep -v $(basename -- "$0") | awk '{print $2}'`
        if [ -n "$TOMCATPID" ]; then
                echo "Tomcat is still running. Attempting to kill PID =" $TOMCATPID
                kill -9 $TOMCATPID
        fi
        echo "Tomcat stopped" | tee -a $LOGFILE
else
        echo "Tomcat is not running" | tee -a $LOGFILE
fi

echo "Moving log files to " $ARCHLOGDIR | tee -a $LOGFILE
mv ~/SBOPWebapp_* $ARCHLOGDIR 2>&1 | tee -a $LOGFILE
mv $BOBJEDIR/tomcat/logs/*.* $ARCHLOGDIR 2>&1 | tee -a $LOGFILE
mv $BOBJEDIR/tomcat/bin/TraceLog_* $ARCHLOGDIR 2>&1 | tee -a $LOGFILE

echo "Starting Tomcat..." | tee -a $LOGFILE
exec ${BOBJEDIR}tomcatstartup.sh | tee -a $LOGFILE
echo "Tomcat has been started" | tee -a $LOGFILE

