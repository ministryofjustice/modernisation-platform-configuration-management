#!/bin/bash
set -e

STAGE=$1
RELEASE=$2
USERNAME=$3
PASSWORD=$4
TNS=$5
TOPDIR=${STAGE}/${RELEASE}
TAGDIR=/u01/tag

 . ~/.bash_profile
#Check Database release deployed  or not
CNT=`sqlplus -s ${USERNAME}/${PASSWORD}@${TNS} << EOF
set head off
set feedback off
select 'RELEASE_STATUS='||count(1) from db_patches where profile_code='TAG' and profile_value like '${RELEASE}';
exit
EOF
`

if [ `echo ${CNT} | grep RELEASE_STATUS | awk -F= '{ print $2 }' ` =  "0" ]
then
	echo "Release not deployed on database."
	exit 1
fi

 . ~/.bash_profile
export PATH=${PATH}:/u01/tag/utils/scripts
#Take backup of file before release deployment
FORMS_LIST=`ls -A ${TOPDIR}/FormsSources`
for i in ${FORMS_LIST}
do
	if [ -f ${TAGDIR}/FormsSources/${i} ]
	then
			echo "Taking backup of ${i}"
		cp -p ${TAGDIR}/FormsSources/$i ${TOPDIR}/backup/.
	fi
done

# Deploy release
cd ${TOPDIR}
./app_patch.sh -t ${TAGDIR}

#Compile forms and copy compiled forms to forms and FormsObjects directory.
for i in ${FORMS_LIST}
do
	FORM=`echo ${i} | awk -F. '{ print $1 }'`
	cd ${TAGDIR}/FormsSources
	echo "Compiling ${FORM}"
	compform.sh -c ${USERNAME}/${PASSWORD}@${TNS} -f ${FORM}
	if [ $? == 0 ]
	then
		for ext in fmx plx mmx
		do
			if [ -f ${TAGDIR}/FormsSources/${FORM}.${ext} ]
			then
				echo "Copying ${FORM}.${ext} ....."
				cp -p ${TAGDIR}/FormsSources/${FORM}.${ext} ${TAGDIR}/forms/.
				mv ${TAGDIR}/FormsSources/${FORM}.${ext} ${TAGDIR}/FormsObjects/.
			fi
		done
	fi
done