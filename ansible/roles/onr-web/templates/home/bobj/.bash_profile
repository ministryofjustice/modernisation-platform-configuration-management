# Get the aliases and functions
if [ -f ~/.bashrc ]; then
        . ~/.bashrc
fi

# User specific environment and startup programs

PATH=$PATH:$HOME/.local/bin:$HOME/bin

export PATH
export LC_ALL=en_GB.utf8

umask 022
LD_LIBRARY_PATH=/u02/temp/DISK_1/setup

PATH=${LD_LIBRARY_PATH}:$PATH

export LD_LIBRARY_PATH PATH
