public class MonthlySnapshotScheduler implements Schedulable {

    /**
     * Fires MonthlySnapshotBatch on schedule.
     *
     * To schedule (run once in Execute Anonymous):
     *   System.schedule('Monthly Snapshot Job', '0 0 5 1 * ?', new MonthlySnapshotScheduler());
     *
     * Cron: '0 0 5 1 * ?' = 5:00 AM on the 1st of every month.
     */
    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new MonthlySnapshotBatch(), 1);
    }
}
