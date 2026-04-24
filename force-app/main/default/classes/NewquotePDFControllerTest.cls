@IsTest
private class NewquotePDFControllerTest {

    // Create simple data once for all tests
    @TestSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
    }

    @IsTest
    static void test_SavePdf_Success() {
        // Get a record to link the file to
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        // Invoke the method under test with a valid Id
        NewquotePDFController.savePdfAsFile(acc.Id);
        Test.stopTest();

        // Optional: touch created records (no asserts as requested)
        // Query any links created to ensure DML executed in test context
        List<ContentDocumentLink> links = [
            SELECT Id, LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :acc.Id
        ];
        for (ContentDocumentLink l : links) {
            // no-op - honoring "no assert" requirement
            String touch = l.Id;
        }
    }

    @IsTest
    static void test_SavePdf_ErrorPath_NullId() {
        // Exercise the exception path (null LinkedEntityId causes DML error)
        Test.startTest();
        try {
            NewquotePDFController.savePdfAsFile(null);
        } catch (Exception e) {
            // Expected to bubble up as AuraHandledException; no asserts per instructions
            String message = e.getMessage();
        }
        Test.stopTest();
    }
}