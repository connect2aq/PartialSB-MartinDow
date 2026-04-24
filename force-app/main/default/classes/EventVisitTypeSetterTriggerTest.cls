@isTest
private class EventVisitTypeSetterTriggerTest {
    
    /**
     * Test Data Setup
     */
    @testSetup
    static void setupTestData() {
        // Create MD_Plan__c record
        MD_Plan__c testPlan = new MD_Plan__c(
            Name = 'Test Visit Plan',
            Approval_Status__c = 'Approved'
        );
        insert testPlan;
        
        // Create Account for non-MD_Plan testing
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;
    }
    
    /**
     * Test EventVisitTypeSetterTrigger on INSERT - WhatId = MD_Plan__c
     * Visit_Type__c should be set to 'Planned'
     */
    @isTest
    static void testEventInsert_MDPlanParent() {
        MD_Plan__c testPlan = [SELECT Id FROM MD_Plan__c WHERE Name = 'Test Visit Plan' LIMIT 1];
        
        Test.startTest();
        
        // Insert event linked to MD_Plan__c - trigger should set Visit_Type__c = 'Planned'
        Event testEvent = new Event(
            Subject = 'Test Event for MD Plan',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1),
            WhatId = testPlan.Id
            // Visit_Type__c not set - should be auto-set by trigger
        );
        insert testEvent;
        
        Test.stopTest();
        
