@isTest
public class QuotePDFGeneratorControllerTest {
  @isTest
  static void testControllerConstructor() {
    MD_Quote__c quote = new MD_Quote__c(Quote_Name__c = 'Test Quote');
    insert quote;
    Test.startTest();
    ApexPages.StandardController sc = new ApexPages.StandardController(quote);
    new QuotePDFGeneratorController(sc);
    Test.stopTest();
    // No assertion needed, just ensure no exceptions and code is covered
  }
}