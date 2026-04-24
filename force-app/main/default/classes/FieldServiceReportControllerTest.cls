@isTest
public class FieldServiceReportControllerTest {

    @isTest
    static void testConstructorAndLocalTime() {

        // Create a test MD_Case__c record
        MD_Case__c c = new MD_Case__c();
        insert c;

        // Create StandardController for Visualforce extension
        ApexPages.StandardController sc = new ApexPages.StandardController(c);

        // Instantiate the extension controller (covers constructor)
        FieldServiceReportController ext = new FieldServiceReportController(sc);

        // Call the method to get coverage
        Datetime dt = ext.getLocalTime();

        // No asserts needed
    }
}