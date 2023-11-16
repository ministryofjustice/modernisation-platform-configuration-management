The python scripts in this directory are designed to be run with wlst.
Credentials should be picked up automatically from boot.properties

Setting environment

```
. $WL_HOME/server/bin/setWLSEnv.sh
. /u01/app/oracle/Middleware/user_projects/domains/NomisDomain/bin/setDomainEnv.sh
```

Checking managed server status
```
wlst.sh ~/admin/scripts/ms_state.py
```

Use systemctl scripts for starting and stopping each individual component.
This ensures any component output goes to /var/log/messages.

```
systemctl start wls_nodemanager
systemctl start wls_adminserver
systemctl start wls_managedserver
```
