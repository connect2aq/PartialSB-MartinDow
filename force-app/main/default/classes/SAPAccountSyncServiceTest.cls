@IsTest
private class SAPAccountSyncServiceTest {

    // ----- helpers -----
    private static String yyyymmdd(Date d) {
        return String.valueOf(d.year())
             + String.valueOf(d.month()).leftPad(2,'0')
             + String.valueOf(d.day()).leftPad(2,'0');
    }

    private static void setToken(String baseUrl) {
        TokenRequest.AuthTokenResult tr = new TokenRequest.AuthTokenResult();
        tr.token = 'TEST_TOKEN';
        tr.baseEndpointUrl = baseUrl;
        tr.success = true;
        tr.errorMessage = null;
        TokenRequest.testTokenResult = tr;
    }

    private static void clearToken() {
        TokenRequest.testTokenResult = null;
    }

    // Common GET endpoint asserted in mocks
    private static Boolean isGetEndpoint(String ep) {
        return ep != null && ep.contains('SAP/GetAccountDetails');
    }

    // ----- mocks -----
    // success: empty data
    private class MockOkEmpty implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            if (isGetEndpoint(req.getEndpoint())) {
                r.setBody('{"success": true, "message": "ok", "data": []}');
            } else {
                r.setBody('{"success": true}');
            }
            return r;
        }
    }

    // success: with data (covers SA + TaxNumbers + Credit + Phase-2 tax)
    private class MockOkWithData implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            if (isGetEndpoint(req.getEndpoint())) {
                String body =
                '{ "success": true, "message": "ok", "data": [' +
                  '{ "kunnr":"K1001","name1":"Acme Lab","country":"PK","bukrs":"3000","akont":"140000",' +
                    '"city":"Karachi","district":"Sindh","postlcod1":"75500","strsuppl3":"Street 1","location":"Phase 2",' +
                    '"n_CUSTMER":[{"eMail":"a@acme.com"}],' +
                    '"n_CUSTMER3":[{"telephone":"021-111"}],' +
                    '"n_CUSTMER4":[{"mobile":"0300-111"}],' +
                    '"n_CUSTMER1":[{"tatyp":"MWST","taxkd":"1"},{"tatyp":"ZPK2","taxkd":"5"}],' +
                    '"n_CUSTMER2":[{"taxtype":"NTN","taxnumber":"12345"}],' +
                    '"n_CUSTMER6":[{"creditSegment":"GEN","creditLimit":"1000","outstandingAmount":"250"}],' +
                    '"cusT_SD":[{' +
                       '"vkorg":"1000","vtweg":"10","spart":"00","bzirk":"001",' +
                       '"vwerk":"P001","kdgrp":"01","vkbur":"KHI","waers":"PKR","vkgrp":"S1",' +
                       '"konda":"A1","kalks":"Z1","inco1":"FOB","inco2":"Port","ztermsd":"PT30","ktgrd":"01","zterm":"PT30"' +
                    '}]' +
                  '}' +
                ']}';
                r.setBody(body);
            } else {
                r.setBody('{"success": true}');
            }
            return r;
        }
    }

    // non-200
    private class MockNon200 implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(500);
            r.setBody('{"success": false, "message":"err"}');
            return r;
        }
    }

    // throw exception from send()
    private class MockThrows implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            // Simulate transport error
            throw new CalloutException('boom');
        }
    }

    // ----- tests -----
    @IsTest
    static void t01_InvalidDate() {
        // No mock/token needed; method exits on validation
        SAPAccountSyncService.ResultSummary s = SAPAccountSyncService.syncByDate('2024-01-02');
        System.assertNotEquals(null, s);
        System.assertEquals(1, s.failureCount);
    }

    @IsTest
    static void t02_AuthFailure() {
        clearToken(); // ensures getAuthToken() does NOT have a fake token
        SAPAccountSyncService.ResultSummary s = SAPAccountSyncService.syncByDate(yyyymmdd(Date.newInstance(2025,1,1)));
        System.assertNotEquals(null, s);
        System.assertEquals(true, s.failureCount > 0);
    }

    @IsTest
    static void t03_HttpException() {
        setToken('https://example.com/');
        Test.setMock(HttpCalloutMock.class, new MockThrows());
        Test.startTest();
        SAPAccountSyncService.ResultSummary s = SAPAccountSyncService.syncByDate(yyyymmdd(Date.newInstance(2025,1,2)));
        Test.stopTest();
        System.assertNotEquals(null, s);
        System.assertEquals(true, s.failureCount > 0);
        clearToken();
    }

    @IsTest
    static void t04_Non200() {
        setToken('https://example.com/');
        Test.setMock(HttpCalloutMock.class, new MockNon200());
        Test.startTest();
        SAPAccountSyncService.ResultSummary s = SAPAccountSyncService.syncByDate(yyyymmdd(Date.newInstance(2025,1,3)));
        Test.stopTest();
        System.assertNotEquals(null, s);
        System.assertEquals(true, s.failureCount > 0);
        clearToken();
    }

    @IsTest
    static void t05_EmptyOK() {
        setToken('https://example.com/');
        Test.setMock(HttpCalloutMock.class, new MockOkEmpty());
        Test.startTest();
        SAPAccountSyncService.ResultSummary s = SAPAccountSyncService.syncByDate(yyyymmdd(Date.newInstance(2025,1,4)));
        Test.stopTest();
        System.assertNotEquals(null, s);
        System.assertEquals(0, s.total, 'no rows should process');
        clearToken();
    }

    @IsTest
    static void t06_FullOK() {
        setToken('https://example.com/');
        Test.setMock(HttpCalloutMock.class, new MockOkWithData());
        Test.startTest();
        SAPAccountSyncService.ResultSummary s = SAPAccountSyncService.syncByDate(yyyymmdd(Date.newInstance(2025,1,5)));
        Test.stopTest();
        System.assertNotEquals(null, s);
        System.assertEquals(true, s.total >= 1);
        System.assertEquals(true, s.successCount >= 1);
        clearToken();
    }
    
    @IsTest
    static void t07_EnqueueFullOK() {
        setToken('https://example.com/');
        Test.setMock(HttpCalloutMock.class, new MockOkWithData());
        Test.startTest();
        SAPAccountSyncService.enqueueSyncByDate(yyyymmdd(Date.newInstance(2025,1,5)));
        Test.stopTest();
        clearToken();
    }
}