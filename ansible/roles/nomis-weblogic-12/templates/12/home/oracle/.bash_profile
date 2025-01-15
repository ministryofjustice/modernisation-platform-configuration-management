# Get the aliases and functions
if [ -f ~/.bashrc ]; then
        . ~/.bashrc
fi

# User specific environment and startup programs
if [ -f /u01/app/oracle/Middleware/wlserver/server/bin/setWLSEnv.sh ]; then
        . /u01/app/oracle/Middleware/wlserver/server/bin/setWLSEnv.sh > /dev/null
fi
