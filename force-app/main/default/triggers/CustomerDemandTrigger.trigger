trigger CustomerDemandTrigger on Customer_Demand__c (after insert) {
    // Collect only those records that do not already have an External_Quote_ID__c
    List<Id> toProcess = new List<Id>();
    for (Customer_Demand__c cd : Trigger.new) {
        if (String.isBlank(cd.External_Quote_ID__c)) {
            toProcess.add(cd.Id);
        }
    }

    if (!toProcess.isEmpty()) {
        // Async future callout to avoid callout-from-trigger limitation
        CustomerDemandIntegrationService.processDemandsForIntegration(toProcess);
    }
}