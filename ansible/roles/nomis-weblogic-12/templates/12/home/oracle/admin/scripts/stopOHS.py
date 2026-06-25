nmConnect(userConfigFile='/u01/tmp/wlst.userconfig',
    userKeyFile='/u01/tmp/wlst.userkey',
    host='{{ weblogic_domain_hostname }}',
    port='{{ weblogic_nm_port | default(5556) }}',
    domainName='{{ weblogic_domain_name }}',
    domainDir='/u01/app/oracle/Middleware/user_projects/domains/{{ weblogic_domain_name }}',
    nmType='ssl')

print('Check OHS ServerStatus')
status = nmServerStatus(serverName='ohs1', serverType='OHS')
print(status)

if status == 'RUNNING':
    print('Stopping server ohs1 ...')
    nmKill(serverName='ohs1', serverType='OHS')
else:
    print('ohs1 is not RUNNING, current status = ' + status)

print('Check OHS ServerStatus after stop request')
status = nmServerStatus(serverName='ohs1', serverType='OHS')
print(status)

nmDisconnect()
exit()