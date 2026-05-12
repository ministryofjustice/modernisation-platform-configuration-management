# .bash_profile managed by modernisation-platform-configuration-management/ansible/roles/ncr-bip
export JAVA_HOME={{ sap_bip_installation_directory }}/sap_bobj/enterprise_xi40/linux_x64/sapjvm
export PATH="$JAVA_HOME/bin:$PATH"
# Get the aliases and functions
if [ -f ~/.bashrc ]; then
        . ~/.bashrc
fi

# User specific environment and startup programs
export EDITOR=vi
export PS1="[\u@\h {{ ec2.tags['Name'] }} \W]\$ "

# Set locale
export LANG=en_GB.utf8
export LC_ALL=en_GB.utf8
export TZ=Europe/London
