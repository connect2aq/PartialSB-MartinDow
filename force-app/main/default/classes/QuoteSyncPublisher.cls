public class QuoteSyncPublisher {
    public static void publishSyncEvent(Id opportunityId) {
        QuoteSyncEvent__e event = new QuoteSyncEvent__e(
            Opportunity_Id__c = opportunityId, // Use the parameter instead of hard-coded value
            Message__c = 'Previous synced quote has been unsynced. This quote has been synced.'
        );
        EventBus.publish(event);
    }
}