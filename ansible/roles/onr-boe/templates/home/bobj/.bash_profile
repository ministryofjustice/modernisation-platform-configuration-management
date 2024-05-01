# Get the aliases and functions
if [ -f ~/.bashrc ]; then
        . ~/.bashrc
fi

# User specific environment and startup programs

PATH=$PATH:$HOME/.local/bin:$HOME/bin

export PATH
export LC_ALL=en_GB.utf8 # required for installer to run

# TODO: in use elsewhere, not sure if needed here
umask 022
ORACLE_BASE=/u01/app/oracle
ORACLE_HOME=/u01/app/oracle/product/12c/client_1
# TNS_ADMIN=/u01/app/oracle/product/19c/client_1/network/admin
# LD_LIBRARY_PATH=/u01/app/oracle/product/19c/client_1/lib

PATH=${ORACLE_HOME}:${ORACLE_BASE}:$PATH

export ORACLE_BASE ORACLE_HOME PATH

# PATH=${ORACLE_HOME}:${ORACLE_BASE}:${TNS_ADMIN}:${LD_LIBRARY_PATH}:$PATH

# export ORACLE_BASE ORACLE_HOME TNS_ADMIN LD_LIBRARY_PATH PATH
