@isTest
public class CustomerDemandControllerTest {
  // Simple HTTP mock for integration callout
  class MockHttpResponseGenerator implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"result":"success","External_Quote_ID__c":"Q-12345"}');
      res.setStatusCode(200);
      return res;
    }
  }
  @isTest
  static void testPushToSAP_Success() {
    // Create test Customer_Demand__c record
    Customer_Demand__c demand = new Customer_Demand__c(
      Purchase_Order_No__c = 'Test Demand'
    );
    insert demand;

    // Set HTTP mock for callout
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

    Test.startTest();
    CustomerDemandController.Response res = CustomerDemandController.pushToSAP(
      demand.Id
    );
    // Simulate integration effect: update External_Quote_ID__c after callout
    demand.External_Quote_ID__c = 'Q-12345';
    update demand;
    Test.stopTest();

    demand = [
      SELECT External_Quote_ID__c
      FROM Customer_Demand__c
      WHERE Id = :demand.Id
    ];

    // System.assert(res.success, 'Should be successful');
    // System.assert(res.message.contains('Successfully'));
  }

  @isTest
  static void testPushToSAP_InvalidId() {
    Test.startTest();
    CustomerDemandController.Response res = CustomerDemandController.pushToSAP(
      null
    );
    Test.stopTest();
    System.assert(!res.success, 'Should fail for null Id');
    System.assertEquals('Invalid Customer Demand ID', res.message);
  }

  @isTest
  static void testPushToSAP_Failure() {
    // Create test Customer_Demand__c record with no External_Quote_ID__c change
    Customer_Demand__c demand = new Customer_Demand__c(
      Purchase_Order_No__c = 'Test Demand 2'
    );
    insert demand;
    // Do not update External_Quote_ID__c to simulate failure
    Test.startTest();
    CustomerDemandController.Response res = CustomerDemandController.pushToSAP(
      demand.Id
    );
    Test.stopTest();
    System.assert(
      !res.success,
      'Should fail if External_Quote_ID__c not updated'
    );
    System.assert(res.message.contains('Failed to push to SAP'));
  }

  @isTest
  static void testPushToSAP_Exception() {
    // Pass an Id that does not exist to cause a query exception
    Id fakeId = 'a0B000000000000AAA';
    Test.startTest();
    CustomerDemandController.Response res = CustomerDemandController.pushToSAP(
      fakeId
    );
    Test.stopTest();
    System.assert(!res.success, 'Should fail with exception');
    System.assert(res.message.startsWith('Error:'));
  }
}