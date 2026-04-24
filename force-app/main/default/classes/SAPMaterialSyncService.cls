public class SAPMaterialSyncService {
    // Wrapper class for API response
    public class MaterialResponse {
        public Boolean success;
        public String message;
        public List<MaterialData> data;
    }

    public class MaterialData {
        public String materialNumber;
        public String description;
        public String unitOfMeasure;
        public String materialType;
        public String oldMaterialNumber;
        public String sizeDimensions;
        public String productionPlant;
        public String materialGroup1;
        public String materialGroup2;
        public String materialGroup3;
        public String materialGroup4;
        public String materialGroup5;
        public String distributionChannel;
        public String division;
        public String quantityUnitISO;
        public String standardPrice;
        public String salesOrg;
        public String plant;
        public String industryStandardDesc;
        public String isBlock;
    }

    // Map for picklist caching
    private static Map<String, Map<String, String>> picklistMap;

    // -------- Test seam for token injection --------
    @TestVisible
    private static String testAuthToken;

    @TestVisible
    static void setAuthTokenForTest(String token) {
        testAuthToken = token;
    }

    // Centralized token fetch with test override
    private static String fetchAuthToken() {
        if (Test.isRunningTest() && testAuthToken != null) {
            return testAuthToken;
        }
        return SAPIntegrationService.getAuthToken();
    }
    // -----------------------------------------------

    // Main async method for production
    @future(callout=true)
    public static void syncMaterialsFromSAP(String requestDate) {
        try {
            String dateParam = String.isNotBlank(requestDate)
                ? requestDate
                : '20250901';

            String token = fetchAuthToken();
            if (String.isBlank(token)) {
                System.debug('ERROR: Failed to retrieve authentication token.');
                return;
            }

            String endpoint =
                'https://onelink.martindow.com/crm-prod/api/SAP/GetMaterialInfo?requestdate=' +
                dateParam;
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + token);
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(60000);

            Http http = new Http();
            HttpResponse res = http.send(req);
            
            ApiLogUtil.get().add('GetMaterialInfo', endpoint, 'GET', null, res.getStatusCode(), res.getBody());

            System.debug('API Response Status: ' + res.getStatusCode());
            System.debug('API Response Body: ' + res.getBody());

            if (res.getStatusCode() == 200) {
                MaterialResponse apiResponse = (MaterialResponse) JSON.deserialize(
                    res.getBody(),
                    MaterialResponse.class
                );

                if (apiResponse.success && apiResponse.data != null) {
                    loadPicklistMapping();
                    List<MD_Product2__c> productsToUpsert = new List<MD_Product2__c>();

                    for (MaterialData item : apiResponse.data) {
                        MD_Product2__c product = new MD_Product2__c();
                        // Map fields from payload to product
                        product.Material_Number__c = item.materialNumber;
                        product.Description__c = item.description;
                        product.Base_Unit_of_Measure__c = item.unitOfMeasure;
                        product.Material_Type__c = item.materialType;
                        product.Old_Material_Number__c = item.oldMaterialNumber;
                        product.Size_Dimensions__c = item.sizeDimensions;
                        product.Plant__c = item.plant;
                        product.Distribution_Channel__c = item.distributionChannel;
                        product.Division__c = item.division;
                        product.Quantity_ISO_UNIT__c = item.quantityUnitISO;
                        product.Standard_Price__c = item.standardPrice != null
                            ? Decimal.valueOf(item.standardPrice)
                            : null;
                        product.Sales_Organization__c = item.salesOrg;
                        product.Industry_Standard_Description__c = item.industryStandardDesc;

                        // Derived fields
                        String strVendor = getVendor(item.industryStandardDesc);
                        String strTech = getTechnology(
                            item.industryStandardDesc
                        );
                        String strProdType = getProductType(
                            item.industryStandardDesc
                        );
                        product.Vendor__c = strVendor;
                        product.Technology__c = strTech;
                        product.Material_Category__c = strProdType;

                        // Picklist mapped values
                        product.Material_Group_1__c = getMappedValue(
                            'Material_Group_1__c',
                            item.materialGroup1
                        );
                        product.Material_Group_2__c = getMappedValue(
                            'Material_Group_2__c',
                            item.materialGroup2
                        );
                        product.Material_Group_3__c = getMappedValue(
                            'Material_Group_3__c',
                            item.materialGroup3
                        );
                        product.Material_Group_4__c = getMappedValue(
                            'Material_Group_4__c',
                            item.materialGroup4
                        );
                        product.Material_Group_5__c = getMappedValue(
                            'Material_Group_5__c',
                            item.materialGroup5
                        );
                        product.IsActive__c = String.isBlank(item.isBlock);

                        productsToUpsert.add(product);
                    }

                    if (!productsToUpsert.isEmpty()) {
                        Database.UpsertResult[] results = Database.upsert(
                            productsToUpsert,
                            MD_Product2__c.Material_Number__c,
                            false
                        );
                        Integer successCount = 0;
                        Integer failCount = 0;
                        for (Database.UpsertResult r : results) {
                            if (r.isSuccess()) {
                                successCount++;
                            } else {
                                failCount++;
                                for (Database.Error err : r.getErrors()) {
                                    System.debug(
                                        'Upsert Error: ' + err.getMessage()
                                    );
                                }
                            }
                        }
                        System.debug(
                            'Upsert Complete: ' +
                                successCount +
                                ' succeeded, ' +
                                failCount +
                                ' failed.'
                        );
                    }
                } else {
                    System.debug(
                        'API returned success=false or no data: ' +
                        apiResponse.message
                    );
                }
            } else {
                System.debug(
                    'API call failed: ' +
                        res.getStatus() +
                        ' - ' +
                        res.getBody()
                );
            }
        } catch (Exception ex) {
            System.debug('Error in syncMaterialsFromSAP: ' + ex.getMessage());
            System.debug('Stack Trace: ' + ex.getStackTraceString());
        } finally {
            ApiLogUtil.get().flushSync();
        }
    }

    // Synchronous method for testing (no @future restriction)
    public static void runSyncNow() {
        try {
            String requestDate = '20250901'; // Hardcoded for testing

            String token = fetchAuthToken();
            if (String.isBlank(token)) {
                System.debug('ERROR: Failed to get token.');
                return;
            }

            String endpoint =
                'https://onelink.martindow.com/crm-prod/api/SAP/GetMaterialInfo?requestdate=' +
                requestDate;
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + token);
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(60000);

            Http http = new Http();
            HttpResponse res = http.send(req);
            
            ApiLogUtil.get().add('GetMaterialInfo', endpoint, 'GET', null, res.getStatusCode(), res.getBody());

            System.debug('API Response Status: ' + res.getStatusCode());
            System.debug('API Response Body: ' + res.getBody());

            if (res.getStatusCode() == 200) {
                MaterialResponse apiResponse = (MaterialResponse) JSON.deserialize(
                    res.getBody(),
                    MaterialResponse.class
                );

                if (apiResponse.success && apiResponse.data != null) {
                    loadPicklistMapping();
                    List<MD_Product2__c> productsToUpsert = new List<MD_Product2__c>();

                    for (MaterialData item : apiResponse.data) {
                        MD_Product2__c product = new MD_Product2__c();
                        // Map fields from payload to product
                        product.Material_Number__c = item.materialNumber;
                        product.Description__c = item.description;
                        product.Base_Unit_of_Measure__c = item.unitOfMeasure;
                        product.Material_Type__c = item.materialType;
                        product.Old_Material_Number__c = item.oldMaterialNumber;
                        product.Size_Dimensions__c = item.sizeDimensions;
                        product.Plant__c = item.plant;
                        product.Distribution_Channel__c = item.distributionChannel;
                        product.Division__c = item.division;
                        product.Quantity_ISO_UNIT__c = item.quantityUnitISO;
                        product.Standard_Price__c = item.standardPrice != null
                            ? Decimal.valueOf(item.standardPrice)
                            : null;
                        product.Sales_Organization__c = item.salesOrg;
                        product.Industry_Standard_Description__c = item.industryStandardDesc;

                        // Derived fields
                        String strVendor = getVendor(item.industryStandardDesc);
                        String strTech = getTechnology(
                            item.industryStandardDesc
                        );
                        String strProdType = getProductType(
                            item.industryStandardDesc
                        );
                        product.Vendor__c = strVendor;
                        product.Technology__c = strTech;
                        product.Material_Category__c = strProdType;

                        // Picklist mapped values
                        product.Material_Group_1__c = getMappedValue(
                            'Material_Group_1__c',
                            item.materialGroup1
                        );
                        product.Material_Group_2__c = getMappedValue(
                            'Material_Group_2__c',
                            item.materialGroup2
                        );
                        product.Material_Group_3__c = getMappedValue(
                            'Material_Group_3__c',
                            item.materialGroup3
                        );
                        product.Material_Group_4__c = getMappedValue(
                            'Material_Group_4__c',
                            item.materialGroup4
                        );
                        product.Material_Group_5__c = getMappedValue(
                            'Material_Group_5__c',
                            item.materialGroup5
                        );
                        product.IsActive__c = String.isBlank(item.isBlock);

                        productsToUpsert.add(product);
                    }

                    if (!productsToUpsert.isEmpty()) {
                        Database.UpsertResult[] results = Database.upsert(
                            productsToUpsert,
                            MD_Product2__c.Material_Number__c,
                            false
                        );
                        Integer successCount = 0;
                        Integer failCount = 0;
                        for (Database.UpsertResult r : results) {
                            if (r.isSuccess()) {
                                successCount++;
                            } else {
                                failCount++;
                                for (Database.Error err : r.getErrors()) {
                                    System.debug(
                                        'Upsert Error: ' + err.getMessage()
                                    );
                                }
                            }
                        }
                        System.debug(
                            'Upsert Complete: ' +
                                successCount +
                                ' succeeded, ' +
                                failCount +
                                ' failed.'
                        );
                    }
                } else {
                    System.debug(
                        'API returned success=false or no data: ' +
                        apiResponse.message
                    );
                }
            } else {
                System.debug(
                    'API call failed: ' +
                        res.getStatus() +
                        ' - ' +
                        res.getBody()
                );
            }
        } catch (Exception ex) {
            System.debug('Error in runSyncNow: ' + ex.getMessage());
            System.debug('Stack Trace: ' + ex.getStackTraceString());
        } finally {
            ApiLogUtil.get().flushSync();
        }
    }

    // Load picklist mappings into static map
    private static void loadPicklistMapping() {
        picklistMap = new Map<String, Map<String, String>>();
        List<Picklist_Table__c> tables = [
            SELECT Salesforce_Field_API__c, Code__c, Combine__c
            FROM Picklist_Table__c
        ];

        for (Picklist_Table__c pt : tables) {
            String field = pt.Salesforce_Field_API__c;
            String code = pt.Code__c;
            String combine = pt.Combine__c;

            if (!picklistMap.containsKey(field)) {
                picklistMap.put(field, new Map<String, String>());
            }
            picklistMap.get(field).put(code, combine);
        }
    }

    // Helper to get Combine__c value by field and code
    private static String getMappedValue(String fieldApi, String code) {
        if (String.isBlank(code) || !picklistMap.containsKey(fieldApi)) {
            return null;
        }
        Map<String, String> codeMap = picklistMap.get(fieldApi);
        return codeMap.get(code);
    }

    // Utility: Get yesterday's date in YYYYMMDD format
    public static String getYesterdayDate() {
        Date yesterday = System.today().addDays(-1);
        // return yesterday.format().replace('-', '').replace('/', '');
        return yesterday.year() +
            String.valueOf(yesterday.month()).leftPad(2, '0') +
            String.valueOf(yesterday.day()).leftPad(2, '0');
    }

    // Test method (calls async version)
    public static void runTestSync() {
        syncMaterialsFromSAP('20250901'); // Use hardcoded date
    }

    // --- Helper Methods ---
    @TestVisible
    private static String getVendor(String code) {
        if (code == null)
            return null;
        String prefix = code.split('-').size() > 0 ? code.split('-')[0] : '';
        Map<String, String> vendorMap = new Map<String, String>{
            'E' => 'E - VitalScientific',
            'S' => 'S - VitalScientific',
            'D' => 'D - VitalScientific',
            'B' => 'B - Boule',
            'LOC' => 'LOC - VitalScientific',
            'U' => 'U - VitalScientific',
            'DM' => 'DM - VitalScientific',
            'A' => 'A - Boule',
            'F' => 'F - VitalScientific',
            'LT' => 'LT -',
            'YHLO' => 'YHLO - YHLO',
            'ER' => 'ER - Erba',
            'NV' => 'NV - Nova',
            'OR' => 'OR - OCD',
            'STA' => 'STA - Stago',
            'AV' => 'AV - AlphaVenus',
            'DYM' => 'DYM - Dymind',
            'HW' => 'HW - Headway',
            'ZYB' => 'ZYB - ZYBIO'
        };
        return vendorMap.containsKey(prefix) ? vendorMap.get(prefix) : null;
    }

    @TestVisible
    private static String getTechnology(String code) {
        if (code == null)
            return null;
        List<String> parts = code.split('-');
        if (parts.size() < 2)
            return null;
        String tech = parts[1];
        if (tech == 'CC')
            return 'CC - Clinical Chemistry';
        if (tech == 'HM')
            return 'HM - Hematology';
        if (tech == 'ELT')
            return 'ELT - Electrolyte';
        if (tech == 'ELCT')
            return 'ELCT - Analyzer';
        if (tech == 'IMA')
            return 'IMA - Immunoassay';
        if (tech == 'COAG')
            return 'COAG - Coagulation';
        if (tech == 'URIN')
            return 'URIN - Urinalysis';
        if (tech == 'ABG')
            return 'ABG - Arterial Blood Gas';
        if (tech == 'POC')
            return 'POC - Point of Care';
        if (tech == 'POCT')
            return 'POCT - Point of Care Test';
        if (tech == 'XRAY')
            return 'XRAY - XRay';
        if (tech == 'PCR')
            return 'PCR -';
        if (tech == 'UBT')
            return 'UBT - Urea Breath Test';
        return null;
    }

    @TestVisible
    private static String getProductType(String code) {
        if (code == null)
            return null;
        List<String> parts = code.split('-');
        if (parts.size() < 3)
            return 'Reagent';
        String prodType = parts[2] != null ? parts[2].toUpperCase() : '';
        // Treat any prodType that starts with 'INS' (INS, INST, INS-M, INSXYZ...) as Instrument
        if (prodType.startsWith('INS'))
            return 'Instrument';
        return 'Reagent';
    }
    // private static String getProductType(String code) {
    //     if (code == null)
    //         return null;
    //     List<String> parts = code.split('-');
    //     if (parts.size() < 3)
    //         return 'Reagent';
    //     String prodType = parts[2];
    //     if (prodType == 'INS' || prodType == 'INS-M')
    //         return 'Instrument';
    //     return 'Reagent';
    // }
}