@isTest
public class AccountKpiControllerTest {
  @testSetup
  static void setup() {
    // Create test Account
    Account acc = new Account(
      Name = 'Test Account',
      Business_Vertical__c = 'Diagnostic'
    );
    insert acc;

    // Create a Contact and link to Account
    Contact con = new Contact(
      FirstName = 'Test',
      LastName = 'Contact',
      AccountId = acc.Id
    );
    insert con;

    // Create related records for test coverage
    MD_Asset__c asset = new MD_Asset__c(
      AccountId__c = acc.Id,
      Status__c = 'RR'
    );
    insert asset;

    // Create Opportunity and link Contact as primary
    MD_Opportunity__c opp = new MD_Opportunity__c(
      Account_Name__c = acc.Id,
      Stage__c = 'Close_Opportunity',
      Close_Won_Or_Close_Lost__c = 'Close Won',
      Contact__c = con.Id,
      Close_Date__c = Date.today()
    );
    insert opp;

    Invoice__c inv = new Invoice__c(BusinessOpportunity__c = opp.Id);
    insert inv;

    Credit_Profile__c cp = new Credit_Profile__c(
      Account__c = acc.Id,
      Credit_Segment__c = 'ZMSPL2 MDSPL Segment - Diagnostics',
      Outstanding_Amount__c = 100,
      Credit_Limit__c = 200
    );
    insert cp;

    MD_Case__c mcase = new MD_Case__c(AccountId__c = acc.Id, Status__c = 'New');
    insert mcase;

    Event ev = new Event(
      Account__c = acc.Id,
      Status__c = 'Completed',
      StartDateTime = System.now(),
      DurationInMinutes = 30
    );
    insert ev;
  }

  @isTest
  static void testGetAssetStageCounts() {
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Test.startTest();
    Map<String, Integer> result = AccountKpiController.getAssetStageCounts(
      acc.Id
    );
    Test.stopTest();
    System.assertNotEquals(null, result);
  }

  @isTest
  static void testGetOpportunityToSalesConversionYTD() {
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Test.startTest();
    Decimal result = AccountKpiController.getOpportunityToSalesConversionYTD(
      acc.Id
    );
    Test.stopTest();
    System.assert(result >= 0);
  }

  @isTest
  static void testGetOpportunityToSalesConversionMTD() {
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Test.startTest();
    Decimal result = AccountKpiController.getOpportunityToSalesConversionMTD(
      acc.Id
    );
    Test.stopTest();
    System.assert(result >= 0);
  }

  @isTest
  static void testGetOpenComplaints() {
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Test.startTest();
    Integer result = AccountKpiController.getOpenComplaints(acc.Id);
    Test.stopTest();
    System.assert(result >= 0);
  }

  @isTest
  static void testGetCreditProfiles() {
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Test.startTest();
    List<Map<String, Object>> result = AccountKpiController.getCreditProfiles(
      acc.Id
    );
    Test.stopTest();
    System.assertNotEquals(null, result);
  }

  @isTest
  static void testGetVisitStatsMTD() {
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Test.startTest();
    Map<String, Integer> result = AccountKpiController.getVisitStatsMTD(acc.Id);
    Test.stopTest();
    System.assertNotEquals(null, result);
  }

  @isTest
  static void testGetVisitStatsYTD() {
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Test.startTest();
    Map<String, Integer> result = AccountKpiController.getVisitStatsYTD(acc.Id);
    Test.stopTest();
    System.assertNotEquals(null, result);
  }

  @isTest
  static void testGetAccountSegment() {
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Test.startTest();
    String result = AccountKpiController.getAccountSegment(acc.Id);
    Test.stopTest();
    System.assertNotEquals(null, result);
  }

  @isTest
  static void testGetSalesKpi() {
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Test.startTest();
    Map<String, Decimal> result = AccountKpiController.getSalesKpi(acc.Id);
    Test.stopTest();
    System.assertNotEquals(null, result);
  }

  @isTest
  static void testGetOpenOpportunities() {
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Test.startTest();
    Map<String, Object> result = AccountKpiController.getOpenOpportunities(
      acc.Id
    );
    Test.stopTest();
    System.assertNotEquals(null, result);
  }

  @isTest
  static void testGetOpportunityToSalesConversion() {
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Test.startTest();
    Decimal result = AccountKpiController.getOpportunityToSalesConversion(
      acc.Id
    );
    Test.stopTest();
    System.assert(result >= 0);
  }
}