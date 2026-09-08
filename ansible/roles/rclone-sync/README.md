# Clone local directories/files using rclone

For example, use to sync files on a local filesystem to sharepoint.

Installs a script for copying/syncing local directories using rclone.
 - Must have `rclone` installed
 - The script runs via a systemd timer.
 - The script can run on multiple servers, there is a best-efforts locking mechanism
 - Use `rclone_sync_config` for configuration

Example config

```
rclone_sync_config:
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
 - `shared lock`: set this if you are enabling on multiple machines and
   the source directory is on a file share. It is a directory on the
   file share that will be created/removed by the script to manage locking
 - `rclone_args`: default rclone args to apply on every rclone command
 - `dirs`: a dictionary of directories to sync using rclone.
   The dictionary key is used in syslog logs. Then specify the rclone cmd,
   e.g. copy or sync, the src directory, rclone destination, and any
   additional `rclone_args`.
