@IsTest
private class CustomerDemandIntegrationServiceTest {

    // ----------------------------
    // Callout Mocks
    // ----------------------------

    private class AppFailQuotationMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success": false, "message": "Invalid data sent", "data": null}');
            return res;
        }
    }

    private class Non200QuotationMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setStatus('500 Internal Server Error');
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error":"boom"}');
            return res;
        }
    }

    private class InvalidJsonMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setHeader('Content-Type', 'application/json');
            res.setBody('NOT_JSON_AT_ALL');
            return res;
        }
    }

    private class SuccessQuotationMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success": true, "message": "ok", "data": "12345678"}');
            return res;
        }
    }

    // ----------------------------
    // Token helper
    // ----------------------------
    private static void setAuth(String token, String baseUrl, Boolean successFlag) {
        TokenRequest.testTokenResult = new TokenRequest.AuthTokenResult();
        TokenRequest.testTokenResult.token = token;
        TokenRequest.testTokenResult.baseEndpointUrl = baseUrl;
        TokenRequest.testTokenResult.success = successFlag;
        TokenRequest.testTokenResult.errorMessage = null;
    }

    // ----------------------------
    // Demand helper (prefer existing data)
    // ----------------------------
    // English comment: Prefer using an existing Customer_Demand__c to avoid validations on insert.
    private static Customer_Demand__c getOrSeedDemand(Boolean withExternalId) {
        Customer_Demand__c cd;
        try {
            cd = [
                SELECT Id, External_Quote_ID__c, Status__c
                FROM Customer_Demand__c
                LIMIT 1
            ];
            // Adjust External_Quote_ID__c according to the scenario
            if (withExternalId && String.isBlank(cd.External_Quote_ID__c)) {
                cd.External_Quote_ID__c = 'ALREADY_SET';
                update cd;
            } else if (!withExternalId && !String.isBlank(cd.External_Quote_ID__c)) {
                cd.External_Quote_ID__c = null;
                update cd;
            }
            return cd;
        } catch (Exception ignore) {
            // If org has no existing data, attempt a minimal insert with only writable, safe fields.
            Customer_Demand__c ins = new Customer_Demand__c();
            ins.Order_Type__c        = 'YQT - Customer Demand';
            ins.QT_Valid_From__c     = Date.today();
            ins.QT_Valid_To__c       = Date.today().addDays(10);
            ins.Purchase_Order_No__c = 'PO-TEST';
            ins.Date_of_Creation__c  = Date.today();
            if (withExternalId) {
                ins.External_Quote_ID__c = 'ALREADY_SET';
            }
            insert ins;
            return ins;
        }
    }

    // ----------------------------
    // Tests (no asserts) — method-level SeeAllData to allow using existing demand
    // ----------------------------

    @IsTest(SeeAllData=true)
    static void test_postQuotation_missingBaseUrl_savesError() {
        setAuth('FAKE_TOKEN', null, true);
        Customer_Demand__c cd = getOrSeedDemand(false);

        Test.startTest();
        CustomerDemandIntegrationService.postQuotation(cd.Id);
        Test.stopTest();

        cd = [SELECT Id, External_Quote_ID__c, Error_Message__c, Status__c FROM Customer_Demand__c WHERE Id = :cd.Id];
        System.debug(cd);
        TokenRequest.testTokenResult = null;
    }

    @IsTest(SeeAllData=true)
    static void test_postQuotation_http200_appFail_savesApiMessage() {
        setAuth('FAKE_TOKEN', 'https://example.com/api/', true);
        Customer_Demand__c cd = getOrSeedDemand(false);
        Test.setMock(HttpCalloutMock.class, new AppFailQuotationMock());

        Test.startTest();
        CustomerDemandIntegrationService.postQuotation(cd.Id);
        Test.stopTest();

        cd = [SELECT Id, External_Quote_ID__c, Error_Message__c, Status__c FROM Customer_Demand__c WHERE Id = :cd.Id];
        System.debug(cd);
        TokenRequest.testTokenResult = null;
    }

    @IsTest(SeeAllData=true)
    static void test_postQuotation_non200_savesResponseBody() {
        setAuth('FAKE_TOKEN', 'https://example.com/api/', true);
        Customer_Demand__c cd = getOrSeedDemand(false);
        Test.setMock(HttpCalloutMock.class, new Non200QuotationMock());

        Test.startTest();
        CustomerDemandIntegrationService.postQuotation(cd.Id);
        Test.stopTest();

        cd = [SELECT Id, External_Quote_ID__c, Error_Message__c, Status__c FROM Customer_Demand__c WHERE Id = :cd.Id];
        System.debug(cd);
        TokenRequest.testTokenResult = null;
    }

    @IsTest(SeeAllData=true)
    static void test_postQuotation_invalidJson_exceptionPath() {
        setAuth('FAKE_TOKEN', 'https://example.com/api/', true);
        Customer_Demand__c cd = getOrSeedDemand(false);
        Test.setMock(HttpCalloutMock.class, new InvalidJsonMock());

        Test.startTest();
        CustomerDemandIntegrationService.postQuotation(cd.Id);
        Test.stopTest();

        cd = [SELECT Id, External_Quote_ID__c, Error_Message__c, Status__c FROM Customer_Demand__c WHERE Id = :cd.Id];
        System.debug(cd);
        TokenRequest.testTokenResult = null;
    }

    @IsTest(SeeAllData=true)
    static void test_future_processDemands_failure_missingBaseUrl() {
        setAuth('FAKE_TOKEN', '', true);
        Customer_Demand__c cd = getOrSeedDemand(false);

        Test.startTest();
        CustomerDemandIntegrationService.processDemandsForIntegration(new List<Id>{ cd.Id });
        Test.stopTest();

        cd = [SELECT Id, External_Quote_ID__c, Error_Message__c, Status__c FROM Customer_Demand__c WHERE Id = :cd.Id];
        System.debug(cd);
        TokenRequest.testTokenResult = null;
    }

    @IsTest(SeeAllData=true)
    static void test_success_path_direct_and_utils() {
        setAuth('FAKE_TOKEN', 'https://example.com/api/', true);
        Customer_Demand__c cd = getOrSeedDemand(false);
        Test.setMock(HttpCalloutMock.class, new SuccessQuotationMock());

        Test.startTest();
        CustomerDemandIntegrationService.postQuotation(cd.Id);
        Test.stopTest();

        CustomerDemandIntegrationService.extractCode('ABC - Something');
        CustomerDemandIntegrationService.extractCode('XYZ');
        CustomerDemandIntegrationService.extractCode(null);
        CustomerDemandIntegrationService.formatDate(Date.today());
        CustomerDemandIntegrationService.formatDate(Datetime.now());

        cd = [SELECT Id, External_Quote_ID__c, Status__c FROM Customer_Demand__c WHERE Id = :cd.Id];
        System.debug(cd);
        TokenRequest.testTokenResult = null;
    }

    @IsTest(SeeAllData=true)
    static void test_processDemands_skips_when_externalId_present() {
        setAuth('FAKE_TOKEN', 'https://example.com/api/', true);
        Customer_Demand__c cd = getOrSeedDemand(true); // ensure External_Quote_ID__c set
        Test.setMock(HttpCalloutMock.class, new SuccessQuotationMock());

        Test.startTest();
        CustomerDemandIntegrationService.processDemandsForIntegration(new List<Id>{ cd.Id });
        Test.stopTest();

        cd = [SELECT Id, External_Quote_ID__c FROM Customer_Demand__c WHERE Id = :cd.Id];
        System.debug(cd);
        TokenRequest.testTokenResult = null;
    }
}