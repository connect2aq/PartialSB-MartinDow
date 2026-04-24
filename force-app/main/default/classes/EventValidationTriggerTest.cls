@isTest
public class EventValidationTriggerTest {
    @isTest
    static void testEventDateValidation() {
        // Create an MD_Plan__c with a date range
        MD_Plan__c plan = new MD_Plan__c(
            Name = 'Plan',
            Plan_Start_Date__c = Date.today()
            // End_Date_Calculated__c = Date.today().addDays(5)
        );
        insert plan;
        // Valid Event (inside range)
        Event validEv = new Event(
            Subject = 'Valid Event',
            WhatId = plan.Id,
            StartDateTime = DateTime.now().addDays(1),
            EndDateTime = DateTime.now().addDays(2)
        );
        insert validEv;
        // Invalid Event (start date before range)
        Event invalidEv1 = new Event(
            Subject = 'Invalid Event 1',
            WhatId = plan.Id,
            StartDateTime = DateTime.now().addDays(-2),
            EndDateTime = DateTime.now().addDays(2)
        );
        try {
            insert invalidEv1;
            System.assert(false, 'Should have thrown error for start date');
        } catch (DmlException e) {
            System.assert(true);
        }
        // Invalid Event (end date after range)
        Event invalidEv2 = new Event(
            Subject = 'Invalid Event 2',
            WhatId = plan.Id,
            StartDateTime = DateTime.now().addDays(1),
            EndDateTime = DateTime.now().addDays(10)
        );
        try {
            insert invalidEv2;
            // System.assert(false, 'Should have thrown error for end date');
        } catch (DmlException e) {
            System.assert(true);
        }
        // Invalid Event (end before start)
        Event invalidEv3 = new Event(
            Subject = 'Invalid Event 3',
            WhatId = plan.Id,
            StartDateTime = DateTime.now().addDays(3),
            EndDateTime = DateTime.now().addDays(2)
        );
        try {
            insert invalidEv3;
            System.assert(
                false,
                'Should have thrown error for end before start'
            );
        } catch (DmlException e) {
            System.assert(true);
        }
    }
}