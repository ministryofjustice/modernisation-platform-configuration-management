#!/bin/sh
# Do not remove the line 'source bobjenv.sh' as it is required by the SAP installer and applications.
. ./bobjenv.sh
# START USERCONFIG - Enter your user config settings to be retained here
JAVA_OPTS="$JAVA_OPTS -Xmx4096m -XX:MaxMetaspaceSize=1024m"

# END USERCONFIG