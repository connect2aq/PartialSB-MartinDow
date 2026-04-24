public with sharing class VisitPlanningHandler {
    // 👉 Event Status field ka API name
    public static final String EVT_STATUS_FIELD = 'Status__c';
    // Normalize helper (trim + lowercase)
    private static String norm(String s) { return (s == null) ? null : s.trim().toLowerCase(); }
    // Parent → Child mapping (normalized keys)
    private static final Map<String, String> STATUS_MAP_NORM = new Map<String, String>{
        'pending'  => 'Pending Approval',
        'approved' => 'Planned (Approved)'
        // 'rejected' => 'Rejected' // add if needed and value exists on Event picklist
    };
    /**
     * Parent MD_Plan__c insert/update ke baad related Events ko sync karta hai.
     * (Yahan user-change detection nahi — parent update hamesha re-sync karega)
     */
    public static void syncEventStatuses(Map<Id, MD_Plan__c> vpNewMap, Set<Id> vpIds){
        if (vpIds == null || vpIds.isEmpty()) return;
        // Parent Id -> normalized status
        Map<Id, String> parentStatusNorm = new Map<Id, String>();
        for (Id vpId : vpIds) {
            MD_Plan__c vp = vpNewMap.get(vpId);
            parentStatusNorm.put(vpId, norm(vp != null ? vp.Approval_Status__c : null));
        }
        // Related events + current status
        List<Event> evts = [
            SELECT Id, WhatId, Status__c
            FROM Event
            WHERE WhatId IN :vpIds
        ];
        List<Event> toUpdate = new List<Event>();
        for (Event e : evts) {
            String target = STATUS_MAP_NORM.get(parentStatusNorm.get(e.WhatId));
            if (String.isBlank(target)) continue;
            // Avoid unnecessary DML
            if (e.Status__c != target) {
                e.Status__c = target; // or: e.put(EVT_STATUS_FIELD, target);
                toUpdate.add(e);
            }
        }
        if (!toUpdate.isEmpty()) {
            Database.update(toUpdate, false); // partial success
        }
    }
    /**
     * Event insert/update (before) par parent MD_Plan__c se status inherit karta hai.
     * UPDATED: Ab hamesha parent se sync karega, user ki manual changes preserve nahi karega.
     */
    public static void applyStatusFromParent(List<Event> newRecs){
        if (newRecs == null || newRecs.isEmpty()) return;
        
        // Collect parent ids
        Set<Id> parentIds = new Set<Id>();
        for (Event e : newRecs) if (e.WhatId != null) parentIds.add(e.WhatId);
        if (parentIds.isEmpty()) return;
        
        Map<Id, MD_Plan__c> vpById = new Map<Id, MD_Plan__c>([
            SELECT Id, Approval_Status__c
            FROM MD_Plan__c
            WHERE Id IN :parentIds
        ]);
        
        for (Event e : newRecs) {
            MD_Plan__c vp = vpById.get(e.WhatId);
            if (vp == null) continue;
            String target = STATUS_MAP_NORM.get(norm(vp.Approval_Status__c));
            if (String.isBlank(target)) continue;
            // Before-save context: directly set, no DML
            // Ab hamesha parent se override karega
            e.put(EVT_STATUS_FIELD, target);
        }
    }
}