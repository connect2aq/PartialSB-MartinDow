public with sharing class QuotePDFGenerator {
  @AuraEnabled
  public static void generateAndAttachPDF(Id quoteId) {
    PageReference pdfPage = Page.QuotePDF; // Make sure QuotePDF is your Visualforce page
    pdfPage.getParameters().put('id', quoteId);
    Blob pdfBlob;
    if (Test.isRunningTest()) {
      pdfBlob = Blob.valueOf('Test PDF');
    } else {
      pdfBlob = pdfPage.getContentAsPDF();
    }

    Attachment attach = new Attachment();
    attach.Name = 'Quote_' + quoteId + '.pdf';
    attach.ParentId = quoteId;
    attach.Body = pdfBlob;
    attach.ContentType = 'application/pdf';
    insert attach;
  }
}