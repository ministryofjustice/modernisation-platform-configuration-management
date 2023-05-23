#!/bin/bash

set -eo pipefail

main() {
  . /u01/app/oracle/Middleware/wlserver_10.3/server/bin/setWLSEnv.sh
  . /u01/app/oracle/Middleware/user_projects/domains/NomisDomain/bin/setDomainEnv.sh
  timeout 10 /u01/app/oracle/Middleware/wlserver_10.3/common/bin/wlst.sh ~/admin/scripts/ms_state.py
}

main | grep -vE '^$|^CLASSPATH|^PATH|^Initializing|^Welcome to|^Type help|^Warning: An insecure protocol|^server. To|^Admin port|^Your environment has been set.'
