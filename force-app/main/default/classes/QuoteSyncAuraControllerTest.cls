@isTest
public class QuoteSyncAuraControllerTest {
  @isTest
  static void testGetOpportunityId() {
    MD_Opportunity__c opp = new MD_Opportunity__c(
      Name = 'Test Opp',
      Close_Date__c = Date.today().addDays(30)
    );
    insert opp;
    MD_Quote__c quote = new MD_Quote__c(
      Quote_Name__c = 'Test Quote',
      MD_Opportunity__c = opp.Id
    );
    insert quote;
    Test.startTest();
    Id result = QuoteSyncAuraController.getOpportunityId(quote.Id);
    Test.stopTest();
    System.assertEquals(
      opp.Id,
      result,
      'Should return the correct Opportunity Id'
    );
  }
}