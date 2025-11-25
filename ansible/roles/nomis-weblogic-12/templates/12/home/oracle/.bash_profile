# Get the aliases and functions
if [ -f ~/.bashrc ]; then
        . ~/.bashrc
fi

# User specific environment and startup programs
if [ -f /u01/app/oracle/Middleware/wlserver/server/bin/setWLSEnv.sh ]; then
        . /u01/app/oracle/Middleware/wlserver/server/bin/setWLSEnv.sh > /dev/null
fi

# User specific environment and startup programs
export ORACLE_HOME=/u01/app/oracle/Middleware
export DOMAIN_BASE=$ORACLE_HOME/user_projects/domains
export DOMAIN_HOME=$DOMAIN_BASE/nomis
export OHS_INST=$DOMAIN_HOME/config/fmwconfig/components/OHS/instances/ohs1
. $DOMAIN_HOME/bin/setDomainEnv.sh


export PATH=$PATH:$ORACLE_HOME/bin:/u01/tag/utils/scripts


export LD_LIBRARY_PATH=/u01/app/oracle/Middleware/lib:/u01/app/oracle/Middleware/oracle_common/jdk/jre/lib/amd64:/u01/app/oracle/Middleware/oracle_common/jdk/jre/lib/amd64/server:/u01/app/oracle/Middleware/oracle_common/jdk/jre/lib/amd64/native_threads

export PRODUCT_HOME=/u01/app/oracle/Middleware/ohs
export LD_LIBRARY_PATH=/u01/app/oracle/Middleware/ohs/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/u01/app/oracle/Middleware/oracle_common/lib:$LD_LIBRARY_PATH
export ORACLE_INSTANCE=/u01/app/oracle/Middleware/user_projects/domains/nomis
export COMPONENT_NAME=ohs1
export COMPONENT_TYPE=OHS
