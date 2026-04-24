@isTest
public class EventTriggerHandlerTest {
  @isTest
  static void testAccountFieldChangeBlockedForApprovedMDPlan() {
    // Create an approved MD_Plan__c
    MD_Plan__c plan = new MD_Plan__c(
      Name = 'Test Plan',
      Approval_Status__c = 'Approved'
    );
    insert plan;
    // Create two Accounts
    Account acc1 = new Account(Name = 'Account 1');
    Account acc2 = new Account(Name = 'Account 2');
    insert new List<Account>{ acc1, acc2 };
    // Create an Event linked to the approved MD_Plan__c and acc1
    Event ev = new Event(
      Subject = 'Test Event',
      WhatId = plan.Id,
      Account__c = acc1.Id,
      StartDateTime = System.now(),
      EndDateTime = System.now().addHours(1)
    );
    insert ev;
    // Try to change Account__c to acc2 (should be blocked)
    ev.Account__c = acc2.Id;
    try {
      update ev;
      System.assert(false, 'Should have thrown error for Account__c change');
    } catch (DmlException e) {
      System.assert(true);
    }
  }
}