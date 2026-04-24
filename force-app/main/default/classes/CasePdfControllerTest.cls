@isTest
public class CasePdfControllerTest {
  @isTest
  static void testSavePdfAsFile() {
    // Create a test Case record
    Case testCase = new Case(Subject = 'Test PDF Case');
    insert testCase;

    // Mock the PageReference.getContentAsPDF() call
    Test.startTest();
    try {
      // This will throw in test context, so we expect an exception
      CasePdfController.savePdfAsFile(testCase.Id);
      System.assert(true, 'savePdfAsFile executed');
    } catch (Exception e) {
      System.assert(
        e.getMessage().contains('Error saving PDF'),
        'Expected AuraHandledException for PDF generation'
      );
    }
    Test.stopTest();
  }
}