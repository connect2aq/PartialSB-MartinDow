@IsTest
private class MdQuotePdfControllerTest {

    // Utility to create a record with required fields only
    // depth controls how deep we create parent lookups for required references
    private static SObject createRecordWithRequiredFields(Schema.SObjectType typeToken, Integer depth) {
        SObject s = typeToken.newSObject();
        Schema.DescribeSObjectResult sDesc = typeToken.getDescribe();
        Map<String, Schema.SObjectField> fields = sDesc.fields.getMap();

        for (Schema.SObjectField f : fields.values()) {
            Schema.DescribeFieldResult fd = f.getDescribe();
            String api = fd.getName();

            // Skip non-createable, calculated, defaulted fields and Id
            if (!fd.isCreateable() || fd.isDefaultedOnCreate() || fd.isCalculated() || api == 'Id') {
                continue;
            }

            Schema.DisplayType t = fd.getType();

            // Handle required references by creating a parent record recursively
            if (t == Schema.DisplayType.Reference) {
                if (!fd.isNillable() && depth > 0) {
                    List<Schema.SObjectType> refTypes = fd.getReferenceTo();
                    if (!refTypes.isEmpty()) {
                        SObject parent = createRecordWithRequiredFields(refTypes[0], depth - 1);
                        s.put(api, (Id) parent.get('Id'));
                    }
                }
                continue;
            }

            // Only populate when field is required (not nillable)
            if (fd.isNillable()) {
                continue;
            }

            // Minimal generic values by type
            if (t == Schema.DisplayType.String || t == Schema.DisplayType.TextArea) {
                s.put(api, 'Test');
            } else if (t == Schema.DisplayType.Boolean) {
                s.put(api, true);
            } else if (t == Schema.DisplayType.Email) {
                s.put(api, 'test@example.com');
            } else if (t == Schema.DisplayType.Url) {
                s.put(api, 'https://example.com');
            } else if (t == Schema.DisplayType.Phone) {
                s.put(api, '1111111');
            } else if (t == Schema.DisplayType.Integer) {
                s.put(api, 1);
            } else if (t == Schema.DisplayType.Long) {
                s.put(api, 1L);
            } else if (t == Schema.DisplayType.Double || t == Schema.DisplayType.Currency || t == Schema.DisplayType.Percent) {
                s.put(api, 1.0);
            } else if (t == Schema.DisplayType.Date) {
                s.put(api, Date.today());
            } else if (t == Schema.DisplayType.Datetime) {
                s.put(api, System.now());
            } else if (t == Schema.DisplayType.Picklist) {
                List<Schema.PicklistEntry> p = fd.getPicklistValues();
                if (!p.isEmpty()) {
                    s.put(api, p[0].getValue());
                }
            } else if (t == Schema.DisplayType.MultiPicklist) {
                List<Schema.PicklistEntry> p = fd.getPicklistValues();
                if (!p.isEmpty()) {
                    s.put(api, p[0].getValue());
                }
            }
        }

        insert s;
        return s;
    }

    @IsTest
    static void test_savePdf_success() {
        // Create a minimal valid MD_Quote__c record
        SObject quote = createRecordWithRequiredFields(MD_Quote__c.SObjectType, 2);
        Id quoteId = (Id) quote.get('Id');  // FIX: cast to Id once and reuse

        Test.startTest();
        MdQuotePdfController.savePdfAsFile(quoteId);
        Test.stopTest();

        // Touch the created links to ensure SOQL runs (no asserts as requested)
        List<ContentDocumentLink> links = [
            SELECT Id, LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :quoteId   // FIX: bind Id, not Object
        ];
        for (ContentDocumentLink l : links) {
            String touch = l.Id;
        }
    }

    @IsTest
    static void test_savePdf_nullId_errorPath() {
        // Exercise the exception path when recordId is null
        Test.startTest();
        try {
            MdQuotePdfController.savePdfAsFile(null);
        } catch (Exception e) {
            // No assertions per your requirement
            String msg = e.getMessage();
        }
        Test.stopTest();
    }
}