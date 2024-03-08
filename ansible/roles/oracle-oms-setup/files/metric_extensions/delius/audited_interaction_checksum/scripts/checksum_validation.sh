#!/bin/bash

. ~/.bash_profile

sqlplus -s / as sysdba << EOSQL
SET HEADING OFF
SET PAGES 0
SET FEEDBACK OFF
SET LINES 256

ALTER SESSION SET NLS_DATE_FORMAT = 'DD-MON-YYYY HH24:MI:SS';

WITH most_recent_resetlogs AS (
    SELECT
        client_db,
        MAX(start_date_time) resetlogs_date_time
    FROM
        delius_audit_dms_pool.audited_interaction_checksum
    WHERE
        resetlogs = 'Y'
    GROUP BY
        client_db
), most_recently_validated_ranges AS (
    SELECT
        x.client_db,
        x.start_date_time,
        x.end_date_time,
        x.row_count,
        x.data_checksum,
        x.checksum_validated
    FROM
        delius_audit_dms_pool.audited_interaction_checksum x
    WHERE
        ( x.client_db, x.end_date_time ) IN (
            SELECT
                y.client_db, MAX(y.end_date_time)
            FROM
                delius_audit_dms_pool.audited_interaction_checksum y
            WHERE
                y.checksum_validated != 'N'
            AND
                y.start_date_time >= (
                    SELECT
                        resetlogs_date_time
                    FROM
                        most_recent_resetlogs r
                    WHERE
                        r.client_db = y.client_db
                )
            GROUP BY
                y.client_db
        )
), monitoring_discontinuities AS (
    SELECT
        a.client_db,
        COUNT(*) discontinuities
    FROM
        delius_audit_dms_pool.audited_interaction_checksum a
    WHERE
        NOT EXISTS (
            SELECT
                1
            FROM
                delius_audit_dms_pool.audited_interaction_checksum b
            WHERE
                    a.client_db = b.client_db
                AND a.end_date_time = b.start_date_time
        )
            AND ( a.client_db, a.start_date_time ) NOT IN (
            SELECT
                c.client_db, MAX(c.start_date_time)
            FROM
                delius_audit_dms_pool.audited_interaction_checksum c
            GROUP BY
                c.client_db
        )
            AND a.start_date_time >= (
            SELECT
                resetlogs_date_time
            FROM
                most_recent_resetlogs r
            WHERE
                r.client_db = a.client_db
        )
    GROUP BY
        a.client_db
)
SELECT
    mrr.client_db
    || '|'
    || rl.resetlogs_date_time
    || '|'
    || mrr.start_date_time
    || '|'
    || mrr.end_date_time
    || '|'
    || round(sysdate - mrr.start_date_time, 1)
    || '|'
    || round(sysdate - mrr.end_date_time, 1)
    || '|'
    || mrr.row_count
    || '|'
    || mrr.data_checksum
    || '|'
    || mrr.checksum_validated
    || '|'
    || coalesce(md.discontinuities, 0)
FROM
         most_recently_validated_ranges mrr
    INNER JOIN most_recent_resetlogs                 rl ON mrr.client_db = rl.client_db
    LEFT OUTER JOIN monitoring_discontinuities            md ON mrr.client_db = md.client_db
GROUP BY
    mrr.client_db,
    rl.resetlogs_date_time,
    mrr.start_date_time,
    mrr.end_date_time,
    mrr.row_count,
    mrr.data_checksum,
    mrr.checksum_validated,
    md.discontinuities;


EXIT
EOSQL