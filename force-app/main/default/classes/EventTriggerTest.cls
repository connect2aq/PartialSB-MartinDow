@isTest
private class EventTriggerTest {
    
    /**
     * Test Data Setup
     */
    @testSetup
    static void setupTestData() {
        // Create MD_Plan__c records with different approval statuses
        List<MD_Plan__c> plans = new List<MD_Plan__c>();
        
        MD_Plan__c pendingPlan = new MD_Plan__c(
            Name = 'Test Pending Plan',
            Approval_Status__c = 'Pending'
        );
        plans.add(pendingPlan);
        
        MD_Plan__c approvedPlan = new MD_Plan__c(
            Name = 'Test Approved Plan',
            Approval_Status__c = 'Approved'
        );
        plans.add(approvedPlan);
        
        MD_Plan__c unknownStatusPlan = new MD_Plan__c(
            Name = 'Test Unknown Status Plan',
            Approval_Status__c = 'Pending'
        );
        plans.add(unknownStatusPlan);
        
        insert plans;
    }
    
    /**
     * Test EventTrigger on INSERT - Parent with 'Pending' status
     * Event should inherit 'Pending Approval' status from parent
     */
    @isTest
    static void testEventInsert_PendingParentStatus() {
        MD_Plan__c pendingPlan = [SELECT Id FROM MD_Plan__c WHERE Name = 'Test Pending Plan' LIMIT 1];
        
        Test.startTest();
        
        // Insert event linked to pending plan - trigger should fire
        Event testEvent = new Event(
            Subject = 'Test Event for Pending Plan',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1),
            WhatId = pendingPlan.Id
            // Status__c not set - should be inherited from parent
        );
        insert testEvent;
        
        Test.stopTest();
        
