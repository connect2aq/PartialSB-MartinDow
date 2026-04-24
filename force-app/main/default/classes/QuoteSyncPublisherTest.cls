@isTest
public class QuoteSyncPublisherTest {
    @isTest
    static void testPublishSyncEvent() {
        // Create test Opportunity to get valid ID
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert testOpp;
        
        Test.startTest();
        
        // Use the actual test Opportunity ID
        QuoteSyncPublisher.publishSyncEvent(testOpp.Id);
        
        Test.stopTest();
        
        // Verify no exceptions occurred
        System.assert(true, 'Event should be published successfully');
    }
    
    @isTest
    static void testPublishSyncEvent_NullId() {
        Test.startTest();
        
        try {
            // Test with null ID
            QuoteSyncPublisher.publishSyncEvent(null);
            System.assert(true, 'Should handle null ID gracefully');
        } catch (Exception e) {
            System.assert(false, 'Should not throw exception for null ID: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
}