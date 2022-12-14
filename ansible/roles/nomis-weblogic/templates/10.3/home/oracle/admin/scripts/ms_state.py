#!/usr/bin/python
import getopt
import sys
import socket

from java.io import FileInputStream

propInputStream = FileInputStream("/home/oracle/admin/scripts/weblogic.properties")
configProps = Properties()
configProps.load(propInputStream) 
adminURL=configProps.get("domain.adminurl")
adminUsername=configProps.get("domain.adminUsername")
adminPassword=configProps.get("domain.adminPassword")
adminServerName=configProps.get("domain.adminServerName")

def usage():
   print('get_param.py -u <username> -p <password> -h <admin_hostname>')

try:
   opts, args = getopt.getopt(sys.argv[1:],"u:p:h:d:n:",["properties=","password=","hostname="])
except getopt.GetoptError:
   usage()
   sys.exit(2)
for opt, arg in opts:
   if opt in ("-u", "--username"):
      adminUsername = arg
   elif opt in ("-p", "--password"):
      adminPassword = arg
   elif opt in ("-h", "--hostname"):
      adminURL = arg + ':7001'

# Connect to the AdminServer.
connect(adminUsername, adminPassword, adminURL)

servers=cmo.getServers()
print "-------------------------------------------------------"
print "\t"+cmo.getName()+" domain status"
print "-------------------------------------------------------"
for server in servers:
    state(server.getName(),server.getType())
print "-------------------------------------------------------"
