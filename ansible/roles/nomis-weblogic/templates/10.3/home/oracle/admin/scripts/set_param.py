#!/usr/bin/python
import getopt
import sys
import socket
from java.io import FileInputStream


def usage():
    print 'set_param.py -d <param_directory> -n <param_name> -v <param_value>'


def conn():
  try:
    connect(url=adminURL, adminServerName=adminServerName)
  except ConnectionException,e:
    print 'Unable to find admin server'
    exit()


propInputStream = FileInputStream("/home/oracle/admin/scripts/weblogic.properties")
configProps = Properties()
configProps.load(propInputStream)
adminURL = configProps.get("domain.adminurl")
adminServerName = configProps.get("domain.adminServerName")
directory = ''
name = ''
value = ''

try:
    opts, args = getopt.getopt(sys.argv[1:], "d:n:v:", [ "directory=", "name=", "value="])
except getopt.GetoptError:
    usage()
    sys.exit(2)
for opt, arg in opts:
    if opt in ("-d", "--directory"):
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

conn()
edit()
startEdit()
cd('/')
cd(directory)
set(name, value)
save()
activate()
