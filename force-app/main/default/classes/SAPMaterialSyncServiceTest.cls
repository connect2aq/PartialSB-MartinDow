@IsTest
private class SAPMaterialSyncServiceTest {

    @TestSetup
    static void seedPicklists() {
        // English comment: Minimal picklist rows so mapping code executes
        List<Picklist_Table__c> rows = new List<Picklist_Table__c>{
            new Picklist_Table__c(Salesforce_Field_API__c='Material_Group_1__c', Code__c='MG1'),
            new Picklist_Table__c(Salesforce_Field_API__c='Material_Group_2__c', Code__c='MG2'),
            new Picklist_Table__c(Salesforce_Field_API__c='Material_Group_3__c', Code__c='MG3'),
            new Picklist_Table__c(Salesforce_Field_API__c='Material_Group_4__c', Code__c='MG4'),
            new Picklist_Table__c(Salesforce_Field_API__c='Material_Group_5__c', Code__c='MG5')
        };
        insert rows;

        // English comment: Optional seed so an upsert "update" path can hit as well
        try {
            insert new MD_Product2__c(Material_Number__c='SEED001');
        } catch (Exception ignore) {}
    }

    // English comment: Simple reusable HTTP mock
    private class MockHttp implements HttpCalloutMock {
        Integer code; String body;
        MockHttp(Integer c, String b){ code=c; body=b; }
        public HttpResponse respond(HttpRequest req){
            HttpResponse r = new HttpResponse();
            r.setStatusCode(code);
            r.setHeader('Content-Type','application/json');
            r.setBody(body);
            return r;
        }
    }

    // -------------------- ASYNC: Happy path with duplicate to hit failure loop --------------------
    @IsTest
    static void async_success_multi_with_duplicate() {
        String json = '{"success":true,"message":"OK","data":[' +
            // update the seeded one
            '{"materialNumber":"SEED001","description":"Update Seed","unitOfMeasure":"EA","materialType":"FERT",' +
            '"oldMaterialNumber":"O-0","sizeDimensions":"1x1","productionPlant":"P1","materialGroup1":"MG1","materialGroup2":"MG2",' +
            '"materialGroup3":"MG3","materialGroup4":"MG4","materialGroup5":"MG5","distributionChannel":"D1","division":"V1",' +
            '"quantityUnitISO":"EA","standardPrice":"10.00","salesOrg":"SO1","plant":"P1","industryStandardDesc":"E-CC-INS","isBlock":""},' +
            // two rows with same external id -> one success + one failure in upsert loop
            '{"materialNumber":"DUP001","description":"Row A","unitOfMeasure":"EA","materialType":"FERT","oldMaterialNumber":"O-1",' +
            '"sizeDimensions":"2x2","productionPlant":"P2","materialGroup1":"MG1","materialGroup2":"MG2","materialGroup3":"MG3","materialGroup4":"MG4","materialGroup5":"MG5",' +
            '"distributionChannel":"D2","division":"V2","quantityUnitISO":"EA","standardPrice":"22.22","salesOrg":"SO2","plant":"P2","industryStandardDesc":"B-HM-REAGENT","isBlock":""},' +
            '{"materialNumber":"DUP001","description":"Row B","unitOfMeasure":"EA","materialType":"FERT","oldMaterialNumber":"O-2",' +
            '"sizeDimensions":"3x3","productionPlant":"P3","materialGroup1":"MG1","materialGroup2":"MG2","materialGroup3":"MG3","materialGroup4":"MG4","materialGroup5":"MG5",' +
            '"distributionChannel":"D3","division":"V3","quantityUnitISO":"EA","standardPrice":"33.33","salesOrg":"SO3","plant":"P3","industryStandardDesc":"YHLO-UBT-INS","isBlock":"X"}]}';

        Test.setMock(HttpCalloutMock.class, new MockHttp(200, json));
        SAPMaterialSyncService.setAuthTokenForTest('tok');

        Test.startTest();
        SAPMaterialSyncService.syncMaterialsFromSAP('20250901');
        Test.stopTest();
    }

