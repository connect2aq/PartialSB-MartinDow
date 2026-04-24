global class SchedulerSAPMaterialSyncService implements Schedulable {
    global void execute(SchedulableContext sc) {
        // Build request date as Yesterday in YYYYMMDD format
        String requestDate = SAPMaterialSyncService.getYesterdayDate();

        // Call the async future method
        SAPMaterialSyncService.syncMaterialsFromSAP(requestDate);
    }

    // Optional helper: schedule daily at a specific hour/minute (Org time zone)
    public static String scheduleDaily(String jobName, Integer hour, Integer minute) {
        // Fallbacks if nulls are passed
        Integer h = (hour == null) ? 1 : hour;
        Integer m = (minute == null) ? 0 : minute;

        // Cron: second minute hour day-of-month month day-of-week
        String cron = '0 ' + String.valueOf(m) + ' ' + String.valueOf(h) + ' * * ?';
        return System.schedule(jobName, cron, new SchedulerSAPMaterialSyncService());
    }

    // Optional helper: schedule a one-off run at a specific Datetime
    public static String scheduleOnce(String jobName, Datetime whenToRun) {
        Datetime dt = whenToRun;
        String cron =
            String.valueOf(dt.second()) + ' ' +
            String.valueOf(dt.minute()) + ' ' +
            String.valueOf(dt.hour())   + ' ' +
            String.valueOf(dt.day())    + ' ' +
            String.valueOf(dt.month())  + ' ? ' +
            String.valueOf(dt.year());
        return System.schedule(jobName, cron, new SchedulerSAPMaterialSyncService());
    }
}