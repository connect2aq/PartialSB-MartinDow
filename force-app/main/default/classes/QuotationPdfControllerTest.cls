@isTest
public class QuotationPdfControllerTest {
  @isTest
  static void testControllerWithPaymentTerms() {
    Account acc = new Account(Name = 'Test Account');
    insert acc;
    MD_Quote__c quote = new MD_Quote__c(Account__c = acc.Id);
    insert quote;
    MD_Sales_Area__c area = new MD_Sales_Area__c(
      Parent_Account__c = acc.Id,
      Payment_Terms__c = 'C014 - within 30 days Due net'
    );
    insert area;
    Test.startTest();
    Test.setCurrentPageReference(new PageReference('/apex/SomePage'));
    ApexPages.currentPage().getParameters().put('id', quote.Id);
    ApexPages.StandardController sc = new ApexPages.StandardController(quote);
    QuotationPdfController ctrl = new QuotationPdfController(sc);
    Test.stopTest();
    System.assertEquals('C014 - within 30 days Due net', ctrl.PaymentTerms);
  }

  @isTest
  static void testControllerNoPaymentTerms() {
    Account acc = new Account(Name = 'No Terms Account');
    insert acc;
    MD_Quote__c quote = new MD_Quote__c(Account__c = acc.Id);
    insert quote;
    Test.startTest();
    Test.setCurrentPageReference(new PageReference('/apex/SomePage'));
    ApexPages.currentPage().getParameters().put('id', quote.Id);
    ApexPages.StandardController sc = new ApexPages.StandardController(quote);
    QuotationPdfController ctrl = new QuotationPdfController(sc);
    Test.stopTest();
    System.assertEquals(null, ctrl.PaymentTerms);
  }
}