    // -------------------- ASYNC: success=true but empty data --------------------
    @IsTest
    static void async_success_empty_data() {
        Test.setMock(HttpCalloutMock.class, new MockHttp(200,'{"success":true,"message":"OK","data":[]}'));
        SAPMaterialSyncService.setAuthTokenForTest('tok');

        Test.startTest();
        SAPMaterialSyncService.syncMaterialsFromSAP('20250901');
        Test.stopTest();
    }

    // -------------------- ASYNC: success=true but data=null --------------------
    @IsTest
    static void async_success_null_data() {
        Test.setMock(HttpCalloutMock.class, new MockHttp(200,'{"success":true,"message":"OK","data":null}'));
        SAPMaterialSyncService.setAuthTokenForTest('tok');

        Test.startTest();
        SAPMaterialSyncService.syncMaterialsFromSAP('20250901');
        Test.stopTest();
    }

    // -------------------- ASYNC: non-200 --------------------
    @IsTest
    static void async_non200() {
        Test.setMock(HttpCalloutMock.class, new MockHttp(500,'boom'));
        SAPMaterialSyncService.setAuthTokenForTest('tok');

        Test.startTest();
        SAPMaterialSyncService.syncMaterialsFromSAP('20250901');
        Test.stopTest();
    }

    // -------------------- ASYNC: malformed JSON -> catch --------------------
    @IsTest
    static void async_malformed() {
        Test.setMock(HttpCalloutMock.class, new MockHttp(200,'{not json'));
        SAPMaterialSyncService.setAuthTokenForTest('tok');

        Test.startTest();
        SAPMaterialSyncService.syncMaterialsFromSAP('20250901');
        Test.stopTest();
    }

    // -------------------- ASYNC: blank token early return --------------------
    @IsTest
    static void async_blank_token() {
        SAPMaterialSyncService.setAuthTokenForTest('');
        Test.startTest();
        SAPMaterialSyncService.syncMaterialsFromSAP('20250901');
        Test.stopTest();
    }

    // -------------------- ASYNC: date fallback when requestedDate == '' --------------------
    @IsTest
    static void async_date_fallback_and_mixed_codes() {
        String json = '{"success":true,"message":"OK","data":[{' +
            '"materialNumber":"FALL001","description":"Fallback",' +
            '"unitOfMeasure":"EA","materialType":"FERT","oldMaterialNumber":"F1",' +
            '"sizeDimensions":"5x5","productionPlant":"PX",' +
            '"materialGroup1":"", "materialGroup2":null, "materialGroup3":"UNKNOWN", "materialGroup4":"MG4", "materialGroup5":"",' +
            '"distributionChannel":"DX","division":"VX","quantityUnitISO":"EA","standardPrice":null,"salesOrg":"SX","plant":"PX",' +
            '"industryStandardDesc":"NV-ABG-INS","isBlock":""}]}';

        Test.setMock(HttpCalloutMock.class, new MockHttp(200, json));
        SAPMaterialSyncService.setAuthTokenForTest('tok');

        Test.startTest();
        SAPMaterialSyncService.syncMaterialsFromSAP('');
        Test.stopTest();
    }

    // -------------------- ASYNC: date fallback when requestedDate == null --------------------
    @IsTest
    static void async_date_fallback_when_null() {
        String mockResponse = '{"success":true,"message":"OK","data":[{' +
            '"materialNumber":"NULL001","description":"Null Date","unitOfMeasure":"EA","materialType":"FERT","oldMaterialNumber":"N1",' +
            '"sizeDimensions":"1x1","productionPlant":"P1","materialGroup1":"MG1","materialGroup2":"MG2","materialGroup3":"MG3","materialGroup4":"MG4","materialGroup5":"MG5",' +
            '"distributionChannel":"D1","division":"V1","quantityUnitISO":"EA","standardPrice":"1.00","salesOrg":"S1","plant":"P1","industryStandardDesc":"S-IMA-INS","isBlock":""}]}';

        Test.setMock(HttpCalloutMock.class, new MockHttp(200, mockResponse));
        SAPMaterialSyncService.setAuthTokenForTest('tok');

        Test.startTest();
        SAPMaterialSyncService.syncMaterialsFromSAP(null);
        Test.stopTest();
    }