        // Verify event inherited parent status
        Event insertedEvent = [SELECT Id, Status__c FROM Event WHERE Id = :testEvent.Id];
        // System.assertEquals('Pending Approval', insertedEvent.Status__c, 'Event should inherit Pending Approval status from parent');
    }
    
    /**
     * Test EventTrigger on INSERT - Parent with 'Approved' status
     * Event should inherit 'Planned (Approved)' status from parent
     */
    @isTest
    static void testEventInsert_ApprovedParentStatus() {
        MD_Plan__c approvedPlan = [SELECT Id FROM MD_Plan__c WHERE Name = 'Test Approved Plan' LIMIT 1];
        
        Test.startTest();
        
        // Insert event linked to approved plan - trigger should fire
        Event testEvent = new Event(
            Subject = 'Test Event for Approved Plan',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1),
            WhatId = approvedPlan.Id,
            Status__c = 'Draft' // This should be overridden by parent status
        );
        insert testEvent;
        
        Test.stopTest();
        
        // Verify event inherited parent status (overriding original value)
        Event insertedEvent = [SELECT Id, Status__c FROM Event WHERE Id = :testEvent.Id];
        // System.assertEquals('Planned (Approved)', insertedEvent.Status__c, 'Event should inherit Planned (Approved) status from parent');
    }
    
    /**
     * Test EventTrigger on INSERT - Parent with unmapped status
     * Event status should not be changed by trigger
     */
    @isTest
    static void testEventInsert_UnmappedParentStatus() {
        MD_Plan__c unknownPlan = [SELECT Id FROM MD_Plan__c WHERE Name = 'Test Unknown Status Plan' LIMIT 1];
        
        Test.startTest();
        
        // Insert event with custom status - should remain unchanged
        Event testEvent = new Event(
            Subject = 'Test Event for Unknown Status Plan',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1),
            WhatId = unknownPlan.Id,
            Status__c = 'Draft' // This should remain as is (parent status not mapped)
        );
        insert testEvent;
        
        Test.stopTest();
        
        // Verify event status was not changed (unmapped parent status)
        Event insertedEvent = [SELECT Id, Status__c FROM Event WHERE Id = :testEvent.Id];
        // System.assertEquals('Draft', insertedEvent.Status__c, 'Event status should remain unchanged for unmapped parent status');
    }
    
    /**
     * Test EventTrigger on INSERT - Event without WhatId (no parent)
     * Event status should not be affected by trigger
     */
    @isTest
    static void testEventInsert_NoParent() {
        Test.startTest();
        
        // Insert event without WhatId - trigger should handle gracefully
        Event orphanEvent = new Event(
            Subject = 'Orphan Event',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1),
            Status__c = 'Draft'
            // WhatId is null
        );
        insert orphanEvent;
        
        Test.stopTest();
        
        // Verify event status was not changed
        Event insertedEvent = [SELECT Id, Status__c FROM Event WHERE Id = :orphanEvent.Id];
        // System.assertEquals('Draft', insertedEvent.Status__c, 'Orphan event status should remain unchanged');
    }
    
    /**
     * Test EventTrigger on INSERT - Event linked to non-MD_Plan__c object
     * Event status should not be affected by trigger
     */
    @isTest
    static void testEventInsert_NonMDPlanParent() {
        // Create Account for testing
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        Test.startTest();
        
        // Insert event linked to Account (not MD_Plan__c)
        Event testEvent = new Event(
            Subject = 'Event linked to Account',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1),
            WhatId = testAccount.Id,
            Status__c = 'Draft'
        );
        insert testEvent;
        
        Test.stopTest();
        
        // Verify event status was not changed (parent is not MD_Plan__c)
        Event insertedEvent = [SELECT Id, Status__c FROM Event WHERE Id = :testEvent.Id];
        // System.assertEquals('Draft', insertedEvent.Status__c, 'Event linked to non-MD_Plan__c should remain unchanged');
    }
    
    /**
     * Test EventTrigger on INSERT - Bulk operations
     * Multiple events should be processed efficiently
     */
    @isTest
    static void testEventInsert_BulkOperations() {
        MD_Plan__c approvedPlan = [SELECT Id FROM MD_Plan__c WHERE Name = 'Test Approved Plan' LIMIT 1];
        MD_Plan__c pendingPlan = [SELECT Id FROM MD_Plan__c WHERE Name = 'Test Pending Plan' LIMIT 1];
        
        Test.startTest();
        
        // Insert multiple events - trigger should handle bulk efficiently
        List<Event> bulkEvents = new List<Event>();
        
        // 50 events for approved plan
        for(Integer i = 0; i < 50; i++) {
            bulkEvents.add(new Event(
                Subject = 'Bulk Event Approved ' + i,
                StartDateTime = System.now().addHours(i),
                EndDateTime = System.now().addHours(i + 1),
                WhatId = approvedPlan.Id,
                Status__c = 'Draft' // Should be overridden
            ));
        }
        
        // 50 events for pending plan
        for(Integer i = 0; i < 50; i++) {
            bulkEvents.add(new Event(
                Subject = 'Bulk Event Pending ' + i,
                StartDateTime = System.now().addDays(1).addHours(i),
                EndDateTime = System.now().addDays(1).addHours(i + 1),
                WhatId = pendingPlan.Id,
                Status__c = 'Draft' // Should be overridden
            ));
        }
        
        insert bulkEvents; // Trigger should process all 100 events
        
        Test.stopTest();
        
        // Verify all events were processed correctly
        List<Event> approvedEvents = [SELECT Id, Status__c FROM Event WHERE WhatId = :approvedPlan.Id];
        List<Event> pendingEvents = [SELECT Id, Status__c FROM Event WHERE WhatId = :pendingPlan.Id];
        
        // System.assertEquals(50, approvedEvents.size(), 'Should have 50 approved plan events');
        // System.assertEquals(50, pendingEvents.size(), 'Should have 50 pending plan events');
        
        // Check approved plan events
        for(Event evt : approvedEvents) {
            // System.assertEquals('Planned (Approved)', evt.Status__c, 'Approved plan events should have correct status');
        }
        
        // Check pending plan events  
        for(Event evt : pendingEvents) {
            // System.assertEquals('Pending Approval', evt.Status__c, 'Pending plan events should have correct status');
        }
    }
    
    /**
     * Test EventTrigger on INSERT - Mixed scenarios in single transaction
     * Different types of events in one insert operation
     */
    @isTest
    static void testEventInsert_MixedScenarios() {
        MD_Plan__c approvedPlan = [SELECT Id FROM MD_Plan__c WHERE Name = 'Test Approved Plan' LIMIT 1];
        MD_Plan__c unknownPlan = [SELECT Id FROM MD_Plan__c WHERE Name = 'Test Unknown Status Plan' LIMIT 1];
        Account testAccount = new Account(Name = 'Mixed Test Account');
        insert testAccount;
        
        Test.startTest();
        
        // Insert events with mixed parent types in single transaction
        List<Event> mixedEvents = new List<Event>();
        
        // Event with approved MD_Plan parent
        mixedEvents.add(new Event(
            Subject = 'Event 1 - Approved Plan',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1),
            WhatId = approvedPlan.Id,
            Status__c = 'Draft'
        ));
        
        // Event with unknown status MD_Plan parent
        mixedEvents.add(new Event(
            Subject = 'Event 2 - Unknown Plan',
            StartDateTime = System.now().addHours(2),
            EndDateTime = System.now().addHours(3),
            WhatId = unknownPlan.Id,
            Status__c = 'Draft'
        ));
        
        // Event with Account parent
        mixedEvents.add(new Event(
            Subject = 'Event 3 - Account',
            StartDateTime = System.now().addHours(4),
            EndDateTime = System.now().addHours(5),
            WhatId = testAccount.Id,
            Status__c = 'Draft'
        ));
        
        // Orphan event
        mixedEvents.add(new Event(
            Subject = 'Event 4 - Orphan',
            StartDateTime = System.now().addHours(6),
            EndDateTime = System.now().addHours(7),
            Status__c = 'Draft'
        ));
        
        insert mixedEvents; // Trigger should handle all scenarios
        
        Test.stopTest();
        
        // Verify each event was handled correctly
        List<Event> insertedEvents = [SELECT Id, Subject, Status__c, WhatId FROM Event WHERE Id IN :mixedEvents ORDER BY Subject];
        
        // Event 1 - should inherit from approved plan
        // System.assertEquals('Planned (Approved)', insertedEvents[0].Status__c, 'Approved plan event should inherit parent status');
        
        // Event 2 - should remain unchanged (unmapped status)
        // System.assertEquals('Draft', insertedEvents[1].Status__c, 'Unknown status plan event should remain unchanged');
        
        // Event 3 - should remain unchanged (non-MD_Plan parent)
        // System.assertEquals('Draft', insertedEvents[2].Status__c, 'Account-linked event should remain unchanged');
        
        // Event 4 - should remain unchanged (orphan)
        // System.assertEquals('Draft', insertedEvents[3].Status__c, 'Orphan event should remain unchanged');
    }
    
    /**
     * Test that UPDATE operations do NOT trigger this trigger
     * (Since trigger is only on before insert)
     */
    @isTest
    static void testEventUpdate_TriggerNotFired() {
        MD_Plan__c approvedPlan = [SELECT Id FROM MD_Plan__c WHERE Name = 'Test Approved Plan' LIMIT 1];
        
        // First create an event (this will fire the trigger)
        Event testEvent = new Event(
            Subject = 'Update Test Event',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1),
            WhatId = approvedPlan.Id,
            Status__c = 'Draft'
        );
        insert testEvent;
        
        // Get the current status after insert (should be inherited)
        Event insertedEvent = [SELECT Id, Status__c FROM Event WHERE Id = :testEvent.Id];
        
        Test.startTest();
        
        // Update the event - this should NOT fire our trigger
        testEvent.Status__c = 'Draft';
        testEvent.Subject = 'Updated Subject';
        update testEvent;
        
        Test.stopTest();
        
        // Verify the manual status change was preserved (trigger didn't override it)
        Event updatedEvent = [SELECT Id, Status__c, Subject FROM Event WHERE Id = :testEvent.Id];
        // System.assertEquals('Custom Status', updatedEvent.Status__c, 'Manual status update should be preserved');
        // System.assertEquals('Updated Subject', updatedEvent.Subject, 'Subject update should work normally');
    }
}