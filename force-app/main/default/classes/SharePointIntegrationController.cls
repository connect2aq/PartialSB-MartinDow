public with sharing class SharePointIntegrationController {

    @AuraEnabled
    public static void updateAccountStatus(Id accountId, String status) {
        try {
            Account acc = [
                SELECT Id, Account_Status__c
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];
            acc.Account_Status__c = status;
            update acc;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Failed to update account status: ' + e.getMessage()
            );
        }
    }

    @AuraEnabled
    public static List<Contact> getAccountContacts(Id accountId) {
        // Minimal addition: include Primary_Contact__c for LWC validation
        return [
            SELECT Id, Email, Phone, MobilePhone, Primary_Contact__c
            FROM Contact
            WHERE AccountId = :accountId
        ];
    }

    @AuraEnabled
    public static List<MD_Sales_Area__c> getAccountSalesAreas(Id accountId) {
        return [
            SELECT
                Id,
                Sales_Org__c,
                Distribution_Channel__c,
                Division__c,
                Sales_District__c,
                Delivering_Plant__c,
                Customer_Group__c,
                Sales_Office__c,
                Sales_Group__c,
                Currency__c,
                Price_Group__c,
                Pricing_Procedure_Indicator__c,
                Incoterms__c,
                Incoterms_Description__c,
                Payment_Terms__c,
                Customer_Account_Assignment_Group__c,
                Output_Tax_Category_MWST_Code__c,
                Output_Tax_Category_ZMST_Code__c,
                Output_Tax_Category_ZMWS_Code__c,
                Output_Tax_Category_ZPK2_Code__c
            FROM MD_Sales_Area__c
            WHERE Parent_Account__c = :accountId
        ];
    }

    @AuraEnabled
    public static List<MD_Tax_Number__c> getAccountTaxNumbers(Id accountId) {
        return [
            SELECT Id, Tax_Category_Code__c, Category_Value__c
            FROM MD_Tax_Number__c
            WHERE Account__c = :accountId
        ];
    }

    @AuraEnabled
    public static List<Credit_Profile__c> getAccountCreditProfiles(Id accountId) {
        return [
            SELECT Id, Credit_Segment__c, Credit_Limit__c
            FROM Credit_Profile__c
            WHERE Account__c = :accountId
        ];
    }

    // Additional SAP-specific validation fields
    @AuraEnabled
    public static Account getAccountForSAPValidation(Id accountId) {
        try {
            return [
                SELECT
                    Id,
                    Account_Status__c,
                    Name,
                    City__c,
                    Province__c,
                    Postal_Code__c,
                    AddressLine_1__c,
                    Country_Code__c,
                    Company_Code__c,
                    Reconciliation_Account__c,
                    Payment_Terms_FI_Role__c,
                    Business_Vertical__c
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException(
                'Failed to get account: ' + e.getMessage()
            );
        }
    }
}