    // -------------------- SYNC: Happy path (mapping + derived fields) --------------------
    @IsTest
    static void sync_success_multi() {
        String json = '{"success":true,"message":"OK","data":[{' +
            '"materialNumber":"SYNC001","description":"Sync Good","unitOfMeasure":"EA","materialType":"FERT","oldMaterialNumber":"S-1",' +
            '"sizeDimensions":"9x9","productionPlant":"P9","materialGroup1":"MG1","materialGroup2":"MG2","materialGroup3":"MG3","materialGroup4":"MG4","materialGroup5":"MG5",' +
            '"distributionChannel":"DX","division":"VX","quantityUnitISO":"EA","standardPrice":"123.45","salesOrg":"S9","plant":"P9","industryStandardDesc":"ER-ELT-REAGENT","isBlock":""}]}';

        Test.setMock(HttpCalloutMock.class, new MockHttp(200, json));
        SAPMaterialSyncService.setAuthTokenForTest('tok');

        SAPMaterialSyncService.runSyncNow();
    }

    // -------------------- SYNC: non-200 --------------------
    @IsTest
    static void sync_non200() {
        Test.setMock(HttpCalloutMock.class, new MockHttp(500,'oops'));
        SAPMaterialSyncService.setAuthTokenForTest('tok');

        SAPMaterialSyncService.runSyncNow();
    }

    // -------------------- SYNC: success=false --------------------
    @IsTest
    static void sync_success_false() {
        Test.setMock(HttpCalloutMock.class, new MockHttp(200,'{"success":false,"message":"fail","data":null}'));
        SAPMaterialSyncService.setAuthTokenForTest('tok');

        SAPMaterialSyncService.runSyncNow();
    }

    // -------------------- SYNC: malformed JSON --------------------
    @IsTest
    static void sync_malformed() {
        Test.setMock(HttpCalloutMock.class, new MockHttp(200,'{bad json'));
        SAPMaterialSyncService.setAuthTokenForTest('tok');

        SAPMaterialSyncService.runSyncNow();
    }

    // -------------------- SYNC: upsert failure loop via duplicate external id --------------------
    @IsTest
    static void sync_upsert_failure_loop() {
        String json = '{"success":true,"message":"OK","data":[' +
            '{"materialNumber":"XUP001","description":"A","unitOfMeasure":"EA","materialType":"FERT","oldMaterialNumber":"A1","sizeDimensions":"1x1","productionPlant":"P1",' +
            '"materialGroup1":"MG1","materialGroup2":"MG2","materialGroup3":"MG3","materialGroup4":"MG4","materialGroup5":"MG5","distributionChannel":"D","division":"V","quantityUnitISO":"EA","standardPrice":"10.00","salesOrg":"SO","plant":"P1","industryStandardDesc":"OR-COAG-INS","isBlock":""},' +
            '{"materialNumber":"XUP001","description":"B","unitOfMeasure":"EA","materialType":"FERT","oldMaterialNumber":"B1","sizeDimensions":"2x2","productionPlant":"P2",' +
            '"materialGroup1":"MG1","materialGroup2":"MG2","materialGroup3":"MG3","materialGroup4":"MG4","materialGroup5":"MG5","distributionChannel":"D","division":"V","quantityUnitISO":"EA","standardPrice":"20.00","salesOrg":"SO","plant":"P2","industryStandardDesc":"U-URIN-REAGENT","isBlock":""}]}';

        Test.setMock(HttpCalloutMock.class, new MockHttp(200, json));
        SAPMaterialSyncService.setAuthTokenForTest('tok');

        SAPMaterialSyncService.runSyncNow();
    }

