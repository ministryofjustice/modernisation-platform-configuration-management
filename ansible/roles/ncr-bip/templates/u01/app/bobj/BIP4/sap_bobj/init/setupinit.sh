#!/bin/sh
# This file copies the rc files and creates the proper symlinks.
# This can only be done by root.

USERNAME=`id | sed -e "s|).*\$||" -e "s|^.*(||" `
if [ "$USERNAME" != "root" ]; then
        echo "Log in as root and run in order to set up the init scripts. (STU00136)"
        exit 0
fi

errorExit()
{
        echo $1
        exit 1
}

chown root "/u01/app/bobj/BIP4/sap_bobj/init/SAPBOBJEnterpriseXI40" || errorExit "System initialization scripts failed. (STU00131)"

SOFTWARE=`uname -s`
case X"$SOFTWARE" in
XSunOS)
        if [ -f "/etc/init.d/SAPBOBJEnterpriseXI40" ]; then
                rm -rf "/etc/init.d/SAPBOBJEnterpriseXI40"
                mv -f "/u01/app/bobj/BIP4/sap_bobj//init/SAPBOBJEnterpriseXI40" "/etc/init.d/SAPBOBJEnterpriseXI40" || errorExit "System initialization scripts failed. (STU00131)"
                exit 0
        fi

    mv -f "/u01/app/bobj/BIP4/sap_bobj//init/SAPBOBJEnterpriseXI40" "/etc/init.d/SAPBOBJEnterpriseXI40" || errorExit "System initialization scripts failed. (STU00131)"
    cd /etc/init.d || errorExit "System initialization scripts failed. (STU00131)"
    ln -s /etc/init.d/SAPBOBJEnterpriseXI40 ../rc3.d/S99SAPBOBJEnterpriseXI40 || errorExit "System initialization scripts failed. (STU00131)"
    ln -s /etc/init.d/SAPBOBJEnterpriseXI40 ../rc1.d/K01SAPBOBJEnterpriseXI40 || errorExit "System initialization scripts failed. (STU00131)"
    ln -s /etc/init.d/SAPBOBJEnterpriseXI40 ../rc0.d/K01SAPBOBJEnterpriseXI40 || errorExit "System initialization scripts failed. (STU00131)"
;;
XLinux)
        if [ -f "/etc/init.d/SAPBOBJEnterpriseXI40" ]; then
                rm -rf "/etc/init.d/SAPBOBJEnterpriseXI40"
                mv -f "/u01/app/bobj/BIP4/sap_bobj//init/SAPBOBJEnterpriseXI40" "/etc/init.d/SAPBOBJEnterpriseXI40" || errorExit "System initialization scripts failed. (STU00131)"
                exit 0
        fi

    mv -f "/u01/app/bobj/BIP4/sap_bobj//init/SAPBOBJEnterpriseXI40" "/etc/init.d/SAPBOBJEnterpriseXI40" || errorExit "System initialization scripts failed. (STU00131)"
    cd /etc/init.d || errorExit "System initialization scripts failed. (STU00131)"
    if [ -f "/etc/redhat-release" ]; then
            ln -s /etc/init.d/SAPBOBJEnterpriseXI40 ../rc0.d/K01SAPBOBJEnterpriseXI40 || errorExit "System initialization scripts failed. (STU00131)"
            ln -s /etc/init.d/SAPBOBJEnterpriseXI40 ../rc1.d/K01SAPBOBJEnterpriseXI40 || errorExit "System initialization scripts failed. (STU00131)"
            ln -s /etc/init.d/SAPBOBJEnterpriseXI40 ../rc2.d/K01SAPBOBJEnterpriseXI40 || errorExit "System initialization scripts failed. (STU00131)"
            ln -s /etc/init.d/SAPBOBJEnterpriseXI40 ../rc3.d/S99SAPBOBJEnterpriseXI40 || errorExit "System initialization scripts failed. (STU00131)"
            ln -s /etc/init.d/SAPBOBJEnterpriseXI40 ../rc4.d/K01SAPBOBJEnterpriseXI40 || errorExit "System initialization scripts failed. (STU00131)"
            ln -s /etc/init.d/SAPBOBJEnterpriseXI40 ../rc5.d/S99SAPBOBJEnterpriseXI40 || errorExit "System initialization scripts failed. (STU00131)"
            ln -s /etc/init.d/SAPBOBJEnterpriseXI40 ../rc6.d/K01SAPBOBJEnterpriseXI40 || errorExit "System initialization scripts failed. (STU00131)"
    else
            ln -s /etc/init.d/SAPBOBJEnterpriseXI40 ./rc3.d/S99SAPBOBJEnterpriseXI40 || errorExit "System initialization scripts failed. (STU00131)"
            ln -s /etc/init.d/SAPBOBJEnterpriseXI40 ./rc5.d/S99SAPBOBJEnterpriseXI40 || errorExit "System initialization scripts failed. (STU00131)"
            ln -s /etc/init.d/SAPBOBJEnterpriseXI40 ./rc3.d/K01SAPBOBJEnterpriseXI40 || errorExit "System initialization scripts failed. (STU00131)"
            ln -s /etc/init.d/SAPBOBJEnterpriseXI40 ./rc5.d/K01SAPBOBJEnterpriseXI40 || errorExit "System initialization scripts failed. (STU00131)"
        insserv -v SAPBOBJEnterpriseXI40 || errorExit "System initialization scripts failed. (STU00131)"
    fi

