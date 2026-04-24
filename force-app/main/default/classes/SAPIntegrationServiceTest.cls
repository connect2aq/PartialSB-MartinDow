@isTest
public class SAPIntegrationServiceTest {
  @isTest
  static void testSAPAccountRequestSerialization() {
    // Build SAPAccountRequest with nested data
    SAPAccountRequest req = new SAPAccountRequest();
    req.Kunnr = '1000001';
    req.Name1 = 'Test Name1';
    req.Name2 = 'Test Name2';
    req.Name4 = 'Test Name4';
    req.Searchterm1 = 'Search1';
    req.Searchterm2 = 'Search2';
    req.City = 'Test City';
    req.District = 'Test District';
    req.PostlCod1 = '12345';
    req.StrSuppl3 = 'Street';
    req.Location = 'Loc';
    req.Country = 'PK';
    req.Bukrs = '3000';
    req.Akont = 'AKT';
    req.Vkorg = 'ORG';
    req.Zterm = 'ZT';
    req.Vtweg = '10';
    req.Spart = '30';
    req.Bzirk = 'BZ';
    req.Vwerk = 'VW';
    req.Kdgrp = 'KG';
    req.Vkbur = 'VB';
    req.Waers = 'PKR';
    req.Vkgrp = 'VG';
    req.Konda = 'KD';
    req.Kalks = 'KL';
    req.Vsbed = 'VS';
    req.Inco1 = 'INC1';
    req.Inco2 = 'INC2';
    req.ZtermSd = 'ZTS';
    req.Ktgrd = 'KT';

    // Add nested N_CUSTMER
    SAPAccountRequest.N_CUSTMER custmer = new SAPAccountRequest.N_CUSTMER();
    custmer.KUNNR = '1000001';
    custmer.EMail = 'test@example.com';
    req.N_CUSTMER = new List<SAPAccountRequest.N_CUSTMER>{ custmer };

    // Add nested N_CUSTMER1
    SAPAccountRequest.N_CUSTMER1 custmer1 = new SAPAccountRequest.N_CUSTMER1();
    custmer1.Kunnr = '1000001';
    custmer1.Tatyp = 'T1';
    custmer1.Taxkd = 'TX';
    req.N_CUSTMER1 = new List<SAPAccountRequest.N_CUSTMER1>{ custmer1 };

    // Add nested N_CUSTMER2
    SAPAccountRequest.N_CUSTMER2 custmer2 = new SAPAccountRequest.N_CUSTMER2();
    custmer2.KUNNR = '1000001';
    custmer2.Taxtype = 'VAT';
    custmer2.Taxnumber = '123456';
    req.N_CUSTMER2 = new List<SAPAccountRequest.N_CUSTMER2>{ custmer2 };

    // Add nested N_CUSTMER3
    SAPAccountRequest.N_CUSTMER3 custmer3 = new SAPAccountRequest.N_CUSTMER3();
    custmer3.Kunnr = '1000001';
    custmer3.Telephone = '1234567890';
    req.N_CUSTMER3 = new List<SAPAccountRequest.N_CUSTMER3>{ custmer3 };

    // Add nested N_CUSTMER4
    SAPAccountRequest.N_CUSTMER4 custmer4 = new SAPAccountRequest.N_CUSTMER4();
    custmer4.Kunnr = '1000001';
    custmer4.Mobile = '9876543210';
    req.N_CUSTMER4 = new List<SAPAccountRequest.N_CUSTMER4>{ custmer4 };

    // Add nested N_CUSTMER6
    SAPAccountRequest.N_CUSTMER6 custmer6 = new SAPAccountRequest.N_CUSTMER6();
    custmer6.Kunnr = '1000001';
    custmer6.CreditSegment = 'SEG1';
    custmer6.CreditLimit = '100000';
    req.N_CUSTMER6 = new List<SAPAccountRequest.N_CUSTMER6>{ custmer6 };

    // Serialize to JSON and check fields
    String jsonStr = JSON.serialize(req);
    System.assert(jsonStr.contains('"Kunnr":"1000001"'));
    System.assert(jsonStr.contains('"EMail":"test@example.com"'));
    System.assert(jsonStr.contains('"CreditLimit":"100000"'));
  }

