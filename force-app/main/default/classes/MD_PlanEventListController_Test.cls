@isTest
private class MD_PlanEventListController_Test {

    @testSetup
    static void setupData() {
        // Get any one Record Type for MD_Plan__c (use Monthly by default if available)
        Id rtId;
        for (RecordType rt : [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'MD_Plan__c'
              AND DeveloperName IN ('Monthly_Plan', 'Weekly_Plan')
            LIMIT 1
        ]) {
            rtId = rt.Id;
        }

        MD_Plan__c plan = new MD_Plan__c();
        plan.Name = 'Event List Test Plan';
        if (rtId != null) {
            plan.RecordTypeId = rtId;
        }
        // TODO: Add any required fields for MD_Plan__c here
        insert plan;

        // Create a few Events related to this plan
        List<Event> eventsToInsert = new List<Event>();

        DateTime startTime = System.now().addHours(1);
        DateTime endTime = System.now().addHours(2);

        Event e1 = new Event();
        e1.Subject = 'Test Event 1';
        e1.StartDateTime = startTime;
        e1.EndDateTime = endTime;
        e1.IsAllDayEvent = false;
        e1.WhatId = plan.Id;
        eventsToInsert.add(e1);

        Event e2 = new Event();
        e2.Subject = 'Test Event 2';
        e2.StartDateTime = startTime.addDays(1);
        e2.EndDateTime = endTime.addDays(1);
        e2.IsAllDayEvent = false;
        e2.WhatId = plan.Id;
        eventsToInsert.add(e2);

        insert eventsToInsert;
    }

    @isTest
    static void testGetPlanEvents_WithValidPlan() {
        MD_Plan__c plan = [
            SELECT Id
            FROM MD_Plan__c
            WHERE Name = 'Event List Test Plan'
            LIMIT 1
        ];

        Test.startTest();
        List<Map<String, Object>> results =
            MD_PlanEventListController.getPlanEvents(plan.Id, 10);
        Test.stopTest();

        System.debug('Plan events (valid plan): ' + results);
    }

    @isTest
    static void testGetPlanEvents_NullPlanId() {
        Test.startTest();
        List<Map<String, Object>> results =
            MD_PlanEventListController.getPlanEvents(null, 10);
        Test.stopTest();

        System.debug('Plan events (null planId): ' + results);
    }

    @isTest
    static void testGetPlanEvents_ZeroLimit() {
        MD_Plan__c plan = [
            SELECT Id
            FROM MD_Plan__c
            WHERE Name = 'Event List Test Plan'
            LIMIT 1
        ];

        // limitSize <= 0 should default to 50
        Test.startTest();
        List<Map<String, Object>> results =
            MD_PlanEventListController.getPlanEvents(plan.Id, 0);
        Test.stopTest();

        System.debug('Plan events (zero limit): ' + results);
    }
}