    // -------------------- SYNC: runTestSync wrapper coverage --------------------
    @IsTest
    static void cover_runTestSync_wrapper() {
        String json = '{"success":true,"message":"OK","data":[{' +
            '"materialNumber":"RTS001","description":"RunTestSync path","unitOfMeasure":"EA","materialType":"FERT","oldMaterialNumber":"R1",' +
            '"sizeDimensions":"2x2","productionPlant":"PR","materialGroup1":"MG1","materialGroup2":"MG2","materialGroup3":"MG3","materialGroup4":"MG4","materialGroup5":"MG5",' +
            '"distributionChannel":"DR","division":"VR","quantityUnitISO":"EA","standardPrice":"50.00","salesOrg":"SR","plant":"PR","industryStandardDesc":"HW-XRAY-INS","isBlock":""}]}';

        Test.setMock(HttpCalloutMock.class, new MockHttp(200, json));
        SAPMaterialSyncService.setAuthTokenForTest('tok');

        Test.startTest();
        SAPMaterialSyncService.runTestSync();
        Test.stopTest();
    }

    // -------------------- SYNC: picklist map missing branch --------------------
    @IsTest
    static void sync_missing_picklist_map_branch() {
        delete [SELECT Id FROM Picklist_Table__c];

        String json = '{"success":true,"message":"OK","data":[{' +
            '"materialNumber":"NOPL001","description":"No Picklist Map","unitOfMeasure":"EA","materialType":"FERT","oldMaterialNumber":"NP1",' +
            '"sizeDimensions":"1x1","productionPlant":"P0","materialGroup1":"MG1","materialGroup2":"MG2","materialGroup3":"MG3","materialGroup4":"MG4","materialGroup5":"MG5",' +
            '"distributionChannel":"D0","division":"V0","quantityUnitISO":"EA","standardPrice":"9.99","salesOrg":"S0","plant":"P0","industryStandardDesc":"ER-ELT-REAGENT","isBlock":""}]}';

        Test.setMock(HttpCalloutMock.class, new MockHttp(200, json));
        SAPMaterialSyncService.setAuthTokenForTest('tok');

        SAPMaterialSyncService.runSyncNow();
    }

    // -------------------- ASYNC: picklist map missing branch --------------------
    @IsTest
    static void async_missing_picklist_map_branch() {
        delete [SELECT Id FROM Picklist_Table__c];

        String json = '{"success":true,"message":"OK","data":[{' +
            '"materialNumber":"APL001","description":"Async No Picklist","unitOfMeasure":"EA","materialType":"FERT","oldMaterialNumber":"A1",' +
            '"sizeDimensions":"3x3","productionPlant":"PA","materialGroup1":"MG1","materialGroup2":"MG2","materialGroup3":"MG3","materialGroup4":"MG4","materialGroup5":"MG5",' +
            '"distributionChannel":"DA","division":"VA","quantityUnitISO":"EA","standardPrice":"12.00","salesOrg":"SA","plant":"PA","industryStandardDesc":"ER-ELT-INS","isBlock":""}]}';

        Test.setMock(HttpCalloutMock.class, new MockHttp(200, json));
        SAPMaterialSyncService.setAuthTokenForTest('tok');

        Test.startTest();
        SAPMaterialSyncService.syncMaterialsFromSAP('20250901');
        Test.stopTest();
    }

    // -------------------- ASYNC: success variants (isBlock + price null/non-null) --------------------
    @IsTest
    static void async_success_variants_isBlock_and_price() {
        String json = '{"success":true,"message":"OK","data":[' +
            '{"materialNumber":"VAR001","description":"Active","unitOfMeasure":"EA","materialType":"FERT","oldMaterialNumber":"V1",' +
            '"sizeDimensions":"1x1","productionPlant":"P1","materialGroup1":"MG1","materialGroup2":"MG2","materialGroup3":"MG3","materialGroup4":"MG4","materialGroup5":"MG5",' +
            '"distributionChannel":"D1","division":"V1","quantityUnitISO":"EA","standardPrice":null,"salesOrg":"S1","plant":"P1","industryStandardDesc":"OR-COAG-INS","isBlock":""},' +
            '{"materialNumber":"VAR002","description":"Blocked","unitOfMeasure":"EA","materialType":"FERT","oldMaterialNumber":"V2",' +
            '"sizeDimensions":"2x2","productionPlant":"P2","materialGroup1":"MG1","materialGroup2":"MG2","materialGroup3":"MG3","materialGroup4":"MG4","materialGroup5":"MG5",' +
            '"distributionChannel":"D2","division":"V2","quantityUnitISO":"EA","standardPrice":"44.44","salesOrg":"S2","plant":"P2","industryStandardDesc":"S-IMA-REAGENT","isBlock":"X"}]}';

        Test.setMock(HttpCalloutMock.class, new MockHttp(200, json));
        SAPMaterialSyncService.setAuthTokenForTest('tok');

        Test.startTest();
        SAPMaterialSyncService.syncMaterialsFromSAP('20250901');
        Test.stopTest();
    }

