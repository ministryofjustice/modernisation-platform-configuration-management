# .bash_profile managed by modernisation-platform-configuration-management/ansible/roles/ncr-bip

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

# User specific environment and startup programs

export EDITOR=vi
export PS1="[\u@\h {{ ec2.tags['Name'] }} \W]\$ "

# Oracle setup
export ORACLE_HOME={{ oracle_home }}
export PATH=$PATH:$ORACLE_HOME/bin:/usr/bin
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
export NLS_LANG='ENGLISH_UNITED KINGDOM.UTF8'

# Set locale
export LANG=en_GB.utf8
export LC_ALL=en_GB.utf8
export TZ=Europe/London

export BOE={{ sap_bip_installation_directory }}/sap_bobj
export JAVA_HOME=$BOE/enterprise_xi40/linux_x64/sapjvm
export PATH=$PATH:$JAVA_HOME/bin
export FRS=/opt/data/BusinessObjects/BIP4/FRSDATA

#limits are set by ansible in /etc/security/limits.conf

#TMC Following added as per SAP Note 3257944
#SESSION_LOGGING=1

# See KB1968075 https://me.sap.com/notes/0001968075
export MALLOC_ARENA_MAX=1
