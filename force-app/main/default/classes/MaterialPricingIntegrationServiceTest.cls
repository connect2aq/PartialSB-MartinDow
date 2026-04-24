@IsTest
private class MaterialPricingIntegrationServiceTest {

    @testSetup
    static void setupData() {
        // English comment: Seed sample products that match mock response
        insert new List<MD_Product2__c>{
            new MD_Product2__c(Material_Number__c = '15002865', Price__c = 0),
            new MD_Product2__c(Material_Number__c = '15002671', Price__c = 0)
        };
    }

    // English comment: Composite mock — 1st call: token; next calls: pricing responses by requested date
    private class PricingAndTokenMock implements HttpCalloutMock {
        private Integer callNo = 0;

        public HTTPResponse respond(HTTPRequest req) {
            callNo++;
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String url = req.getEndpoint() == null ? '' : req.getEndpoint();
            String method = req.getMethod();

            // ---- 1) Token call (first call) ----
            if (callNo == 1) {
                res.setStatusCode(200);
                res.setBody('{' +
                    '"success": true,' +
                    '"token": "TEST_TOKEN",' +
                    '"baseEndpointUrl": "https://example.com/"' +
                '}');
                return res;
            }

            // ---- 2) Pricing calls (GET) ----
            if ('GET'.equalsIgnoreCase(method)) {

                // A) Success with data array (2 matches + 1 non-matching)
                if (url.endsWith('/SAP/GetMaterialPricingInfo/20251104')) {
                    res.setStatusCode(200);
                    res.setBody('{' +
                        '"success": true,' +
                        '"message": "Success",' +
                        '"data": [' +
                        '  {"materialNo":"15002865","amount": 123.45},' +
                        '  {"materialNo":"15002671","amount": "678.90"},' +   // string amount parses via try
                        '  {"materialNo":"99999999","amount": "N/A"}' +        // unparsable -> skipped
                        ']}' );
                    return res;
                }

                // B) Success with "No Data"
                if (url.endsWith('/SAP/GetMaterialPricingInfo/20251105')) {
                    res.setStatusCode(200);
                    res.setBody('{"success": true, "message": "Success", "data": "No Data"}');
                    return res;
                }

                // C) Non-200 (abort)
                if (url.endsWith('/SAP/GetMaterialPricingInfo/20251106')) {
                    res.setStatusCode(500);
                    res.setBody('{"success": false, "message": "Server Error"}');
                    return res;
                }

                // D) Success with empty array
                if (url.endsWith('/SAP/GetMaterialPricingInfo/20251107')) {
                    res.setStatusCode(200);
                    res.setBody('{"success": true, "message": "Success", "data": []}');
                    return res;
                }

                // E) data = null
                if (url.endsWith('/SAP/GetMaterialPricingInfo/20251108')) {
                    res.setStatusCode(200);
                    res.setBody('{"success": true, "message": "Success", "data": null}');
                    return res;
                }

                // F) Unexpected string (not "No Data")
                if (url.endsWith('/SAP/GetMaterialPricingInfo/20251109')) {
                    res.setStatusCode(200);
                    res.setBody('{"success": true, "message": "Success", "data": "SOMETHING_ELSE"}');
                    return res;
                }

                // G) Unexpected non-list type (object)
                if (url.endsWith('/SAP/GetMaterialPricingInfo/20251110')) {
                    res.setStatusCode(200);
                    res.setBody('{"success": true, "message": "Success", "data": {"foo": 1}}');
                    return res;
                }

                // H) Array with only unknown materials (no matching products)
                if (url.endsWith('/SAP/GetMaterialPricingInfo/20251111')) {
                    res.setStatusCode(200);
                    res.setBody('{' +
                        '"success": true,' +
                        '"message": "Success",' +
                        '"data": [' +
                        '  {"materialNo":"99900001","amount": 10.00},' +
                        '  {"materialNo":"99900002","amount": 20.00}' +
                        ']}' );
                    return res;
                }

                // I) Malformed JSON to exercise exception path
                if (url.endsWith('/SAP/GetMaterialPricingInfo/20251112')) {
                    res.setStatusCode(200);
                    res.setBody('{"success": true, "message": "Success", "data": [ '); // broken JSON
                    return res;
                }

                // Default safety
                if (url.contains('/SAP/GetMaterialPricingInfo/')) {
                    res.setStatusCode(200);
                    res.setBody('{"success": true, "message": "Success", "data": []}');
                    return res;
                }
            }

            // Fallback
            res.setStatusCode(200);
            res.setBody('{"success": true, "message": "OK", "data": []}');
            return res;
        }
    }

