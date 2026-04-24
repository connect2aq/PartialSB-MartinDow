public with sharing class CustomerDemandController {
    
    public class Response {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
    }
    
    @AuraEnabled
    public static Response pushToSAP(Id demandId) {
        Response res = new Response();
        
        try {
            if (demandId == null) {
                res.success = false;
                res.message = 'Invalid Customer Demand ID';
                return res;
            }
            
            // Get initial External Quote ID
            Customer_Demand__c demandBefore = [SELECT External_Quote_ID__c FROM Customer_Demand__c WHERE Id = :demandId LIMIT 1];
            String initialQuoteId = demandBefore.External_Quote_ID__c;
            
            //CustomerDemandIntegrationService.createCustomerDemandInSystem(demandId);
            
            // Check if External Quote ID was updated
            Customer_Demand__c demandAfter = [SELECT External_Quote_ID__c FROM Customer_Demand__c WHERE Id = :demandId LIMIT 1];
            
            if (String.isNotBlank(demandAfter.External_Quote_ID__c) && demandAfter.External_Quote_ID__c != initialQuoteId) {
                res.success = true;
                res.message = 'Successfully pushed to SAP. Quote ID: ' + demandAfter.External_Quote_ID__c;
            } else {
                res.success = false;
                res.message = 'Failed to push to SAP. Please check debug logs for details.';
            }
            
        } catch (Exception ex) {
            res.success = false;
            res.message = 'Error: ' + ex.getMessage();
        }
        
        return res;
    }
}