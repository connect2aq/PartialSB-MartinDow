@isTest
public class EventValAccUpdAfterApprTest {
  @isTest
  static void testEventBeforeUpdate() {
    // Create a test Event
    Event ev = new Event(
      Subject = 'Test Event',
      StartDateTime = System.now(),
      EndDateTime = System.now().addHours(1)
      // Add other required fields if any
    );
    insert ev;

    // Update the Event to fire the trigger
    ev.Subject = 'Updated Subject';
    update ev;

    // Add assertions here if EventTriggerHandler.handleBeforeUpdate modifies the Event
    // Example: System.assertEquals('ExpectedValue', ev.SomeField__c);
  }
}