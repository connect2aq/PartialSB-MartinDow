trigger EventValidationTrigger on Event (before insert, before update) {
    
    // Set to store MD_plan__c Ids for bulk queries
    Set<Id> visitPlanningIds = new Set<Id>();
    
    // Collect all related Visit Planning Ids
    for (Event evt : Trigger.new) {
        if (evt.WhatId != null && String.valueOf(evt.WhatId).startsWith(MD_plan__c.sObjectType.getDescribe().getKeyPrefix())) {
            visitPlanningIds.add(evt.WhatId);
        }
    }
    
    // If no Visit Planning records found, exit early
    if (visitPlanningIds.isEmpty()) {
        return;
    }
    
    // Query Visit Planning records with their date ranges
    Map<Id, MD_plan__c> visitPlanningMap = new Map<Id, MD_plan__c>(
        [SELECT Id, Plan_Start_Date__c, End_Date_Calculated__c 
         FROM MD_plan__c 
         WHERE Id IN :visitPlanningIds]
    );
    
    // Validate each Event
    for (Event evt : Trigger.new) {
        // Check if this event is related to Visit Planning
        if (evt.WhatId != null && visitPlanningMap.containsKey(evt.WhatId)) {
            
            MD_plan__c visitPlan = visitPlanningMap.get(evt.WhatId);
            
            // Skip validation if Visit Planning dates are not set
            if (visitPlan.Plan_Start_Date__c == null || visitPlan.End_Date_Calculated__c == null) {
                continue;
            }
            
            // Convert Event DateTime to Date for comparison
            Date eventStartDate = evt.StartDateTime != null ? evt.StartDateTime.date() : null;
            Date eventEndDate = evt.EndDateTime != null ? evt.EndDateTime.date() : null;
            
            // Validate Event Start Date
            if (eventStartDate != null) {
                if (eventStartDate < visitPlan.Plan_Start_Date__c || eventStartDate > visitPlan.End_Date_Calculated__c) {
                    evt.StartDateTime.addError('Event Start Date must be within Visit Planning date range (' + 
                                            visitPlan.Plan_Start_Date__c.format() + ' to ' + 
                                            visitPlan.End_Date_Calculated__c.format() + ')');
                }
            }
            
            // Validate Event End Date
            if (eventEndDate != null) {
                if (eventEndDate < visitPlan.Plan_Start_Date__c || eventEndDate > visitPlan.End_Date_Calculated__c) {
                    evt.EndDateTime.addError('Event End Date must be within Visit Planning date range (' + 
                                           visitPlan.Plan_Start_Date__c.format() + ' to ' + 
                                           visitPlan.End_Date_Calculated__c.format() + ')');
                }
            }
            
            // Additional validation: Event End Date should not be before Start Date
            if (eventStartDate != null && eventEndDate != null && eventEndDate < eventStartDate) {
                evt.EndDateTime.addError('Event End Date cannot be before Start Date');
            }
        }
    }
}