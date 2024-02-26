#!/bin/bash
#
# Agent may not start automatically on boot if SELinux is enabled
# and file label on startup script is not correct.
# See MOS Note:
#   Oracle Linux: Oracle Enterprise Manager agent gcstartup fails to start on boot when SELinux is enabled (Doc ID 2766918.1)
#
GCSTARTUP=/etc/rc.d/init.d/gcstartup

# No action required unless SELinux is enabled
if [[ $(sestatus | awk '/SELinux status:/{print $NF}') == "enabled" ]]; then
	if [[ $(matchpathcon -V $GCSTARTUP) != "$GCSTARTUP verified." ]]; then
		semanage fcontext -a -t initrc_exec_t $GCSTARTUP
		restorecon -v $GCSTARTUP
		echo "$GCSTARTUP file label changed."
        fi
fi
