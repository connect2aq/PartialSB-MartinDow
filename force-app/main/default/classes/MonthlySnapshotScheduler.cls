public class MonthlySnapshotScheduler implements Schedulable {

    /**
     * Fires MonthlySnapshotBatch on schedule.
     *
     * To schedule (run once in Execute Anonymous):
     *   System.schedule('Monthly Snapshot Job', '0 0 2 1 * ?', new MonthlySnapshotScheduler());
     *
     * Cron: '0 0 2 1 * ?' = 2:00 AM on the 1st of every month.
     */
    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new MonthlySnapshotBatch(), 1);
    }
}
