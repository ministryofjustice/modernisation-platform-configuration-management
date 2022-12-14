#!/bin/ksh
#
# $Header:   Y:/ProjectDB/RELEASE/archives/ENGINEERING/CM_UNIX_SCRIPTS/formfns.sh-arc   1.3   Sep 18 2009 14:43:08   rcallaghan  $
#
# Standard functions for form compilation
#
# Version 1.1 28/01/2009 RAC
# Added copy of pll files to output directory to compile_form function.
#
#
# Version 1.2 08/06/2009 RAC
# Added get_nls_data function to set NLS_LENGTH_SEMANTICS
# for compilation script, now portable between BYTE and CHAR
# databases.
#
# Version 1.3 15/09/2009 RAC
# Changed to use frmcmp_batch
# N.B. the calling script has to alter the environment
# for the batch compiler to work. Direct call to the 
# frmcmp_batch exe, not the shell script.
#
# Version 1.4 26/07/2012 RAC
# Updated for OAS 11g R2
#

function f_CD
#----------------------------------------------------------
#  Function     : f_CD
#  Description  : Function to change directory, check reply and output
#               : error if the cd fails
#  Parameters   : path/directory
#  Returns      : 0 - Success
#               : 1 - Failed
#----------------------------------------------------------
{
    typeset to_dir=$1

    cd $to_dir 2>/dev/null 1>/dev/null
    res=$?
    if [ $res != 0 ] ; then
        echo "Failed to change directory to $to_dir - aborting"
        return 1 ;
    else
        echo "Current directory is $PWD"
        return 0 ;
    fi

}

