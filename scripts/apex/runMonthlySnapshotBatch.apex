// ─────────────────────────────────────────────────────────────────────────────
// Step 1: Launch the batch (scope = 1 customer per transaction)
// ─────────────────────────────────────────────────────────────────────────────
Id jobId = Database.executeBatch(new MonthlySnapshotBatch(), 1);
System.debug('Batch launched. Job ID: ' + jobId);

// ─────────────────────────────────────────────────────────────────────────────
// Step 2: Immediately check job status (re-run this block to poll progress)
// ─────────────────────────────────────────────────────────────────────────────
AsyncApexJob job = [
    SELECT Id, Status, JobItemsProcessed, TotalJobItems, NumberOfErrors, ExtendedStatus
    FROM AsyncApexJob
    WHERE Id = :jobId
];
System.debug(
    'Status: ' + job.Status +
    ' | Progress: ' + job.JobItemsProcessed + '/' + job.TotalJobItems +
    ' | Errors: ' + job.NumberOfErrors
);

// ─────────────────────────────────────────────────────────────────────────────
// Steps 3 & 4 run automatically inside the batch finish() method.
// When the job Status = 'Completed', open the Apex Debug Log for the
// batch finish transaction to see:
//   • Customers processed / failed count
//   • Snapshots written today (per customer)
//   • Invoices assigned/updated today
// ─────────────────────────────────────────────────────────────────────────────