  @isTest
  static void testBuildSAPRequest() {
    // Create test Account
    Account acc = new Account(
      Name = 'Test Account',
      SAP_Customer_Number__c = '1000001',
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
      // Phone = '021-1234567',
      // Cell__c = '03001234567',
      // Email__c = 'test@martindow.com',
      Business_Vertical__c = 'DIAGNOSTIC' // Set to null to avoid picklist error
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
      Tax_Category_Code__c = 'PK01 - Pakistan: CNIC',
      Category_Value__c = '888888'
    );
    insert tax;

    // Create related Credit Profile
    Credit_Profile__c cp = new Credit_Profile__c(
      Account__c = acc.Id,
      Credit_Segment__c = 'ZMSPL2 MDSPL Segment - Diagnostics',
      Credit_Limit__c = 50000
    );
    insert cp;

    Test.startTest();
    SAPAccountRequest req = SAPIntegrationService.buildSAPRequest(acc.Id);
    Test.stopTest();

    System.assertEquals('1000001', req.Kunnr);
    // System.assertEquals('Test Account', req.Name1);
    // System.assertEquals('Karachi', req.City);
    // System.assertEquals('Sindh', req.District);
    // System.assertEquals('75500', req.PostlCod1);
    // System.assertEquals('Line1', req.StrSuppl3);
    // System.assertEquals('Line2', req.Location);
    // System.assertEquals('PK', req.Country);
    // System.assertEquals('3000', req.Bukrs);
    // System.assertEquals('RA', req.Akont);
    // System.assertEquals('PT', req.Zterm);
    // System.assertEquals('ORG', req.Vkorg);
    // System.assertEquals('10', req.Vtweg);
    // System.assertEquals('30', req.Spart);
    // System.assertEquals('CG', req.Kdgrp);
    // System.assertEquals('SD', req.Bzirk);
    // System.assertEquals('SO', req.Vkbur);
    // System.assertEquals('PKR', req.Waers);
    // System.assertEquals('SG', req.Vkgrp);
    // System.assertEquals('PG', req.Konda);
    // System.assertEquals('PPI', req.Kalks);
    // System.assertEquals('PLANT', req.Vwerk);
    // System.assertEquals('INC', req.Inco1);
    // System.assertEquals('PT', req.ZtermSd);
    // System.assertEquals('CAG', req.Ktgrd);
    // System.assertEquals('Vertical1', req.Searchterm1);
    // System.assertEquals('DIAG', req.Searchterm2);
    // System.assertEquals(1, req.N_CUSTMER.size());
    // System.assertEquals('contact@martindow.com', req.N_CUSTMER[0].EMail);
    // System.assertEquals(1, req.N_CUSTMER3.size());
    // System.assertEquals('021-7654321', req.N_CUSTMER3[0].Telephone);
    // System.assertEquals(1, req.N_CUSTMER4.size());
    // System.assertEquals('03007654321', req.N_CUSTMER4[0].Mobile);
    // System.assertEquals(4, req.N_CUSTMER1.size());
    // System.assertEquals(1, req.N_CUSTMER2.size());
    // System.assertEquals('VAT', req.N_CUSTMER2[0].Taxtype);
    // System.assertEquals('TX123', req.N_CUSTMER2[0].Taxnumber);
    // System.assertEquals(1, req.N_CUSTMER6.size());
    // System.assertEquals('50000', req.N_CUSTMER6[0].CreditLimit);
  }

  @isTest
  static void testCreateAccountInSAP_noToken() {
    // This test will simulate a failed token retrieval
    Test.startTest();
    SAPIntegrationService.createAccountInSAP('001000000000001AAA'); // Use a dummy Id
    Test.stopTest();
    // No exception should be thrown, and debug logs should show token failure
  }

  // Mock for HTTP callouts
  class MockHttpResponseGenerator implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      // Simulate Auth call
      if (req.getEndpoint().contains('/Login/Auth')) {
        res.setStatusCode(200);
        res.setBody('{"token":"mocked-token","success":true}');
      } else if (req.getEndpoint().contains('/SAP/PostCustomer')) {
        res.setStatusCode(200);
        res.setBody('{"success":true,"message":"OK","data":"SAP12345"}');
      } else {
        res.setStatusCode(400);
        res.setBody('{"success":false,"message":"Bad Request"}');
      }
      return res;
    }
  }

  @isTest
  static void testGetAuthToken_callout() {
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
    Test.startTest();
    String token = SAPIntegrationService.getAuthToken();
    Test.stopTest();
    System.assertEquals('mocked-token', token, 'Should return mocked token');
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
    SAPIntegrationService.createAccountInSAP(acc.Id);
    Test.stopTest();
    // Assert Account updated with SAP Customer Number
    Account updated = [
      SELECT SAP_Customer_Number__c, Account_Status__c
      FROM Account
      WHERE Id = :acc.Id
    ];
    System.assertEquals('SAP12345', updated.SAP_Customer_Number__c);
    System.assertEquals('Active', updated.Account_Status__c);
  }
}