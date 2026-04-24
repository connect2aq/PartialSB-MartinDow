@IsTest
private class CustomerDemandTriggerTest {

    // ----- Mocks -----

    // Success mock: returns 200 with success=true and data value
    private class SuccessQuotationMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setBody('{"success": true, "message": "ok", "data": "TRIG-123456"}');
            return res;
        }
    }

    // Failure mock: returns 500 so we cover non-200 branch
    private class FailStatusMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setStatus('Internal Server Error');
            res.setBody('{"success": false, "message": "server error"}');
            return res;
        }
    }

    // ----- Test utilities -----

    // Provide a fake token and base endpoint so TokenRequest does not make a real call
    private static void setupFakeAuth(String baseUrl) {
        TokenRequest.testTokenResult = new TokenRequest.AuthTokenResult();
        TokenRequest.testTokenResult.token = 'FAKE_TOKEN';
        TokenRequest.testTokenResult.baseEndpointUrl = baseUrl;
        TokenRequest.testTokenResult.success = true;
        TokenRequest.testTokenResult.errorMessage = null;
    }

    // Minimal factory for Customer_Demand__c to satisfy mapping in buildQuotationRequest
    private static Customer_Demand__c makeDemand(Boolean presetExternalId) {
        Customer_Demand__c cd = new Customer_Demand__c();
        // Fields mapped in service; adjust if your org requires more fields
        cd.Order_Type__c = 'YQT - Customer Demand'; // extractCode will handle
       // cd.Sales_Org__c = '3000 - Org';
       // cd.Distribution_Channel__c = '10 - DC';
       // cd.Division__c = '30 - Div';
        cd.QT_Valid_From__c = Date.newInstance(2025, 6, 1);
        cd.QT_Valid_To__c   = Date.newInstance(2025, 6, 30);
       // cd.Plant__c = '3300 - Plant';
        cd.Purchase_Order_No__c = '96 96';
      //  cd.Sales_Office__c = '1000 - Office';
        cd.Date_of_Creation__c = Date.newInstance(2025, 6, 20);
        if (presetExternalId) {
            cd.External_Quote_ID__c = 'PRESET-ALREADY';
        }
        insert cd;
        return cd;
    }

    // ----- Tests -----

    @IsTest
    static void test_afterInsert_success_updates_external_id() {
        setupFakeAuth('https://example.com/crm-prod/api/');
        Test.setMock(HttpCalloutMock.class, new SuccessQuotationMock());

        Test.startTest();
        Customer_Demand__c cd = makeDemand(false); // after-insert fires trigger → future method
        Test.stopTest(); // flush future job

        // Re-query for visibility (no asserts per user preference)
        Customer_Demand__c afterCd = [
            SELECT Id, External_Quote_ID__c
            FROM Customer_Demand__c
            WHERE Id = :cd.Id
        ];
        System.debug('Positive path External_Quote_ID__c: ' + afterCd.External_Quote_ID__c);

        TokenRequest.testTokenResult = null;
    }

    @IsTest
    static void test_afterInsert_skips_when_external_id_preset() {
        setupFakeAuth('https://example.com/crm-prod/api/');
        Test.setMock(HttpCalloutMock.class, new SuccessQuotationMock());

        Test.startTest();
        Customer_Demand__c cd = makeDemand(true); // preset external id → future wrapper should skip
        Test.stopTest();

        Customer_Demand__c afterCd = [
            SELECT Id, External_Quote_ID__c
            FROM Customer_Demand__c
            WHERE Id = :cd.Id
        ];
        System.debug('Skip path External_Quote_ID__c (unchanged): ' + afterCd.External_Quote_ID__c);

        TokenRequest.testTokenResult = null;
    }

    @IsTest
    static void test_afterInsert_non200_response_branch() {
        setupFakeAuth('https://example.com/crm-prod/api/');
        Test.setMock(HttpCalloutMock.class, new FailStatusMock());

        Test.startTest();
        Customer_Demand__c cd = makeDemand(false); // will callout but receive 500
        Test.stopTest();

        Customer_Demand__c afterCd = [
            SELECT Id, External_Quote_ID__c
            FROM Customer_Demand__c
            WHERE Id = :cd.Id
        ];
        System.debug('Non-200 path External_Quote_ID__c (likely blank): ' + afterCd.External_Quote_ID__c);

        TokenRequest.testTokenResult = null;
    }
}