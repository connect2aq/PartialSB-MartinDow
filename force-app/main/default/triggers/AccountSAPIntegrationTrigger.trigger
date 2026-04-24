trigger AccountSAPIntegrationTrigger on Account (after update) {
    List<Id> accountsForSAP = new List<Id>();
    
    for (Account newAccount : Trigger.new) {
        Account oldAccount = Trigger.oldMap.get(newAccount.Id);
        
        // Check condition: status changed TO 'Ready for SAP Push'
        if (oldAccount.Account_Status__c != 'Ready for SAP Push' && 
            newAccount.Account_Status__c == 'Ready for SAP Push') {
            
            accountsForSAP.add(newAccount.Id);
            System.debug('Account added for SAP integration: ' + newAccount.Name);
        }
    }
    
    // Call future method if any accounts need processing
    if (!accountsForSAP.isEmpty()) {
        SAPIntegrationService.processAccountsForSAP(accountsForSAP);
        System.debug('SAP integration triggered for ' + accountsForSAP.size() + ' accounts');
    }
}