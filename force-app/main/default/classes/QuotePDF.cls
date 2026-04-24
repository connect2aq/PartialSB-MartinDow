public with sharing class QuotePDF {
  @InvocableMethod(label='Generate Quote PDF')
  public static void generatePDF(List<Id> quoteIds) {
    List<Attachment> attachments = new List<Attachment>();

    for (Id quoteId : quoteIds) {
      MD_Quote__c quote = [
        SELECT Id, Name
        FROM MD_Quote__c
        WHERE Id = :quoteId
        LIMIT 1
      ];

      PageReference pdfPage = Page.quotePDF; // ← Visualforce page ka EXACT API name likhna zaroori hai
      pdfPage.getParameters().put('id', quoteId);

      Blob pdfBlob;
      try {
        if (Test.isRunningTest()) {
          pdfBlob = Blob.valueOf('Test PDF');
        } else {
          pdfBlob = pdfPage.getContentAsPDF();
        }
      } catch (Exception e) {
        System.debug('Error generating PDF: ' + e.getMessage());
        continue;
      }

      attachments.add(
        new Attachment(
          ParentId = quote.Id,
          Name = 'Quote_' + quote.Name + '.pdf',
          Body = pdfBlob,
          ContentType = 'application/pdf'
        )
      );
    }

    if (!attachments.isEmpty()) {
      insert attachments;
    }
  }
}