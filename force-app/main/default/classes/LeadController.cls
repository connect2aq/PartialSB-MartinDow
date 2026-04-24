public without sharing class LeadController {
    @AuraEnabled(cacheable=true)
    public static List<Lead> getLeads(String searchKey) {
        String key = String.isBlank(searchKey) ? '%' : '%' + searchKey + '%';
        return [
            SELECT Id, Name, Company, Status
            FROM Lead
            WHERE Name LIKE :key OR Company LIKE :key
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Lead getLeadById(Id leadId) {
        return [SELECT Id, Name, Company, Status FROM Lead WHERE Id = :leadId];
    }

    @AuraEnabled
    public static Lead createLead(String name, String company, String status) {
        Lead l = new Lead(LastName = name, Company = company, Status = status);
        insert l;
        return l;
    }
}