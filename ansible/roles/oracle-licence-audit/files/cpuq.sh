#!/bin/sh

SCRIPT_VERSION="23.4.1"
SCRIPT_NAME=${0}

################################################################################
#
# this script is used to gather Operating System information for use by the
# Oracle team
#
################################################################################



################################################################################
#
#********************Hardware Identification and Detection**********************
#
################################################################################


################################################################################
#
# time stamp
#

setTime() {

	# set time
	NOW="`date '+%m/%d/%Y %H:%M %Z'`"

}


##############################################################
# make echo more portable
#

echo_print() {
  #IFS=" " command 
  eval 'printf "%b\n" "$*"'
} 


################################################################################
#
# expand debug output
#

echo_debug() {
 
	if [ "$DEBUG" = "true" ] ; then
		$ECHO "$*" 
		$ECHO "$*" >> $ORA_DEBUG_FILE	 
	fi
	
} 

setOutputFiles() {
	FILE_EXT=${$}
	# set tmp directory and files we will use in the script
	if [ "$tmp_dir" != "" ];then
		TMPDIR="$tmp_dir"
	else
		TMPDIR="/tmp"
	fi
	
	ORA_IPADDR_FILE="$TMPDIR"/oraipaddrs.$FILE_EXT
	ORA_MSG_FILE="$TMPDIR"/oramsgfile.$FILE_EXT
	touch ${ORA_MSG_FILE}

	# this wil allow us to pass the ORA_MACHINE_INFO file name 
	# from a calling shell script
	ORA_MACHINFO_FILE="$TMPDIR"/${MACHINE_NAME}-ct_cpuq.txt 
	ORA_PROCESSOR_FILE="$TMPDIR"/$MACHINE_NAME-proc.txt

	# debug and error files
	ORA_DEBUG_FILE="$TMPDIR"/oradebugfile.$FILE_EXT
	UNIXCMDERR="${TMPDIR}"/unixcmderrs.$FILE_EXT

	
	$ECHO_DEBUG "\ndebug.function.setOutputFiles"
}

################################################################################
#
# set parameters based on user and hardware
#

