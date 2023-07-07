#!/bin/bash
set -eo pipefail

echo "+++Setting up Oracle HAS as Oracle user"

unset ORAENV_ASK

# retrieve password from parameter store
password_ASMSYS="{{ database_asmsys_password }}"
password_ASMSNMP="{{ database_asmsnmp_password }}"

# reconfigure Oracle HAS
source oraenv <<< +ASM
srvctl remove listener || true
srvctl add listener
# get spfile for ASM
spfile=$(adrci exec="set home +asm ; show alert -tail 1000" | grep -oE -m 1 '\+ORADATA.*' || true)
echo "+++Spfile set to '$spfile'"
srvctl add asm -l LISTENER -p "$spfile" -d "ORCL:ORA*"
crsctl modify resource "ora.asm" -attr "AUTO_START=1"
crsctl modify resource "ora.cssd" -attr "AUTO_START=1"
crsctl stop has
crsctl enable has
crsctl start has
sleep 10

# wait for HAS to come up, particuarly ASM
i=0
while [[ "$i" -le 10 ]]; do
    echo "+++Wait for ASM service #$((i + 1))"
    asm_status=$(srvctl status asm | grep "ASM is running" || true)
    if [[ -n "$asm_status" ]]; then
        echo "+++Mount disks"
        asmcmd mount DATA # returns exit code zero even if already mounted
        asmcmd mount FLASH

        # resize disks
        echo "+++Resize disks"
        sqlplus -s / as sysasm <<< "alter diskgroup DATA resize all;"
        sqlplus -s / as sysasm <<< "alter diskgroup FLASH resize all;"

        # set asm passwords
        echo "+++Set ASM Passwords"
        asmcmd orapwusr --modify --password ASMSNMP <<< "$password_ASMSNMP"
        asmcmd orapwusr --modify --password SYS <<< "$password_ASMSYS"
        break
    fi
    if [[ "$i" -eq 10 ]]; then
        echo "The ASM disks could not be re-sized as the ASM service was not ready after 5 minutes"
        break
    fi
    sleep 30
    i=$((i + 1))
done

crsctl check has
crsctl check css
asmcmd lsdg

echo "+++Finished setting up Oracle HAS as Oracle user"
