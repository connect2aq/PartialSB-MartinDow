@IsTest
private class PicklistMapperTest {

    @TestSetup
    static void setup() {
        // Pre-seed a few mapping rows. These are only used by PicklistMapper.preload and mapOrCode.
        // Choose codes and combines that are harmless; no DML to real SObjects here.
        List<Picklist_Table__c> rows = new List<Picklist_Table__c>();

        // Example for Account-level mapping
        rows.add(new Picklist_Table__c(
            Salesforce_Field_API__c = 'Country_Code__c',
            Code__c = 'PK'
           // Combine__c = 'PK'
        ));
        rows.add(new Picklist_Table__c(
            Salesforce_Field_API__c = 'Company_Code__c',
            Code__c = '3000'
            // Combine__c = '3000'
        ));

        // Example for tax fields (label-shaped combine)
        rows.add(new Picklist_Table__c(
            Salesforce_Field_API__c = 'Output_Tax_Category_MWST_Code__c',
            Code__c = '1'
            // Combine__c = '1 - Standard'
        ));

        insert rows;
    }

    @IsTest
    static void testPreloadAndMap() {
        // Build needs map similar to production path
        Map<String, Set<String>> needs = new Map<String, Set<String>>();
        needs.put('Country_Code__c', new Set<String>{ 'PK' });
        needs.put('Company_Code__c', new Set<String>{ '3000' });
        needs.put('Output_Tax_Category_MWST_Code__c', new Set<String>{ '1' });

        // Preload once
        PicklistMapper.preload(needs);

        // Exercise mapOrCode for different fields
        String v1 = PicklistMapper.mapOrCode('Country_Code__c', 'PK');
        String v2 = PicklistMapper.mapOrCode('Company_Code__c', '3000');
        String v3 = PicklistMapper.mapOrCode('Output_Tax_Category_MWST_Code__c', '1');

        // No asserts by user preference; this executes code paths of preload/mapOrCode.
    }
}