setOSSystemInfo() {

	# debug
	$ECHO_DEBUG "\ndebug.function.setOSSystemInfo"

	
	SCRIPT_SHELL=$SHELL
	
	if [ "$OS_NAME" = "Linux" ] ; then
		set -xv	
		cat /proc/cpuinfo 
		set +xv

	if [ "$SCRIPT_USER" = "ROOT" ] ; then
		
			VERSION=`/usr/sbin/dmidecode 2>/dev/null | grep "# dmidecode" | cut -d ' ' -f3`

			MAJOR=`echo $VERSION | cut -d'.' -f1`
			MINOR=`echo $VERSION | cut -d'.' -f2`


			case "${MAJOR}" in
				2)
					if [ ${MINOR} -le 6 ] ; then
						set -xv
						/usr/sbin/dmidecode
						set +xv
					else
						set -xv
						/usr/sbin/dmidecode --type processor
						/usr/sbin/dmidecode --type system | egrep -i 'system information|manufacturer|product'
						set +xv
					fi
					;;
				*)
						set -xv
						/usr/sbin/dmidecode --type processor
						/usr/sbin/dmidecode --type system | egrep -i 'system information|manufacturer|product'
						set +xv
					;;
			esac
			UUID=`dmidecode --string system-uuid`
			$ECHO "UUID="$UUID
			
			/usr/sbin/dmidecode 2>/dev/null | egrep -i 'vmware'  >/dev/null 2>&1
			if [ $? -eq 0 ] ; then
				$ECHO "CPUQ: CT-01104: WARNING: VMWare virtual machine"
			fi
			
			/usr/sbin/dmidecode 2>/dev/null | egrep -i 'virtualbox' >/dev/null 2>&1
			if [ $? -eq 0 ] ; then
				$ECHO "CPUQ: CT-01104: WARNING: Oracle VirtualBox machine"
			fi	
		else
			$ECHO "CPUQ: CT-01101: WARNING: /usr/sbin/dmidecode command not executed - $SCRIPT_USER insufficient privileges"
		fi
		
		
		## Check for Linux LPAR config file
		if [ -s  /proc/ppc64/lparcfg ]; then
			## file exists so cat it
			cat /proc/ppc64/lparcfg
		fi
		
		## Oracle VM for x86
		if [ -s /OVS/Repositories ] || [ -s /OVS/running_pool ]; then
			for CFGFILE in `find /OVS/Repositories/*/VirtualMachines /OVS/running_pool/*/ -name vm.cfg -print`
			do
					$ECHO
					$ECHO "#### BEGIN OVM Config File: $CFGFILE ####"
					$ECHO OVM Config File: $CFGFILE
					ls -l $CFGFILE
					cat $CFGFILE
					$ECHO  "#### END OVM Config File: $CFGFILE ####"
			done
			if [ -x /usr/sbin/xm ];
			then
		        	set -xv
		        	/usr/sbin/xm info
		        	set +xv
		        	$ECHO 
				if [ -x /usr/sbin/xenpm ];
				then
		        		set -xv
		      			/usr/sbin/xenpm get-cpu-topology
		        		set +xv
				fi
		        	$ECHO
		        	set -xv
		        	/usr/sbin/xm vcpu-list
		        	set +xv
			fi
			if [ -x /usr/sbin/ovs-agent-db ];
				then
						# get server pool name if one exists
		        		$ECHO
						$ECHO "#### OVM Server Pool Info ####"
						set -xv
		      			/usr/sbin/ovs-agent-db dump_db -c server_pool
						set +xv
						$ECHO
						set -xv
						# get a list of severs in the sever pool
						/usr/sbin/ovs-agent-db dump_db -c server_pool_servers
		        		set +xv
				fi
			if [ -s  /var/log/ovs-agent.log ]; then
				## file exists so cat it
				grep "migrate_vm" /var/log/ovs-agent.log
				grep "'cpus'" /var/log/ovs-agent.log
			fi
		fi
		
		if [ -x /usr/local/bin/ovm-info ];
		then
				set -xv
				/usr/local/bin/ovm-info
				set +xv
		fi
		

                ## Oracle Database Appliance
                if [ -x /opt/oracle/oak/bin/oakcli ];
                then
                	/opt/oracle/oak/bin/oakcli validate -d  > /dev/null 2>&1
			if [ $? -eq 0 ] ; then
						$ECHO "Oracle Database Appliance Processor Information"
						set -xv
						/opt/oracle/oak/bin/oakcli show processor
						/opt/oracle/oak/bin/oakcli show core_config_key
						
						/opt/oracle/oak/bin/oakcli show cpupool -node 0
						/opt/oracle/oak/bin/oakcli show cpupool -node 1
						
						set +xv
						ODA_IMPL=`/opt/oracle/oak/bin/oakcli validate -d | grep "Type of environment found" |cut -d ":" -f3`
				echo "Implementation type : [$ODA_IMPL]"
			fi
				elif [ -x /opt/oracle/dcs/bin/odacli ];
				then
				# Must be an ODA X6-2 S/M/L Model which does not support oakcli or CPU Pools
					if [ -x /opt/oracle/oak/bin/odaadmcli ];
					then
						set -xv
						/opt/oracle/oak/bin/odaadmcli show env_hw
						/opt/oracle/oak/bin/odaadmcli show processor
						set +xv
					fi
					set -xv
					/opt/oracle/dcs/bin/odacli describe-cpucore
					/opt/oracle/dcs/bin/odacli list-cpucores
					/opt/oracle/dcs/bin/odacli list-databases
					set +xv

                fi	

		#
		# Oracle Linux KVM start
		#
        if [ -s /etc/oracle-release ] ; then
        	$ECHO ""
        	set -xv
        	cat /etc/oracle-release
        	set +xv
        fi

        set -xv
        /usr/bin/lscpu
        set +xv

		if [ -x /usr/bin/numactl ] ; then
			$ECHO ""
			set -xv
			/usr/bin/numactl -H
			set +xv
		fi

		if [ -x /usr/bin/lstopo-no-graphics ] ; then
			$ECHO ""
			set -xv
			/usr/bin/lstopo-no-graphics --no-io --no-legend --of txt
			set +xv
		fi
		$ECHO ""

		if [ -x /usr/bin/virsh ] ; then
			$ECHO "$MACHINE_NAME is an OLVM Host"
			set -xv
			/usr/bin/virsh --readonly list
			set +xv
			$ECHO ""
			for OLKVM in `/usr/bin/virsh --readonly list | grep -v "\bId" | grep -v "\-\-" | cut -c7- | cut -f1 -d' '`
			do
				$ECHO $OLKVM
				#get vcpuinfo from virsh command
				set -xv
				/usr/bin/virsh --readonly vcpuinfo $OLKVM --pretty
				set +xv
			done
		else
			$ECHO "/usr/bin/virsh not executable"
		fi

		if [ -s /var/log/ovirt-engine/engine.log ] ; then
			grep "MigrateVDSCommand" /var/log/ovirt-engine/engine.log
		fi

		#
		# Oracle Linux KVM end
		#

		#
		# check OCI info
		#
		curl --connect-timeout 10 -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/ 2>/dev/null | grep '"shape"\|"ocpus"\|"timeCreated"'
		if [ $? -ne 0 ] ; then
			$ECHO "curl command to get OCI data failed to execute, please contact GLAS for assistance."
		fi

		RELEASE=`uname -r`
		IPADDR=`/sbin/ifconfig | grep inet | awk '{print $2}' | sed 's/addr://'`
	elif [ "$OS_NAME" = "SunOS" ] ; then
		set -xv
		/usr/sbin/prtconf 
		/usr/sbin/prtdiag
		set +xv
		/usr/sbin/psrinfo -p > /dev/null 2>&1
		isPoptionSupported=${?}

		if [ ${isPoptionSupported} -eq  0 ]
		then
			set -xv
			/usr/sbin/psrinfo -vp
			set +xv
		else
			set -xv
			/usr/sbin/psrinfo -v 
			set +xv
		fi
		## Get a list of cores on the system
		set -xv
		if [ -x /usr/bin/kstat ] ; then
			/usr/bin/kstat cpu_info | egrep "core_id|on-line|offline" | awk ' /core_id/ { Cores = $0 } /state/ { threadState = $0 ; printf("%s|%s\n", Cores, threadState) }' | sort | uniq
		else
			/bin/kstat cpu_info | egrep "core_id|on-line|offline" | awk ' /core_id/ { Cores = $0 } /state/ { threadState = $0 ; printf("%s|%s\n", Cores, threadState) }' | sort | uniq
		fi
		set +xv
		
		# Let's check if we're a VM - we need prtdiag to run successfully to do this
		/usr/sbin/prtdiag > /dev/null 2>&1
		if [ $? -eq 0 ] ; then
			SYSCON=`/usr/sbin/prtdiag | grep "System Configuration:" | cut -d':' -f2`
			$ECHO $SYSCON | egrep 'Sun Microsystems|Oracle Corporation'
			SUNCHECK=$?
				
			if [ $SUNCHECK -ne 0 ] ; then
				$ECHO "CPUQ: CT-01102: WARNING: Possible Virtual Machine $SYSCON, processor information is also needed for the physical machine"
			fi
		fi
		
		# Look for LDOMs and get LDOM version
		if [ -x /usr/sbin/virtinfo ] ; then
			set -xv
			/usr/sbin/virtinfo -ap
			set +xv
		fi
		
		if [ -x /usr/sbin/ldm ] || [ -x /opt/SUNWldm/bin/ldm ]; then
		 if [ -x /usr/sbin/ldm ]; then
		   alias ldm=/usr/sbin/ldm
		  else
		   alias ldm=/opt/SUNWldm/bin/ldm
		  fi 
			set -xv
			ldm -V
			ldm list
			ldm list-devices -p cpu
			set +xv
		
			# Get a list of LDOMs and get their configurations and core allocations
			for DOM in `ldm list | grep -v "NAME" | cut -f1 -d' '`
			do
				set -xv
				ldm list -o resmgmt,core $DOM
				set +xv
			done
		fi
		
		RELEASE=`uname -r`
		MAJOR=`echo $RELEASE | cut -d'.' -f1`
		MINOR=`echo $RELEASE | cut -d'.' -f2`
		if [ ${MINOR} -gt 9 ] ; then
			set -xv
			# check and see if we're running in the global zone
			ZONENAME=`/sbin/zonename`
			set +xv
			if [ "$ZONENAME" != "global" ] ; then
				$ECHO "CPUQ: CT-01103: WARNING: ${0} executed in the $ZONENAME zone, processor information is also needed for the global zone"
			fi
			set -xv
			# Get a list of zones and their UUIDs
			/usr/sbin/zoneadm list -cp
			# Loop through each zone and get its config info
			for CFG_ZONENAME in `/usr/sbin/zoneadm list -c`
			do
				$ECHO "\nZone $CFG_ZONENAME configuration:"
				/usr/sbin/zonecfg -z $CFG_ZONENAME info
			done
			/usr/sbin/pooladm
			set +xv
		fi

		IPADDR=`grep $MACHINE_NAME /etc/hosts | awk '{print $1}'`
	elif [ "$OS_NAME" = "HP-UX" ] ; then

                # Check if this is server is Instance Capacity System	
	        if [ -x /usr/sbin/icapstatus ] ; then
			set -xv
			/usr/sbin/icapstatus
			set +xv
			if [ $? -eq 2 ] ; then
				$ECHO "\n$MACHINE_NAME is not an Instant Capacity System\n"
			fi
		elif [ -x /usr/sbin/icod_stat ] ; then
			# Check deprecated icod_stat command
			set -xv
			/usr/sbin/icod_stat
			if [ $? -eq 2 ] ; then
				$ECHO "\n$MACHINE_NAME is not an Instant Capacity System\n"
			fi
			set +xv
		fi
		
		set -xv
		/usr/sbin/ioscan -fkC processor 
		set +xv
		set -xv
		/usr/bin/getconf MACHINE_MODEL
		set +xv
		RELEASE=`uname -r`
		IPADDR=`grep $MACHINE_NAME /etc/hosts | awk '{print $1}'`
 
		if [ -x /usr/contrib/bin/machinfo ] ; then
			set -xv
			/usr/contrib/bin/machinfo 
			set +xv
		fi

		## Check if this is a Itanium box
		## if so run hpvmstatus for IVM's and setboot to see if 
		## processors have HyperThread enabled
		MACH_HARDWARE=`uname -m`
		if [ "${MACH_HARDWARE}" = "ia64" ] ; then
				
			## Check to see if Integrity VMs are configured
			## Let's first check if hpvmstatus is installed in the default location
			if [ -x /opt/hpvm/bin/hpvmstatus ] ; then

				for IVM in `/opt/hpvm/bin/hpvmstatus -V | grep "Virtual Machine Name" | cut -d ':' -f2`
				do
					set -xv
				        /opt/hpvm/bin/hpvmstatus -V -P $IVM
				        set +xv
				done
				
			else
				# Let's just see if hpvmstatus can be found
				for IVM in `hpvmstatus -V | grep "Virtual Machine Name" | cut -d ':' -f2`
					do
					set -xv
					hpvmstatus -V -P $IVM
					set +xv
				done
			fi
			
			if [ -x /usr/sbin/setboot ] ; then
				set -xv
				/usr/sbin/setboot
				set +xv
			else
				## if setboot is not where it is should be
				## just try and see if it is in the PATH
				set -xv
				setboot
				set +xv
			fi
		fi
		
		## Check to see if nPars are configured
		if [ -x /usr/sbin/parstatus ] ; then
			set -xv
			/usr/sbin/parstatus			
			set +xv
		fi
		
		## Check to see if vPars are configured
		if [ -x /usr/sbin/vparstatus ] ; then
			set -xv
			# Get the name of the vPar where this script ran
			/usr/sbin/vparstatus -w
			
			# Get info for all the vPars
			/usr/sbin/vparstatus
			
			# check for dual core
			/usr/sbin/vparstatus -d
			set +xv
		fi
		
		if [ -x /usr/sbin/vparhwmgmt ] ; then
			set -xv
			/usr/sbin/vparhwmgmt -p cpu -l
			set +xv
		fi
		
		## Check to see if Secure Resource Partitions/HP Containers are configured.
		if [ -x /opt/hpsrp/bin/srp ] ; then
			set -xv
			/opt/hpsrp/bin/srp -l -v -s prm			
			set +xv
		fi

				
	elif [ "$OS_NAME" = "AIX" ] ; then
		set -xv
		uname -Mm
		/usr/sbin/lsdev -Cc processor 
		/usr/sbin/prtconf 
		set +xv
		if [ -x /usr/bin/lparstat ] ; then
			VERSION=`uname -v`
			## Check OS version to see if we need to 
			## pass W option to get WPAR info
			if [ ${VERSION} -gt 5 ] ; then 
				set -xv
				/usr/bin/lparstat -iW
				set +xv
			else
				set -xv
				/usr/bin/lparstat -i
				set +xv
			fi
		fi
		
		if [ -x /usr/bin/errpt ] ; then
			set -xv
			/usr/bin/errpt -a -J CLIENT_PMIG_STARTED,CLIENT_PMIG_DONE | tee ${ORA_MSG_FILE}
			/usr/bin/ls -l ${ORA_MSG_FILE}
			set +xv
		fi
		
		if [ -x /usr/sbin/lsattr ] ; then
			for PROC in `/usr/sbin/lsdev -Cc processor | cut -d' ' -f1`
			do
				set -xv
				/usr/sbin/lsattr -EH -l ${PROC}
				set +xv
			done
		fi

		if [ "$SCRIPT_USER" = "ROOT" ] ; then
			set -xv
			/usr/sbin/smtctl
			set +xv
		else
			$ECHO "smtctl command not executed - $SCRIPT_USER insufficient privileges"
		fi

		RELEASE="`uname -v`.`uname -r`"
		IPADDR=`grep $MACHINE_NAME /etc/hosts | awk '{print $1}'` 
 
	elif [ "$OS_NAME" = "OSF1" -o "$OS_NAME" = "UnixWare" ] ; then
		set -xv
		/usr/sbin/psrinfo -v
		set +xv
		IPADDR=`grep $MACHINE_NAME /etc/hosts | awk '{print $1}'` 
	fi
	
	# populate IP adresses to file
	$ECHO "$IPADDR" > $ORA_IPADDR_FILE
	
}


