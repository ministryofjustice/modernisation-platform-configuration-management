#!/bin/bash
export JAVA_HOME=/u01/app/apache/tomcat/jre-9.0.4
export CATALINA_HOME=/u01/app/apache/tomcat/latest
export CATALINA_OPTS="-Duser.timezone=GMT"
export PATH=$JAVA_HOME/bin::/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/oracle/.local/bin:/home/oracle/bin
$CATALINA_HOME/bin/startup.sh
