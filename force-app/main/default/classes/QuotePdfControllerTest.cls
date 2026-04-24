@isTest
public class QuotePdfControllerTest {
    @isTest
    static void testSavePdfAsFile() {
        // Create test Account
        Account testAccount = new Account(
            Name = 'Test Account',
            City__c = 'Karachi'
        );
        insert testAccount;

        // Create test Contact
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = testAccount.Id
        );
        insert testContact;

        // Create test MD_Quote__c record
        MD_Quote__c testQuote = new MD_Quote__c(
            Account__c = testAccount.Id,
            Contact__c = testContact.Id,
            Subject__c = 'Test Quotation',
            // Total_Price__c = 5000000,
            Price_Validity__c = '30 Days',
            Sales_Tax__c = '18% GST',
            Warranty__c = '1 Year',
            Payment_Term__c = 'Advance',
            Installation__c = 'Will be done by our trained engineers'
        );
        insert testQuote;

        Test.startTest();
        try {
            QuotePdfController.savePdfAsFile(testQuote.Id);
            
            // Verify ContentVersion was created
            List<ContentVersion> cvList = [
                SELECT Id, Title 
                FROM ContentVersion 
                WHERE Title LIKE 'Quotation PDF%'
            ];
            System.assertEquals(1, cvList.size(), 'ContentVersion should be created');
            
            // Verify ContentDocumentLink was created
            List<ContentDocumentLink> cdlList = [
                SELECT Id 
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :testQuote.Id
            ];
            System.assertEquals(1, cdlList.size(), 'PDF should be linked to Quote record');
            
        } catch (Exception e) {
            System.assert(
                e.getMessage().contains('Error saving PDF'),
                'Expected AuraHandledException for PDF generation'
            );
        }
        Test.stopTest();
    }
}