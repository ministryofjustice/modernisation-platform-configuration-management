# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
        . ~/.bashrc
fi

# User specific environment and startup programs

PATH=$PATH:$HOME/.local/bin:$HOME/bin

umask 022
export PATH
export ORACLE_HOME={{ oracle_home }}
export PATH=$ORACLE_HOME/bin:$PATH
