// Normal incremental run — only creates snapshots for missing months
//BusinessCaseSnapshotService.processSnapshotsForCustomer('3020000386');

// Force recalculate — recalculates ALL months and updates existing snapshots
// Use this after fixing invoice data or any operational issue
Integer count = BusinessCaseSnapshotService.assignInvoicesForCustomer('3020000605');
System.debug('Invoices assigned: ' + count);

BusinessCaseSnapshotService.processSnapshotsForCustomer('3020000605', true);
System.debug('Snapshots processed for customer 3020000605');
