public with sharing class MachinePdfController {

    public MachinePdfController(ApexPages.StandardController controller) {
        // optional: you can capture recordId here if needed
    }

    public Datetime getLocalTime() {
        Datetime utcNow = System.now();
        Integer offset = UserInfo.getTimeZone().getOffset(utcNow) / 1000;
        return utcNow.addSeconds(offset);
    }

    @AuraEnabled
    public static void savePdfAsFile(Id recordId) {
        PageReference pdf = Page.FieldServiceReportPDFforMachine;
        pdf.getParameters().put('id', recordId);
        Blob pdfContent;
        try {
            if (Test.isRunningTest()) {
                pdfContent = Blob.valueOf('Test PDF Content');
            } else {
                pdfContent = pdf.getContentAsPDF();
            }

            ContentVersion cv = new ContentVersion();
            cv.VersionData = pdfContent;
            cv.Title = 'Field Service Report - ' + DateTime.now().format('yyyyMMddHHmmss');
            cv.PathOnClient = 'FSR_Machine_' + recordId + '.pdf';
            insert cv;

            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = [
                SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id
            ].ContentDocumentId;
            cdl.LinkedEntityId = recordId;
            cdl.ShareType = 'V';
            insert cdl;
        } catch (Exception e) {
            throw new AuraHandledException('Error saving PDF: ' + e.getMessage());
        }
    }
}