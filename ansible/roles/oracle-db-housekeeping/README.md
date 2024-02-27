# Overview

Role for configuring scheduled oracle Database server housekeeping.

# Pre-requisite for scheduled db server housekeeping

In group_vars add details for audit housekeeping
# Oracle database housekeeping
audit_housekeeping_period: 60
db_housekeeping_script: db_server_housekeeping.sh
housekeeping_cron:
  db_server_housekeeping:
    - name: database_server_housekeeping
      weekday: "0"
      minute: "30"
      hour: "08"
      # job: command generated in 

Example:
no_proxy="*" ansible-playbook site.yml --limit test-oem-a -e force_role=oracle-db-housekeeping
