#!/usr/bin/python
from java.io import FileInputStream
import time
import getopt
import sys
import re

# Get location of the properties file.
properties = ''
try:
    opts, args = getopt.getopt(sys.argv[1:], "p:h::", ["properties="])
except getopt.GetoptError:
    print 'create_managed_server.py -p <path-to-properties-file>'
    sys.exit(2)
for opt, arg in opts:
    if opt == '-h':
        print 'create_managed_server.py -p <path-to-properties-file>'
        sys.exit()
    elif opt in ("-p", "--properties"):
        properties = arg
print 'properties=', properties

# Load the properties from the properties file.

propInputStream = FileInputStream(properties)
configProps = Properties()
configProps.load(propInputStream)

# Get Variables From Properties Files
# Admin Console
adminUsername = configProps.get("admin.username")
adminPassword = configProps.get("admin.password")
adminURL = configProps.get("admin.url")

# Cluster
clusterName = configProps.get("cluster.name")

# Managed Server
msName = configProps.get("ms.name")
msAddress = configProps.get("ms.address")
msPort = configProps.get("ms.port")
msCluster = configProps.get("ms.cluster")

# Data Source
dsName = configProps.get("ds.name")
dsJNDIName = configProps.get("ds.jndi.name")
dsURL = configProps.get("ds.url")
dsDriver = configProps.get("ds.driver")
dsUsername = configProps.get("ds.username")
dsPassword = configProps.get("ds.password")
dsTargetType = configProps.get("ds.target.type")
dsTargetName = configProps.get("ds.target.name")

# Deployment
appName = configProps.get("app.name")
path = configProps.get("app.path")
target = configProps.get("app.target")

# JMS Module
jmsModuleName = configProps.get("jms.module.name")
jmsdescriptorFileName = configProps.get("jms.descriptorFile.name")
jmsTarget = configProps.get("jms.target")
jmsFServerName = configProps.get("jms.fserver.name")
jmsFServerContext = configProps.get("jms.fserver.context")
jmsFServerJNDIProperty = configProps.get("jms.fserver.jndiproperty")
jmsFServerDestName = configProps.get("jms.fserver.destination.name")
jmsFServerDestLocJNDIName = configProps.get(
    "jms.fserver.destination.local.jndi.name")
jmsFServerDestRemJNDIName = configProps.get(
    "jms.fserver.destination.remote.jndi.name")
jmsFServerFactoryName = configProps.get("jms.fserver.factory.name")
jmsFServerFactoryLocJNDIName = configProps.get(
    "jms.fserver.factory.local.jndi.name")
jmsFServerFactoryRemJNDIName = configProps.get(
    "jms.fserver.factory.remote.jndi.name")

# Function that waits for a managed server to start before proceeding Wait for Managed Server to start


def wait_for_ms_start():
    stopped = True
    while stopped:
        try:
            domainRuntime()
            cd('/ServerLifeCycleRuntimes/' + msName)
            serverState = cmo.getState()
            if serverState == "RUNNING":
                print msName + ' is ' + serverState
                stopped = False
            elif serverState == "STARTING":
                print msName + ' is ' + serverState
                Thread.sleep(10000)
                continue
            elif serverState == "FORCE_SHUTTING_DOWN":
                print msName + ' is ' + serverState
                Thread.sleep(10000)
                continue
            elif serverState == "SHUTDOWN":
                print msName + ' is ' + serverState
                print 'Starting ' + msName
                cmo.start()
                continue
        except:
            print 'Server :'+msName + ' seems to be down '
            Thread.sleep(10000)
            continue


# Connect to the AdminServer.
connect(adminUsername, adminPassword, adminURL)

# Create Cluster
if clusterName:
    edit()
    startEdit()
    cd('/')
    cmo.createCluster(clusterName)
    cd('/Clusters/' + clusterName)
    cmo.setClusterMessagingMode('unicast')
    save()
    activate()

# Create Managed Server
if msName:
    edit()
    startEdit()
    cd('/')
    cmo.createServer(msName)
    cd('/Servers/' + msName)
    cmo.setListenAddress(msAddress)
    cmo.setListenPort(int(msPort))
    cd('/Servers/' + msName + '/Log/' + msName)
    cmo.setRedirectStderrToServerLogEnabled(true)
    cmo.setRedirectStdoutToServerLogEnabled(true)
    cmo.setMemoryBufferSeverity('Debug')
    cd('/Servers/' + msName)
    cmo.setCluster(getMBean('/Clusters/' + msCluster))
    cmo.setMachine(getMBean('/Machines/' + msAddress))
    save()
    activate()
    # Start Managed Server
    start(msName, 'Server')
    wait_for_ms_start()

