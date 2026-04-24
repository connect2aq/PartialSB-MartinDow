public with sharing class QuotePdfController {
    @AuraEnabled
    public static void savePdfAsFile(Id recordId) {
        PageReference pdf = Page.QuotationReportPDF;
        pdf.getParameters().put('id', recordId);
        Blob pdfContent;
        
        try {
            if (Test.isRunningTest()) {
                // Simulate PDF content in test context
                pdfContent = Blob.valueOf('Test PDF Content');
            } else {
                pdfContent = pdf.getContentAsPDF();
            }
            
            ContentVersion cv = new ContentVersion();
            cv.VersionData = pdfContent;
            cv.Title = 'Quotation PDF - ' + DateTime.now().format('yyyyMMddHHmmss');
            cv.PathOnClient = 'Quote_' + recordId + '.pdf';
            insert cv;

            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
            ].ContentDocumentId;
            cdl.LinkedEntityId = recordId;
            cdl.ShareType = 'V';
            insert cdl;
        } catch (Exception e) {
            throw new AuraHandledException('Error saving PDF: ' + e.getMessage());
        }
    }
}