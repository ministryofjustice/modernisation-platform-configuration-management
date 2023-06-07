# ---------------------------------------------------------
# Check the status of all WL instances including the admin
# ---------------------------------------------------------
import sys
from java.io import FileInputStream

propInputStream = FileInputStream(
    "/home/oracle/admin/scripts/weblogic.properties")
configProps = Properties()
configProps.load(propInputStream)
domainName = configProps.get("domain.name")
domainHome = configProps.get("domain.home")
wlConfigFile = configProps.get("domain.configfile")
wlKeyFile = configProps.get("domain.keyfile")
nmConfigFile = configProps.get("nm.configfile")
nmKeyFile = configProps.get("nm.keyfile")
nmHome = configProps.get("nm.home")
nmPort = configProps.get("nm.port")
nmMachines = configProps.get("nm.host")
adminUrl = configProps.get("domain.adminurl")
adminServerName = configProps.get("domain.adminServerName")


def conn():
    try:
        connect(userConfigFile=wlConfigFile,
                userKeyFile=wlKeyFile, url=adminUrl)
    except ConnectionException, e:
        print 'Unable to find admin server'
        exit()


def ServerState(server):
    if server != 'wls':
        nmConnect(userConfigFile=nmConfigFile, userKeyFile=nmKeyFile, port=nmPort,
                  host=nmMachines, domainName=domainName, domainDir=domainHome, nmType='Plain')
        nmServerStatus(server)
        exit()
    else:
        conn()
        serverNames = cmo.getServers()
        domainRuntime()
        print 'Fetching state of every WebLogic instance'
        print ''
        for name in serverNames:
            cd("/ServerLifeCycleRuntimes/" + name.getName())
            serverState = cmo.getState()
            print '%-20s' % (name.getName()) + serverState
        disconnect()
        exit()


def nmConn(machine):
    try:
        nmConnect(userConfigFile=nmConfigFile, userKeyFile=nmKeyFile, port=nmPort,
                  host=nmMachines, domainName=domainName, domainDir=domainHome, nmType='Plain')
        status = "SUCCESS"
    except ConnectionException, e:
        status = "FAILED"
    print 'Nodemanager Connection: ' + status


def nmStartNM(machine):
    try:
        nmConnect(userConfigFile=nmConfigFile, userKeyFile=nmKeyFile, port=nmPort,
                  host=nmMachines, domainName=domainName, domainDir=domainHome, nmType='Plain')
        print 'Nodemanager already running'

    except:
        print 'start nodemaneger except'
        startNodeManager(verbose='false', NodeManagerHome=nmHome,
                         ListenPort=nmPort, ListenAddress=nmMachines)


def nmStop():
    try:
        nmConnect(userConfigFile=nmConfigFile, userKeyFile=nmKeyFile, port=nmPort,
                  host=nmMachines, domainName=domainName, domainDir=domainHome, nmType='Plain')
        stopNodeManager()
        print 'Stopped nodemanager'
    except:
        print 'Reached exception for nmstop'


def nmStartAS():
    try:
        nmStart(adminServerName)
    except:
        print 'Issues starting admin server'


if __name__ == "main":
    action = sys.argv[1]
    module = sys.argv[2]
    if action == 'status':
        if module == 'nm':
            nmConn(nmMachines)
            exit()
        elif module == 'wls':
            ServerState(module)
        elif module == 'as':
            ServerState(adminServerName)
    elif action == 'stop':
        if module == 'as':
            conn()
            shutdown(adminServerName, 'Server', 'true', 0, block='true')
            disconnect()
            exit()
        elif module == 'ms':
            msname = sys.argv[3]
            nmConn(nmMachines)
            nmKill(msname)
            exit()
        elif module == 'nm':
            nmStop()
            exit()
    elif action == 'start':
        if module == 'ms':
            msname = sys.argv[3]
            nmConn(nmMachines)
            nmStart(msname)
            exit()
        elif module == 'nm':
            print nmMachines
            nmStartNM(nmMachines)
            exit()
        elif module == 'as':
            nmConn(nmMachines)
            nmStartAS()
            exit()
