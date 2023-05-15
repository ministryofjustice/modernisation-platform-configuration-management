# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
        . ~/.bashrc
fi

# User specific environment and startup programs

PATH=$PATH:$HOME/.local/bin:$HOME/bin

export PATH
export ORACLE_HOME=/u01/app/oracle/product/11.2.0.4/db_1
export PATH=$ORACLE_HOME/bin:$PATH
