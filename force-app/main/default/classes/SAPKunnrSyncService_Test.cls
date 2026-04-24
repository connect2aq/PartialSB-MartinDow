@IsTest
private class SAPKunnrSyncService_Test {

    // Sequence-based mock: first call -> token, next calls -> per sequence
    private class SeqMock implements HttpCalloutMock {
        Integer idx = 0;
        List<Integer> codes;
        List<String> bodies;
        SeqMock(List<Integer> codes, List<String> bodies) {
            this.codes = codes;
            this.bodies = bodies;
        }
        public HTTPResponse respond(HTTPRequest req) {
            Integer i = idx < codes.size() ? idx : codes.size() - 1;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(codes[i]);
            res.setStatus(codes[i] == 200 ? 'OK' : 'ERROR');
            if (i < bodies.size()) res.setBody(bodies[i]); else res.setBody('');
            res.setHeader('Content-Type', 'application/json');
            idx++;
            return res;
        }
    }

    // Token JSON (what TokenRequest.getAuthToken() expects)
    private static String tokenBody() {
        return '{"success":true,"token":"test-token","baseEndpointUrl":"https://sap.example.com/api"}';
        // even if your TokenRequest ignores "success", it will pick token + baseEndpointUrl from here
    }

    // Success payload (same shape you shared)
    private static String successBody() {
        return '{' +
            '"success": true,' +
            '"message": "Success",' +
            '"data": [' +
            '  {' +
            '    "kunnr": "3020001224",' +
            '    "name1": "Shaukat Omer Memorial Hospital",' +
            '    "name2": "",' +
            '    "searchterm1": "DIAGNOSTIC",' +
            '    "city": "Karachi",' +
            '    "district": "Sindh",' +
            '    "postlcod1": "74200",' +
            '    "strsuppl3": "Fauji Foundation,",' +
            '    "location": "Shah Faisal Colony No 2,",' +
            '    "country": "PK",' +
            '    "bukrs": "3000",' +
            '    "akont": "1033000001",' +
            '    "cusT_SD": [' +
            '      {' +
            '        "vkorg": "3000","zterm": "C019","vtweg": "10","spart": "30","bzirk": "3000",' +
            '        "vwerk": "3300","kdgrp": "06","vkbur": "1000","waers": "PKR","vkgrp": "Z01",' +
            '        "konda": "01","kalks": "1","vsbed": "01","inco1": "LCL","inco2": "Local",' +
            '        "ztermsd": "C019","ktgrd": "01","faksd": "01","lifsd": "01","aufsd": "01"' +
            '      }' +
            '    ],' +
            '    "n_CUSTMER": [ { "kunnr": "3020001224", "eMail": "someone@example.com" } ],' +
            '    "n_CUSTMER1": [' +
            '      { "kunnr": "3020001224", "tatyp": "ZPK2", "taxkd": "1" },' +
            '      { "kunnr": "3020001224", "tatyp": "ZMST", "taxkd": "5" },' +
            '      { "kunnr": "3020001224", "tatyp": "ZMWS", "taxkd": "3" },' +
            '      { "kunnr": "3020001224", "tatyp": "MWST", "taxkd": "0" }' +
            '    ],' +
            '    "n_CUSTMER2": [ { "kunnr": "3020001224", "taxtype": "PK02", "taxnumber": "0710397-2" } ],' +
            '    "n_CUSTMER3": [ { "kunnr": "3020001224", "telephone": "021-3814060" } ],' +
            '    "n_CUSTMER4": [ { "kunnr": "3020001224", "mobile": "021-3814060" } ],' +
            '    "n_CUSTMER6": [ { "kunnr": "3020001224","creditSegment": "ZMDSPL2",' +
            '                    "creditLimit": "10000000.000","outstandingAmount": "4693907.000"} ]' +
            '  }' +
            '] }';
    }

    // 200 but No Data Available
    private static String noDataBody() {
        return '{ "success": true, "message": "Success", "data": "No Data Available" }';
    }

    // 400 error body
    private static String badRequestBody() {
        return '{ "success": false, "message": "HTTP 400 - Bad Request" }';
    }

    // ---------- Tests ----------

    // 1) Invalid KUNNR branch
    @IsTest
    static void t01_invalidKunnr() {
        Test.startTest();
        SAPKunnrSyncService.KunnrUIResult res =
            SAPKunnrSyncService.runAndFetchBundleByKunnr('123'); // not 10 digits / not starting with 3
        Test.stopTest();
    }

    // 2) Full happy path: token -> success data
    @IsTest
    static void t02_successFlow() {
        Test.setMock(HttpCalloutMock.class,
            new SeqMock(
                new List<Integer>{ 200, 200 },
                new List<String> { tokenBody(), successBody() }
            )
        );

        Test.startTest();
        SAPKunnrSyncService.KunnrUIResult res =
            SAPKunnrSyncService.runAndFetchBundleByKunnr('3020001224');
        Test.stopTest();

        // Touch created records (no asserts)
        List<Account> accs = [
            SELECT Id FROM Account WHERE SAP_Customer_Number__c = '3020001224'
        ];
        if (!accs.isEmpty()) {
            Id aId = accs[0].Id;
            List<MD_Sales_Area__c> sas = [
                SELECT Id FROM MD_Sales_Area__c WHERE Parent_Account__c = :aId
            ];
            List<MD_Tax_Number__c> tns = [
                SELECT Id FROM MD_Tax_Number__c WHERE Account__c = :aId
            ];
            List<Credit_Profile__c> cps = [
                SELECT Id FROM Credit_Profile__c WHERE Account__c = :aId
            ];
        }
    }

    // 3) 200 + No Data Available branch
    @IsTest
    static void t03_noData() {
        Test.setMock(HttpCalloutMock.class,
            new SeqMock(
                new List<Integer>{ 200, 200 },
                new List<String> { tokenBody(), noDataBody() }
            )
        );
        Test.startTest();
        SAPKunnrSyncService.KunnrUIResult res =
            SAPKunnrSyncService.runAndFetchBundleByKunnr('3020001224');
        Test.stopTest();
    }

    // 4) Error path: token ok, SAP returns 400 -> extractErrorMessage() path
    @IsTest
    static void t04_badRequest() {
        Test.setMock(HttpCalloutMock.class,
            new SeqMock(
                new List<Integer>{ 200, 400 },
                new List<String> { tokenBody(), badRequestBody() }
            )
        );
        Test.startTest();
        SAPKunnrSyncService.KunnrUIResult res =
            SAPKunnrSyncService.runAndFetchBundleByKunnr('3020001224');
        Test.stopTest();
    }

    // 5) Fallback path cover: 6 query attempts fail (404), path success (200)
    @IsTest
    static void t05_queryFallbackToPath() {
        // order: token (200), then six 404s for query keys, then final 200 for path
        Test.setMock(HttpCalloutMock.class,
            new SeqMock(
                new List<Integer>{
                    200, // token
                    404,404,404,404,404,404, // query attempts
                    200  // final path call
                },
                new List<String>{
                    tokenBody(),
                    '', '', '', '', '', '',
                    successBody()
                }
            )
        );
        Test.startTest();
        SAPKunnrSyncService.KunnrUIResult res =
            SAPKunnrSyncService.runAndFetchBundleByKunnr('3020001224');
        Test.stopTest();
    }
}