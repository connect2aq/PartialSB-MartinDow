@isTest
public class CustomWebToLeadHandlerTest {
  @isTest
  static void testCreateMDLead() {
    // Prepare JSON body
    String jsonBody =
      '{' +
      '"firstName":"John",' +
      '"lastName":"Doe",' +
      '"company":"Acme Inc",' +
      '"email":"john.doe@example.com",' +
      '"mobile":"1234567890",' +
      '"webToLead":true,' +
      '"leadSource":"Website"' +
      '}';

    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/CustomWebToLead';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf(jsonBody);
    RestContext.request = req;
    RestResponse res = new RestResponse();
    RestContext.response = res;

    Test.startTest();
    CustomWebToLeadHandler.createMDLead();
    Test.stopTest();

    // Assert that the lead was created
    MD_Lead__c[] leads = [
      SELECT
        Id,
        First_Name__c,
        Name,
        Company__c,
        Email__c,
        Mobile__c,
        Web_to_Lead__c,
        Lead_Source__c
      FROM MD_Lead__c
      WHERE Email__c = 'john.doe@example.com'
    ];
    System.assertEquals(1, leads.size(), 'Lead should be created');
    System.assertEquals('John', leads[0].First_Name__c);
    System.assertEquals('Doe', leads[0].Name);
    System.assertEquals('Acme Inc', leads[0].Company__c);
    System.assertEquals('1234567890', leads[0].Mobile__c);
    System.assertEquals(true, leads[0].Web_to_Lead__c);
    System.assertEquals('Website', leads[0].Lead_Source__c);
  }
}