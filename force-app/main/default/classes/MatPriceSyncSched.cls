global with sharing class MatPriceSyncSched implements Schedulable {

    // English comment: Platform scheduler entry point
    global void execute(SchedulableContext sc) {
        String requestDate = getYesterdayDate();
        // English comment: Run the pricing sync for yesterday (YYYYMMDD)
        MaterialPricingIntegrationService.syncByDate(requestDate);
    }

    // English comment: Returns yesterday in YYYYMMDD, zero-padded and timezone-safe
    public static String getYesterdayDate() {
        Date d = Date.today().addDays(-1);
        return dateToYyyymmdd(d);
    }

    // English comment: Helper to format Date -> YYYYMMDD
    private static String dateToYyyymmdd(Date d) {
        String y = String.valueOf(d.year());
        String m = d.month() < 10 ? '0' + String.valueOf(d.month()) : String.valueOf(d.month());
        String dd = d.day() < 10 ? '0' + String.valueOf(d.day()) : String.valueOf(d.day());
        return y + m + dd;
    }

    // English comment: Schedule daily at a specific hour/minute (Org time)
    public static String scheduleDaily(String jobName, Integer hour, Integer minute) {
        Integer h = (hour == null) ? 1 : hour;
        Integer m = (minute == null) ? 0 : minute;
        // Cron: second minute hour day-of-month month day-of-week
        String cron = '0 ' + String.valueOf(m) + ' ' + String.valueOf(h) + ' * * ?';
        return System.schedule(jobName, cron, new MatPriceSyncSched());
    }

    // English comment: One-off schedule helper for an exact Datetime
    public static String scheduleOnce(String jobName, Datetime whenToRun) {
        Datetime dt = whenToRun;
        String cron =
            String.valueOf(dt.second()) + ' ' +
            String.valueOf(dt.minute()) + ' ' +
            String.valueOf(dt.hour())   + ' ' +
            String.valueOf(dt.day())    + ' ' +
            String.valueOf(dt.month())  + ' ? ' +
            String.valueOf(dt.year());
        return System.schedule(jobName, cron, new MatPriceSyncSched());
    }
}