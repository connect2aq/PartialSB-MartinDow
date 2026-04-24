trigger EventVisitTypeSetterTrigger on Event (before insert, before update) {
    
    for (Event evt : Trigger.new) {
        // Check if WhatId is populated and points to MD_Plan__c
        if (evt.WhatId != null) {
            // Get the sObject type from the ID
            String sObjectType = evt.WhatId.getSObjectType().getDescribe().getName();
            
            if (sObjectType == 'MD_Plan__c') {
                // WhatId is MD_Plan__c, so set as Planned
                evt.Visit_Type__c = 'Planned';
            } else {
                // WhatId is some other object, set as Unplanned
                evt.Visit_Type__c = 'Unplanned';
            }
        } else {
            // WhatId is null/empty, set as Unplanned
            evt.Visit_Type__c = 'Unplanned';
        }
    }
}