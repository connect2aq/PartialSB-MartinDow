@isTest
public class AccountStatusRestAPITest {
  @isTest
  static void testDoPost_Success() {
    Account acc = new Account(
      Name = 'Test Account',
      Account_Status__c = 'Draft'
    );
    insert acc;
    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/AccountStatus';
    req.httpMethod = 'POST';
    req.addHeader('Content-Type', 'application/json');
    req.requestBody = Blob.valueOf(
      '{"Id":"' + acc.Id + '","Account_Status__c":"Active"}'
    );
    RestContext.request = req;
    RestResponse res = new RestResponse();
    RestContext.response = res;
    Test.startTest();
    AccountStatusRestAPI.doPost();
    Test.stopTest();
    Account updated = [
      SELECT Account_Status__c
      FROM Account
      WHERE Id = :acc.Id
    ];
    System.assertEquals('Active', updated.Account_Status__c);
    System.assertEquals(200, RestContext.response.statusCode);
  }

  @isTest
  static void testDoPost_MissingAccountId() {
    // Missing Account ID
    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/AccountStatus';
    req.httpMethod = 'POST';
    req.addHeader('Content-Type', 'application/json');
    req.requestBody = Blob.valueOf('{"Account_Status__c":"Active"}');
    RestContext.request = req;
    RestContext.response = new RestResponse();
    Test.startTest();
    AccountStatusRestAPI.doPost();
    Test.stopTest();
    System.assertEquals(400, RestContext.response.statusCode);
  }

  @isTest
  static void testDoPost_InvalidAccountStatus() {
    // Invalid Account Status
    Account acc = new Account(
      Name = 'Test Account 2',
      Account_Status__c = 'Draft'
    );
    insert acc;
    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/AccountStatus';
    req.httpMethod = 'POST';
    req.addHeader('Content-Type', 'application/json');
    req.requestBody = Blob.valueOf(
      '{"Id":"' + acc.Id + '","Account_Status__c":"InvalidStatus"}'
    );
    RestContext.request = req;
    RestContext.response = new RestResponse();
    Test.startTest();
    AccountStatusRestAPI.doPost();
    Test.stopTest();
    System.assertEquals(400, RestContext.response.statusCode);
  }

  @isTest
  static void testDoPost_AccountNotFound() {
    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/AccountStatus';
    req.httpMethod = 'POST';
    req.addHeader('Content-Type', 'application/json');
    req.requestBody = Blob.valueOf(
      '{"Id":"001000000000000AAA","Account_Status__c":"Active"}'
    );
    RestContext.request = req;
    RestContext.response = new RestResponse();
    Test.startTest();
    AccountStatusRestAPI.doPost();
    Test.stopTest();
    System.assertEquals(404, RestContext.response.statusCode);
  }
}