    // --- Core paths already covered ---

    @IsTest
    static void test_Success_With_DataArray() {
        ApiLogUtil.get().clear();
        Test.setMock(HttpCalloutMock.class, new PricingAndTokenMock());
        Test.startTest();
        MaterialPricingIntegrationService.syncByDate('20251104');
        Test.stopTest();

        List<MD_Product2__c> after = [
            SELECT Id, Material_Number__c, Price__c
            FROM MD_Product2__c
            WHERE Material_Number__c IN ('15002865','15002671')
            ORDER BY Material_Number__c
        ];
        System.debug('After success+data update: ' + after);

        List<API_Log__c> logs = [
            SELECT Id, API_Name__c, Response_Code__c
            FROM API_Log__c
            ORDER BY CreatedDate DESC
            LIMIT 5
        ];
        System.debug('Logs (success+data): ' + logs);
    }

    @IsTest
    static void test_Success_NoData() {
        ApiLogUtil.get().clear();
        Test.setMock(HttpCalloutMock.class, new PricingAndTokenMock());
        Test.startTest();
        MaterialPricingIntegrationService.syncByDate('20251105');
        Test.stopTest();
    }

    @IsTest
    static void test_Non200() {
        ApiLogUtil.get().clear();
        Test.setMock(HttpCalloutMock.class, new PricingAndTokenMock());
        Test.startTest();
        MaterialPricingIntegrationService.syncByDate('20251106');
        Test.stopTest();
    }

    @IsTest
    static void test_EmptyArray() {
        ApiLogUtil.get().clear();
        Test.setMock(HttpCalloutMock.class, new PricingAndTokenMock());
        Test.startTest();
        MaterialPricingIntegrationService.syncByDate('20251107');
        Test.stopTest();
    }

    // --- Extra branches for higher coverage ---

    @IsTest
    static void test_DataNull() {
        ApiLogUtil.get().clear();
        Test.setMock(HttpCalloutMock.class, new PricingAndTokenMock());
        Test.startTest();
        MaterialPricingIntegrationService.syncByDate('20251108');
        Test.stopTest();
    }

    @IsTest
    static void test_DataUnexpectedString() {
        ApiLogUtil.get().clear();
        Test.setMock(HttpCalloutMock.class, new PricingAndTokenMock());
        Test.startTest();
        MaterialPricingIntegrationService.syncByDate('20251109');
        Test.stopTest();
    }

    @IsTest
    static void test_DataUnexpectedType() {
        ApiLogUtil.get().clear();
        Test.setMock(HttpCalloutMock.class, new PricingAndTokenMock());
        Test.startTest();
        MaterialPricingIntegrationService.syncByDate('20251110');
        Test.stopTest();
    }

    @IsTest
    static void test_NoMatchingProducts() {
        ApiLogUtil.get().clear();
        Test.setMock(HttpCalloutMock.class, new PricingAndTokenMock());
        Test.startTest();
        MaterialPricingIntegrationService.syncByDate('20251111');
        Test.stopTest();
    }

    @IsTest
    static void test_MalformedJson_ExceptionPath() {
        ApiLogUtil.get().clear();
        Test.setMock(HttpCalloutMock.class, new PricingAndTokenMock());
        Test.startTest();
        MaterialPricingIntegrationService.syncByDate('20251112');
        Test.stopTest();
    }

    // English comment: Invalid date guard (no callout)
    @IsTest
    static void test_InvalidDate_Guard() {
        ApiLogUtil.get().clear();
        Test.startTest();
        MaterialPricingIntegrationService.syncByDate('2025-11-04'); // invalid
        MaterialPricingIntegrationService.syncByDate('');           // blank
        MaterialPricingIntegrationService.syncByDate('2025');       // short
        Test.stopTest();
    }
}