################################################################################
#
# output welcome message.
#

beginMsg()
{
$ECHO "\n*******************************************************************************" >&2
$ECHO   "Terms for Oracle Software Collection Tool


By selecting \"Accept License Agreement\" (or the equivalent) or by installing or using the Software (as defined below), You indicate Your acceptance of these terms and Your agreement, as an authorized representative of Your company or organization (if being acquired for use by an entity) or as an individual, to comply with the license terms that apply to the Software.  If you are not willing to be bound by these terms, do not indicate Your acceptance and do not download, install, or use the Software.  


License Agreement

PLEASE SCROLL DOWN AND READ ALL OF THE FOLLOWING TERMS AND CONDITIONS OF THIS LICENSE AGREEMENT (this \"Agreement\") CAREFULLY.  THIS AGREEMENT IS A LEGALLY BINDING CONTRACT BETWEEN YOU AND ORACLE AMERICA, INC. THAT SETS FORTH THE TERMS THAT GOVERN YOUR USE OF THE SOFTWARE. 

YOU MUST ACCEPT AND ABIDE BY THESE TERMS AS PRESENTED TO YOU - ANY CHANGES, ADDITIONS OR DELETIONS BY YOU TO THESE TERMS ARE NOT ACCEPTED  AND WILL NOT BE PART OF THIS AGREEMENT.  

Definitions
\"Oracle\" refers to Oracle America, Inc. 

\"You\" and \"Your\" refers to the individual or entity that wishes to use the Software. 

\"Software\" refers to the tool(s), script(s) and/or software product(s) (and any applicable documentation) provided with these terms to You by Oracle and which You wish to access and use to measure, monitor and/or manage Your usage of separately-licensed Oracle software (the \"Programs\") that has been licensed under a separate agreement between Oracle and You, such as an Oracle Master Agreement, an Oracle Software License and Services Agreement, an Oracle PartnerNetwork Agreement or an Oracle distribution agreement (each, an \"Oracle License Agreement\").  

Rights Granted
Oracle grants You a non-exclusive, non-transferable limited right to use the Software, subject to the terms of this Agreement, for the limited purpose of measuring, monitoring and/or managing Your usage of the Programs.  You may allow Your agents and contractors (including, without limitation, outsourcers) to use the Software for this purpose and You are responsible for their compliance with this Agreement in such use.  You (including Your agents, contractors and/or outsourcers) may not use the Software for any other purpose.  

Ownership and Restrictions
Oracle and Oracle's licensors retain all ownership and intellectual property rights to the Software. The Software may be installed on one or more servers; provided, however, that You may only make one copy of the Software for backup or archival purposes.  

Third party technology that may be appropriate or necessary for use with the Software is specified in the Software documentation, notice files or readme files.  Such third party technology is licensed to You under the terms of the third party technology license agreement specified in the Software documentation, notice files or readme files and not under the terms of this Agreement.  

You may not:
-	use the Software for Your own internal data processing or for any commercial or production purposes, or use the Software for any purpose except the purpose stated herein; 
-	remove or modify any Software markings or any notice of Oracle's or Oracle's licensors' proprietary rights;
-	make the Software available in any manner to any third party for use in the third party's business operations, without Oracle's prior written consent;
-	use the Software to provide third party training or rent or lease the Software or use the Software for commercial time sharing or service bureau use;
-	assign this Agreement or give or transfer the Software or an interest in them to another individual or entity;
-	cause or permit reverse engineering (unless required by law for interoperability), disassembly or decompilation of the Software (the foregoing prohibition includes but is not limited to review of data structures or similar materials produced by the Software);
-	disclose results of any Software benchmark tests without Oracle's prior written consent; 
-	use any Oracle name, trademark or logo without Oracle's prior written consent.  

Disclaimer of Warranty
ORACLE DOES NOT GUARANTEE THAT THE SOFTWARE WILL PERFORM ERROR-FREE OR UNINTERRUPTED.   TO THE EXTENT NOT PROHIBITED BY LAW, THE SOFTWARE IS PROVIDED \"AS IS\" WITHOUT WARRANTY OF ANY KIND AND THERE ARE NO WARRANTIES, EXPRESS OR IMPLIED, OR CONDITIONS, INCLUDING WITHOUT LIMITATION, WARRANTIES OR CONDITIONS OF MERCHANTABILITY, NONINFRINGEMENT OR FITNESS FOR A PARTICULAR PURPOSE, THAT APPLY TO THE SOFTWARE.  

No Right to Technical Support
You acknowledge and agree that Oracle's technical support organization will not provide You with technical support for the Software licensed under this Agreement.  

End of Agreement
You may terminate this Agreement by destroying all copies of the Software.  Oracle has the right to terminate Your right to use the Software at any time upon notice to You, in which case You shall destroy all copies of the Software. 

Entire Agreement
You agree that this Agreement is the complete agreement for the Software and supersedes all prior or contemporaneous agreements or representations, written or oral, regarding the Software.  If any term of this Agreement is found to be invalid or unenforceable, the remaining provisions will remain effective and such term shall be replaced with a term consistent with the purpose and intent of this Agreement. 

Limitation of Liability
IN NO EVENT SHALL ORACLE BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, PUNITIVE OR CONSEQUENTIAL DAMAGES, OR ANY LOSS OF PROFITS, REVENUE, DATA OR DATA USE, INCURRED BY YOU OR ANY THIRD PARTY.  ORACLE'S ENTIRE LIABILITY FOR DAMAGES ARISING OUT OF OR RELATED TO THIS AGREEMENT, WHETHER IN CONTRACT OR TORT OR OTHERWISE, SHALL IN NO EVENT EXCEED THE GREATER OF ONE THOUSAND U.S. DOLLARS (U.S. $1,000) OR THE LICENSE FEES THAT YOU HAVE PAID TO ORACLE FOR PROGRAMS PURSUANT TO AN ORACLE LICENSE AGREEMENT.

Export
Export laws and regulations of the United States and any other relevant local export laws and regulations apply to the Software.  You agree that such export control laws govern Your use of the Software (including technical data) provided under this Agreement, and You agree to comply with all such export laws and regulations (including \"deemed export\" and \"deemed re-export\" regulations).  You agree that no data, information, and/or Software (or direct product thereof) will be exported, directly or indirectly, in violation of any export laws, nor will they be used for any purpose prohibited by these laws including, without limitation, nuclear, chemical, or biological weapons proliferation, or development of missile technology.  

Other
1.	This Agreement is governed by the substantive and procedural laws of the State of California, USA.  You and Oracle agree to submit to the exclusive jurisdiction of, and venue in, the courts of San Francisco or Santa Clara counties in California in any dispute arising out of or relating to this Agreement. 

2.	You may not assign this Agreement or give or transfer the Software or an interest in them to another individual or entity.  If You grant a security interest in the Software, the secured party has no right to use or transfer the Software.

3.	Except for actions for breach of Oracle's proprietary rights, no action, regardless of form, arising out of or relating to this Agreement may be brought by either party more than two years after the cause of action has accrued.

4.	The relationship between You and Oracle is that of licensee/licensor.  Nothing in this Agreement shall be construed to create a partnership, joint venture, agency, or employment relationship between the parties.  The parties agree that they are acting solely as independent contractors hereunder and agree that the parties have no fiduciary duty to one another or any other special or implied duties that are not expressly stated herein.  Neither party has any authority to act as agent for, or to incur any obligations on behalf of or in the name of the other.  

5.	This Agreement may not be modified and the rights and restrictions may not be altered or waived except in a writing signed by authorized representatives of You and Oracle.  

6.	Any notice required under this Agreement shall be provided to the other party in writing.  

7.	In order to assist You with the measurement, monitoring or management of Your usage of the Programs, Oracle may have access to and collect Your information, which may include personal information, and data residing on Oracle, customer or third-party systems on which the Software is used and/or to which Oracle is provided access to perform any associated services.  Oracle treats such information and data in accordance with the terms of the Oracle Services Privacy Policy and the Oracle Corporate Security Practices, which are available, respectively, at http://www.oracle.com/privacy and www.oracle.com/corporate/security-practices, and treats such data as confidential in accordance with the terms of the Oracle License Agreement applicable to the Programs.  The Oracle Services Privacy Policy and the Oracle Corporate Security Practices are subject to change at Oracle's discretion; however, Oracle will not materially reduce the level of protection specified in the Oracle Services Privacy Policy or the Oracle Corporate Security Practices in effect at the time the information was collected during the period that Oracle retains such information.  

Contact Information
Should You have any questions concerning Your use of the Software or this Agreement, please contact Oracle at: http://www.oracle.com/corporate/contact/

Oracle America, Inc.
500 Oracle Parkway, 
Redwood City, CA 94065


Last updated 7 July 2020
\n" | more


ANSWER=

$ECHO "Accept License Agreement? "
	while [ -z "${ANSWER}" ]
	do
		$ECHO "$1 [y/n/q]: \c" >&2
  	read ANSWER
		#
		# Act according to the user's response.
		#
		case "${ANSWER}" in
			Y|y)
				return 0     # TRUE
				;;
			N|n|Q|q)
				exit 1     # FALSE
				;;
			#
			# An invalid choice was entered, reprompt.
			#
			*) ANSWER=
				;;
		esac
	done
}


