#!/bin/bash
# this script must be run as the oracle user

# has is running immediately -> restart
# has takes time to start    -> restart
# has doesn't start after some time -> start

function main {
  check_user_is_oracle
  set_oraenv
  wait_for_has_to_start
  check_asm_working no_error # if asm has mounted disk, exit
  
  stop_has
  start_has
  wait_for_asm_to_start
  check_asm_working no_error # if asm has mounted disk, exit

  # retry just incase
  sleep 120
  stop_has
  start_has
  wait_for_asm_to_start
  check_asm_working error_on_fail # if asm has mounted disk, exit, otherwise syslog error for alert
}

# vars
# 30s x 6 = 3 minutes
wait_interval=30 # seconds
wait_times=7
total_wait_time=$(( $wait_interval * $wait_times - $wait_interval ))

function check_user_is_oracle {
  # checks user is oracle and environment is oracle's
  # whoami would still give oracle when ran with oracle user, not using oracle's env
  if [ $USER != "oracle" ]; then
    echo "Script must be run as oracle. Try sudo su - oracle."
    exit 1
  fi
}

function set_oraenv {
  export ORACLE_SID=+ASM
  export ORAENV_ASK=NO
  . oraenv
}

function wait_for_has_to_start {
  for ((i = 1 ; i <= $wait_times ; i++)); do
    if crsctl check has | grep -q 'Oracle High Availability Services is online'; then
      echo "Oracle High Availability Services is online"
      break
    else
      if [[ $i -eq ${wait_times} ]]; then
        echo "HAS is not running after ${total_wait_time}s"
        break
      fi
      echo "HAS is not running. Waiting ${wait_interval}s"
      sleep ${wait_interval}
    fi
  done
}

function stop_has {
  echo "stopping HAS"
  crsctl stop has
}

function start_has {
  echo "starting HAS"
  crsctl start has
  echo "HAS status:"
  crsctl check has
}

function wait_for_asm_to_start {
  for ((i = 1 ; i <= $wait_times ; i++)); do
    if srvctl status asm | grep -q "ASM is running"; then
      echo "ASM is running."
      break
    else
      echo "ASM is not running. Waiting ${wait_interval}s"
      sleep ${wait_interval}
    fi
  done
}

function check_asm_working {
  error_on_fail=$1
  for ((i = 1 ; i <= $wait_times ; i++)); do
    if asmcmd lsdg | grep -q 'MOUNTED' ; then 
      echo "\nASM is working"
      /bin/logger "ASM disk rules changed successfully"
      echo "> asmcmd lsdg"
      asmcmd lsdg
      exit
    else
      if [[ $i -eq ${wait_times} ]] && [ "${error_on_fail}" = "error_on_fail" ]; then
        echo "\nASM is not working"
        /bin/logger "ASM not working and fix script completed"
        break
      fi
      echo "\nASM is not working. Waiting ${wait_interval}s"
      sleep ${wait_interval}
    fi
  done
}

main