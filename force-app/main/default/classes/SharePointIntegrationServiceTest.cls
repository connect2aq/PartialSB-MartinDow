@isTest
public class SharePointIntegrationServiceTest {
  @isTest
  static void testGetAuthToken_callout() {
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
    Test.startTest();
    String token = SharePointIntegrationService.getAuthToken();
    Test.stopTest();
    System.assertEquals('mocked-token', token, 'Should return mocked token');
  }

  @isTest
  static void testBuildSAPRequest() {
    // Create test Account
    Account acc = new Account(
      Name = 'Test Account',
      SAP_Customer_Number__c = '1000001',
      Share_Point_Number__c = 'SP1001',
      Account_Name2__c = 'Name2',
      City__c = 'Karachi',
      Province__c = 'Sindh',
      Postal_Code__c = '75500',
      AddressLine_1__c = 'Line1',
      Addess_Line_2__c = 'Line2',
      Country_Code__c = 'PK',
      Company_Code__c = '3000',
      Reconciliation_Account__c = '1033000001 - Accounts receivable - Life Science',
      Payment_Terms_FI_Role__c = 'C001 - Pay immediately',
      Business_Vertical__c = 'DIAGNOSTIC'
    );
    insert acc;

    // Create related Contact
    Contact con = new Contact(
      FirstName = 'Test',
      LastName = 'Contact',
      Email = 'contact@martindow.com',
      Phone = '021-7654321',
      MobilePhone = '03007654321',
      AccountId = acc.Id
    );
    insert con;

    // Create related Sales Area
    MD_Sales_Area__c sa = new MD_Sales_Area__c(
      Parent_Account__c = acc.Id,
      Sales_Org__c = '3000',
      Distribution_Channel__c = '10 - Local',
      Division__c = '30 - Diagnostics',
      Customer_Group__c = '10 - Pathological Labs',
      Sales_District__c = '2000 - Central Region',
      Delivering_Plant__c = '3300 - MDSPL – Korangi Warehouse',
      Sales_Office__c = '2000 - Sales Office LHR',
      Sales_Group__c = 'Z07 - Sales Group Lahore',
      Currency__c = 'PKR - Pakistani Rupee',
      Price_Group__c = 'P01 - Bulk buyer',
      Pricing_Procedure_Indicator__c = '1 - Standard',
      Incoterms__c = 'LCL - Local Sales',
      Incoterms_Description__c = 'Incoterm Desc',
      Payment_Terms__c = 'C014 - within 30 days Due net',
      Customer_Account_Assignment_Group__c = '01 - Domestic Revenues',
      Output_Tax_Category_MWST_Code__c = '1 - Liable for Taxes LS',
      Output_Tax_Category_ZMST_Code__c = '5 - End User/Govt/Tribal',
      Output_Tax_Category_ZMWS_Code__c = '1 - Unregistered',
      Output_Tax_Category_ZPK2_Code__c = '0 - Further Sales Tax 3%'
    );
    insert sa;

    // Create related Tax Number
    MD_Tax_Number__c tax = new MD_Tax_Number__c(
      Account__c = acc.Id,
      Tax_Category_Code__c = 'PK01 - CNIC',
      Category_Value__c = '888888'
    );
    insert tax;

    // Create related Credit Profile
    Credit_Profile__c cp = new Credit_Profile__c(
      Account__c = acc.Id,
      Credit_Segment__c = 'ZMSPL2 Segment',
      Credit_Limit__c = 50000
    );
    insert cp;

    Test.startTest();
    SharePointAccountRequest req = SharePointIntegrationService.buildSAPRequest(
      acc.Id
    );
    Test.stopTest();

    System.assertEquals('Test Account', req.NAME1);
    // System.assertEquals('Karachi', req.City);
    // System.assertEquals('PK', req.Country);
    // System.assertEquals('contact@martindow.com', req.nCustomer[0].eMail);
    // System.assertEquals('021-7654321', req.nCustomer3[0].telephone);
    // System.assertEquals('03007654321', req.nCustomer4[0].mobile);
    // System.assertEquals('3000', req.SalesOrg);
    // System.assertEquals('P01', req.PriceGroup);
    // System.assertEquals('50000', req.nCustomer6[0].creditLimit);
  }

  @isTest
  static void testCreateAccountInSAP_callout() {
    // Create test Account
    Account acc = new Account(
      Name = 'SAP Test',
      SAP_Customer_Number__c = '2000001'
    );
    insert acc;
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
    Test.startTest();
    SharePointIntegrationService.createAccountInSAP(acc.Id);
    Test.stopTest();
    // Assert Account updated with Share Point Number
    Account updated = [
      SELECT Share_Point_Number__c, Account_Status__c
      FROM Account
      WHERE Id = :acc.Id
    ];
    System.assertEquals('SP12345', updated.Share_Point_Number__c);
    System.assertEquals('Pending Approval', updated.Account_Status__c);
  }

  // Mock for HTTP callouts
  class MockHttpResponseGenerator implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      // Simulate Auth call
      if (req.getEndpoint().contains('/Login/Auth')) {
        res.setStatusCode(200);
        res.setBody('{"token":"mocked-token","success":true}');
      } else if (req.getEndpoint().contains('/Sharepoint/InsertCustomer')) {
        res.setStatusCode(200);
        res.setBody('{"success":true,"message":"OK","data":"SP12345"}');
      } else {
        res.setStatusCode(400);
        res.setBody('{"success":false,"message":"Bad Request"}');
      }
      return res;
    }
  }
}