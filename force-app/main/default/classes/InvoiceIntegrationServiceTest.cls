@isTest
public class InvoiceIntegrationServiceTest {
  @isTest
  static void testFetchAndProcessInvoicesFromSAP() {
    // Mock TokenRequest.getAuthToken
    TokenRequest.testTokenResult = new TokenRequest.AuthTokenResult();
    TokenRequest.testTokenResult.token = 'test-token';
    TokenRequest.testTokenResult.baseEndpointUrl = 'https://test.sap/';
    TokenRequest.testTokenResult.success = true;
    TokenRequest.testTokenResult.errorMessage = null;

    Test.startTest();
    Test.setMock(HttpCalloutMock.class, new MockSAPInvoiceHttpResponse());
    Date fromDate = Date.today().addDays(-7);
    Date toDate = Date.today();
    try {
      InvoiceIntegrationService.fetchAndProcessInvoicesFromSAP(
        fromDate,
        toDate
      );
      System.assert(true, 'No exception thrown');
    } catch (Exception e) {
      System.assert(false, 'Exception thrown: ' + e.getMessage());
    }
    Test.stopTest();
    TokenRequest.testTokenResult = null;
  }

  // Mock HTTP response for SAP callout
  class MockSAPInvoiceHttpResponse implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      // Return a minimal valid JSON for InvoiceProcessingService.InvoiceWrapper
      res.setBody('{"invoices":[]}');
      return res;
    }
  }
}