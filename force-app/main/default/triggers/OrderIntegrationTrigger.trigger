trigger OrderIntegrationTrigger on MD_Order__c (after update) {
    List<Id> ordersForIntegration = new List<Id>();
    
    for (MD_Order__c newOrder : Trigger.new) {
        MD_Order__c oldOrder = Trigger.oldMap.get(newOrder.Id);
        
        // Check condition: status changed TO 'Approved'
        if (oldOrder.Status__c != 'Approved' && 
            newOrder.Status__c == 'Approved') {
            
            ordersForIntegration.add(newOrder.Id);
            System.debug('Order added for integration: ' + newOrder.Id);
        }
    }
    
    // Call future method if any orders need processing
    if (!ordersForIntegration.isEmpty()) {
        OrderIntegrationService.processOrdersForIntegration(ordersForIntegration);
        System.debug('Order integration triggered for ' + ordersForIntegration.size() + ' orders');
    }
}