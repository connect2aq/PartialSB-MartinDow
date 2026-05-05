// Run this script anytime after launching the batch to check progress and results.
// Re-run it repeatedly until Status = Completed.

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

// Once Status = Completed, the finish() method has already logged:
//   - Customers processed / failed
//   - Snapshots written today per customer
//   - Invoices assigned today
// Open: Setup > Apex Jobs > click the job > View Debug Log
