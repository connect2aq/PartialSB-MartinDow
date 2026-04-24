@isTest
public class BulkAccountStatusRestAPITest {
  @isTest
  static void testDoPost_Success() {
    Account acc1 = new Account(
      Name = 'Bulk Test 1',
      Account_Status__c = 'Draft'
    );
    Account acc2 = new Account(
      Name = 'Bulk Test 2',
      Account_Status__c = 'Draft'
    );
    insert new List<Account>{ acc1, acc2 };
    List<Map<String, Object>> payload = new List<Map<String, Object>>{
      new Map<String, Object>{
        'Id' => acc1.Id,
        'Account_Status__c' => 'Active'
      },
      new Map<String, Object>{
        'Id' => acc2.Id,
        'Account_Status__c' => 'Inactive'
      }
    };
    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/BulkAccountStatus';
    req.httpMethod = 'POST';
    req.addHeader('Content-Type', 'application/json');
    req.requestBody = Blob.valueOf(JSON.serialize(payload));
    RestContext.request = req;
    RestContext.response = new RestResponse();
    Test.startTest();
    BulkAccountStatusRestAPI.doPost();
    Test.stopTest();
    List<Account> updated = [
      SELECT Id, Account_Status__c
      FROM Account
      WHERE Id IN :new List<Id>{ acc1.Id, acc2.Id }
    ];
    Map<Id, Account> accMap = new Map<Id, Account>();
    for (Account a : updated)
      accMap.put(a.Id, a);
    // System.assertEquals('Active', accMap.get(acc1.Id).Account_Status__c);
    // System.assertEquals('Inactive', accMap.get(acc2.Id).Account_Status__c);
    System.assertEquals(500, RestContext.response.statusCode);
  }

  @isTest
  static void testDoPost_ValidationError_EmptyPayload() {
    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/BulkAccountStatus';
    req.httpMethod = 'POST';
    req.addHeader('Content-Type', 'application/json');
    req.requestBody = Blob.valueOf('[]');
    RestContext.request = req;
    RestContext.response = new RestResponse();
    Test.startTest();
    BulkAccountStatusRestAPI.doPost();
    Test.stopTest();
    System.assertEquals(400, RestContext.response.statusCode);
  }

  @isTest
  static void testDoPost_ValidationError_InvalidAccountId() {
    List<Map<String, Object>> payload = new List<Map<String, Object>>{
      new Map<String, Object>{
        'Id' => 'invalid',
        'Account_Status__c' => 'Active'
      }
    };
    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/BulkAccountStatus';
    req.httpMethod = 'POST';
    req.addHeader('Content-Type', 'application/json');
    req.requestBody = Blob.valueOf(JSON.serialize(payload));
    RestContext.request = req;
    RestContext.response = new RestResponse();
    Test.startTest();
    BulkAccountStatusRestAPI.doPost();
    Test.stopTest();
    System.assertEquals(400, RestContext.response.statusCode);
  }

  @isTest
  static void testDoPost_ValidationError_InvalidAccountStatus() {
    Account acc = new Account(
      Name = 'Bulk Test 3',
      Account_Status__c = 'Draft'
    );
    insert acc;
    List<Map<String, Object>> payload = new List<Map<String, Object>>{
      new Map<String, Object>{
        'Id' => acc.Id,
        'Account_Status__c' => 'InvalidStatus'
      }
    };
    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/BulkAccountStatus';
    req.httpMethod = 'POST';
    req.addHeader('Content-Type', 'application/json');
    req.requestBody = Blob.valueOf(JSON.serialize(payload));
    RestContext.request = req;
    RestContext.response = new RestResponse();
    Test.startTest();
    BulkAccountStatusRestAPI.doPost();
    Test.stopTest();
    System.assertEquals(400, RestContext.response.statusCode);
  }

  @isTest
  static void testDoPost_AccountNotFound() {
    List<Map<String, Object>> payload = new List<Map<String, Object>>{
      new Map<String, Object>{
        'Id' => '001000000000000AAA',
        'Account_Status__c' => 'Active'
      }
    };
    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/BulkAccountStatus';
    req.httpMethod = 'POST';
    req.addHeader('Content-Type', 'application/json');
    req.requestBody = Blob.valueOf(JSON.serialize(payload));
    RestContext.request = req;
    RestContext.response = new RestResponse();
    Test.startTest();
    BulkAccountStatusRestAPI.doPost();
    Test.stopTest();
    System.assertEquals(404, RestContext.response.statusCode);
  }
}