#!/bin/bash

THISSCRIPT=`basename $0`

info () {
  T=`date +"%D %T"`
  echo -e "INFO : $THISSCRIPT : $T : $1"
}

# --------
# Main
# --------
# Configure ASMLib
/usr/sbin/oracleasm configure -u oracle -g oinstall -b -s y -e

# Check status and load ASMLib
/usr/sbin/oracleasm status > /dev/null 2>&1
[ $? -ne 0 ] && /usr/sbin/oracleasm init

let diskno=0
# Here we list only the devices that have been attached for use as ASM disks.
ls /dev/xvdc* | while read device_persistant_name
do
  # Establish diskfullname as not same as device_persistant_name if nvme disks.
  diskname=$(lsblk -Pno NAME,TYPE "${device_persistant_name}" | grep -i "disk" | cut -d '=' -f 2 | cut -d '"' -f 2)
  diskfullname="/dev/${diskname}"

  info "Device persistant name: ${device_persistant_name} - Device name: ${diskfullname}"

  # if device does match this reg ex continue.
  # In our Terraform code we will create disks which conform to that naming
  info 'Continue if device matches this reg ex ^/dev/xvdc[a-x]$'
  echo "${device_persistant_name}" | grep -Po "^/dev/xvdc[a-x]$"

  if echo "${device_persistant_name}" | grep -qPo "^/dev/xvdc[a-x]$"
  then
      # do next
      info "It's potentially a disk we want for ASM: ${device_persistant_name}"
      # check if disk/partition is mounted
      mount | grep "${diskfullname}" > /dev/null
      if [ $? -ne 0 ]
      then
          #
          info "Not mounted"
          # Is this a disk or a partion?
          lsblk -dPno NAME,TYPE "${diskfullname}" | grep -i "part"
          if [ $? -ne 0 ]
          then
              info "It is a disk"
              # Check if partition exists
              info "Check if partition exists"

              lsblk -Pno NAME,TYPE "${diskfullname}" | grep -i "part"
              if [ $? -ne 0 ]
              then
                  info "Create full partition"
                  echo -e 'o\nn\np\n1\n\n\nw' | fdisk "${diskfullname}"
                  sync
                  sleep 5
              else
                  info "Partion exists - skipping"
              fi

              # Get partition name
              partname="/dev/$(lsblk -Pno NAME,TYPE "${diskfullname}" | grep -i "part" | cut -d '=' -f 2 | cut -d '"' -f 2)"
              info "Partition name: ${partname}"

              info "Check if it is a asm disk"

              diskno=$(expr ${diskno} + 1)

              /usr/sbin/oracleasm querydisk "${partname}"
              /usr/sbin/oracleasm querydisk "${partname}" | grep "marked an ASM disk" > /dev/null
              if [ $? -ne 0 ]
              then
                  info "Creating ASMDISK${diskno} ${partname}"

                  /usr/sbin/oracleasm createdisk "ASMDISK${diskno}" "${partname}"
                  /usr/sbin/oracleasm scandisks
                  sleep 5
              fi
          else
            info "Not a disk - skipping"
          fi
      else
          info "Already mounted - skipping"
      fi
  else
      info "It's not a disk or partition we want for ASM: ${device_persistant_name}"
  fi

  echo -e "\n"
done
