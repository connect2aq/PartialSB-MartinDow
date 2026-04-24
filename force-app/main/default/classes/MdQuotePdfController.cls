// Creates a PDF from the Visualforce page and attaches it to the record as a File.
public with sharing class MdQuotePdfController {

    @AuraEnabled
    public static void savePdfAsFile(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException('recordId is required to generate PDF.');
        }

        // Point to your VF page (rename if needed)
        PageReference pdf = Page.NewquotepdfVF;
        pdf.getParameters().put('id', recordId);

        Blob pdfContent;
        try {
            if (Test.isRunningTest()) {
                // Simulate PDF content in tests
                pdfContent = Blob.valueOf('Test PDF Content');
            } else {
                pdfContent = pdf.getContentAsPDF();
            }

            // Fetch Name for nicer file title (optional but useful)
            MD_Quote__c quote = [
                SELECT Name
                FROM MD_Quote__c
                WHERE Id = :recordId
                LIMIT 1
            ];

            ContentVersion cv = new ContentVersion();
            cv.VersionData = pdfContent;
            cv.Title = 'MD Quote PDF - ' + quote.Name + ' - ' + DateTime.now().format('yyyyMMddHHmmss');
            cv.PathOnClient = 'MD_Quote_' + quote.Name + '.pdf';
            cv.ContentLocation = 'S';
            insert cv;

            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
                LIMIT 1
            ].ContentDocumentId;
            cdl.LinkedEntityId = recordId;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            insert cdl;

        } catch (Exception e) {
            throw new AuraHandledException('Error saving PDF: ' + e.getMessage());
        }
    }
}