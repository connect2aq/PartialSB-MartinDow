@isTest
public class QuotePDFGeneratorTest {
  @isTest
  static void testGenerateAndAttachPDF() {
    // Create a test quote record
    MD_Quote__c quote = new MD_Quote__c(Quote_Name__c = 'Test Quote');
    insert quote;
    // Use Test.isRunningTest() logic in controller to allow coverage
    Test.startTest();
    QuotePDFGenerator.generateAndAttachPDF(quote.Id);
    Test.stopTest();
    List<Attachment> atts = [
      SELECT Id, ParentId, Name
      FROM Attachment
      WHERE ParentId = :quote.Id
    ];
    System.assertEquals(
      1,
      atts.size(),
      'Attachment should be created in test context'
    );
  }
}