@isTest
private class SchedulerSAPMaterialSyncService_Test {

    // Simple HTTP mock used by the underlying service call //
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;
        MockHttpResponseGenerator(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(responseBody);
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }

    @isTest
    static void testExecuteDirect() {
        // Token seam + callout mock
        SAPMaterialSyncService.setAuthTokenForTest('mock-token');
        String body = '{"success":true,"message":"OK","data":[' +
                      '{"materialNumber":"MATSCH1","description":"From Scheduler","unitOfMeasure":"EA","materialType":"FERT",' +
                      '"oldMaterialNumber":"","sizeDimensions":"","productionPlant":"P1","materialGroup1":"MG1","materialGroup2":"MG2","materialGroup3":"MG3","materialGroup4":"MG4","materialGroup5":"MG5",' +
                      '"distributionChannel":"DCS","division":"DIVS","quantityUnitISO":"EA","standardPrice":"1.00","salesOrg":"SOS","plant":"P1","industryStandardDesc":"E-CC-INS","isBlock":""}' +
                      ']}';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, body));

        // Execute scheduler directly
        Test.startTest();
        new SchedulerSAPMaterialSyncService().execute(null);
        Test.stopTest();
    }

    @isTest
    static void testScheduleFramework() {
        // Token seam + callout mock
        SAPMaterialSyncService.setAuthTokenForTest('mock-token');
        String body = '{"success":true,"message":"OK","data":[' +
                      '{"materialNumber":"MATSCH2","description":"Scheduled Run","unitOfMeasure":"EA","materialType":"FERT",' +
                      '"oldMaterialNumber":"","sizeDimensions":"","productionPlant":"P2","materialGroup1":"MG1","materialGroup2":"MG2","materialGroup3":"MG3","materialGroup4":"MG4","materialGroup5":"MG5",' +
                      '"distributionChannel":"DCS","division":"DIVS","quantityUnitISO":"EA","standardPrice":"2.00","salesOrg":"SOS","plant":"P2","industryStandardDesc":"B-HM-REAGENT","isBlock":"X"}' +
                      ']}';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, body));

        // Schedule job (daily at 1 AM). On Test.stopTest(), the scheduled execute enqueues the future call.
        Test.startTest();
        System.schedule('SAPMaterialSyncScheduler_Test', '0 0 1 * * ?', new SchedulerSAPMaterialSyncService());
        Test.stopTest();
    }

    @isTest
    static void testHelperMethods() {
        // Token seam + callout mock
        SAPMaterialSyncService.setAuthTokenForTest('mock-token');
        String body = '{"success":true,"message":"OK","data":[' +
                      '{"materialNumber":"MATSCH3","description":"Helper Run","unitOfMeasure":"EA","materialType":"FERT",' +
                      '"oldMaterialNumber":"","sizeDimensions":"","productionPlant":"P3","materialGroup1":"MG1","materialGroup2":"MG2","materialGroup3":"MG3","materialGroup4":"MG4","materialGroup5":"MG5",' +
                      '"distributionChannel":"DCS","division":"DIVS","quantityUnitISO":"EA","standardPrice":"3.00","salesOrg":"SOS","plant":"P3","industryStandardDesc":"E-IMA-INS-M","isBlock":""}' +
                      ']}';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, body));

        // Exercise helper methods that build cron strings
        Test.startTest();
        SchedulerSAPMaterialSyncService.scheduleDaily('SAPMatSync_Daily_1AM', 1, 0);
        SchedulerSAPMaterialSyncService.scheduleOnce('SAPMatSync_Once', System.now().addMinutes(1));
        Test.stopTest();
    }
}