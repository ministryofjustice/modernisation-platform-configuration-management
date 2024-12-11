#!/u01/app/oracle/Middleware/oracle_common/common/bin/wlst.sh
nmConnect('{{ weblogic_admin_username }}','{{ weblogic_admin_password }}','localhost','5556','nomis')
print('Check OHS ServerStatus')
if nmServerStatus(serverName='ohs1',serverType='OHS') != 'RUNNING':
    nmStart(serverName='ohs1', serverType='OHS')