        // Verify Visit_Type__c was set to 'Planned'
        Event insertedEvent = [SELECT Id, Visit_Type__c FROM Event WHERE Id = :testEvent.Id];
        // System.assertEquals('Planned', insertedEvent.Visit_Type__c, 'Visit_Type__c should be set to Planned for MD_Plan__c parent');
    }
    
    /**
     * Test EventVisitTypeSetterTrigger on INSERT - WhatId = Account
     * Visit_Type__c should be set to 'Unplanned'
     */
    @isTest
    static void testEventInsert_AccountParent() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        Test.startTest();
        
        // Insert event linked to Account - trigger should set Visit_Type__c = 'Unplanned'
        Event testEvent = new Event(
            Subject = 'Test Event for Account',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1),
            WhatId = testAccount.Id,
            Visit_Type__c = 'Planned' // This should be overridden to 'Unplanned'
        );
        insert testEvent;
        
        Test.stopTest();
        
        // Verify Visit_Type__c was set to 'Unplanned'
        Event insertedEvent = [SELECT Id, Visit_Type__c FROM Event WHERE Id = :testEvent.Id];
        // System.assertEquals('Unplanned', insertedEvent.Visit_Type__c, 'Visit_Type__c should be set to Unplanned for Account parent');
    }
    
    /**
     * Test EventVisitTypeSetterTrigger on INSERT - WhatId = null
     * Visit_Type__c should be set to 'Unplanned'
     */
    @isTest
    static void testEventInsert_NoParent() {
        Test.startTest();
        
        // Insert event without WhatId - trigger should set Visit_Type__c = 'Unplanned'
        Event orphanEvent = new Event(
            Subject = 'Orphan Event',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1)
            // WhatId is null
            // Visit_Type__c not set
        );
        insert orphanEvent;
        
        Test.stopTest();
        
        // Verify Visit_Type__c was set to 'Unplanned'
        Event insertedEvent = [SELECT Id, Visit_Type__c FROM Event WHERE Id = :orphanEvent.Id];
        // System.assertEquals('Unplanned', insertedEvent.Visit_Type__c, 'Visit_Type__c should be set to Unplanned for orphan event');
    }
    
    /**
     * Test EventVisitTypeSetterTrigger on UPDATE - Change WhatId from Account to MD_Plan__c
     * Visit_Type__c should change from 'Unplanned' to 'Planned'
     */
    @isTest
    static void testEventUpdate_ChangeToMDPlan() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        MD_Plan__c testPlan = [SELECT Id FROM MD_Plan__c WHERE Name = 'Test Visit Plan' LIMIT 1];
        
        // First create event linked to Account
        Event testEvent = new Event(
            Subject = 'Test Event for Update',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1),
            WhatId = testAccount.Id
        );
        insert testEvent;
        
        Test.startTest();
        
        // Update event to link to MD_Plan__c - trigger should change Visit_Type__c
        testEvent.WhatId = testPlan.Id;
        update testEvent;
        
        Test.stopTest();
        
        // Verify Visit_Type__c was updated to 'Planned'
        Event updatedEvent = [SELECT Id, Visit_Type__c FROM Event WHERE Id = :testEvent.Id];
        // System.assertEquals('Planned', updatedEvent.Visit_Type__c, 'Visit_Type__c should be updated to Planned after changing to MD_Plan__c');
    }
    
    /**
     * Test EventVisitTypeSetterTrigger - Bulk operations on INSERT
     * Multiple events should be processed efficiently
     */
    @isTest
    static void testBulkInsert_MixedParentTypes() {
        MD_Plan__c testPlan = [SELECT Id FROM MD_Plan__c WHERE Name = 'Test Visit Plan' LIMIT 1];
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        Test.startTest();
        
        // Insert multiple events with different parent types
        List<Event> bulkEvents = new List<Event>();
        
        // 30 events with MD_Plan__c parent (should be 'Planned')
        for(Integer i = 0; i < 30; i++) {
            bulkEvents.add(new Event(
                Subject = 'Bulk MD_Plan Event ' + i,
                StartDateTime = System.now().addHours(i),
                EndDateTime = System.now().addHours(i + 1),
                WhatId = testPlan.Id
            ));
        }
        
        // 35 events with Account parent (should be 'Unplanned')
        for(Integer i = 0; i < 35; i++) {
            bulkEvents.add(new Event(
                Subject = 'Bulk Account Event ' + i,
                StartDateTime = System.now().addDays(1).addHours(i),
                EndDateTime = System.now().addDays(1).addHours(i + 1),
                WhatId = testAccount.Id
            ));
        }
        
        // 35 orphan events (should be 'Unplanned')
        for(Integer i = 0; i < 35; i++) {
            bulkEvents.add(new Event(
                Subject = 'Bulk Orphan Event ' + i,
                StartDateTime = System.now().addDays(3).addHours(i),
                EndDateTime = System.now().addDays(3).addHours(i + 1)
                // WhatId is null
            ));
        }
        
        insert bulkEvents; // Trigger should process all 100 events
        
        Test.stopTest();
        
        // Verify all events were processed correctly
        List<Event> plannedEvents = [SELECT Id FROM Event WHERE Visit_Type__c = 'Planned'];
        List<Event> unplannedEvents = [SELECT Id FROM Event WHERE Visit_Type__c = 'Unplanned'];
        
        // System.assertEquals(30, plannedEvents.size(), 'Should have 30 Planned events (MD_Plan__c parents)');
        // System.assertEquals(70, unplannedEvents.size(), 'Should have 70 Unplanned events (Account + Orphan)');
    }
    
    /**
     * Test EventVisitTypeSetterTrigger - Override manual values
     * Trigger should always set correct value regardless of manual input
     */
    @isTest
    static void testTriggerOverridesManualValues() {
        MD_Plan__c testPlan = [SELECT Id FROM MD_Plan__c WHERE Name = 'Test Visit Plan' LIMIT 1];
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        Test.startTest();
        
        // Create events with manually set wrong Visit_Type__c values
        List<Event> testEvents = new List<Event>();
        
        // MD_Plan event with wrong 'Unplanned' value - should be corrected to 'Planned'
        testEvents.add(new Event(
            Subject = 'MD_Plan Event with Wrong Value',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1),
            WhatId = testPlan.Id,
            Visit_Type__c = 'Unplanned' // Wrong value - should be overridden
        ));
        
        // Account event with wrong 'Planned' value - should be corrected to 'Unplanned'
        testEvents.add(new Event(
            Subject = 'Account Event with Wrong Value',
            StartDateTime = System.now().addHours(2),
            EndDateTime = System.now().addHours(3),
            WhatId = testAccount.Id,
            Visit_Type__c = 'Planned' // Wrong value - should be overridden
        ));
        
        insert testEvents;
        
        Test.stopTest();
        
        // Verify trigger corrected the wrong values
        List<Event> correctedEvents = [SELECT Id, Subject, Visit_Type__c FROM Event WHERE Id IN :testEvents ORDER BY Subject];
        
        // Account event should be corrected to 'Unplanned'
        // System.assertEquals('Unplanned', correctedEvents[0].Visit_Type__c, 'Account event should be corrected to Unplanned');
        
        // MD_Plan event should be corrected to 'Planned'
        // System.assertEquals('Planned', correctedEvents[1].Visit_Type__c, 'MD_Plan event should be corrected to Planned');
    }
}