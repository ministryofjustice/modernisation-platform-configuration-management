#!/usr/bin/python
import getopt
import sys
import socket
from java.io import FileInputStream


def conn():
    try:
        connect(url=adminURL, adminServerName=adminServerName)
    except ConnectionException, e:
        print 'Unable to find admin server'
        exit()


propInputStream = FileInputStream(
    "/home/oracle/admin/scripts/weblogic.properties")
configProps = Properties()
configProps.load(propInputStream)
adminURL = configProps.get("domain.adminurl")
adminServerName = configProps.get("domain.adminServerName")

conn()
servers = cmo.getServers()
print "-------------------------------------------------------"
print "\t"+cmo.getName()+" domain status"
print "-------------------------------------------------------"
for server in servers:
    state(server.getName(), server.getType())
print "-------------------------------------------------------"
