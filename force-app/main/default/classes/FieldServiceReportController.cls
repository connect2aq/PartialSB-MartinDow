public class FieldServiceReportController {

    // Constructor for Visualforce extension
    public FieldServiceReportController(ApexPages.StandardController controller) {
    }

    // Convert UTC → User Timezone
    public Datetime getLocalTime() {
        Datetime utcNow = System.now();
        Integer offset = UserInfo.getTimeZone().getOffset(utcNow) / 1000;
        return utcNow.addSeconds(offset);
    }
}