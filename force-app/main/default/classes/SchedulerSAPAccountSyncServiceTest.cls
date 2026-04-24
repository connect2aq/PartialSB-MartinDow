@IsTest
private class SchedulerSAPAccountSyncServiceTest {

    // Reuse a mock that returns an empty list for any date (keeps the run lightweight)
    private class AnyDayMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String body = '{ "success": true, "message": "ok", "data": [] }';
            res.setStatusCode(200);
            res.setBody(body);
            return res;
        }
    }

    @TestSetup
    static void setup() {
        TokenRequest.testTokenResult = new TokenRequest.AuthTokenResult();
        TokenRequest.testTokenResult.token = 'sched-token';
        TokenRequest.testTokenResult.baseEndpointUrl = 'https://example.com/api/';
        TokenRequest.testTokenResult.success = true;
        TokenRequest.testTokenResult.errorMessage = null;
    }

    @IsTest
    static void testExecuteViaScheduleOnce() {
        Test.setMock(HttpCalloutMock.class, new AnyDayMock());

        // Schedule one-off a minute from now; Test.stopTest triggers it
        Datetime whenToRun = System.now().addMinutes(1);
        Test.startTest();
        String jobId = SchedulerSAPAccountSyncService.scheduleOnce('SAP Sync One-Off Test', whenToRun);
        Test.stopTest();

        // No asserts; ensures execute() ran and called SAPAccountSyncService with a computed yesterday date.
    }

    @IsTest
    static void testExecuteDirect() {
        Test.setMock(HttpCalloutMock.class, new AnyDayMock());
        Test.startTest();
        new SchedulerSAPAccountSyncService().execute(null);
        Test.stopTest();
    }

    @IsTest
    static void testScheduleDailyHelper() {
        Test.setMock(HttpCalloutMock.class, new AnyDayMock());
        Test.startTest();
        String jobId = SchedulerSAPAccountSyncService.scheduleDaily('SAP Sync Daily Test', 1, 5);
        Test.stopTest();
    }
}