@isTest
public class QuotePDFTest {
  @isTest
  static void testGeneratePDFMultipleIds() {
    MD_Quote__c quote1 = new MD_Quote__c(Quote_Name__c = 'Test Quote 1');
    MD_Quote__c quote2 = new MD_Quote__c(Quote_Name__c = 'Test Quote 2');
    insert new List<MD_Quote__c>{ quote1, quote2 };
    Test.startTest();
    QuotePDF.generatePDF(new List<Id>{ quote1.Id, quote2.Id });
    Test.stopTest();
    List<Attachment> atts = [
      SELECT Id
      FROM Attachment
      WHERE ParentId IN :new List<Id>{ quote1.Id, quote2.Id }
    ];
    System.assertEquals(
      2,
      atts.size(),
      'Two attachments should be created in test context'
    );
  }

  @isTest
  static void testGeneratePDFEmptyList() {
    Test.startTest();
    QuotePDF.generatePDF(new List<Id>());
    Test.stopTest();
    System.assert(true, 'No error on empty input');
  }

  @isTest
  static void testGeneratePDFInvalidId() {
    Boolean exceptionThrown = false;
    try {
      Test.startTest();
      QuotePDF.generatePDF(new List<Id>{ 'a00xx0000000000AAA' });
      Test.stopTest();
    } catch (Exception e) {
      exceptionThrown = true;
      System.assert(
        e.getMessage().contains('List has no rows'),
        'Should throw QueryException for invalid ID'
      );
    }
    System.assert(exceptionThrown, 'Exception should be thrown for invalid ID');
  }
}