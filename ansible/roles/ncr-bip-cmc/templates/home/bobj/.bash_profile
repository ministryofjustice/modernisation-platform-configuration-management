# Get the aliases and functions
if [ -f ~/.bashrc ]; then
        . ~/.bashrc
fi

# User specific environment and startup programs

PATH=$PATH:$HOME/.local/bin:$HOME/bin

export PATH

# Oracle setup.
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19c/client_1
export TNS_ADMIN=/u01/app/oracle/product/19c/client_1/network/admin
export LD_LIBRARY_PATH=/u01/app/oracle/product/19c/client_1/lib

export PATH=$ORACLE_HOME:$ORACLE_BASE$:$TNS_ADMIN:$LB_LIBRARY_PATH:$PATH