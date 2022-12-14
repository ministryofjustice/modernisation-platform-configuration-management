#!/bin/bash
# set -x
. /home/oracle/.bash_profile
. $WL_HOME/server/bin/setWLSEnv.sh &>/dev/null
LOGDIR=`dirname $0`/../log
WLLOGFILE=$LOGDIR/wl.log
NMLOGFILE=$LOGDIR/nm.log
WL_PROPERTIES=`dirname $0`/weblogic.properties
action=$1 
DOMAIN_HOME=`grep domain.home ${WL_PROPERTIES} | awk -F= '{print $2 }'`
JAVA_HOME=/usr/java/jdk1.6.0_43
ADMIN_SCRIPTS=/home/oracle/admin/scripts

usage () {
  echo ""
  echo "Usage:"
  echo ""
  echo " $THISSCRIPT <action>"
  echo ""
  echo "where"
  echo ""
  echo " action = stop OR start OR status OR ms_Stop OR ms_start"
  echo ""
  exit $ERROR_STATUS
}

set_env()
{
. /u01/app/oracle/Middleware/user_projects/domains/NomisDomain/bin/setDomainEnv.sh
}

nodemanager_start()
{
$WL_HOME/server/bin/startNodeManager.sh &
sleep 5
}

adminserver_start()
{
set_env
$DOMAIN_HOME/bin/startWebLogic.sh &
sleep 20
opmnctl startall
}

adminserver_stop()
{
$DOMAIN_HOME/bin/stopWebLogic.sh &
sleep 20
}

adminserver_check()
{
set_env 
${WL_HOME}/common/bin/wlst.sh ${ADMIN_SCRIPTS}/weblogicControl.py status wls > /tmp/status.log
if [ `grep -i ADMINSERVER /tmp/status.log | grep RUNNING | wc -l` -eq 1 ]
then
	echo "AdminServer started successfully. "
else
	sleep 10
	adminserver_check
fi
}

managedserver_start_check()
{
CNT=`cat $WL_PROPERTIES | grep domain.managedServers| awk -F= '{print $2}'|tr ',' '\n'|wc -l`
set_env
while [ `${WL_HOME}/common/bin/wlst.sh ${ADMIN_SCRIPTS}/weblogicControl.py status wls| grep WLS| grep "RUNNING"| wc -l` -lt ${CNT} ]
do
	FAILED_MS=`${WL_HOME}/common/bin/wlst.sh ${ADMIN_SCRIPTS}/weblogicControl.py status wls| grep WLS| egrep -iv "RUNNING|STARTING|RESUMING"| grep -v WLST| awk '{ print $1}'| head -1 `
	if [ "${FAILED_MIS}" != "" ]
	then
		${WL_HOME}/common/bin/wlst.sh ${ADMIN_SCRIPTS}/weblogicControl.py start ms ${FAILED_MS} `hostname` &
	fi
	sleep 20
done
}

managedserver_stop_check()
{
CNT=`cat $WL_PROPERTIES | grep domain.managedServers| awk -F= '{print $2}'|tr ',' '\n'|wc -l`
set_env
while [ `${WL_HOME}/common/bin/wlst.sh ${ADMIN_SCRIPTS}/weblogicControl.py status wls| grep WLS| grep "SHUTDOWN"| wc -l` -lt ${CNT} ]
do
        FAILED_MS=`${WL_HOME}/common/bin/wlst.sh ${ADMIN_SCRIPTS}/weblogicControl.py status wls| grep WLS| egrep -iv "SHUTDOWN"| grep WLST | awk '{ print $1}'| head -1 `
        if [ "${FAILED_MIS}" == "" ]
        then
                ${WL_HOME}/common/bin/wlst.sh ${ADMIN_SCRIPTS}/weblogicControl.py stop ms ${FAILED_MS} `hostname` &
        fi
        sleep 10
done
}

nodemanager_stop()
{
if [ `pgrep -f weblogic.NodeManager | wc -l` -gt 0 ]
then
	pkill -f weblogic.NodeManager
else
	echo "Nodemanager already down"
fi
}

managed_server_start()
{
set_env
for i in `cat ${WL_PROPERTIES} | grep domain.managedServers| awk -F= '{print $2}'|tr ',' '\n'`
do
        ${WL_HOME}/common/bin/wlst.sh ${ADMIN_SCRIPTS}/weblogicControl.py start ms ${i} `hostname` &
done
managedserver_start_check
opmnctl startall
}

managed_server_stop()
{
opmnctl stopall
set_env
for i in `cat ${WL_PROPERTIES} | grep domain.managedServers| awk -F= '{print $2}'|tr ',' '\n'`
do
        ${WL_HOME}/common/bin/wlst.sh ${ADMIN_SCRIPTS}/weblogicControl.py stop ms ${i} `hostname` &
done
managedserver_stop_check
}

weblogic_control_start()
{
nodemanager_start
adminserver_start
adminserver_check
managed_server_start
echo "Deploying Keepalive"
#mv /u01/tag/static/keepalive.htm_SG /u01/tag/static/keepalive.htm
}

weblogic_control_stop()
{
managed_server_stop
adminserver_stop
nodemanager_stop
}

# Main
echo "${1} - `date` " >> /home/oracle/admin/scripts/operation.log
case $1 in
  status) set_env && ${WL_HOME}/common/bin/wlst.sh ${ADMIN_SCRIPTS}/weblogicControl.py status wls
          ;;
   start) weblogic_control_start
          ;;
    stop) weblogic_control_stop
          ;;
   ms_stop) managed_server_stop
         ;;
   ms_start) managed_server_start
          ;;
       *) usage
          ;;
esac
