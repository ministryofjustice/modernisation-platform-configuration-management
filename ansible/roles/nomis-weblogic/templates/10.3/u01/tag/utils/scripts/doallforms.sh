#!/bin/ksh
#
# $Header:   Y:/ProjectDB/RELEASE/archives/ENGINEERING/CM_UNIX_SCRIPTS/doallforms.sh-arc   1.4   Jan 26 2010 12:48:08   rcallaghan  $
#
# Version 1.1 RAC 28JAN2009
# Reinstated object library copy.
# Additional checks for absolute paths of
# and access too source and object dirs.
#
# Version 1.2 RAC 08JUN2009
# Set NLS_LENGTH_SEMANTICS (by call to get_nls_data function)
#
# Version 1.3 RAC 15SEP2009
# Changed to use batch compiler.
# Now sets TERM, ORACLE_TERM and LD_LIBRARY_PATH
# and unsets LANG and NLS_LANG
# so the batch compiler gets the right environment.
# Calls the batch compiler exe direct, not via the shell script.
#
# Version 1.4 RAC 26JAN2010
# Modified forms groups to split prefixes with large numbers
# of files. Spawn more processes that compile fewer forms each.
# Run time is now ~10 minutes.
#
# Version 1.5 RAC 18AUG2010
# Added new group for UID(SCORR)
#
# Version 1.6 RAC 26JUL2012
# Updated for OAS 11g R2
#

export USAGE="\n${0} USAGE: ${0}
\t\t\t\t\t-s <Source Directory>
\t\t\t\t\t-o <Object Directory>
\t\t\t\t\t-e <Target Database>
\t\t\t\t\t-p <OMS_OWNER Password>"

typeset SD # source dir
typeset OD # object dir
typeset TD # target DB
typeset RS # result check
typeset DU=oms_owner # database user
typeset DP # database password

typeset CTEST # string to hold DB connection test result
typeset CS # DB connect string
typeset FORMS_PATH

#Version 1.2
typeset NLS_LENGTH_SEMANTICS

#Version 1.4
typeset form_groups1="OCU[A-H] OCU[I-O] OCU[P-Z] OID[A-O] OID[P-Z] OCD[A-I] OCD[J-Z] OUM[A-L] OUM[M-Z] \
                      OII[A-L] OII[M-Z] OCM[A-R] OCM[S-Z] OTD[A-L] OTD[M-Z] OIM OIU OTM OTU OMU OCI" 
typeset form_groups2="OTI[A-L] OTI[M-Z] OSI OSU OUU OUD OUI OYM HEL WEB UID UPD TEM OMS LOG CTA"
#End version 1.4

typeset -i rslt
typeset cur_dir
typeset buff

#Variables to track background processes and wait or terminate
typeset next_pid
typeset pid_list
typeset worry_pid

typeset obj_libs="SJS_FORMS10G.olb WEBUTIL.olb"

typeset core_plls="TAG OFG"

while getopts :e:s:o:p: OPT
do
        case ${OPT} in
                s) SD=${OPTARG};;
                o) OD=${OPTARG};;
                e) TD=${OPTARG};;
                p) DP=${OPTARG};;
                :) echo "\n-${OPTARG} requires a value, check usage"
                   echo "${USAGE}"
                   exit 1;;
                \?) echo "${USAGE}"
                   exit 1;;
        esac
done

if [[ -z ${ORACLE_HOME} ]] #Version 1.3
then
        echo "\nEnvironment variable ORACLE_HOME is not set"
        echo "Run abandoning\n"
        exit 1
fi

if [[ "${TD}" = "CNOMTx" ]]
then
        echo "\nTarget Database has not been specified"
        echo "Run abandoning\n"
        exit 1
fi

if [[ "${SD}" = "/tmp" ]]
then
        echo "\nSource directory has not been specified"
        echo "Run abandoning\n"
        exit 1
fi

if [[ "${OD}" = "/tmp" ]]
then
        echo "\nObject directory has not been specified"
        echo "Run abandoning\n"
        exit 1
fi

if [[ "${DP}" = "xyz" ]]
then
        echo "\nDatabase password has not been specified"
        echo "Run abandoning\n"
        exit 1
fi

export SD=/u01/tag/FormsSources
export OD=/u01/tag/FormsObjects

CS=${DU}/${DP}@${TD}

# Version 1.3
# Set and export variables for batch compiler
set -a
TNS_ADMIN=${ORACLE_HOME}/network/admin
LD_LIBRARY_PATH=${ORACLE_HOME}/lib:${ORACLE_HOME}/jdk/jre/lib/amd64:${ORACLE_HOME}/jdk/jre/lib/amd64/native_threads:${ORACLE_HOME}/jdk/jre/lib/amd64/server:${LD_LIBRARY_PATH}

