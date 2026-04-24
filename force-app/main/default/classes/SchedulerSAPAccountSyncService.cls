global class SchedulerSAPAccountSyncService implements Schedulable {
    // Runs from the platform scheduler
    global void execute(SchedulableContext sc) {
        // Build request date = yesterday in YYYYMMDD
        String requestDate = getYesterdayDate();

        // Call the sync and log a compact summary
        SAPAccountSyncService.enqueueSyncByDate(requestDate);
        /*
            SAPAccountSyncService.ResultSummary res = SAPAccountSyncService.syncByDate(requestDate);
            System.debug('AccountSync | date=' + requestDate +
                         ' | total=' + res.total +
                         ' | success=' + res.successCount +
                         ' | failed=' + res.failureCount +
                         ' | failures=' + String.join(res.failures, ' || '));
		*/
    }

    // Helper: yesterday in YYYYMMDD (timezone-safe, zero-padded)
    public static String getYesterdayDate() {
        Date d = Date.today().addDays(-1);
        return dateToYyyymmdd(d);
    }

    // Helper: format Date -> YYYYMMDD
    private static String dateToYyyymmdd(Date d) {
        String y = String.valueOf(d.year());
        String m = d.month() < 10 ? '0' + String.valueOf(d.month()) : String.valueOf(d.month());
        String dd = d.day() < 10 ? '0' + String.valueOf(d.day()) : String.valueOf(d.day());
        return y + m + dd;
    }

    // Optional: schedule daily at a specific hour/minute (Org time zone)
    public static String scheduleDaily(String jobName, Integer hour, Integer minute) {
        Integer h = (hour == null) ? 1 : hour;
        Integer m = (minute == null) ? 0 : minute;
        // Cron: second minute hour day-of-month month day-of-week
        String cron = '0 ' + String.valueOf(m) + ' ' + String.valueOf(h) + ' * * ?';
        return System.schedule(jobName, cron, new SchedulerSAPAccountSyncService());
    }

    // Optional: schedule a one-off run at a specific Datetime
    public static String scheduleOnce(String jobName, Datetime whenToRun) {
        Datetime dt = whenToRun;
        String cron =
            String.valueOf(dt.second()) + ' ' +
            String.valueOf(dt.minute()) + ' ' +
            String.valueOf(dt.hour())   + ' ' +
            String.valueOf(dt.day())    + ' ' +
            String.valueOf(dt.month())  + ' ? ' +
            String.valueOf(dt.year());
        return System.schedule(jobName, cron, new SchedulerSAPAccountSyncService());
    }
}