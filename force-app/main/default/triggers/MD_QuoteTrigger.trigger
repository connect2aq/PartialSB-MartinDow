trigger MD_QuoteTrigger on MD_Quote__c (after update) {
    for (MD_Quote__c quote : Trigger.new) {
        MD_Quote__c oldQuote = Trigger.oldMap.get(quote.Id);
        
        // When IsSyncing__c changed from false to true
        if (!oldQuote.IsSyncing__c && quote.IsSyncing__c) {
            // Publish platform event with the opportunity linked to this quote
            QuoteSyncPublisher.publishSyncEvent(quote.MD_Opportunity__c);
        }
    }
}