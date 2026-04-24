@IsTest
private class MatPriceSyncSchedTest {

    @testSetup
    static void setupData() {
        // English comment: Seed products that match the pricing mock response
        insert new List<MD_Product2__c>{
            new MD_Product2__c(Material_Number__c = '15002865', Price__c = 0),
            new MD_Product2__c(Material_Number__c = '15002671', Price__c = 0)
        };
    }

    // English comment: Composite mock -> 1st call: token; 2nd call: pricing for yesterday (any date suffix)
    private class TokenAndPricingMock implements HttpCalloutMock {
        private Integer callNo = 0;

        public HTTPResponse respond(HTTPRequest req) {
            callNo++;
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            String url = req.getEndpoint() == null ? '' : req.getEndpoint();
            String method = req.getMethod();

            // English comment: First call -> Token endpoint (whatever TokenRequest calls first)
            if (callNo == 1) {
                res.setStatusCode(200);
                // English comment: Adjust keys only if your TokenRequest expects different names
                res.setBody('{' +
                    '"success": true,' +
                    '"token": "TEST_TOKEN",' +
                    '"baseEndpointUrl": "https://example.com/"' +
                '}');
                return res;
            }

            // English comment: Second call -> Pricing endpoint (accept any yesterday date in URL)
            if ('GET'.equalsIgnoreCase(method) && url.contains('/SAP/GetMaterialPricingInfo/')) {
                res.setStatusCode(200);
                // English comment: Return array with 2 matching materials (will update records)
                res.setBody('{' +
                    '"success": true,' +
                    '"message": "Success",' +
                    '"data": [' +
                    '  {"materialNo":"15002865","amount": 111.11},' +
                    '  {"materialNo":"15002671","amount": 222.22}' +
                    ']}' );
                return res;
            }

            // English comment: Fallback safety
            res.setStatusCode(200);
            res.setBody('{"success": true, "message": "OK", "data": []}');
            return res;
        }
    }

    // English comment: Executes the schedulable via scheduleOnce; stopTest() will fire the job
    @IsTest
    static void test_ExecuteViaScheduleOnce() {
        ApiLogUtil.get().clear();
        Test.setMock(HttpCalloutMock.class, new TokenAndPricingMock());

        // English comment: Schedule to run one minute from now; it will execute at Test.stopTest()
        Datetime runAt = System.now().addMinutes(1);

        Test.startTest();
        String jobId = MatPriceSyncSched.scheduleOnce('Test MatPriceSync Once', runAt);
        System.debug('Scheduled Job Id: ' + jobId);
        Test.stopTest();

        // English comment: Touch updated rows and logs to ensure paths executed (no asserts per requirement)
        List<MD_Product2__c> after = [
            SELECT Id, Material_Number__c, Price__c
            FROM MD_Product2__c
            WHERE Material_Number__c IN ('15002865', '15002671')
            ORDER BY Material_Number__c
        ];
        System.debug('Products after scheduled execution: ' + after);

        List<API_Log__c> logs = [
            SELECT Id, API_Name__c, Response_Code__c, Response_Message__c
            FROM API_Log__c
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];
        System.debug('Logs after scheduled execution: ' + logs);
    }

    // English comment: Covers scheduleDaily() method (line coverage for cron build and System.schedule)
    @IsTest
    static void test_ScheduleDailyHelper() {
        Test.startTest();
        String idDaily = MatPriceSyncSched.scheduleDaily('Daily Pricing Sync Test', 1, 5);
        System.debug('Daily Scheduled Job Id: ' + idDaily);
        Test.stopTest();
    }

    // English comment: Covers getYesterdayDate() formatting helper
    @IsTest
    static void test_GetYesterdayDateFormatting() {
        String y = MatPriceSyncSched.getYesterdayDate();
        System.debug('Computed Yesterday (YYYYMMDD): ' + y);
    }
}