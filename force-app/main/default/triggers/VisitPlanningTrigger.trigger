trigger VisitPlanningTrigger on MD_Plan__c (after insert, after update) {
    Set<Id> vpIds = new Set<Id>();

    if (Trigger.isInsert) {
        vpIds.addAll(Trigger.newMap.keySet());
    } else if (Trigger.isUpdate) {
        for (MD_Plan__c vp : Trigger.new) {
           MD_Plan__c oldVp = Trigger.oldMap.get(vp.Id);
            if (vp.Approval_Status__c != oldVp.Approval_Status__c) {
                vpIds.add(vp.Id);
            }
        }
    }

    if (!vpIds.isEmpty()) {
        VisitPlanningHandler.syncEventStatuses(Trigger.newMap, vpIds);
    }
}