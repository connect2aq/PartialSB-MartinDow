public with sharing class QuoteSyncAuraController {
    @AuraEnabled(cacheable=true)
    public static Id getOpportunityId(Id quoteId) {
        MD_Quote__c quote = [SELECT MD_Opportunity__c FROM MD_Quote__c WHERE Id = :quoteId LIMIT 1];
        return quote.MD_Opportunity__c;
    }
}