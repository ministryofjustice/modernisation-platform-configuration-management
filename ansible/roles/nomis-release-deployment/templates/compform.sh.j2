#!/bin/ksh
#
# $Header:   Y:/ProjectDB/RELEASE/archives/ENGINEERING/CM_UNIX_SCRIPTS/compform.sh-arc   1.0   Sep 18 2009 14:44:26   rcallaghan  $
#
# Version 1.0 RAC 18-SEP-2008
# Tidied up and added call to DB to
# set NLS_LENGTH_SEMANTICS so the
# form gets compiled with the same
# setting as the target DB.
# Changed to use the batch mode compiler and set
# the environment to run in a standard Oracle 10gAS
# environment.
# LANG and NLS_LANG are unset to force the batch
# compiler to use US7ASCII default NLS_LANG
# setting in forms.
# First book in to PVCS hence 1.0
#
# Updated for OAS 11g R2 1.1
#
set -a
USAGE="\n$(basename ${0}) USAGE: $(basename ${0})
\t\t\t\t\t-f <Form> (8-character name, no suffix)
\t\t\t\t\t-c <oms_owner/password@database>"

typeset CS
typeset FR
typeset SMSO=`tput smso`
typeset RMSO=`tput rmso`
typeset FORMS_PATH="${PWD}:${FORMS_PATH}"
typeset ckeckoms
# Version 2.1
if [[ -z ${ORACLE_HOME} ]]
then
        echo "\nEnvironment variable ORACLE_HOME is not set"
        echo "Run abandoning\n"
        exit 1
fi

TNS_ADMIN=$ORACLE_HOME/network/admin
LD_LIBRARY_PATH=$ORACLE_HOME/lib:$ORACLE_HOME/jdk/jre/lib/sparcv9:$ORACLE_HOME/jdk/jre/lib/sparcv9/native_threads:${ORACLE_HOME}/jdk/jre/lib/sparcv9/server:$LD_LIBRARY_PATH
TERM=vt220
ORACLE_TERM=vt220
typeset buff
typeset rslt
# Unset LANG and NLS_LANG just in case - the batch compiler picks them up
unset LANG
unset NLS_LANG
set +a
#End Version 2.1

while getopts :c:f: OPT
do
        case ${OPT} in
                c) CS=${OPTARG};;
                f) FR=${OPTARG};;
                :) echo "\n-${OPTARG} requires a value, check usage"
                   echo "${USAGE}"
                   exit 1;;
                \?) echo "${USAGE}"
                   exit 1;;
        esac
done

#
# Check the supplied database connection details
#
checkoms=`sqlplus -s $CS <<SQLSCRIPT
set heading off;
set feedback off;
select 'OMS_OWNER' from dual;
SQLSCRIPT`
if [[ "`echo $checkoms | awk '{ print $1 }'`" = "OMS_OWNER" ]]
 then
         echo "Database connection and passwords correct."
else
         echo "ERROR. Unable to login to database using supplied parameters.  Exiting.\n"
         exit 1
fi

# Check that we can access the Oracle forms compiler
buff=$(whence frmcmp_batch)
rslt=$?
if [[ ${rslt} -eq 127 ]]
 then
        echo "\nCannot find Oracle Forms Compiler!\n"
        echo "\nCheck ORACLE HOME and PATH!\n"
        echo "Run abandoning\n"
        exit 1
fi


getnls=`sqlplus -s $CS <<SQLSCRIPT
  set heading off;
  set feedback off;
  show parameter nls_length_semantics
SQLSCRIPT`

nls_value=$(echo ${getnls} | awk '{ print $3 }')

export NLS_LENGTH_SEMANTICS=${nls_value}

export file="${FR}"
export filefmb="${FR}.fmb"
export filemmb="${FR}.mmb"
export filepll="${FR}.pll"

echo ${FORMS_PATH}
echo "Current Directory `pwd`"

if [ -f "${filepll}" ]
then
	echo "\nCompiling ${filepll}\n"
	frmcmp_batch module=${filepll} module_type=LIBRARY userid=${CS} batch=YES compile_all=YES
	if [ ! -r "${file}.plx" ]
	then
		echo "${SMSO}Executable does not exist${RMSO}"
	else
		echo "Executable created"
	fi
fi

if [ -f "${filefmb}" ]
then
	\rm ${file}.fmx 2>/dev/null
	\rm ${file}.err 2>/dev/null
	echo "\nCompiling form ${filefmb}\n"
	#frmcmp_batch Module=${filefmb} Module_type=FORM Userid=${CS} build=YES batch=YES compile_all=YES
	frmcmp_batch Module=${filefmb} Module_type=FORM Userid=${CS} batch=YES compile_all=YES
	tail -1 "${file}.err"
	if [ ! -r "${file}.fmx" ]
	then
		echo "${SMSO}Executable does not exist${RMSO}"
	else
		echo "Executable created"
	fi
fi

if [ -f "${filemmb}" ]
then
	\rm ${file}.mmx 2>/dev/null
	\rm ${file}.err 2>/dev/null
	echo "\nCompiling menu ${filemmb}\n"
	#frmcmp_batch module=${filemmb} module_type=MENU userid=${CS} build=YES batch=YES compile_all=YES
	frmcmp_batch module=${filemmb} module_type=MENU userid=${CS} batch=YES compile_all=YES
	if [ ! -r "${file}.mmx" ]
	then
		echo "${SMSO}Executable does not exist${RMSO}"
	else
		echo "Executable created"
	fi
fi