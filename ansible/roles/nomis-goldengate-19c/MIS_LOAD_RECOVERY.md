# MIS load recovery

**Test and preprod only**, including after a database refresh. In production, use the incident process and agree a recovery plan with the DBA and ETL owners; do not copy these repair steps into production.

Before any retry, confirm the Scheduler job and the remote Windows ETL are both stopped. Capture the failing batch ID, error and current control values, and take a recoverable backup before changing data or partitions. Check recent batches on the MIS database:

```sql
SELECT *
FROM (
  SELECT load_id, business_date, staged_start_scn, staged_end_datetime,
         load_start_datetime, load_end_datetime, error_flag, message
  FROM bodimis.etl_load_log
  WHERE repository_name = 'BODISTAGING'
  ORDER BY load_id DESC
)
WHERE ROWNUM <= 5;
```

## Wrong business date or stale balance-log partitions

1. Confirm the intended business date for the **pending** batch with the ETL owner. The ETL uses the batch's explicit date first, otherwise the previous batch's date plus one day, otherwise the batch's staged start date. Prefer correcting the pending batch rather than rewriting a completed batch: changing a control date does not redate loaded transactions or balances. Check `BODISTAGING.BUSINESS_DATE` for consistency and confirm which date the package actually sees:

   ```sql
   SELECT p.param_value AS business_date_sk, d.day_date
   FROM bodistaging.etl_param p
   LEFT JOIN bodimis.dim_date d ON d.date_sk = p.param_value
   WHERE p.param_name = 'BUSINESS_DATE_SK';
   ```

2. If the `FACT_OFF_ACC_BALANCE_AGG` refresh fails with `ORA-12096` and `ORA-14400`, check whether `BODIMIS.MLOG$_FACT_OFF_ACC_BALANCE` lacks a partition for the expected balance-date key. For that mismatch, confirm the revised `ETL_MIS` package and body are valid and that the parameter above resolves to the intended date. With ETL stopped, prepare the log **before** retrying the refresh; it can fail before the normal maintenance procedure is reached.

   ```sql
   SET SERVEROUTPUT ON
   DECLARE
     l_output VARCHAR2(4000);
   BEGIN
     BODISTAGING.ETL_MIS.prepare_foahb_partitions(l_output);
     DBMS_OUTPUT.PUT_LINE(l_output);
   END;
   /
   ```

   Preparation preserves existing log rows, but its partition DDL commits implicitly. It does not change the business date, fix previously dated facts or reconstruct missing balances. If it fails, stop and inspect the output and current partitions before retrying.

## Overnight load missed or staging batch still open

- **Staging closed, ETL never started** (`STAGED_END_DATETIME` set, `LOAD_START_DATETIME` null): resolve the reason the trigger did not run, then use the normal MIS load trigger. No batch-boundary repair is needed.
- **ETL started but did not complete** (`LOAD_START_DATETIME` set, `LOAD_END_DATETIME` null): check the ETL error and what committed before using the agreed retry procedure for that batch. Resetting the load-log row is not a rollback. A trigger stopped before Python ran does not itself require a reset.
- **Staging still open** (`STAGED_END_DATETIME` null): the newest staging batch is normally open. Recover only if an expected rollover is missing and a later boundary was saved in source `MIS_STOP_POINTS`. Check the open batch's positive `STAGED_START_SCN` matches a retained `AFTER_SCN`; if the boundary is absent, investigate source end-of-day processing rather than inventing a stop point.

For missing rollover boundaries with no later batch already present, suspend normal rollover, replication apply and ETL consumption. Run the following in a dedicated MIS database session with autocommit off, substituting the verified starting load ID:

```sql
BEGIN
  BODISTAGING.MIS_BATCH_PKG.recover_batches(
    p_tgt_owner         => 'BODISTAGING',
    p_from_batch_number => &starting_load_id
  );
END;
/
```

Use the configured package owner if it differs from `BODISTAGING`. Review recovered SCNs, closed batches and staging assignments in the same session, then explicitly `COMMIT` or `ROLLBACK`. Recovery uses saved stop points to rebuild boundaries and reassign surviving staging rows; it does not create missing source stop points, restore overwritten rows or run the ETL. If later batches already exist **after a missing boundary**, stop and review the [historical recovery procedure](README.md#recovering-mis-batch-boundaries) separately; it can renumber existing batches.

After recovery, resume normal processing and verify that the intended batch completes (`LOAD_END_DATETIME` set, `ERROR_FLAG='N'`). For a balance-log repair, also confirm that the balance aggregate refreshed and reconcile the affected balances before closing the incident.
