// Run this script ONCE to launch the batch.
// Then run checkMonthlySnapshotBatch.apex to monitor progress.

Id jobId = Database.executeBatch(new MonthlySnapshotBatch(), 1);
System.debug('Batch launched. Job ID: ' + jobId);
