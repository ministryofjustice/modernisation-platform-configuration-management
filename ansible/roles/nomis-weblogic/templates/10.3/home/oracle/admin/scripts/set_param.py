#!/usr/bin/python
import getopt
import sys
import socket
from java.io import FileInputStream

propInputStream = FileInputStream(
    "/home/oracle/admin/scripts/weblogic.properties")
configProps = Properties()
configProps.load(propInputStream)
adminURL = configProps.get("domain.adminurl")
adminUsername = configProps.get("domain.adminUsername")
adminPassword = configProps.get("domain.adminPassword")
adminServerName = configProps.get("domain.adminServerName")
directory = ''
name = ''
value = ''


def usage():
    print 'get_param.py -u <username> -p <password> -h <admin_hostname> -d <param_directory> -n <param_name> -v <param_value>'


try:
    opts, args = getopt.getopt(sys.argv[1:], "u:p:h:d:n:v:", [
                               "properties=", "password=", "hostname=", "directory=", "name=", "value="])
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
    elif opt in ("-d", "--directory"):
        directory = arg
    elif opt in ("-n", "--name"):
        name = arg
    elif opt in ("-v", "--value"):
        value = arg

if not name or not value or not directory:
    print('missing param, parameter directory, name and value must all be specified')
    print('')
    usage()
    sys.exit(2)

# Connect to the AdminServer.
connect(adminUsername, adminPassword, adminURL)

# Update
edit()
startEdit()
cd('/')
cd(directory)
set(name, value)
save()
activate()