TERM=vt220
ORACLE_TERM=vt220
# Unset LANG and NLS_LANG so the batch compilere can't pick them up.
unset LANG
unset NLS_LANG
set +a
#End Version 1.3

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

# Set up standard functions from function source fils
. formfns.sh
#
check_db ${CS}

rslt=$?
if [[ ${rslt} -ne 0 ]]
then
       echo "\nUnable to connect to database using connection details supplied"
       echo "Run abandoning\n"
       exit 1
fi

#Version 1.2
get_nls_data NLS_LENGTH_SEMANTICS ${CS}

rslt=$?
if [[ ${rslt} -ne 0 ]]
then
       echo "\nUnable to get NLS_LENGTH_SEMANTICS from database ${TD}!"
       echo "Run abandoning\n"
       exit 1
fi

export NLS_LENGTH_SEMANTICS

#Check the source and object directories are correctly specified
# and both are writable

buff=$(echo "${SD}" | cut -c1)
if [[ "/" != "${buff}" ]]
 then
  echo "\nERROR: Source Directory Incorrectly Specified."
  echo "Source and Object Directory Paths must be absolute."
  echo "Run abandoning\n"
  exit 1
fi

rslt=$(check_d -w ${SD})
if [[ ${rslt} -ne 0 ]]
 then
  echo "\nERROR: Source Directory Is Not Writable."
  echo "Run abandoning\n"
  exit 1
fi

buff=$(echo "${OD}" | cut -c1)
if [[ "/" != "${buff}" ]]
 then
  echo "\nERROR: Object Directory Incorrectly Specified."
  echo "Source and Object Directory Paths must be absolute."
  echo "Run abandoning\n"
  exit 1
fi

rslt=$(check_d -w ${OD})
if [[ ${rslt} -ne 0 ]]
 then
  echo "\nERROR: Object Directory Is Not Writable."
  echo "Run abandoning\n"
  exit 1
fi


f_CD ${SD}

rslt=$?
if [[ ${rslt} -ne 0 ]]
then
       echo "\nUnable to access forms source directory!"
       echo "Run abandoning\n"
       exit 1
fi

export FORMS_PATH=${PWD}:${FORMS_PATH} #Version 1.3

echo "\nDeleting old log files...\n"
# Use /usr/bin/rm to avoid daft aliases
/usr/bin/rm *.log > /dev/null 2>&1
/usr/bin/rm *.err > /dev/null 2>&1

echo "\nCompiling Core PLLs at $(date)...\n"
for GRP in ${core_plls}
do
  echo "\nCompiling ${GRP} PLLs...."
  do_grp ${CS} ${OD} ${GRP}
done
#
# Check core PLL logs for errors
#
rslt=$(cat *.log | grep -c ERROR:)
if [[ ${rslt} -ne 0 ]]
 then
  echo "\n!!!!\tErrors found in Core PLL compilation. Please check log files\t!!!!\n"
  exit 1
else
  echo "\n!!!!\tCore PLLs compiled OK\t!!!!\n"
fi
#
echo "\nCompiling first group of forms at $(date)\n"
for GRP in ${form_groups1}
do
  do_grp ${CS} ${OD} ${GRP} &
  next_pid=$!
  pid_list="${pid_list} ${next_pid}"
done

# Send out worry beads
worry &
worry_pid=$!

# Wait for all background jobs to complete
wait ${pid_list}

# Kill worry beads
kill ${worry_pid}

echo "\nCompiling last group of forms at $(date)\n"
for GRP in ${form_groups2}
do
  do_grp ${CS} ${OD} ${GRP} &
  next_pid=$!
  pid_list="${pid_list} ${next_pid}"
done

# Send out worry beads
worry &
worry_pid=$!

# Wait for all background jobs to complete
wait ${pid_list}

# Kill worry beads
kill ${worry_pid}

echo "\nCompilation processes finshed at $(date)\n"

# Check all logs for errors
#
rslt=$(cat *.log | grep -c ERROR:)
if [[ ${rslt} -ne 0 ]]
 then
  echo "\n\n!!!!\tErrors found in forms compilation. Failed objects are listed below\t!!!!\n" #Version 1.3
  grep ERROR: *.log #Version 1.3
  echo "\n\n!!!!\tPlease correct the errors listed above before starting the forms server\t!!!!\n" #Version 1.3
  exit 1
else
  echo "\n\n!!!!\tAll forms compiled OK. Reconciliation below.\t!!!!\n"
  check_result ${SD} ${OD}
fi
