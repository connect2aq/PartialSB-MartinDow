// ── Step 1: Run this full script once to launch the batch ────────────────────
Id jobId = Database.executeBatch(new MonthlySnapshotBatch(), 1);
System.debug('Batch launched. Job ID: ' + jobId);

// ── Step 2: Select only this block and re-run to check progress ──────────────
AsyncApexJob job = [
    SELECT Id, Status, JobItemsProcessed, TotalJobItems, NumberOfErrors, ExtendedStatus
    FROM AsyncApexJob
    WHERE ApexClass.Name = 'MonthlySnapshotBatch'
    ORDER BY CreatedDate DESC
    LIMIT 1
];
System.debug(
    'Status: ' + job.Status +
    ' | Progress: ' + job.JobItemsProcessed + '/' + job.TotalJobItems +
    ' | Errors: ' + job.NumberOfErrors +
    (String.isNotBlank(job.ExtendedStatus) ? ' | Detail: ' + job.ExtendedStatus : '')
);
// Once Status = Completed, open: Setup > Apex Jobs > click the job > View Debug Log
// The finish() method logs: customers processed, snapshots written today, invoices assigned today.
