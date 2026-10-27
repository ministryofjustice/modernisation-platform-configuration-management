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
  shared_lock: "/my-network-mount/.rclone-sync.lock"
  rclone_args:
    - "--min-age=2m"
    - "--stats=0"
    - "--fast-list"
  dirs:
    example:
      frequency_interval_seconds: 3600    # run every hour
      frequency_offset_seconds: 900       # run 15 minutes past the hour
      maintenance_window: "1.0400-1.0430" # e.g. day.HHMM where 1=Monday in UTC"
      rclone_cmd:
        - "copy"
        - "/my/sourcedir"
        - "rcloneconfig:sharepoint/path"
      rclone_args:
        - "--min-age=2m"
        - "--max-age=1d"
        - "--include=*.xlsx"
        - "--ignore-size"      # because MS365 immediately updates xlsx files
        - "--ignore-checksum"  # ditto
        - "--max-depth=1"      # only sync top-level dir
      rclone_sync_args:
        - "--rclone-sync-frequency-interval=3600"              # run every hour
        - "--rclone-sync-frequency-offset=900"                 # run 15 minutes past the hour
        - "--rclone-sync-maintenance-window=1.0400-1.0430"     # don't run during maintenance window, day.HHMM where 1=Monday in UTC
        - "--rclone-error-backoff=600"                         # wait before retrying on error
        - "--rclone-alarm-after-consecutive-error-count=10"    # only alarm after this number of consecutive errors
        - "--rclone-sync-move-after-consecutive-error-count=3" # workaround using moveto if copy/sync repeatedly fails
```

Where
- `shared_lock`: set this if you are enabling on multiple machines and
   the source directory is on a file share. It is a directory on the
   file share that will be created/removed by the script to manage locking
- `rclone_cmd`: the rclone cmd and associated args
- `rclone_args`: default rclone args to apply on every rclone command
- `rclone_sync_args`: args specific to the rclone-sync.sh wrapper script
- `dirs`: a dictionary of directories to sync using rclone.
   The dictionary key is used in syslog logs. Then specify the rclone cmd,
   e.g. copy or sync, and any additional `rclone_args`.
