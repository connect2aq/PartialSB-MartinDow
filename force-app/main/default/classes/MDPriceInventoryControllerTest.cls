@IsTest
private class MDPriceInventoryControllerTest {

    // English comment: Composite mock – 1st call returns token, subsequent calls return inventory responses by material number
    private class TokenAndInventoryV3Mock implements HttpCalloutMock {
        private Integer callNo = 0;

        public HTTPResponse respond(HTTPRequest req) {
            callNo++;
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String url = req.getEndpoint() == null ? '' : req.getEndpoint();

            // --- First call: Token (whatever TokenRequest hits first) ---
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

            // --- Next calls: Inventory v3 by material number switch ---
            if (url.contains('/SAP/GetMaterialInventoryv3')) {
                // Parse material number from query to drive scenarios (FAKE123 = success, FAKEERR = HTTP 500, FAKENOSUCCESS = success:false)
                // English comment: Quick parse to check query value
                String materialNumber = '';
                Integer idx = url.indexOf('MaterialNumber=');
                if (idx >= 0) {
                    materialNumber = url.substring(idx + 'MaterialNumber='.length());
                }

                if (materialNumber == 'FAKE123') {
                    // English comment: SUCCESS (200 + success:true + data as LIST with one item)
                    res.setStatusCode(200);
                    res.setBody('{' +
                        '"success": true,' +
                        '"message": "OK",' +
                        '"data": [' +
                        '  {' +
                        '    "materialNumber":"FAKE123",' +
                        '    "materialDescription":"Test Material",' +
                        '    "plant":"1000",' +
                        '    "totalAvailableStock":15,' +
                        '    "totalBlockedStock":2,' +
                        '    "totalAllocatedStock":3,' +
                        '    "totalRestrictedStock":1,' +
                        '    "supplierBatch": [' +
                        '      {' +
                        '        "storageLocation":"LOC1",' +
                        '        "availableStock":10,' +
                        '        "blockedStock":1,' +
                        '        "allocatedStock":2,' +
                        '        "restrictedStock":0,' +
                        '        "batches": [' +
                        '          {' +
                        '            "supplierBatch":"SB-001",' +
                        '            "batch":"B-001",' +
                        '            "expiryDate":"2025-12-31",' +
                        '            "availableStock":6,' +
                        '            "allocatedStock":1,' +
                        '            "allocations":[{"so":"SO-1","customer":"C-1","name":"Alloc-1","allocatedStock":1}]' +
                        '          }' +
                        '        ]' +
                        '      }' +
                        '    ]' +
                        '  }' +
                        ']}' );
                    return res;
                }

                if (materialNumber == 'FAKEERR') {
                    // English comment: HTTP 500 path
                    res.setStatusCode(500);
                    res.setBody('{"success": false, "message": "Server Error"}');
                    return res;
                }

                if (materialNumber == 'FAKENOSUCCESS') {
                    // English comment: 200 but success=false and data=null to cover error message branch
                    res.setStatusCode(200);
                    res.setBody('{"success": false, "message": "Upstream said no", "data": null}');
                    return res;
                }

                // English comment: Default success with a minimal list item
                res.setStatusCode(200);
                res.setBody('{' +
                    '"success": true,' +
                    '"message": "OK",' +
                    '"data": [' +
                    '  {"materialNumber":"DEFAULT","plant":"2000","totalAvailableStock":1,"totalBlockedStock":0,"totalAllocatedStock":0,"totalRestrictedStock":0,"supplierBatch":[]}' +
                    ']}' );
                return res;
            }

            // English comment: Fallback
            res.setStatusCode(200);
            res.setBody('{"success": true, "message": "OK"}');
            return res;
        }
    }

    // English comment: Token failure (no mocks) -> early error branch
    @IsTest
    static void test_TokenFailure_EarlyError() {
        Test.startTest();
        MDPriceInventoryController.MaterialPriceInventoryWrapper wrap =
            MDPriceInventoryController.getLatestPriceInventory(null, null);
        System.debug('Token failure wrapper: ' + wrap);
        Test.stopTest();
    }

    // English comment: Happy path – success true with list-shaped data and nested supplier/batches/allocations
    @IsTest
    static void test_Success_With_ListAndBatches() {
        Test.setMock(HttpCalloutMock.class, new TokenAndInventoryV3Mock());
        Test.startTest();
        MDPriceInventoryController.MaterialPriceInventoryWrapper wrap =
            MDPriceInventoryController.getLatestPriceInventory(null, 'FAKE123');
        System.debug('Success list wrapper: ' + wrap);
        System.debug('SupplierBatch size: ' + (wrap != null && wrap.supplierBatch != null ? wrap.supplierBatch.size() : 0));
        Test.stopTest();
    }

    // English comment: Non-200 HTTP response (500) -> error branch
    @IsTest
    static void test_Http500_Error() {
        Test.setMock(HttpCalloutMock.class, new TokenAndInventoryV3Mock());
        Test.startTest();
        MDPriceInventoryController.MaterialPriceInventoryWrapper wrap =
            MDPriceInventoryController.getLatestPriceInventory(null, 'FAKEERR');
        System.debug('HTTP 500 wrapper: ' + wrap);
        Test.stopTest();
    }

    // English comment: 200 OK but success=false with data=null -> error message path
    @IsTest
    static void test_SuccessFalse_DataNull() {
        Test.setMock(HttpCalloutMock.class, new TokenAndInventoryV3Mock());
        Test.startTest();
        MDPriceInventoryController.MaterialPriceInventoryWrapper wrap =
            MDPriceInventoryController.getLatestPriceInventory(null, 'FAKENOSUCCESS');
        System.debug('Success=false wrapper: ' + wrap);
        Test.stopTest();
    }
}