;;
XAIX)
        if [ -f "/etc/SAPBOBJEnterpriseXI40" ]; then
                rm -rf "/etc/init.d/SAPBOBJEnterpriseXI40"
                mv -f "/u01/app/bobj/BIP4/sap_bobj/init/SAPBOBJEnterpriseXI40" "/etc/SAPBOBJEnterpriseXI40"
                exit 0
        fi

    mkdir -p /etc/SAPBOBJEnterpriseXI40
    mv -f "/u01/app/bobj/BIP4/sap_bobj/init/SAPBOBJEnterpriseXI40" "/etc/SAPBOBJEnterpriseXI40"
    if ! grep BobjE140 /etc/inittab >/dev/null; then
        echo "BobjE140:2:once:/etc/SAPBOBJEnterpriseXI40/SAPBOBJEnterpriseXI40 start > /dev/null 2>&1" >> /etc/inittab
    fi
    if [ ! -f "/etc/rc.shutdown" ]; then
        echo "#!/bin/sh" >> /etc/rc.shutdown
        chmod 755 /etc/rc.shutdown
    fi
    if ! grep SAPBOBJEnterpriseXI40 /etc/rc.shutdown >/dev/null; then
        echo "/etc/SAPBOBJEnterpriseXI40/SAPBOBJEnterpriseXI40 stop > /dev/null 2>&1" >> /etc/rc.shutdown
    fi
;;
XHP-UX)
        if [ -f "/sbin/init.d/SAPBOBJEnterpriseXI40" ]; then
                rm -rf "/sbin/init.d/SAPBOBJEnterpriseXI40"
                mv -f "/u01/app/bobj/BIP4/sap_bobj//init/SAPBOBJEnterpriseXI40" "/sbin/init.d/SAPBOBJEnterpriseXI40" || errorExit "System initialization scripts failed. (STU00131)"
                exit 0
        fi

    mv -f "/u01/app/bobj/BIP4/sap_bobj//init/SAPBOBJEnterpriseXI40" "/sbin/init.d/SAPBOBJEnterpriseXI40" || errorExit "System initialization scripts failed. (STU00131)"
    cd /sbin/init.d || errorExit "System initialization scripts failed. (STU00131)"

    SNUM=99
    if [ `uname -m` = "ia64" ]; then
        SNUM=901
        while [ "" != "`ls /sbin/rc2.d | grep ^S$SNUM`" -a $SNUM -lt 999 ]; do
            SNUM=`expr $SNUM + 1` # increment counter
        done
    fi

    ln -s /sbin/init.d/SAPBOBJEnterpriseXI40 ../rc2.d/S"$SNUM"SAPBOBJEnterpriseXI40 || errorExit "System initialization scripts failed. (STU00131)"
    ln -s /sbin/init.d/SAPBOBJEnterpriseXI40 ../rc1.d/K01SAPBOBJEnterpriseXI40 || errorExit "System initialization scripts failed. (STU00131)"
    ln -s /sbin/init.d/SAPBOBJEnterpriseXI40 ../rc0.d/K01SAPBOBJEnterpriseXI40 || errorExit "System initialization scripts failed. (STU00131)"
;;
esac

echo "System initialization scripts created."

# EOF