# Create Data Source(s)
if dsName:
    # Create List of Data Source(s)
    dsUsernames = dsUsername.split(",")
    dsPasswords = dsPassword.split(",")
    dsName = dsName.split(",")
    dsJNDIName = dsJNDIName.split(",")
    datasources = zip(dsName, dsJNDIName, dsUsernames, dsPasswords)
    for dsName, dsJNDIName, dsUsername, dsPassword in datasources:
        edit()
        startEdit()
        cd('/')
        cmo.createJDBCSystemResource(dsName)
        cd('/JDBCSystemResources/' + dsName + '/JDBCResource/' + dsName)
        cmo.setName(dsName)
        cd('/JDBCSystemResources/' + dsName + '/JDBCResource/' +
           dsName + '/JDBCDataSourceParams/' + dsName)
        set('JNDINames', jarray.array([String(dsJNDIName)], String))
        cd('/JDBCSystemResources/' + dsName + '/JDBCResource/' +
           dsName + '/JDBCDriverParams/' + dsName)
        cmo.setUrl(dsURL)
        cmo.setDriverName(dsDriver)
        set('Password', dsPassword)
        cd('/JDBCSystemResources/' + dsName + '/JDBCResource/' +
           dsName + '/JDBCConnectionPoolParams/' + dsName)
        cmo.setTestTableName('SQL SELECT 1 FROM DUAL\r\n\r\n')
        cd('/JDBCSystemResources/' + dsName + '/JDBCResource/' + dsName +
           '/JDBCDriverParams/' + dsName + '/Properties/' + dsName)
        cmo.createProperty('user')
        cd('/JDBCSystemResources/' + dsName + '/JDBCResource/' + dsName +
           '/JDBCDriverParams/' + dsName + '/Properties/' + dsName + '/Properties/user')
        cmo.setValue(dsUsername)
        cd('/SystemResources/' + dsName)
        set('Targets', jarray.array(
            [ObjectName('com.bea:Name='+dsTargetName+',Type=Cluster')], ObjectName))
        cd('/JDBCSystemResources/' + dsName + '/JDBCResource/' +
           dsName + '/JDBCConnectionPoolParams/' + dsName)
        set('MaxCapacity', '300')
        save()
        activate()
        # Restart Managed Server
        cd('/')
        domainRuntime()
        cd('/ServerLifeCycleRuntimes/'+msName)
        cmo.forceShutdown()
        wait_for_ms_start()

# Create JMS Module (For TAGSAR)
if jmsModuleName:
    edit()
    startEdit()
    # Create JMS Module
    cd('/')
    cmo.createJMSSystemResource(jmsModuleName,jmsdescriptorFileName)
    cd('/SystemResources/'+jmsModuleName)
    set('Targets', jarray.array(
        [ObjectName('com.bea:Name='+jmsTarget+',Type=Cluster')], ObjectName))
    save()
    # Create Foreign Server
    cd('/JMSSystemResources/'+jmsModuleName+'/JMSResource/'+jmsModuleName)
    cmo.createForeignServer(jmsFServerName)
    cd('/JMSSystemResources/'+jmsModuleName+'/JMSResource/' +
       jmsModuleName+'/ForeignServers/'+jmsFServerName)
    cmo.setDefaultTargetingEnabled(true)
    cmo.setInitialContextFactory(jmsFServerContext)
    cmo.createJNDIProperty('datasource')
    cd('/JMSSystemResources/'+jmsModuleName+'/JMSResource/'+jmsModuleName +
       '/ForeignServers/'+jmsFServerName+'/JNDIProperties/'+'datasource')
    cmo.setValue(jmsFServerJNDIProperty)
    # Create Foreign Destination
    cd('/JMSSystemResources/'+jmsModuleName+'/JMSResource/' +
       jmsModuleName+'/ForeignServers/'+jmsFServerName)
    FD = cmo.createForeignDestination(jmsFServerDestName)
    cd('ForeignDestinations')
    FD.setLocalJNDIName(jmsFServerDestLocJNDIName)
    FD.setRemoteJNDIName(jmsFServerDestRemJNDIName)
    # Create Foreign Connection Factory
    cd('/JMSSystemResources/'+jmsModuleName+'/JMSResource/' +
       jmsModuleName+'/ForeignServers/'+jmsFServerName)
    cmo.createForeignConnectionFactory(jmsFServerFactoryName)
    cd('/JMSSystemResources/'+jmsModuleName+'/JMSResource/'+jmsModuleName +
       '/ForeignServers/'+jmsFServerName+'/ForeignConnectionFactories/'+jmsFServerFactoryName)
    cmo.setLocalJNDIName(jmsFServerFactoryLocJNDIName)
    cmo.setRemoteJNDIName(jmsFServerFactoryRemJNDIName)
    # Set timeout seconds for Java Transaction API (JTA)
    cd('/JTA/NomisDomain/')
    cmo.setTimeoutSeconds(1000)
    save()
    activate()

# Create App Deployment
if appName:
    edit()
    startEdit()
    progress = deploy(appName, path, target)
    progress.printStatus()
    save()
    activate()

# Start Application
if appName:
    startApplication(appName)

disconnect()
exit()
