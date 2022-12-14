The python scripts in this directory are designed to be run with wlst. Be
sure to source the environment scripts and run from the domain directory
to avoid requiring password credentials, e.g.

```
. $WL_HOME/server/bin/setWLSEnv.sh
. /u01/app/oracle/Middleware/user_projects/domains/NomisDomain/bin/setDomainEnv.sh
wlst.sh ~/admin/scripts/weblogicControl.py status wls
```

Note there are init.d scripts for starting and stopping each individual component.

```
service weblogic-node-manager start
service weblogic-server start
service WLS_FORMS start
service WLS_REPORTS start
service opmn start
```
