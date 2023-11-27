# Overview

Role for configuring scheduled CSR DB training schema refreshes every Sunday and Adhoc schema refreshes from Production. 

# Pre-requisite for scheduled refresh 

Schema passwords stored in secrets manager 

In group_vars add details for training refresh schedule and catalog details 
# rman details
db_sid: PPIWFM
refresh_script: csr_training_schema_refresh.sh
training_schema_refresh_cron:
  iwfm_train_refresh:
    - name: iwfm_train_refresh
      weekday: "6"
      minute: "00"
      hour: "06"
      dump_file: iwfm_train3_06042023.dmp
      source_schema: iwfm_train3
      target_schema: iwfm_train4
  train_custom_refresh:
    - name: train_custom_refresh
      weekday: "6"
      minute: "00"
      hour: "06"
      dump_file: train_custom3_06042023.dmp
      source_schema: train_custom3
      target_schema: train_custom4


Example:
no_proxy="*" ansible-playbook site.yml --limit pp-csr-db-a -e force_role=csr-preprod-refresh