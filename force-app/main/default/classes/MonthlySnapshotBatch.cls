public class MonthlySnapshotBatch implements Database.Batchable<String>, Database.Stateful {

    private Boolean forceRecalculate;
    private String  adminEmail;
    private Integer processed = 0;
    private Integer failed    = 0;
    private List<String> errors = new List<String>();

    public MonthlySnapshotBatch() {
        Snapshot_Batch_Config__mdt config = Snapshot_Batch_Config__mdt.getInstance('Default');
        this.forceRecalculate = (config != null && config.Force_Recalculate__c == true);
        this.adminEmail       = (config != null && String.isNotBlank(config.Admin_Email__c))
                                    ? config.Admin_Email__c
                                    : null;
    }

    /**
     * Collect all unique customer codes from active Individual and Master Business Cases.
     * Returns them as an iterable so each customer runs in its own batch transaction.
     */
    public Iterable<String> start(Database.BatchableContext bc) {
        Set<String> codeSet = new Set<String>();

        for (Business_Case__c rec : [
            SELECT Customer_Number__c
            FROM Business_Case__c
            WHERE Customer_Number__c != NULL
                AND Is_Master__c = FALSE
                AND Master_Business_Case__c = NULL
                AND (Status__c LIKE '%Active%'
                    OR Status__c LIKE '%Revised%'
                    OR Status__c LIKE '%New%')
        ]) {
            codeSet.add(rec.Customer_Number__c);
        }

        for (Business_Case__c rec : [
            SELECT Customer_Numbera__c
            FROM Business_Case__c
            WHERE Customer_Numbera__c != NULL
                AND RecordType.Name = 'Master Business Case'
                AND (Status__c LIKE '%Active%'
                    OR Status__c LIKE '%Revised%'
                    OR Status__c LIKE '%New%')
        ]) {
            codeSet.add(rec.Customer_Numbera__c);
        }

        return new List<String>(codeSet);
    }

    /**
     * Each execute() call receives exactly one customer code (scope = 1).
     * Governor limits reset per transaction — safe for any number of customers.
     *
     * forceRecalculate is read from Snapshot_Batch_Config__mdt.Default:
     *   true  = recalculate ALL months (stabilization phase)
     *   false = incremental, only the newest missing month (normal monthly run)
     */
    public void execute(Database.BatchableContext bc, List<String> scope) {
        try {
            BusinessCaseSnapshotService.assignInvoicesForCustomerList(scope);
        } catch (Exception e) {
            errors.add('assignInvoices [' + String.join(scope, ',') + ']: ' + e.getMessage());
        }

        for (String customerCode : scope) {
            try {
                BusinessCaseSnapshotService.processSnapshotsForCustomer(customerCode, forceRecalculate);
                processed++;
            } catch (Exception e) {
                failed++;
                errors.add('processSnapshots [' + customerCode + ']: ' + e.getMessage());
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('=== MonthlySnapshotBatch Complete ===');
        System.debug('Customers processed: ' + processed + ' | Failed: ' + failed + ' | Force recalculate: ' + forceRecalculate);

        if (!errors.isEmpty()) {
            System.debug('--- Errors ---');
            System.debug(String.join(errors, '\n'));
        }

        // ── Verification: snapshots written today ────────────────────────────
        Map<Id, Integer> snapsByBCId = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Business_Case__c bcId, COUNT(Id) cnt
            FROM Business_Case_Sales_Snapshot__c
            WHERE LastModifiedDate = TODAY
            GROUP BY Business_Case__c
        ]) {
            snapsByBCId.put((Id) ar.get('bcId'), (Integer) ar.get('cnt'));
        }

        Map<Id, String> bcCustomerMap = new Map<Id, String>();
        for (Business_Case__c caseRec : [
            SELECT Id, Customer_Number__c
            FROM Business_Case__c
            WHERE Id IN :snapsByBCId.keySet()
        ]) {
            bcCustomerMap.put(caseRec.Id, caseRec.Customer_Number__c);
        }

        Integer totalSnapshotsWritten = 0;
        Map<String, Integer> snapsByCustomer = new Map<String, Integer>();
        for (Id caseId : snapsByBCId.keySet()) {
            String code = bcCustomerMap.containsKey(caseId) ? bcCustomerMap.get(caseId) : String.valueOf(caseId);
            Integer cnt = snapsByBCId.get(caseId);
            snapsByCustomer.put(code, cnt);
            totalSnapshotsWritten += cnt;
        }
        System.debug('--- Snapshots written today: ' + snapsByCustomer.size() + ' customers, ' + totalSnapshotsWritten + ' records ---');
        System.debug(snapsByCustomer);

        // ── Verification: invoices assigned today ────────────────────────────
        Integer invoicesAssigned = [
            SELECT COUNT()
            FROM Invoice_Line_Item__c
            WHERE Business_Case__c != NULL
                AND LastModifiedDate = TODAY
        ];
        System.debug('--- Invoices assigned/updated today: ' + invoicesAssigned + ' ---');

        // ── Write log record ─────────────────────────────────────────────────
        String status = (failed > 0 || !errors.isEmpty()) ? 'Completed with Errors' : 'Completed';
        try {
            insert new RR_Snapshot_Batch_Log__c(
                Job_Id__c              = String.valueOf(bc.getJobId()),
                Status__c              = status,
                Customers_Processed__c = processed,
                Customers_Failed__c    = failed,
                Force_Recalculate__c   = forceRecalculate,
                Snapshots_Written__c   = totalSnapshotsWritten,
                Invoices_Assigned__c   = invoicesAssigned,
                Run_Date__c            = Date.today(),
                Errors__c              = errors.isEmpty() ? null : String.join(errors, '\n')
            );
        } catch (Exception e) {
            System.debug('Failed to write log record: ' + e.getMessage());
        }

        // ── Email admin on every run (success or failure) ─────────────────────
        if (String.isNotBlank(adminEmail)) {
            try {
                String subject = errors.isEmpty()
                    ? 'Monthly Snapshot Batch — Completed successfully on ' + Date.today().format()
                    : 'Monthly Snapshot Batch — ' + failed + ' error(s) on ' + Date.today().format();

                String body =
                    'Monthly Snapshot Batch run summary.\n\n' +
                    'Run Date      : ' + Date.today().format() + '\n' +
                    'Status        : ' + status + '\n' +
                    'Force Recalc  : ' + forceRecalculate + '\n' +
                    'Processed     : ' + processed + '\n' +
                    'Failed        : ' + failed + '\n' +
                    'Snapshots     : ' + totalSnapshotsWritten + '\n' +
                    'Invoices      : ' + invoicesAssigned;

                if (!errors.isEmpty()) {
                    body += '\n\n--- Errors ---\n' + String.join(errors, '\n');
                }

                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new List<String>{ adminEmail });
                mail.setSubject(subject);
                mail.setPlainTextBody(body);
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
            } catch (Exception e) {
                System.debug('Failed to send admin email: ' + e.getMessage());
            }
        }
    }
}
