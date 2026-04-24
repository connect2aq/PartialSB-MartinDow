@isTest
public class MachinePdfControllerTest {

    @isTest
    static void testAllMethods() {

        // Prepare test case
        MD_Case__c testCase = new MD_Case__c();
        insert testCase;

        // ⭐ Create VF StandardController
        ApexPages.StandardController sc = new ApexPages.StandardController(testCase);

        // ⭐ Instantiate Extension Controller
        MachinePdfController ext = new MachinePdfController(sc);

        // ⭐ Call getLocalTime() → covers method
        Datetime lt = ext.getLocalTime();
        System.assertNotEquals(null, lt, 'localTime must return a value');

        Test.startTest();

        // ⭐ Test the main method
        MachinePdfController.savePdfAsFile(testCase.Id);

        Test.stopTest();

        // ⭐ Verify ContentVersion created
        ContentVersion cv = [
            SELECT Id, Title, ContentDocumentId
            FROM ContentVersion
            WHERE Title LIKE 'Field Service Report%'
            LIMIT 1
        ];
        System.assertNotEquals(null, cv, 'ContentVersion should be created');

        // ⭐ Verify CDL created
        ContentDocumentLink cdl = [
            SELECT Id, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :testCase.Id
            LIMIT 1
        ];
        System.assertEquals(testCase.Id, cdl.LinkedEntityId);
    }
}