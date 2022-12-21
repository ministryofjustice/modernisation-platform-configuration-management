#!/usr/bin/python
import getopt
import sys
import socket
from java.io import FileInputStream


def usage():
    print('get_param.py -d <param_directory> -n <param_name>')


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
directory = ''
name = ''

try:
    opts, args = getopt.getopt(sys.argv[1:], "d:n:", ["directory=", "name="])
except getopt.GetoptError:
    usage()
    sys.exit(2)
for opt, arg in opts:
    if opt in ("-d", "--directory"):
        directory = arg
    elif opt in ("-n", "--name"):
        name = arg

if not name or not directory:
    print('missing param, parameter directory and name must be specified')
    print('')
    usage()
    sys.exit(2)

conn()
cd(directory)
value = get(name)

print('Value="' + value + '"')
