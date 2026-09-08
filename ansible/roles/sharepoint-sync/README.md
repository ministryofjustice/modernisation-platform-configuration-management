# Upload files to sharepoint using rclone

Example group vars like this

```
sharepoint_sync_config:
  shared_lock: "/samba.delius-prod.internal/secure/NPS/nart/.sharepoint-sync.lock"
  rclone_args:
    - "--min-age=2m"
    - "--stats=0"
    - "--fast-list"
  dirs:
    wmt:
      rclone_cmd: copy
      rclone_src: "/samba.delius-prod.internal/secure/NPS/National/wmt"
      rclone_dest: "wmt:NDelius MIS Reports/Caseload Reports"
      rclone_args:
        - "--include=*.xlsx"
        - "--dry-run"
```

Where
 - `shared lock`: set this if you are enabling on multiple machines.
   This must be a file share available on all machines running the script.
 - `rclone_args`: default rclone args to apply on every rclone command
 - `dirs`: a dictionary of directories to sync to sharepoint.
   The dictionary key is used in syslog logs. Then specify the rclone cmd,
   e.g. copy or sync, the src directory, rclone destination, and any
   additional `rclone_args`.
