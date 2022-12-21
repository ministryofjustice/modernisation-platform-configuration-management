The python scripts in this directory are designed to be run with wlst.
Credentials should be picked up automatically from boot.properties

Setting environment

```
. $WL_HOME/server/bin/setWLSEnv.sh
. /u01/app/oracle/Middleware/user_projects/domains/NomisDomain/bin/setDomainEnv.sh
wlst.sh ~/admin/scripts/weblogicControl.py status wls
```

Checking managed server status
```
wlst.sh ~/admin/scripts/ms_state.py status wls
```

Use init.d scripts for starting and stopping each individual component.
This ensures any component output goes to /var/log/messages.

```
service weblogic-node-manager start
service weblogic-server start
service WLS_FORMS start
service WLS_REPORTS start
service WLS_HOTPAGE start
service WLS_TAGSAR start
service WLS_AUTOLOGOFF start
service opmn start
```

Or use master script to restart everything

```
service weblogic-all status
service weblogic-all restart
```

And to bring in and out of load balancer

```
service weblogic-healthcheck start # to bring in
service weblogic-healthcheck stop # to take out
```
