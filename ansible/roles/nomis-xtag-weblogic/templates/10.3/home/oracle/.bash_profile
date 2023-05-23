# Get the aliases and functions
if [ -f ~/.bashrc ]; then
        . ~/.bashrc
fi

# User specific environment and startup programs

PATH=$PATH:$HOME/.local/bin:$HOME/bin

export PATH
umask 022
EDITOR=vi
DOMAIN=`basename /u01/app/oracle/Middleware/user_projects/domains/*` 
DOMAIN_HOME=/u01/app/oracle/Middleware/user_projects/domains/NomisDomain
JAVA_OPTS="-Xms128m -Xmx1024m -XX:MaxPermSize=256m"
JAVA_HOME=/usr/java/jdk1.6.0_43
export JAVA_HOME

# Oracle setup.
ORACLE_BASE=/u01/app/oracle
ORACLE_HOME=/u01/app/oracle/Middleware/forms_home
ORACLE_INSTANCE=/u01/app/oracle/Middleware/forms_instance 
ORACLE_INSTANCE_HOME=/u01/app/oracle/Middleware/forms_instance
WEBLOGIC_HOME=/u01/app/oracle/Middleware
MW_HOME=/u01/app/oracle/Middleware
WL_HOME=/u01/app/oracle/Middleware/wlserver_10.3 
NODEMGR=${WL_HOME}/server/bin
WEBLOGIC=/u01/app/oracle/Middleware/user_projects/domains/${DOMAIN}/bin 

LD_LIBRARY_PATH=/u01/app/oracle/Middleware/forms_home/lib:/u01/app/oracle/Middleware/forms_home/jdk/jre/lib/amd64:/u01/app/oracle/Middleware/forms_home/jdk/jre/lib/amd64/server:/u01/app/oracle/Mi$

PATH=${JAVA_HOME}/bin:${ORACLE_INSTANCE_HOME}/bin:${ORACLE_HOME}/opmn/bin:${WEBLOGIC_HOME}:${ORACLE_HOME}/dcm/bin:$ORACLE_HOME/bin:${ORACLE_HOME}/OPatch:${PATH}:/u01/tag/utils/scripts:${WL_HOME}/common/bin:$LD_LIBRARY$ 
export DOMAIN_HOME ORACLE_BASE ORACLE_HOME ORACLE_INSTANCE_HOME ORACLE_INSTANCE PATH EDITOR
export WEBLOGIC_HOME WL_HOME NODEMGR WEBLOGIC JAVA_OPTS
