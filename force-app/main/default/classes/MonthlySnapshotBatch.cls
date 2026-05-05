public class MonthlySnapshotBatch implements Database.Batchable<String>, Database.Stateful {

    private Integer processed = 0;
    private Integer failed = 0;
    private List<String> errors = new List<String>();

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
     * Step 1: assignInvoicesForCustomerList — bulk, uses only 3 SOQL queries.
     * Step 2: processSnapshotsForCustomer  — incremental (forceRecalculate = false),
     *         only creates the snapshot for the most recently completed month.
     */
    public void execute(Database.BatchableContext bc, List<String> scope) {
        try {
            BusinessCaseSnapshotService.assignInvoicesForCustomerList(scope);
        } catch (Exception e) {
            errors.add('assignInvoices [' + String.join(scope, ',') + ']: ' + e.getMessage());
        }

        for (String customerCode : scope) {
            try {
                BusinessCaseSnapshotService.processSnapshotsForCustomer(customerCode, false);
                processed++;
            } catch (Exception e) {
                failed++;
                errors.add('processSnapshots [' + customerCode + ']: ' + e.getMessage());
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('=== MonthlySnapshotBatch Complete ===');
        System.debug('Customers processed: ' + processed + ' | Failed: ' + failed);

        if (!errors.isEmpty()) {
            System.debug('--- Errors ---');
            System.debug(String.join(errors, '\n'));
        }

        // Verification 1: snapshots created/updated today
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

        Map<String, Integer> snapsByCustomer = new Map<String, Integer>();
        for (Id caseId : snapsByBCId.keySet()) {
            String code = bcCustomerMap.containsKey(caseId) ? bcCustomerMap.get(caseId) : String.valueOf(caseId);
            snapsByCustomer.put(code, snapsByBCId.get(caseId));
        }
        System.debug('--- Snapshots written today: ' + snapsByCustomer.size() + ' customers ---');
        System.debug(snapsByCustomer);

        // Verification 2: invoices assigned today
        Integer invoicesAssigned = [
            SELECT COUNT()
            FROM Invoice_Line_Item__c
            WHERE Business_Case__c != NULL
                AND LastModifiedDate = TODAY
        ];
        System.debug('--- Invoices assigned/updated today: ' + invoicesAssigned + ' ---');
    }
}