################################################################################
#
# print out the search header
#

printMachineInfo() {
	
	NUMIPADDR=0
	
	# print script information
	$ECHO "[BEGIN SCRIPT INFO]"
	$ECHO "Script Name=$SCRIPT_NAME"
	$ECHO "Script Version=$SCRIPT_VERSION"
	$ECHO "CT Version=${CT_BUILD_VERSION}"
	$ECHO "Script Command options=$SCRIPT_OPTIONS"
	$ECHO "Script Command shell=$SCRIPT_SHELL"
	$ECHO "Script Command user=$SCRIPT_USER"
	$ECHO "Script Start Time=$NOW"
	# Get the approximate end time of the script by calling setTime again.
	setTime
	$ECHO "Script End Time=$NOW"
	$ECHO "[END SCRIPT INFO]"

	# print system information
	$ECHO "[BEGIN SYSTEM INFO]"
	$ECHO "Machine Name=$MACHINE_NAME"
	$ECHO "Operating System Name=$OS_NAME"
	$ECHO "Operating System Release=$RELEASE"

	for IP in `cat $ORA_IPADDR_FILE`
	do
		NUMIPADDR=`expr ${NUMIPADDR} + 1`
		$ECHO "System IP Address $NUMIPADDR=$IP"
	done
	
	cat ${ORA_PROCESSOR_FILE}
	cksum ${ORA_MSG_FILE} | cut -d' ' -f1-2

	$ECHO "[END SYSTEM INFO]"

	}


