public with sharing class QuotePDFGeneratorController {
  public QuotePDFGeneratorController(ApexPages.StandardController stdCtrl) {
    MD_Quote__c quote = (MD_Quote__c) stdCtrl.getRecord();
    QuotePDFGenerator.generateAndAttachPDF(quote.Id);
  }
}