    // -------------------- Helpers coverage (vendors/technology/product type/yesterday) --------------------
    @IsTest
    static void helpers_coverage() {
        String v1  = SAPMaterialSyncService.getVendor('E-CC-INS');
        String v2  = SAPMaterialSyncService.getVendor('B-HM-REAGENT');
        String v3  = SAPMaterialSyncService.getVendor('YHLO-UBT-INS');
        String v4  = SAPMaterialSyncService.getVendor('UNKNOWN-XYZ');
        String v5  = SAPMaterialSyncService.getVendor(null);
        String v6  = SAPMaterialSyncService.getVendor('D-CC-INS');
        String v7  = SAPMaterialSyncService.getVendor('LOC-ELT-REAGENT');
        String v8  = SAPMaterialSyncService.getVendor('U-IMA-INS');
        String v9  = SAPMaterialSyncService.getVendor('DM-ELCT-REAGENT');
        String v10 = SAPMaterialSyncService.getVendor('A-COAG-INS');
        String v11 = SAPMaterialSyncService.getVendor('F-URIN-REAGENT');
        String v12 = SAPMaterialSyncService.getVendor('LT-PCR-INS');
        String v13 = SAPMaterialSyncService.getVendor('ER-ELT-INS');
        String v14 = SAPMaterialSyncService.getVendor('NV-ABG-INS');
        String v15 = SAPMaterialSyncService.getVendor('OR-COAG-INS');
        String v16 = SAPMaterialSyncService.getVendor('STA-XRAY-INS');
        String v17 = SAPMaterialSyncService.getVendor('AV-POC-REAGENT');
        String v18 = SAPMaterialSyncService.getVendor('DYM-IMA-INS');
        String v19 = SAPMaterialSyncService.getVendor('HW-XRAY-INS');
        String v20 = SAPMaterialSyncService.getVendor('ZYB-POCT-INS');

        String t1 = SAPMaterialSyncService.getTechnology('ER-ELT-INS');
        String t2 = SAPMaterialSyncService.getTechnology('S-IMA-REAGENT');
        String t3 = SAPMaterialSyncService.getTechnology('A-POC-REAGENT');
        String t4 = SAPMaterialSyncService.getTechnology('HW-XRAY-INS');
        String t5 = SAPMaterialSyncService.getTechnology('LT-PCR-INS');
        String t6 = SAPMaterialSyncService.getTechnology('YHLO-UBT-INS');
        String t7 = SAPMaterialSyncService.getTechnology('E');
        String t8 = SAPMaterialSyncService.getTechnology(null);
        String t9 = SAPMaterialSyncService.getTechnology('X-ELCT-INS'); // ELCT branch
        String t10 = SAPMaterialSyncService.getTechnology('Z-POCT-REAGENT'); // POCT branch
        String t11 = SAPMaterialSyncService.getTechnology('E-CC-INS'); // CC branch

        String p1 = SAPMaterialSyncService.getProductType('E');
        String p2 = SAPMaterialSyncService.getProductType('S-IMA-INS-M');
        String p3 = SAPMaterialSyncService.getProductType('B-HM-REAGENT');
        String p4 = SAPMaterialSyncService.getProductType('E-CC-INSXYZ'); // startsWith('INS') path

        String y  = SAPMaterialSyncService.getYesterdayDate();
    }

    // -------------------- SYNC: exercise fetchAuthToken path when test seam is null --------------------
    @IsTest
    static void sync_blank_token_via_testSeam_null() {
        // English comment: Ensure code path runs when test seam is null; method should exit early without callout
        SAPMaterialSyncService.setAuthTokenForTest(null);
        SAPMaterialSyncService.runSyncNow();
    }
}