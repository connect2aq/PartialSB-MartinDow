public with sharing class MD_PlanEventListController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getPlanEvents(Id planId, Integer limitSize) {
        if (planId == null) {
            return new List<Map<String, Object>>();
        }

        if (limitSize == null || limitSize <= 0) {
            limitSize = 50;
        }

        List<Event> events = [
            SELECT
                Id,
                Subject,
            	StartDateTime,
    			EndDateTime,
                Visit_Type__c,
                Account__c, Account__r.Name,
                Contact_Person__c, Contact_Person__r.Name,
                Opportunity__c, Opportunity__r.Name,
                Case__c, Case__r.Name
            FROM Event
            WHERE WhatId = :planId
            ORDER BY StartDateTime DESC NULLS LAST
            LIMIT :limitSize
        ];

        List<Map<String, Object>> rows = new List<Map<String, Object>>();

        for (Event e : events) {
            Map<String, Object> row = new Map<String, Object>();

            row.put('Id', e.Id);

            // Clickable Subject (View)
            row.put('eventUrl', '/lightning/r/Event/' + e.Id + '/view');
            row.put('eventSubject', e.Subject);

            // Customer
            row.put('accountUrl', e.Account__c == null ? null : '/lightning/r/Account/' + e.Account__c + '/view');
            row.put('accountName', e.Account__r == null ? null : e.Account__r.Name);

            // Contact Person (assuming lookup to Contact)
            row.put('contactUrl', e.Contact_Person__c == null ? null : '/lightning/r/Contact/' + e.Contact_Person__c + '/view');
            row.put('contactName', e.Contact_Person__r == null ? null : e.Contact_Person__r.Name);
            
            // DateTime
            row.put('startDateTime', e.StartDateTime);
			row.put('endDateTime', e.EndDateTime);


            // Visit Type
            row.put('visitType', e.Visit_Type__c);

            // Opportunity
            row.put('oppUrl', e.Opportunity__c == null ? null : '/lightning/r/Opportunity/' + e.Opportunity__c + '/view');
            row.put('oppName', e.Opportunity__r == null ? null : e.Opportunity__r.Name);

            // Service Request (MD_Case__c) - using Name
            row.put('caseUrl', e.Case__c == null ? null : '/lightning/r/MD_Case__c/' + e.Case__c + '/view');
            row.put('caseName', e.Case__r == null ? null : e.Case__r.Name);

            rows.add(row);
        }

        return rows;
    }
}