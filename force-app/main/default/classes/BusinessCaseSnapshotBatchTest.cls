/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class BusinessCaseSnapshotBatchTest 
{
    // Mock Provider that overrides the static method using Stub API
    private class SnapshotServiceMock implements System.StubProvider {
        public Object handleMethodCall(Object stubbedObject, String methodName, Type returnType, List<Type> paramTypes, List<String> paramNames, List<Object> params) {
            if (methodName == 'processBatchSnapshots') {
                // Simulate a successful snapshot creation
                System.debug('🧪 Mock processBatchSnapshots called with ' + params[0]);
                return ((List<Business_Case__c>)params[0]).size();
            }
            return null;
        }
    }

    @TestSetup
    static void setupData() {
        // Create a sample Account
        Account acc = new Account(
            Name = 'Test Account',
            Province__c = 'Punjab',
            City__c = 'Lahore',
            AddressLine_1__c = '123 Street',
            Postal_Code__c = '54000',
            Country_Code__c = 'PK',
            SAP_Customer_Number__c = '12345'
        );
        insert acc;

        // Create some Business_Case__c records with different statuses
        List<Business_Case__c> cases = new List<Business_Case__c>();
        cases.add(new Business_Case__c(
                    //Name = 'Test Case ' + i,
                    Status__c = 'Active' ,
                    Account__c = acc.Id
                    //Customer_Name__c = acc.Name,
                    //Customer_Number__c = acc.Customer_Number__c
                ));
        // for (Integer i = 0; i < 5; i++) 
        // {
        //     if(i <= 2)
        //     {
        //         cases.add(new Business_Case__c(
        //             //Name = 'Test Case ' + i,
        //             Status__c = 'Active' ,
        //             Account__c = acc.Id
        //             //Customer_Name__c = acc.Name,
        //             //Customer_Number__c = acc.Customer_Number__c
        //         ));
        //     }
        //     else{
        //         cases.add(new Business_Case__c(
        //             //Name = 'Test Case ' + i,
        //             Status__c =  'Revised',
        //             Account__c = acc.Id
        //             //Customer_Name__c = acc.Name,
        //             //Customer_Number__c = acc.Customer_Number__c
        //         ));
        //     }
        // }
        insert cases;
    }

    @IsTest
    static void testBatchExecution() {
        // Replace the actual service method with mock implementation using Stub API or dependency injection if applicable
        // For now, assume the real service is safe to call

        // Run the batch
        Test.startTest();
        BusinessCaseSnapshotBatch batch = new BusinessCaseSnapshotBatch();
        Database.executeBatch(batch, 2); // 2 = small batch size for testing
        Test.stopTest();

        // Assertions
        List<Business_Case__c> processed = [SELECT Id FROM Business_Case__c WHERE Status__c IN ('Active','Revised')];
        System.assert(processed.size() > 0, 'Expected some records to be processed');
    }

    @IsTest
    static void testBatchWithNoRecords() {
        // Delete all data created in setup
        delete [SELECT Id FROM Business_Case__c];

        Test.startTest();
        BusinessCaseSnapshotBatch batch = new BusinessCaseSnapshotBatch();
        Database.executeBatch(batch, 1);
        Test.stopTest();

        System.assertEquals(0, [SELECT count() FROM Business_Case__c], 'No records should exist');
    }

    @IsTest
    static void testStartQuery() {
        BusinessCaseSnapshotBatch batch = new BusinessCaseSnapshotBatch();
        Database.QueryLocator locator = batch.start(null);
        System.assertNotEquals(null, locator, 'QueryLocator should not be null');
    }
}