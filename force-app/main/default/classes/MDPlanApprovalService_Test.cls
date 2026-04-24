@isTest
private class MDPlanApprovalService_Test {

    @testSetup
    static void setupData() {

        // 1) Get a role that is allowed as Initial Submitter
        //    (Must match a role name from the Initial Submitters list on the approval process)
        UserRole submitterRole = [
            SELECT Id, Name
            FROM UserRole
            WHERE Name = 'Sales Specialist BU2 North'
            LIMIT 1
        ];

        // 2) Get a standard profile for the test user
        Profile stdProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        // 3) Create a user with that role (allowed to submit for approval)
        User submitterUser = new User();
        submitterUser.FirstName         = 'MD';
        submitterUser.LastName          = 'Plan Approver';
        submitterUser.Alias             = 'mdappr';
        submitterUser.Email             = 'mdplan.approver@test.com';
        submitterUser.Username          = 'mdplan.approver@test.com';
        submitterUser.TimeZoneSidKey    = 'Asia/Karachi';
        submitterUser.LocaleSidKey      = 'en_US';
        submitterUser.EmailEncodingKey  = 'UTF-8';
        submitterUser.LanguageLocaleKey = 'en_US';
        submitterUser.ProfileId         = stdProfile.Id;
        submitterUser.UserRoleId        = submitterRole.Id;
        insert submitterUser;

        // 4) Get Record Types for MD_Plan__c (Monthly and Weekly)
        Map<String, Id> rtMap = new Map<String, Id>();
        for (RecordType rt : [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'MD_Plan__c'
              AND DeveloperName IN ('Monthly_Plan', 'Weekly_Plan')
        ]) {
            rtMap.put(rt.DeveloperName, rt.Id);
        }

        // 5) Create Monthly and Weekly plans (owned by submitter user)
        System.runAs(submitterUser) {

            // Monthly Plan - for Approve test
            MD_Plan__c monthlyPlan = new MD_Plan__c();
            monthlyPlan.RecordTypeId = rtMap.get('Monthly_Plan');
            monthlyPlan.Name         = 'UT Monthly Plan - Approve';
            insert monthlyPlan;

            // Weekly Plan - for Reject test
            MD_Plan__c weeklyPlan = new MD_Plan__c();
            weeklyPlan.RecordTypeId = rtMap.get('Weekly_Plan');
            weeklyPlan.Name         = 'UT Weekly Plan - Reject';
            insert weeklyPlan;
        }
    }

    @isTest
    static void testProcessApproval_NullRecordId() {
        MDPlanApprovalService.MDPlanApprovalResult result =
            MDPlanApprovalService.processApproval(null, 'Approve', 'Test comment');
        System.debug('Result (null recordId): ' + result);
    }

    @isTest
    static void testProcessApproval_BlankAction() {
        MD_Plan__c plan = [SELECT Id FROM MD_Plan__c LIMIT 1];

        MDPlanApprovalService.MDPlanApprovalResult result =
            MDPlanApprovalService.processApproval(plan.Id, '', 'Test comment');
        System.debug('Result (blank action): ' + result);
    }

    @isTest
    static void testProcessApproval_InvalidAction() {
        MD_Plan__c plan = [SELECT Id FROM MD_Plan__c LIMIT 1];

        MDPlanApprovalService.MDPlanApprovalResult result =
            MDPlanApprovalService.processApproval(plan.Id, 'SomethingElse', 'Test comment');
        System.debug('Result (invalid action): ' + result);
    }

    @isTest
    static void testProcessApproval_NoPendingWorkItem() {
        // Record not submitted for approval
        MD_Plan__c plan = [SELECT Id FROM MD_Plan__c LIMIT 1];

        MDPlanApprovalService.MDPlanApprovalResult result =
            MDPlanApprovalService.processApproval(plan.Id, 'Approve', 'No work item scenario');
        System.debug('Result (no pending work item): ' + result);
    }

    @isTest
    static void testProcessApproval_ApproveAndRejectFlows() {

        // Get the submitter/approver user we created in testSetup
        User submitterUser = [
            SELECT Id, Alias
            FROM User
            WHERE Alias = 'mdappr'
            LIMIT 1
        ];

        System.runAs(submitterUser) {

            MD_Plan__c monthlyPlan = [
                SELECT Id
                FROM MD_Plan__c
                WHERE Name = 'UT Monthly Plan - Approve'
                LIMIT 1
            ];

            MD_Plan__c weeklyPlan = [
                SELECT Id
                FROM MD_Plan__c
                WHERE Name = 'UT Weekly Plan - Reject'
                LIMIT 1
            ];

            Test.startTest();

            // Monthly -> Approve
            submitAndCallService(
                monthlyPlan.Id,
                'Approve',
                'Approve from unit test'
            );

            // Weekly -> Reject
            submitAndCallService(
                weeklyPlan.Id,
                'Reject',
                'Reject from unit test'
            );

            Test.stopTest();
        }
    }

    // Helper: submit record for approval and then call the service
    private static void submitAndCallService(
        Id planId,
        String action,
        String comment
    ) {
        // Submit for approval; Salesforce will pick correct process based on Record Type.
        Approval.ProcessSubmitRequest submitReq = new Approval.ProcessSubmitRequest();
        submitReq.setObjectId(planId);

        // Make sure the current user (runAs user) is also the next approver
        submitReq.setNextApproverIds(new Id[] { UserInfo.getUserId() });

        Approval.ProcessResult submitResult = Approval.process(submitReq);
        System.debug('Submit isSuccess: ' + submitResult.isSuccess());
        System.debug('Submit instance status: ' + submitResult.getInstanceStatus());

        // Call the real service (this will execute the main logic block)
        MDPlanApprovalService.MDPlanApprovalResult result =
            MDPlanApprovalService.processApproval(planId, action, comment);
        System.debug('Service result (' + action + '): ' + result);
    }
}