# winrm-scripts

Some useful scripts for either copying a file onto a remote
server, or for executing a remote command or script.

Credentials are assumed to be stored in SecretsManager.

Example usage

```
PATH=$PATH:/usr/local/bin
export WINRM_PASSWORD=$(winrm_get_creds.sh)
winrm_cmd.py  --host PDPMW0P1UQL0001.azure.hmpp.root ipconfig '/all'
winrm_cmd.py  --host PDPMW0P1UQL0001.azure.hmpp.root --ps 'Get-ChildItem –Path C:\ | ConvertTo-Json'
winrm_copy.py --host PDPMW0P1UQL0001.azure.hmpp.root --sourcefile /tmp/test.txt --destinationfile 'C:\test.txt'
winrm_cmd.py  --host PDPMW0P1UQL0001.azure.hmpp.root --ps 'Remove-Item -Path C:\test.txt'
```
