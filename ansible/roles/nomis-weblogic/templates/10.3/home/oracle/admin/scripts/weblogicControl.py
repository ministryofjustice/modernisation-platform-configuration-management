#---------------------------------------------------------
# Check the status of all WL instances including the admin
# ---------------------------------------------------------
import sys
from java.io import FileInputStream

propInputStream = FileInputStream("/home/oracle/admin/scripts/weblogic.properties")
configProps = Properties()
configProps.load(propInputStream) 
adminURL=configProps.get("domain.adminurl")
adminUsername=configProps.get("domain.adminUsername")
adminPassword=configProps.get("domain.adminPassword")
adminServerName=configProps.get("domain.adminServerName")

def conn():
  try:
    connect(adminUsername, adminPassword, adminURL, adminServerName=adminServerName)
  except ConnectionException,e:
    print 'Unable to find admin server'
    exit()

def ServerState():
  conn()
  serverNames = cmo.getServers()
  domainRuntime()
  print 'Fetching state of every WebLogic instance'
  print ''
 
  for name in serverNames:
    cd("/ServerLifeCycleRuntimes/" + name.getName())
    serverState = cmo.getState()
    print '%-20s' %(name.getName()) + serverState
  disconnect()
  exit()

def wait_for_ms_start(msName):
    stopped = True
    while stopped:
        try:
            domainRuntime()
            cd('/ServerLifeCycleRuntimes/' +msName)
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
            print 'Server :'+msName +' seems to be down '
            Thread.sleep(10000)
            continue

if __name__== "main":
  action=sys.argv[1]
  module=sys.argv[2]
  if action == 'status' and module == 'wls':
    ServerState()
  elif action == 'stop':
    if module == 'as':
      conn()
      shutdown(adminServerName,'Server','true',0)
      disconnect()
      exit()
    elif module == 'ms':
      msName=sys.argv[3]
      conn()
      shutdown(msName,'Server','true',0,force='true')
      exit()
  elif action == 'start' and module == 'ms':
    msName=sys.argv[3]
    conn()
    start(msName,'Server')
    wait_for_ms_start(msName)
    exit()