setAlias() {
unalias -a

cmd_list="printf
touch
cat
more
grep
egrep
cut
find
uname
awk
sed
sort
uniq
expr
cksum
ps
rm
ls
"

path_list="/bin/
/usr/bin/"


for c in $cmd_list
do
alias_flag=0

for p in $path_list
  do 
   if [ -x ${p}${c} ];
   then
                alias ${c}=${p}${c}
                alias_flag=1
                break
  fi
  done    
if [ $alias_flag -eq 0 ] ; then
   if [ "${alias_not_found}" = "" ]; then
      alias_not_found=$c
   else       
     alias_not_found=${alias_not_found},$c
   fi            
 fi
done

 if [ "${alias_not_found}" != "" ]; then 
   eval 'printf "${alias_not_found} utility(ies) not found. Please contact your assigned consultant"'
  exit 600
fi
#alias
}

CredentialValidation() {
if [ $OS_NAME = "Linux" ] && [ $USR_ID != "root" ] ; then
		$ECHO "Current OS user $USR_ID does NOT have administrative rights!"
		$ECHO "If you are sure that the Current OS user $USR_ID is granted the required privileges, continue with yes(y), otherwise select No(n) and please log on with a OS user with sufficient privileges."
		$ECHO "Running Processor Queries with insufficient privileges may have a significant impact on the quality of the data and information collected from this environment. Due to this, Oracle may have to get back to you and ask for additional items, or to execute again."
        ANSWER=
     while [ -z "${ANSWER}" ]
	 do
		$ECHO "Do you wish to continue anyway? [y/n]: \c" >&2
	   	read ANSWER
		case "${ANSWER}" in
			Y|y)
				return 0     # TRUE
				;;
			N|n)
				exit 1     # FALSE
				;;
			*) ANSWER=
				;;
		esac
 	done 		
	
 fi
}


