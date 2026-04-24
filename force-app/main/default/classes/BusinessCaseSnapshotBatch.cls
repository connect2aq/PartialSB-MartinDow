public class BusinessCaseSnapshotBatch implements Database.Batchable<SObject>, Database.Stateful
{
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Return all active business cases to process
        return Database.getQueryLocator([
             SELECT
                Id,
                Name,
                Status__c,
                Account__c,
                Account__r.Province__c,
                Account__r.City__c,
                Account__r.AddressLine_1__c,
                Account__r.Addess_Line_2__c,
                Account__r.Postal_Code__c,
                Account__r.Country_Code__c,
                Customer_Number__c,
                Customer_Name__c,
                Supplier_Name__c,
                Technology__c,
                Region__c,
                SAP_Material_Number__c,
                Machine_Type__c,
                Quantity__c,
                Monthly_Reagent_Commitment__c,
                Unit_Cost__c,
                Margin_Percent__c,
                Agreement_Date__c,
                Asset_Number__c,
                Asset_Number__r.Status__c,
                Machine_Installation__r.Ship_To_Account__c,
                Machine_Installation__r.Ship_To_Account__r.SAP_Customer_Number__c,
                Machine_Installation__r.Ship_To_Account__r.Name,
                Machine_Installation__r.Ship_To_Account__r.Province__c,
                Machine_Installation__r.Ship_To_Account__r.City__c,
                Machine_Installation__r.Ship_To_Account__r.AddressLine_1__c,
                Machine_Installation__r.Ship_To_Account__r.Addess_Line_2__c,
                Machine_Installation__r.Ship_To_Account__r.Postal_Code__c,
                Machine_Installation__r.Ship_To_Account__r.Country_Code__c,
                Machine_Installation__r.Diagnostic_Machine__r.Vendor__c,
                Machine_Installation__r.Diagnostic_Machine__r.Technology__c,
                Ship_To_Customer_Number__c,
                Ship_To_Customer_Name__c,
                Machine_Installation__r.SAP_Account_No_Bill_To__c,
                Machine_Installation__r.bill_to_account__r.Name,
                Machine_Installation__r.Material_Number__c,
                Machine_Installation__r.Status__c,
                Machine_Installation__r.bill_to_account__r.Province__c,
                Machine_Installation__r.bill_to_account__r.City__c,
                Machine_Installation__r.bill_to_account__r.AddressLine_1__c,
                Machine_Installation__r.bill_to_account__r.Postal_Code__c,
                Machine_Installation__r.bill_to_account__r.Country_Code__c
                FROM Business_Case__c
                 where 
                 (Status__c like '%Active%' or Status__c like '%Revised%' or Status__c like '%New%') and 
                 Is_Master__c = false and Master_Business_Case__c = null 
                 //and Customer_Number__c = '3020000477'
                ORDER BY Name
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Business_Case__c> scope) {
        System.debug('📦 Executing batch of size: ' + scope.size());
        
        // Call your existing logic for processing one batch
        Integer snapshotsCreated = BusinessCaseSnapshotService.processBatchSnapshots(scope);
        System.debug(' Batch created ' + snapshotsCreated + ' snapshots');
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(' All batches complete.');
    }
}