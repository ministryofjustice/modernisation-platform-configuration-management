echo Setting environment variables...
#Change INSTALLDIR to the directory where the provisioning files are located
INSTALLDIR={{ sap_provisioning_directory }}

CLASSDIR=$INSTALLDIR/lib
provisioningCP=$INSTALLDIR/conf/:$CLASSDIR/*

export provisioningCP
echo `java -version`
echo "Class path (provisioningCP):" $provisioningCP
