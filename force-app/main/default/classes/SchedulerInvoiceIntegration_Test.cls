@isTest
public class SchedulerInvoiceIntegration_Test {
    @isTest
    public static void testSchedulerExecution() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Test.startTest();

        // Schedule the job with a test cron expression
        String cronExpression = '0 0 1 * * ?'; // Daily at 1 AM
        String jobName = 'InvoiceIntegrationScheduler_Test';

        System.schedule(
            jobName,
            cronExpression,
            new SchedulerInvoiceIntegration()
        );

        Test.stopTest();

        // Verify that the job was scheduled
        List<CronTrigger> scheduledJobs = [
            SELECT Id, CronExpression, TimesTriggered, NextFireTime
            FROM CronTrigger
            WHERE CronJobDetail.Name = :jobName
        ];

        System.assertEquals(1, scheduledJobs.size(), 'Job should be scheduled');
        System.assertEquals(
            cronExpression,
            scheduledJobs[0].CronExpression,
            'Cron expression should match'
        );
    }

    @isTest
    public static void testExecuteMethod() {
        // Set HTTP mock for callouts
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        // Create a test schedulable context
        SchedulerInvoiceIntegration scheduler = new SchedulerInvoiceIntegration();

        Test.startTest();
        scheduler.execute(null);
        Test.stopTest();

        // Add assertions here based on what your InvoiceIntegrationService does
        // For example, if it creates records, query for those records
        // System.assertEquals(expectedCount, actualCount, 'Expected records should be created');
    }
}