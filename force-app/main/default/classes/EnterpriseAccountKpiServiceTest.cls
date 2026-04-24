@isTest
public class EnterpriseAccountKpiServiceTest {
    @testSetup
    static void setup() {
        // Create Enterprise Account with record type
        Id entAccRtId = [
            SELECT Id
            FROM RecordType
            WHERE
                SObjectType = 'Account'
                AND DeveloperName = 'Enterprise_Account'
            LIMIT 1
        ]
        .Id;
        Account entAcc = new Account(
            Name = 'Enterprise Account',
            RecordTypeId = entAccRtId
        );
        insert entAcc;

        // Create Functional Account under Enterprise
        Account funcAcc = new Account(
            Name = 'Functional Account',
            Enterprise_Account__c = entAcc.Id,
            SAP_Customer_Number__c = '123',
            AddressLine_1__c = 'Addr',
            City__c = 'City'
        );
        insert funcAcc;

        // Create Asset for Diagnostic KPIs
        MD_Asset__c asset = new MD_Asset__c(
            AccountId__c = funcAcc.Id,
            Status__c = 'RR'
        );
        insert asset;

        // Create Opportunity (Closed Won, YTD)
        MD_Opportunity__c opp = new MD_Opportunity__c(
            Account_Name__c = funcAcc.Id,
            Stage__c = 'Close_Opportunity',
            Close_Won_Or_Close_Lost__c = 'Close Won',
            Close_Date__c = Date.today(),
            Amount__c = 100
        );
        insert opp;

        // Create Invoice linked to Opportunity
        Invoice__c inv = new Invoice__c(BusinessOpportunity__c = opp.Id);
        insert inv;

        // Create Invoice Line Item for Sales KPIs
        Invoice_Line_Item__c ili = new Invoice_Line_Item__c(
            Invoice__c = inv.Id,
            Invoice_Value__c = 100
        );
        insert ili;

        // Create Event for Visits
        Event ev = new Event(
            Account__c = funcAcc.Id,
            Status__c = 'Completed',
            StartDateTime = System.now(),
            DurationInMinutes = 30
        );
        insert ev;

        // Create Open Opportunity
        MD_Opportunity__c openOpp = new MD_Opportunity__c(
            Account_Name__c = funcAcc.Id,
            // Stage__c = 'Discovery',
            Amount__c = 200,
            Close_Date__c = Date.today().addDays(30)
        );
        insert openOpp;

        // Create Complaint
        MD_Case__c mcase = new MD_Case__c(
            AccountId__c = funcAcc.Id,
            Status__c = 'New'
        );
        insert mcase;
    }

    @isTest
    static void testGetEnterpriseAccountKpiData() {
        Account entAcc = [
            SELECT Id
            FROM Account
            WHERE Name = 'Enterprise Account'
            LIMIT 1
        ];
        Test.startTest();
        EnterpriseAccountKpiDTO dto = EnterpriseAccountKpiService.getEnterpriseAccountKpiData(
            entAcc.Id
        );
        Test.stopTest();
        System.assertNotEquals(null, dto);
        System.assertEquals(entAcc.Id, dto.accountId);
        System.assert(dto.totalSalesYTD >= 0);
        System.assert(dto.openOpportunityCount >= 0);
        System.assert(dto.openComplaints >= 0);
    }

    // @isTest
    // static void testNullEnterpriseAccountId() {
    //   Test.startTest();
    //   Boolean exceptionThrown = false;
    //   try {
    //     EnterpriseAccountKpiService.getEnterpriseAccountKpiData(null);
    //   } catch (AuraHandledException e) {
    //     exceptionThrown = true;
    //     System.assert(
    //       e.getMessage().contains('Enterprise Account Id cannot be null')
    //     );
    //   }
    //   Test.stopTest();
    //   System.assert(exceptionThrown, 'Should have thrown AuraHandledException');
    // }
}