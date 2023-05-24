if [ -f ~/.bashrc ]; then
        . ~/.bashrc
fi

# User specific environment and startup programs

PATH=$PATH:$HOME/.local/bin:$HOME/bin

export PATH
umask 022
export EDITOR=vi
export DOMAIN=`basename /u01/app/oracle/Middleware/user_projects/domains/*`
export JAVA_OPTS="-Xms128m -Xmx1024m -XX:MaxPermSize=256m"
export JAVA_HOME=/usr/bin/java
export JAVA_HOME

export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/Middleware/wlserver_10.3
export WL_HOME=/u01/app/oracle/Middleware/wlserver_10.3
export NODEMGR=${WL_HOME}/server/bin
export WEBLOGIC=/u01/app/oracle/Middleware/user_projects/domains/${DOMAIN}/bin
export XTAG_HOME=/u01/tag/xtag
#. $WL_HOME/server/bin/setWLSEnv.sh