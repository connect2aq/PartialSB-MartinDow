@isTest
public class MD_QuoteTriggerTest {
  @isTest
  static void testPublishSyncEvent() {
    // Create a related Opportunity (if required by lookup)
    MD_Opportunity__c opp = new MD_Opportunity__c(
      Name = 'Test Opp',
      // StageName = 'Seeding',
      Close_Date__c = Date.today().addDays(10)
    );
    insert opp;

    // Create a test MD_Quote__c with IsSyncing__c = false
    MD_Quote__c quote = new MD_Quote__c(
      // Name = 'Test Quote',
      MD_Opportunity__c = opp.Id,
      IsSyncing__c = false
    );
    insert quote;

    // Add a related Quote Line Item to pass validation
    MD_Quote_Line_Item__c qli = new MD_Quote_Line_Item__c(
      Name = 'Test QLI',
      Quantity__c = 1,
      QuoteId__c = quote.Id
      // Add other required fields if any
    );
    insert qli;

    // Update IsSyncing__c to true to fire the trigger
    quote.IsSyncing__c = true;
    update quote;

    // Optionally, assert that the platform event was published (if you have a way to check)
    // Example: List<Quote_Sync__e> events = [SELECT ... FROM Quote_Sync__e];
    // System.assertEquals(1, events.size());
  }
}