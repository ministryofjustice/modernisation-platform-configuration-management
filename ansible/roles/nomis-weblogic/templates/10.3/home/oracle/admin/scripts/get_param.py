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
directory = ''
name = ''


def usage():
    print('get_param.py -u <username> -p <password> -h <admin_hostname> -d <param_directory> -n <param_name>')


try:
    opts, args = getopt.getopt(sys.argv[1:], "u:p:h:d:n:", [
                               "properties=", "password=", "hostname=", "directory=", "name="])
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

if not name or not directory:
    print('missing param, parameter directory and name must be specified')
    print('')
    usage()
    sys.exit(2)

# Connect to the AdminServer.
connect(adminUsername, adminPassword, adminURL)

cd(directory)
value = get(name)

print('Value="' + value + '"')
