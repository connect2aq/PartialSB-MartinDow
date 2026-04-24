@isTest
public class OrderIntegrationTriggerTest {
  @isTest
  static void testOrderIntegrationTrigger() {
    // Create a test MD_Order__c with Status__c != 'Approved'
    MD_Order__c order = new MD_Order__c(
      Status__c = 'Open'
      // Add other required fields if any
    );
    insert order;

    // Update Status__c to 'Approved' to fire the trigger
    order.Status__c = 'Approved';
    update order;

    // Optionally, assert that the future method was called or integration logic was executed
    // This may require a mock or checking side effects if possible
  }
}