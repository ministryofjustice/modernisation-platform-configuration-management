#!/bin/bash

. ~/.bash_profile

# Exit without failure if database is not up
srvctl status database -d $ORACLE_SID >/dev/null || exit 0

sqlplus -s / as sysdba<<EOF
SET PAGES 0
SET LINES 40
SET FEEDBACK OFF
SET ECHO OFF
WITH blocking_session AS
(SELECT s.sid,
        s.serial#,
        l.id1,
        l.id2
 FROM  v\$lock l
 INNER JOIN v\$session s ON l.sid = s.sid
 AND l.block = 1
 AND s.type != 'BACKGROUND'),
 waiting_session AS
(SELECT s.sid,
        l.id1,
        l.id2
 FROM  v\$lock  l
 INNER JOIN v\$session s ON l.sid = s.sid
 AND l.request <> 0
 AND NOT (s.event = 'enq: CI - contention' AND s.p1 LIKE '112%' and s.program like 'rman@%' ) -- Ignore Cross Instance Call Waits for ASM Map Locks during RMAN Backup
 AND s.type != 'BACKGROUND')
SELECT b.sid||'|'||b.serial#||'|'||count(*)
FROM blocking_session b,
     waiting_session w
WHERE w.id1 = b.id1
AND w.id2 = b.id2
AND w.sid <> b.sid
AND NOT EXISTS (SELECT 1 
                 FROM   dba_objects o
                 WHERE  w.id1 = o.object_id 
                 AND (o.owner,o.object_name) IN (('NDMIS_DATA','AUDITED_INTERACTION'))
                 )
GROUP BY b.sid,b.serial#;
EXIT
EOF