function list_forms
{
  typeset prefix=$1
  ls -1 ${prefix}* | cut -d"." -f1 | sort -u
}
#
function check_result
{
  typeset indir=$1
  typeset outdir=$2
  typeset informs=$(ls -1 ${indir}/*.fmb | wc -l)
  typeset inlibs=$(ls -1 ${indir}/*.pll | wc -l)
  typeset inmenus=$(ls -1 ${indir}/*.mmb | wc -l)
  typeset outforms=$(ls -1 ${outdir}/*.fmx | wc -l)
  typeset outlibs=$(ls -1 ${outdir}/*.plx | wc -l)
  typeset outmenus=$(ls -1 ${outdir}/*.mmx | wc -l)
  #
  if [[ ${informs} -ne ${outforms} ]]
   then
     echo "\n\tForm input and output counts mismatch. Please check"
  else
     echo "\t${outforms} forms compiled successfully"
  fi
  if [[ ${inlibs} -ne ${outlibs} ]]
   then
     echo "\n\tLibrary input and output counts mismatch. Please check"
  else
     echo "\t${outlibs} libraries compiled successfully"
  fi
  if [[ ${inmenus} -ne ${outmenus} ]]
   then
     echo "\n\tMenu input and output counts mismatch. Please check"
  else
     echo "\t${outmenus} menus compiled successfully\n"
  fi
}
#
function do_grp
{
  typeset dbc=$1
  typeset outdir=$2
  typeset grp=$3
  typeset form
  for form in $(list_forms ${grp})
  do
  compile_form ${dbc} ${outdir} ${form} 2>&1 >> ${grp}.log
  done
}

function compile_form
{
set -a
typeset dbc=$1
typeset outdir=$2
typeset file=$3
typeset filefmb="${file}.fmb"
typeset filefmx="${file}.fmx"
typeset filepll="${file}.pll"
typeset fileplx="${file}.plx"
typeset filemmb="${file}.mmb"
typeset filemmx="${file}.mmx"

typeset outfile

set +a

if [ -f "${filepll}" ]
 then
  #cp -pf ${filepll} ${outdir} commented out at 1.3
  rslt=$?
  if [[ ${rslt} -ne 0 ]]
   then
    echo "ERROR: Failed to copy Library ${filepll}"
    exit 1
  fi
        outfile="${outdir}/${fileplx}"
        echo "Compiling ${filepll}"
        frmcmp_batch module=${filepll} module_type=LIBRARY output_file=${outfile} userid=${dbc} batch=YES compile_all=YES
        if [ ! -r "${outfile}" ]
        then
                echo "ERROR: Executable ${outfile} does not exist"
        else
                echo "Executable ${outfile} created"
        fi
fi

if [ -f "${filefmb}" ]
then
        outfile="${outdir}/${filefmx}"
        echo "Compiling form ${filefmb}"
        frmcmp_batch module=${filefmb} module_type=FORM output_file=${outfile} userid=${dbc} batch=YES compile_all=YES
        if [ ! -r "${outfile}" ]
        then
                echo "ERROR: Executable ${outfile} does not exist"
        else
                echo "Executable ${outfile} created"
        fi
fi

if [ -f "${filemmb}" ]
then
        outfile="${outdir}/${filemmx}"
        echo "Compiling menu ${filemmb}"
        frmcmp_batch module=${filemmb} module_type=MENU output_file=${outfile} userid=${dbc} batch=YES compile_all=YES
        if [ ! -r "${outfile}" ]
        then
                echo "ERROR: Executable ${outfile} does not exist"
        else
                echo "Executable ${outfile} created"
        fi
fi
}

function worry
#----------------------------------------------------------
#  Function     : worry
#  Description  : Function to output worry beads
#----------------------------------------------------------
{
while true
do
echo ".\c"
sleep 4
done
}

function check_db
#----------------------------------------------------------
#  Function     : check_db
#  Description  : Function to check database connection
#  Parameters   : Database connect string (user/pw@sid)
#  Returns      : 0 - Database connection successful
#               : 1 - Database connection failed
#----------------------------------------------------------
{
  typeset CS=$1
  typeset checkoms

  checkoms=`sqlplus -s $CS <<SQLSCRIPT
  set heading off;
  set feedback off;
  select 'OMS_OWNER' from dual;
SQLSCRIPT`
  if [[ "`echo $checkoms | awk '{ print $1 }'`" = "OMS_OWNER" ]]
   then
           echo "Database connection and passwords correct."
           return 0
  else
           echo "ERROR. Unable to login to database using supplied parameters.  Exiting.\n"
           return 1
  fi
}

function get_nls_data
#----------------------------------------------------------
#  Function     : get_nls_data
#  Description  : Function to get nls_length_semantics from the database
#               : N.B. Database connection must be valid before this is called!
#  Parameters   : Pos 1 - Variable to return string
#               : Pos 2 - Database connect string (user/pw@sid)
#  Returns      : String value in specified variable
#               : 1 - Failed
#----------------------------------------------------------
{
  typeset _var=$1
  typeset CS=$2
  typeset getnls
  typeset nls_value

  getnls=`sqlplus -s $CS <<SQLSCRIPT
  set heading off;
  set feedback off;
  show parameter nls_length_semantics
SQLSCRIPT`

  nls_value=$(echo ${getnls} | awk '{ print $3 }')

  case ${nls_value} in
  BYTE)
  continue;;
  CHAR)
  continue;;
  *)
  echo "\n\tERROR: Unable to retrieve nls_length_semantics!\n"
  return 1;;
  esac

  eval $_var='${nls_value}'
}


function check_d
#----------------------------------------------------------
#  Function     : check_d
#  Description  : Function to check a directory.
#  Parameters   : -r <dir> or -w <dir>
#  Returns      : 0 - Directory exists and has mode specified
#               : 1 - It doesn't
#----------------------------------------------------------
{
    typeset dir
        typeset option_character

    getopts 'r:w:' option_character
    case $option_character in
      r)
            dir=$OPTARG
            if [[ -d $dir ]] && [[ -r $dir ]]
                  then
                    return 0
          else
                    return 1
        fi
      ;;
          w)
            dir=$OPTARG
            if [[ -d $dir ]] && [[ -w $dir ]]
                  then
                    return 0
          else
                    return 1
        fi
          ;;
          *)
            echo "Usage: check_d -r directory \
                    \n       check_d -w directory"
                return 1
      ;;
          esac
           
}

# Now export all the functions
# These will be usable in command files,
# but only if no new shell is invoked
# i.e. no #!<shell> header
typeset -xf f_CD list_foms do_grp compile_form worry check_db check_d
