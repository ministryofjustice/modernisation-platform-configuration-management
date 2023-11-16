#!/usr/bin/python

from java.io import FileInputStream
import time
import getopt
import sys
import re

# Get location of the properties file.
properties = ''
try:
    opts, args = getopt.getopt(sys.argv[1:], "p:h::", ["properies="])
except getopt.GetoptError:
    print 'set_ms_log_rotation.py -p <path-to-properties-file>'
    sys.exit(2)
for opt, arg in opts:
    if opt == '-h':
        print 'set_ms_log_rotation.py -p <path-to-properties-file>'
        sys.exit()
    elif opt in ("-p", "--properties"):
        properties = arg
print 'properties=', properties

# Load the properties from the properties file.

propInputStream = FileInputStream(properties)
configProps = Properties()
configProps.load(propInputStream)

# Set all variables from values in properties file.
adminUsername = configProps.get("admin.username")
adminPassword = configProps.get("admin.password")
adminURL = configProps.get("admin.url")
msName = configProps.get("ms.name")

# Connect to the AdminServer.
connect(adminUsername, adminPassword, adminURL)

edit()
startEdit()

# Manage logging.
cd('/Servers/' + msName + '/Log/' + msName)
cmo.setRotationType('bySize')
cmo.setFileMinSize(50000)
cmo.setNumberOfFilesLimited(true)
cmo.setFileCount(10)
cmo.setRedirectStderrToServerLogEnabled(false)
cmo.setRedirectStdoutToServerLogEnabled(false)
cmo.setMemoryBufferSeverity('Debug')
cmo.setLogFileSeverity('Trace')

save()
activate()

disconnect()
exit()