################################################################################
#
#*********************************** MAIN **************************************
#
################################################################################

umask 022

# command line defaults
SCRIPT_OPTIONS=${*}
LOG_FILE="true"
DEBUG="false"

setAlias


# initialize script values
# set up default os non-specific machine values
OS_NAME=`uname -s`
MACHINE_NAME=`uname -n`
tmp_dir="$1"

USER_ID_CMD=`type whoami >/dev/null 2>/dev/null && echo "Found" || echo "NotFound"`
if [ "$USER_ID_CMD" = "Found" ] ; then
	USR_ID=`whoami`
else
	if [ "$OS_NAME" = "SunOS" ] ; then
		if [ -x /usr/ucb/whoami ] ; then
			USR_ID=`/usr/ucb/whoami`
		fi
	else
		USR_ID=$LOGNAME
	fi
fi

if [ "$USR_ID" = "root" ] ; then
	SCRIPT_USER="ROOT"
else
	SCRIPT_USER=$USR_ID
fi

# set up $ECHO
ECHO="echo_print"

# set up $ECHO for debug
ECHO_DEBUG="echo_debug"

# search start time
setTime
SEARCH_START=$NOW
$ECHO "\nScript started at $SEARCH_START" 


# see if any check* Oracle scripts are running, if not then print license. 
if [ "${CT_BUILD_VERSION}" = "" ] ;then
	STANDALONE=true
	beginMsg
	CredentialValidation
fi

# set output files
#setOutputFiles ${1}
setOutputFiles

# set current system info
setOSSystemInfo> $ORA_PROCESSOR_FILE 2>&1


# Write machine info to the output file
printMachineInfo > $ORA_MACHINFO_FILE 2>>$UNIXCMDERR

if [ -s $UNIXCMDERR ];
then
	cat $UNIXCMDERR >> $ORA_MACHINFO_FILE
fi

# search finish time
setTime
SEARCH_FINISH=$NOW

# if "${STANDALONE}" = "true" then we did not get called from Collection.sh   
# so we need to print the following
if [ "${STANDALONE}" = "true" ] ; then
	$ECHO "\nScript $SCRIPT_NAME finished at $SEARCH_FINISH"
	$ECHO "\nPlease collect the output file generated: $ORA_MACHINFO_FILE"
fi


# delete the tmp files
rm -rf $ORA_IPADDR_FILE $ORA_DEBUG_FILE $ORA_PROCESSOR_FILE $ORA_MSG_FILE $UNIXCMDERR 2>/dev/null

exit 0
