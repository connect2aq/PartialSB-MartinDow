// File 2: EventTriggerHandler.cls
public class EventTriggerHandler {
    
    public static void handleBeforeUpdate(List<Event> newEvents, Map<Id, Event> oldEventsMap) {
        validateAccountFieldForApprovedMDPlans(newEvents, oldEventsMap);
    }
    
    private static void validateAccountFieldForApprovedMDPlans(List<Event> newEvents, Map<Id, Event> oldEventsMap) {
        
        Set<Id> mdPlanIds = new Set<Id>();
        
        // WhatId se linked MD_Plan__c IDs collect karte hain
        for (Event evt : newEvents) {
            if (evt.WhatId != null && isValidMDPlanId(evt.WhatId)) {
                mdPlanIds.add(evt.WhatId);
            }
        }
        
        if (mdPlanIds.isEmpty()) {
            return;
        }
        
        // Approved MD_Plan records query karte hain
        Map<Id, MD_Plan__c> approvedMDPlansMap = new Map<Id, MD_Plan__c>(
            [SELECT Id, Approval_Status__c 
             FROM MD_Plan__c 
             WHERE Id IN :mdPlanIds 
             AND Approval_Status__c = 'Approved']
        );
        
        // Validation logic
        for (Event evt : newEvents) {
            Event oldEvt = oldEventsMap.get(evt.Id);
            
            // Check karte hain ke Event approved MD_Plan se linked hai
            if (evt.WhatId != null && approvedMDPlansMap.containsKey(evt.WhatId)) {
                
                // Account__c field change validation
                if (evt.Account__c != oldEvt.Account__c) {
                    evt.Account__c.addError('Account cannot be changed when Event is linked to an Approved MD Plan.');
                }
            }
        }
    }
    
    // Helper method to check if ID belongs to MD_Plan__c object
    private static Boolean isValidMDPlanId(Id recordId) {
        if (recordId == null) {
            return false;
        }
        
        String sobjectType = recordId.getSObjectType().getDescribe().getName();
        return sobjectType == 'MD_Plan__c';
    }
}