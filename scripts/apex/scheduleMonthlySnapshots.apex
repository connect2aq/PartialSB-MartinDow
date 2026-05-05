// Run this ONCE in Execute Anonymous to register the monthly scheduled job.
// After running, confirm via Setup > Scheduled Jobs.
//
// Cron: '0 0 2 1 * ?' = 2:00 AM on the 1st of every month.
//
// To abort the existing job before rescheduling:
//   CronTrigger ct = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'Monthly Snapshot Job' LIMIT 1];
//   System.abortJob(ct.Id);

System.schedule('Monthly Snapshot Job', '0 0 5 1 * ?', new MonthlySnapshotScheduler());
System.debug('Monthly Snapshot Job scheduled successfully.');
