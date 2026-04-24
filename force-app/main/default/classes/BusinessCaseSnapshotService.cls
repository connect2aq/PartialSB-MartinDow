public class BusinessCaseSnapshotService {
    /**
     * ENHANCED Complete ETL process: Assignment + Comprehensive Snapshot processing
     * This handles ALL Business Cases (with and without invoices) for complete dashboard visibility
     */
    @TestVisible static Boolean forceException = false;

    public static void processCompleteETL() 
    {
        if(forceException == true)
        {
            throw new AuraHandledException('Forced exception for testing purposes');
        }
        else{
            System.debug('=== STARTING ENHANCED COMPLETE ETL PROCESS ===');

            try {
                // Step 1: Assign Business Cases to all invoices
                System.debug('🔗 Step 1: Assigning Business Cases to invoices...');
                Integer assignmentCount = assignBusinessCasesToInvoices();
                System.debug(
                    '✅ Assigned ' +
                        assignmentCount +
                        ' invoice line items to Business Cases'
                );

                Integer masterassignmentCount = assignMasterBusinessCasesToInvoices();
                System.debug(
                    '✅ Assigned Master ' +
                        masterassignmentCount +
                        ' invoice line items to Business Cases'
                );

                // Step 2: Process comprehensive snapshots for ALL months (based on invoice dates + current month for non-invoiced)
                System.debug(
                    '📊 Step 2: Processing snapshots for ALL Business Cases across all relevant months...'
                );
                processComprehensiveSnapshots();
                processMasterComprehensiveSnapshots();
                System.debug('✅ Comprehensive snapshot processing complete');

                System.debug(
                    '=== ENHANCED COMPLETE ETL PROCESS FINISHED SUCCESSFULLY ==='
                );
            } catch (Exception e) {
                System.debug(
                    '❌ Critical error in processCompleteETL: ' + e.getMessage()
                );
                throw new AuraHandledException(
                    'Enhanced Complete ETL process failed: ' + e.getMessage()
                );
            }
        }

        
    }

    /**
     * COMPREHENSIVE: Process snapshots for ALL Business Cases
     * Handles both invoiced and non-invoiced Business Cases for complete dashboard visibility
     * This ensures machines in "Ordered" status and other non-invoiced scenarios appear in dashboard
     */
    public static void processComprehensiveSnapshots() {
        System.debug(
            '=== PROCESSING COMPREHENSIVE SNAPSHOTS FOR ALL BUSINESS CASES ==='
        );

        try {
            System.debug('🚀 Launching Business Case Snapshot Batch...');
            BusinessCaseSnapshotBatch job = new BusinessCaseSnapshotBatch();
            Id jobId = System.Database.executeBatch(job, 20);
            System.debug('🟢 Batch Job ID: ' + jobId);

            // No longer needed - batched processing handles inserts per batch
            // List<Business_Case_Sales_Snapshot__c> snapshotsToInsert = new List<Business_Case_Sales_Snapshot__c>();

            // Get ALL active Business Cases (regardless of invoice status)
            // List<Business_Case__c> allActiveBusinessCases = [
            //   SELECT
            //     Id,
            //     Name,
            //     Status__c,
            //     Account__c,
            //     Account__r.Province__c,
            //     Account__r.City__c,
            //     Account__r.AddressLine_1__c,
            //     Account__r.Addess_Line_2__c,
            //     Account__r.Postal_Code__c,
            //     Account__r.Country_Code__c,
            //     Customer_Number__c,
            //     Customer_Name__c,
            //     Supplier_Name__c,
            //     Technology__c,
            //     Region__c,
            //     SAP_Material_Number__c,
            //     Machine_Type__c,
            //     Quantity__c,
            //     Monthly_Reagent_Commitment__c,
            //     Unit_Cost__c,
            //     Margin_Percent__c,
            //     Agreement_Date__c,
            //     Asset_Number__c,
            //     Asset_Number__r.Status__c,
            //     Machine_Installation__r.Ship_To_Account__c,
            //     Machine_Installation__r.Ship_To_Account__r.SAP_Customer_Number__c,
            //     Machine_Installation__r.Ship_To_Account__r.Name,
            //     Machine_Installation__r.Ship_To_Account__r.Province__c,
            //     Machine_Installation__r.Ship_To_Account__r.City__c,
            //     Machine_Installation__r.Ship_To_Account__r.AddressLine_1__c,
            //     Machine_Installation__r.Ship_To_Account__r.Addess_Line_2__c,
            //     Machine_Installation__r.Ship_To_Account__r.Postal_Code__c,
            //     Machine_Installation__r.Ship_To_Account__r.Country_Code__c,
            //     Machine_Installation__r.Diagnostic_Machine__r.Vendor__c,
            //     Machine_Installation__r.Diagnostic_Machine__r.Technology__c,
            //     Ship_To_Customer_Number__c,
            //     Ship_To_Customer_Name__c,
            //     Machine_Installation__r.SAP_Account_No_Bill_To__c,
            //     Machine_Installation__r.bill_to_account__r.Name,
            //     Machine_Installation__r.Material_Number__c,
            //     Machine_Installation__r.Status__c,
            //     Machine_Installation__r.bill_to_account__r.Province__c,
            //     Machine_Installation__r.bill_to_account__r.City__c,
            //     Machine_Installation__r.bill_to_account__r.AddressLine_1__c,
            //     Machine_Installation__r.bill_to_account__r.Postal_Code__c,
            //     Machine_Installation__r.bill_to_account__r.Country_Code__c
            //   FROM Business_Case__c
            //   where Status__c like '%Active%' or Status__c like '%Revised%' or Status__c like '%New%'
            //   ORDER BY Name
            //   //LIMIT 10000
            // ];

            // if (allActiveBusinessCases.isEmpty()) {
            //   System.debug('⚠️ No active Business Cases found');
            //   return;
            // }

            // System.debug(
            //   '� Found ' +
            //     allActiveBusinessCases.size() +
            //     ' total Business Cases (all statuses, including non-invoiced)'
            // );

            // // OPTIMIZED: Process Business Cases in batches to avoid SOQL query limits
            // Integer batchSize = 5; // Small batch size to stay under query limits
            // Integer totalSnapshots = 0;

            // // Get invoice months for this batch only
            // Set<Id> bcIds = new Set<Id>();
            // for (Business_Case__c bc : allActiveBusinessCases) {
            //   bcIds.add(bc.Id);
            // }

            // // // Single query for all invoice data in this batch
            // // List<Invoice_Line_Item__c> allInvoices = [
            // //   SELECT Business_Case__c, Invoice__r.Invoice_Date__c
            // //   FROM Invoice_Line_Item__c
            // //   WHERE
            // //     Business_Case__c IN :bcIds
            // //     AND Invoice__r.Invoice_Date__c != NULL
            // //     AND DGroup__c = 'Reagent'
            // //   ORDER BY Invoice__r.Invoice_Date__c ASC
            // // ];

            // // Map<Id, Set<Date>> bcToMonths = new Map<Id, Set<Date>>();
            // // Set<Date> months = new Set<Date>();
            // // for (Invoice_Line_Item__c inv : allInvoices)
            // // {
            // //   Id bcId = inv.Business_Case__c;
            // //   Date monthStart = Date.newInstance(
            // //     inv.Invoice__r.Invoice_Date__c.year(),
            // //     inv.Invoice__r.Invoice_Date__c.month(),
            // //     1
            // //   );

            // //   if (!bcToMonths.containsKey(bcId)) {
            // //     bcToMonths.put(bcId, new Set<Date>());
            // //   }
            // //   bcToMonths.get(bcId).add(monthStart);

            // // }

            // // //Query all existing snapshots in one go
            // // List<Business_Case_Sales_Snapshot__c> existingSnapshots = [
            // //   SELECT Business_Case__c, Snapshot_Month__c
            // //   FROM Business_Case_Sales_Snapshot__c
            // //   WHERE Business_Case__c IN :bcIds
            // //     AND Snapshot_Month__c IN :allMonths // collect all months
            // // ];

            // // //Build a lookup map for existing snapshots
            // // Set<String> existingKeys = new Set<String>();
            // // for (Business_Case_Sales_Snapshot__c snap : existingSnapshots) {
            // //     existingKeys.add(snap.Business_Case__c + '_' + snap.Snapshot_Month__c.format());
            // // }

            // // //Now loop and only create snapshots if NOT in existingKeys
            // // for (Business_Case__c bc : businessCases) {
            // //     for (Date month : bcToMonths.get(bc.Id)) {
            // //         String key = bc.Id + '_' + month.format();
            // //         if (!existingKeys.contains(key)) {
            // //             snapshotsToInsert.add(createSnapshotForBusinessCase(bc, month));
            // //         }
            // //     }
            // // }

            // for (Integer i = 0; i < allActiveBusinessCases.size(); i += batchSize) {
            //   List<Business_Case__c> batch = new List<Business_Case__c>();

            //   // Create batch
            //   for (
            //     Integer j = i;
            //     j < Math.min(i + batchSize, allActiveBusinessCases.size());
            //     j++
            //   ) {
            //     batch.add(allActiveBusinessCases[j]);
            //   }

            //   System.debug(
            //     '📦 Processing batch ' +
            //       (i / batchSize + 1) +
            //       ' with ' +
            //       batch.size() +
            //       ' Business Cases'
            //   );

            //   // Process this batch with multi-month logic
            //   Integer snapshotsCreated = processBatchSnapshots(batch);
            //   totalSnapshots += snapshotsCreated;

            //   System.debug(
            //     '✅ Batch completed. Created ' + snapshotsCreated + ' snapshots'
            //   );
            // }

            // System.debug(
            //   '✅ All batches completed. Total snapshots created: ' + totalSnapshots
            // );

            // System.debug('📊 Bulk query found invoice data for Business Cases');

            // LEGACY LOOP DISABLED - Using batched processing above instead
            // if (false) { // OLD LOOP DISABLED
            // // For each Business Case, create snapshots for each of its invoice months
            // for (Business_Case__c bc : allActiveBusinessCases) {
            //   // Legacy variables removed
            //   // Set<Date> invoiceMonthsSet = bcToInvoiceMonths.get(bc.Id);
            //   List<Date> invoiceMonths = new List<Date>();

            //   // Legacy check removed - bcToInvoiceMonths no longer used
            //   // if (invoiceMonthsSet != null && !invoiceMonthsSet.isEmpty()) {
            //   //   invoiceMonths.addAll(invoiceMonthsSet);
            //   // } else {
            //     // No invoices found, use current month for non-invoiced Business Cases
            //     Date currentMonth = Date.today().toStartOfMonth();
            //     invoiceMonths.add(currentMonth);
            //   // }

            //   System.debug('📊 BC ' + bc.Name + ' has invoices in ' + invoiceMonths.size() + ' month(s)');

            //   // Create a snapshot for each invoice month
            //   for (Date snapshotMonth : invoiceMonths) {

            //   System.debug('� BC ' + bc.Name + ' -> Snapshot Month: ' + snapshotMonth.format());

            //   // Check for existing snapshot to avoid duplicates
            //   List<Business_Case_Sales_Snapshot__c> existingSnapshots = [
            //     SELECT Id
            //     FROM Business_Case_Sales_Snapshot__c
            //     WHERE Business_Case__c = :bc.Id AND Snapshot_Month__c = :snapshotMonth
            //     LIMIT 1
            //   ];

            //   if (existingSnapshots.isEmpty()) {
            //     Business_Case_Sales_Snapshot__c snapshot = createSnapshotForBusinessCase(
            //       bc,
            //       snapshotMonth
            //     );
            //     if (snapshot != null) {
            //       // Legacy variable removed: snapshotsToInsert.add(snapshot);
            //       // This code is not executed anymore - batched processing handles inserts
            //     }
            //   } else {
            //     System.debug(
            //       '⏭️ Snapshot already exists for BC: ' +
            //         bc.Name +
            //         ' for month: ' +
            //         snapshotMonth.format()
            //     );
            //   }
            //   } // End of invoice months loop
            // } // End of Business Cases loop
            // } // END OF DISABLED OLD LOOP

            // REPLACED WITH BATCHED PROCESSING ABOVE
            // Legacy bulk insert code removed - now handled in processBatchSnapshots()
            System.debug('✅ Comprehensive snapshot processing complete');
        } catch (Exception e) {
            System.debug(
                '❌ Error in processComprehensiveSnapshots: ' + e.getMessage()
            );
            throw e;
        }
    }

    //Process Master Comprehensive Screenshot
    public static void processMasterComprehensiveSnapshots() {
        System.debug(
            '=== PROCESSING COMPREHENSIVE SNAPSHOTS FOR ALL BUSINESS CASES ==='
        );

        try {
            System.debug('🚀 Launching Master Business Case Snapshot Batch...');
            BusinessCaseMasterSnapshotBatch job = new BusinessCaseMasterSnapshotBatch();
            Id jobId = System.Database.executeBatch(job, 4);
            System.debug('🟢 Batch Job ID: ' + jobId);

            System.debug(
                '✅ Master Comprehensive snapshot processing complete'
            );
        } catch (Exception e) {
            System.debug(
                '❌ Error in processMasterComprehensiveSnapshots: ' +
                e.getMessage()
            );
            throw e;
        }
    }

    // Helper method to determine the appropriate snapshot month for a Business Case
    public static Date determineSnapshotMonth(Id businessCaseId) {
        try {
            // Get the most recent invoice date for this Business Case
            List<Invoice_Line_Item__c> recentInvoices = [
                SELECT Invoice__r.Invoice_Date__c
                FROM Invoice_Line_Item__c
                WHERE
                    Business_Case__c = :businessCaseId
                    AND Invoice__r.Invoice_Date__c != NULL
                    AND DGroup__c = 'Reagent'
                ORDER BY Invoice__r.Invoice_Date__c DESC
                LIMIT 1
            ];

            if (!recentInvoices.isEmpty()) {
                // Use the month of the most recent invoice
                Date invoiceDate = recentInvoices[0].Invoice__r.Invoice_Date__c;
                Date invoiceMonth = Date.newInstance(
                    invoiceDate.year(),
                    invoiceDate.month(),
                    1
                );
                System.debug(
                    '🗓️ Using invoice-based month: ' +
                        invoiceMonth.format() +
                        ' (from invoice date: ' +
                        invoiceDate.format() +
                        ')'
                );
                return invoiceMonth;
            } else {
                // No invoices found, use current month for non-invoiced Business Cases
                Date currentMonth = Date.today().toStartOfMonth();
                System.debug(
                    '🗓️ Using current month (no invoices): ' +
                    currentMonth.format()
                );
                return currentMonth;
            }
        } catch (Exception e) {
            System.debug(
                '⚠️ Error determining snapshot month for BC ' +
                    businessCaseId +
                    ': ' +
                    e.getMessage()
            );
            // Fallback to current month
            return Date.today().toStartOfMonth();
        }
    }

    // Helper method to determine default snapshot month for Business Cases without invoices
    public static Date determineDefaultSnapshotMonth(
        Business_Case__c businessCase
    ) {
        try {
            // Priority 1: Use Agreement_Date__c if available (contract start month)
            if (businessCase.Agreement_Date__c != null) {
                Date agreementMonth = Date.newInstance(
                    businessCase.Agreement_Date__c.year(),
                    businessCase.Agreement_Date__c.month(),
                    1
                );
                System.debug(
                    '🗓️ Using Agreement Date month: ' +
                        agreementMonth.format() +
                        ' for BC ' +
                        businessCase.Name
                );
                return agreementMonth;
            }

            // Priority 2: Use a recent historical month instead of current month (to avoid 2025 dates)
            // Use April 2024 as default since most invoice data is from that timeframe
            Date defaultMonth = Date.newInstance(2024, 4, 1);
            System.debug(
                '🗓️ Using default historical month: ' +
                    defaultMonth.format() +
                    ' for BC ' +
                    businessCase.Name
            );
            return defaultMonth;
        } catch (Exception e) {
            System.debug(
                '⚠️ Error determining default snapshot month for BC ' +
                    businessCase.Name +
                    ': ' +
                    e.getMessage()
            );
            // Final fallback to April 2024
            return Date.newInstance(2024, 4, 1);
        }
    }

    // Helper method to get all unique invoice months for a Business Case
    public static List<Date> getAllInvoiceMonths(Id businessCaseId) {
        try {
            // Get all invoice dates for this Business Case
            List<Invoice_Line_Item__c> allInvoices = [
                SELECT Invoice__r.Invoice_Date__c
                FROM Invoice_Line_Item__c
                WHERE
                    Business_Case__c = :businessCaseId
                    AND Invoice__r.Invoice_Date__c != NULL
                    AND DGroup__c = 'Reagent'
                ORDER BY Invoice__r.Invoice_Date__c ASC
            ];

            Set<Date> uniqueMonths = new Set<Date>();

            for (Invoice_Line_Item__c invoice : allInvoices) {
                Date invoiceDate = invoice.Invoice__r.Invoice_Date__c;
                Date invoiceMonth = Date.newInstance(
                    invoiceDate.year(),
                    invoiceDate.month(),
                    1
                );
                uniqueMonths.add(invoiceMonth);
            }

            List<Date> monthsList = new List<Date>(uniqueMonths);

            if (monthsList.isEmpty()) {
                // No invoices found, use current month for non-invoiced Business Cases
                Date currentMonth = Date.today().toStartOfMonth();
                monthsList.add(currentMonth);
                System.debug(
                    '🗓️ No invoices found, using current month: ' +
                    currentMonth.format()
                );
            } else {
                System.debug(
                    '🗓️ Found ' +
                        monthsList.size() +
                        ' unique invoice months for BC ' +
                        businessCaseId
                );
            }

            return monthsList;
        } catch (Exception e) {
            System.debug(
                '⚠️ Error getting invoice months for BC ' +
                    businessCaseId +
                    ': ' +
                    e.getMessage()
            );
            // Fallback to current month
            List<Date> fallbackList = new List<Date>();
            fallbackList.add(Date.today().toStartOfMonth());
            return fallbackList;
        }
    }

    // Helper method to process a batch of Business Cases with multi-month snapshots
    public static Integer processBatchSnapshots(
        List<Business_Case__c> businessCases
    ) {
        // List<Invoice_Line_Item__c> allInvoices,
        // Map<Id, Set<Date>> bcToMonths,
        // Set<Id> bcIds
        try {
            List<Business_Case_Sales_Snapshot__c> snapshotsToInsert = new List<Business_Case_Sales_Snapshot__c>();
            System.debug(
                '>>>>BusinessCaseSnapshotService-->Process Batch Snapshot-->Batch Size: ' +
                businessCases.size()
            );
            // Get invoice months for this batch only
            Set<Id> bcIds = new Set<Id>();
            for (Business_Case__c bc : businessCases) {
                bcIds.add(bc.Id);
            }

            System.debug(
                '>>>>BusinessCaseSnapshotService-->Process Batch Snapshot-->Batch BIds: ' +
                bcIds
            );

            // Single query for all invoice data in this batch
            List<Invoice_Line_Item__c> allInvoices = [
                SELECT Business_Case__c, Invoice__r.Invoice_Date__c
                FROM Invoice_Line_Item__c
                WHERE
                    Business_Case__c IN :bcIds
                    AND Invoice__r.Invoice_Date__c != NULL
                    AND DGroup__c = 'Reagent'
                ORDER BY Invoice__r.Invoice_Date__c ASC
            ];

            System.debug(
                '>>>>BusinessCaseSnapshotService-->Process Batch Snapshot-->all Invoices : ' +
                allInvoices.size()
            );

            // Group by Business Case and month
            Map<Id, Set<Date>> bcToMonths = new Map<Id, Set<Date>>();
            Set<Date> allMonths = new Set<Date>();
            for (Invoice_Line_Item__c inv : allInvoices) {
                Id bcId = inv.Business_Case__c;
                Date monthStart = Date.newInstance(
                    inv.Invoice__r.Invoice_Date__c.year(),
                    inv.Invoice__r.Invoice_Date__c.month(),
                    1
                );

                if (!bcToMonths.containsKey(bcId)) {
                    bcToMonths.put(bcId, new Set<Date>());
                }
                bcToMonths.get(bcId).add(monthStart);
                allMonths.add(monthStart);
            }

            // Handle BCs with no invoices (default snapshot month)
            for (Business_Case__c bc : businessCases) {
                if (
                    !bcToMonths.containsKey(bc.Id) ||
                    bcToMonths.get(bc.Id).isEmpty()
                ) {
                    Date snapshotMonth = determineDefaultSnapshotMonth(bc);

                    if (!bcToMonths.containsKey(bc.Id)) {
                        bcToMonths.put(bc.Id, new Set<Date>());
                    }
                    bcToMonths.get(bc.Id).add(snapshotMonth);
                    allMonths.add(snapshotMonth);

                    System.debug(
                        '📋 BC ' +
                            bc.Name +
                            ' has no invoices - creating snapshot for ' +
                            snapshotMonth.format() +
                            ' (Machine Status: ' +
                            (bc.Asset_Number__r?.Status__c ?? 'Unknown') +
                            ')'
                    );
                } else {
                    System.debug(
                        '📊 BC ' +
                            bc.Name +
                            ' has invoices in ' +
                            bcToMonths.get(bc.Id).size() +
                            ' month(s)'
                    );
                }
            }

            System.debug(
                '>>>>BusinessCaseSnapshotservice-->processBatchSnapshot-->bcIds: ' +
                bcIds
            );
            System.debug(
                '>>>>BusinessCaseSnapshotservice-->processBatchSnapshot-->all months: ' +
                allMonths
            );
            // Query all existing snapshots in one go for this batch
            List<Business_Case_Sales_Snapshot__c> existingSnapshots = [
                SELECT Business_Case__c, Snapshot_Month__c
                FROM Business_Case_Sales_Snapshot__c
                WHERE
                    Business_Case__c IN :bcIds
                    AND Snapshot_Month__c IN :allMonths
            ];

            System.debug(
                '>>>>BusinessCaseSnapshotservice-->processBatchSnapshot-->existing snapshots: ' +
                existingSnapshots.size()
            );

            // Build a lookup set of existing BC+Month combos
            Set<String> existingKeys = new Set<String>();
            for (Business_Case_Sales_Snapshot__c snap : existingSnapshots) {
                existingKeys.add(
                    snap.Business_Case__c +
                        '_' +
                        snap.Snapshot_Month__c.format()
                );
            }

            // Bulk precompute everything:
            Map<String, InvoiceAggregationResult> invoiceMap = bulkAggregateInvoiceData(
                bcIds,
                allMonths
            );
            Map<String, Decimal> ytdSalesMap = bulkCalculateYTDSales(
                bcIds,
                allMonths
            );
            Map<String, Decimal> totalSalesMap = bulkCalculateTotalSalesTillDate(
                bcIds,
                allMonths
            );

            // Create missing snapshots
            for (Business_Case__c bc : businessCases) {
                System.debug(
                    '>>>>BusinessCaseSnapshotservice-->processBatchSnapshot-->Business Case for Snapshot: ' +
                        bc.Id +
                        ' - ' +
                        bc.Name
                );
                for (Date month : bcToMonths.get(bc.Id)) {
                    String key = bc.Id + '_' + month.format();
                    System.debug(
                        '>>>>BusinessCaseSnapshotservice-->processBatchSnapshot-->Business Case for Snapshot key: ' +
                        key
                    );
                    if (!existingKeys.contains(key)) {
                        Business_Case_Sales_Snapshot__c snapshot = new Business_Case_Sales_Snapshot__c();
                        try {
                            snapshot = createSnapshotForBusinessCase(
                                bc,
                                month,
                                invoiceMap.get(key),
                                ytdSalesMap.get(key),
                                totalSalesMap.get(key)
                            );
                        } catch (Exception sex) {
                            System.debug(
                                '>>>>BusinessCaseSnapshotservice-->processBatchSnapshot-->Exception: ' +
                                sex.getMessage()
                            );
                            snapshot = null;
                        }

                        if (snapshot != null) {
                            snapshotsToInsert.add(snapshot);
                            System.debug(
                                ' Prepared snapshot for BC ' +
                                    bc.Name +
                                    ' for month ' +
                                    month.format()
                            );
                        } else {
                            System.debug(
                                ' Unable to prepare snapshot for BC ' +
                                    bc.Name +
                                    ' for month ' +
                                    month.format()
                            );
                        }
                    } else {
                        System.debug(
                            ' Snapshot already exists for BC ' +
                                bc.Name +
                                ' for month ' +
                                month.format()
                        );
                    }
                }
            }

            // Create snapshots for each BC and month
            // for (Business_Case__c bc : businessCases) {
            //   Set<Date> months = bcToMonths.get(bc.Id);
            //   if (months == null || months.isEmpty()) {
            //     // No invoices found - create single snapshot for contract start month or current month
            //     Date snapshotMonth = determineDefaultSnapshotMonth(bc);

            //     months = new Set<Date>{ snapshotMonth };
            //     System.debug(
            //       '📋 BC ' +
            //         bc.Name +
            //         ' has no invoices - creating snapshot for ' +
            //         snapshotMonth.format() +
            //         ' (Machine Status: ' +
            //         (bc.Asset_Number__r?.Status__c ?? 'Unknown') +
            //         ')'
            //     );
            //   } else {
            //     System.debug(
            //       '📊 BC ' + bc.Name + ' has invoices in ' + months.size() + ' month(s)'
            //     );
            //   }

            //   for (Date month : months) {
            //     // Check if snapshot already exists
            //     List<Business_Case_Sales_Snapshot__c> existing = [
            //       SELECT Id
            //       FROM Business_Case_Sales_Snapshot__c
            //       WHERE Business_Case__c = :bc.Id AND Snapshot_Month__c = :month
            //       LIMIT 1
            //     ];

            //     if (existing.isEmpty()) {
            //       Business_Case_Sales_Snapshot__c snapshot = createSnapshotForBusinessCase(
            //         bc,
            //         month
            //       );
            //       if (snapshot != null) {
            //         snapshotsToInsert.add(snapshot);
            //         System.debug(
            //           '📝 Prepared snapshot for BC ' +
            //             bc.Name +
            //             ' for month ' +
            //             month.format()
            //         );
            //       }
            //     } else {
            //       System.debug(
            //         '⏭️ Snapshot already exists for BC ' +
            //           bc.Name +
            //           ' for month ' +
            //           month.format()
            //       );
            //     }
            //   }
            // }

            // Insert snapshots
            if (!snapshotsToInsert.isEmpty()) {
                //insert snapshotsToInsert;
                Database.SaveResult[] results = Database.insert(
                    snapshotsToInsert,
                    false
                );
                for (Integer i = 0; i < results.size(); i++) {
                    if (!results[i].isSuccess()) {
                        for (Database.Error err : results[i].getErrors()) {
                            System.debug(
                                '❌ Snapshot failed: ' + err.getMessage()
                            );
                            System.debug('   Field: ' + err.getFields());
                        }
                    }
                }
                List<Business_Case_Sales_Snapshot__c> insertedSnaps = [
                    SELECT Id, Name
                    FROM Business_Case_Sales_Snapshot__c
                    WHERE Id IN :snapshotsToInsert
                ];
                System.debug(
                    '✅ Inserted ' + snapshotsToInsert.size() + ' snapshots'
                );
                System.debug(
                    '✅ Inserted Snaps ' + insertedSnaps.size() + ' snapshots'
                );
            }

            return snapshotsToInsert.size();
        } catch (Exception ex) {
            System.debug(
                '>>>>BusinessCaseSnapshotService-->processSnapshots-->exception: ' +
                ex.getMessage()
            );
            return 0;
        }
    }

    //Process Master Business Batch Snapshots
    public static Integer processMasterBatchSnapshots(
        List<Business_Case__c> businessCases
    ) {
        // List<Invoice_Line_Item__c> allInvoices,
        // Map<Id, Set<Date>> bcToMonths,
        // Set<Id> bcIds
        try {
            List<Business_Case__c> mastersWithIndividuals = new List<Business_Case__c>();
            for (Business_Case__c bc : businessCases) {
                if (!bc.Business_Cases__r.isEmpty()) {
                    mastersWithIndividuals.add(bc);
                }
            }

            List<Business_Case_Sales_Snapshot__c> snapshotsToInsert = new List<Business_Case_Sales_Snapshot__c>();
            System.debug(
                '>>>>BusinessCaseSnapshotService-->processMasterBatchSnapshots-->Batch Size: ' +
                mastersWithIndividuals.size()
            );
            // Get invoice months for this batch only
            Set<Id> bcIds = new Set<Id>();
            for (Business_Case__c bc : mastersWithIndividuals) {
                bcIds.add(bc.Id);
            }

            System.debug(
                '>>>>BusinessCaseSnapshotService-->processMasterBatchSnapshots-->Batch BIds: ' +
                bcIds
            );

            // Single query for all invoice data in this batch
            List<Invoice_Line_Item__c> allInvoices = [
                SELECT Business_Case__c, Invoice__r.Invoice_Date__c
                FROM Invoice_Line_Item__c
                WHERE
                    Business_Case__c IN :bcIds
                    AND Invoice__r.Invoice_Date__c != NULL
                    AND DGroup__c = 'Reagent'
                ORDER BY Invoice__r.Invoice_Date__c ASC
            ];

            System.debug(
                '>>>>BusinessCaseSnapshotService-->processMasterBatchSnapshots-->all Invoices : ' +
                allInvoices.size()
            );

            // Group by Business Case and month
            Map<Id, Set<Date>> bcToMonths = new Map<Id, Set<Date>>();
            Set<Date> allMonths = new Set<Date>();
            for (Invoice_Line_Item__c inv : allInvoices) {
                Id bcId = inv.Business_Case__c;
                Date monthStart = Date.newInstance(
                    inv.Invoice__r.Invoice_Date__c.year(),
                    inv.Invoice__r.Invoice_Date__c.month(),
                    1
                );

                if (!bcToMonths.containsKey(bcId)) {
                    bcToMonths.put(bcId, new Set<Date>());
                }
                bcToMonths.get(bcId).add(monthStart);
                allMonths.add(monthStart);
            }

            // Handle BCs with no invoices (default snapshot month)
            for (Business_Case__c bc : mastersWithIndividuals) {
                if (
                    !bcToMonths.containsKey(bc.Id) ||
                    bcToMonths.get(bc.Id).isEmpty()
                ) {
                    Date snapshotMonth = determineDefaultSnapshotMonth(bc);

                    if (!bcToMonths.containsKey(bc.Id)) {
                        bcToMonths.put(bc.Id, new Set<Date>());
                    }
                    bcToMonths.get(bc.Id).add(snapshotMonth);
                    allMonths.add(snapshotMonth);

                    System.debug(
                        '📋 BC ' +
                            bc.Name +
                            ' has no invoices - creating snapshot for ' +
                            snapshotMonth.format() +
                            ' (Master BC with ' +
                            (bc.Business_Cases__r != null
                                ? bc.Business_Cases__r.size()
                                : 0) +
                            ' Individual BCs)'
                    );
                } else {
                    System.debug(
                        '📊 BC ' +
                            bc.Name +
                            ' has invoices in ' +
                            bcToMonths.get(bc.Id).size() +
                            ' month(s)'
                    );
                }
            }

            System.debug(
                '>>>>BusinessCaseSnapshotservice-->processMasterBatchSnapshots-->bcIds: ' +
                bcIds
            );
            System.debug(
                '>>>>BusinessCaseSnapshotservice-->processMasterBatchSnapshots-->all months: ' +
                allMonths
            );
            // Query all existing snapshots in one go for this batch
            List<Business_Case_Sales_Snapshot__c> existingSnapshots = [
                SELECT Business_Case__c, Snapshot_Month__c
                FROM Business_Case_Sales_Snapshot__c
                WHERE
                    Business_Case__c IN :bcIds
                    AND Snapshot_Month__c IN :allMonths
            ];

            System.debug(
                '>>>>BusinessCaseSnapshotservice-->processMasterBatchSnapshots-->existing snapshots: ' +
                existingSnapshots.size()
            );

            // Build a lookup set of existing BC+Month combos
            Set<String> existingKeys = new Set<String>();
            for (Business_Case_Sales_Snapshot__c snap : existingSnapshots) {
                existingKeys.add(
                    snap.Business_Case__c +
                        '_' +
                        snap.Snapshot_Month__c.format()
                );
            }

            // Bulk precompute everything:
            Map<String, InvoiceAggregationResult> invoiceMap = bulkAggregateInvoiceData(
                bcIds,
                allMonths
            );
            Map<String, Decimal> ytdSalesMap = bulkCalculateYTDSales(
                bcIds,
                allMonths
            );
            Map<String, Decimal> totalSalesMap = bulkCalculateTotalSalesTillDate(
                bcIds,
                allMonths
            );

            // Create missing snapshots
            for (Business_Case__c bc : mastersWithIndividuals) {
                System.debug(
                    '>>>>BusinessCaseSnapshotservice-->processMasterBatchSnapshots-->Business Case for Snapshot: ' +
                        bc.Id +
                        ' - ' +
                        bc.Name
                );
                for (Date month : bcToMonths.get(bc.Id)) {
                    String key = bc.Id + '_' + month.format();
                    System.debug(
                        '>>>>BusinessCaseSnapshotservice-->processMasterBatchSnapshots-->Business Case for Snapshot key: ' +
                        key
                    );
                    if (!existingKeys.contains(key)) {
                        Business_Case_Sales_Snapshot__c snapshot = new Business_Case_Sales_Snapshot__c();
                        try {
                            snapshot = createSnapshotForMasterBusinessCase(
                                bc,
                                month,
                                invoiceMap.get(key),
                                ytdSalesMap.get(key),
                                totalSalesMap.get(key)
                            );
                        } catch (Exception sex) {
                            System.debug(
                                '>>>>BusinessCaseSnapshotservice-->processMasterBatchSnapshots-->Exception: ' +
                                sex.getMessage()
                            );
                            snapshot = null;
                        }

                        if (snapshot != null) {
                            snapshotsToInsert.add(snapshot);
                            System.debug(
                                ' Prepared snapshot for BC ' +
                                    bc.Name +
                                    ' for month ' +
                                    month.format()
                            );
                        } else {
                            System.debug(
                                ' Unable to prepare snapshot for BC ' +
                                    bc.Name +
                                    ' for month ' +
                                    month.format()
                            );
                        }
                    } else {
                        System.debug(
                            ' Snapshot already exists for BC ' +
                                bc.Name +
                                ' for month ' +
                                month.format()
                        );
                    }
                }
            }

            // Insert snapshots
            if (!snapshotsToInsert.isEmpty()) {
                //insert snapshotsToInsert;
                Database.SaveResult[] results = Database.insert(
                    snapshotsToInsert,
                    false
                );
                for (Integer i = 0; i < results.size(); i++) {
                    if (!results[i].isSuccess()) {
                        for (Database.Error err : results[i].getErrors()) {
                            System.debug(
                                '❌ Snapshot failed: ' + err.getMessage()
                            );
                            System.debug('   Field: ' + err.getFields());
                        }
                    }
                }
                List<Business_Case_Sales_Snapshot__c> insertedSnaps = [
                    SELECT Id, Name
                    FROM Business_Case_Sales_Snapshot__c
                    WHERE Id IN :snapshotsToInsert
                ];
                System.debug(
                    '✅ Inserted ' + snapshotsToInsert.size() + ' snapshots'
                );
                System.debug(
                    '✅ Inserted Snaps ' + insertedSnaps.size() + ' snapshots'
                );
            }

            return snapshotsToInsert.size();
        } catch (Exception ex) {
            System.debug(
                '>>>>BusinessCaseSnapshotService-->processMasterBatchSnapshots-->exception: ' +
                ex.getMessage()
            );
            return 0;
        }
    }
    /**
     * LEGACY: Process snapshots using bulk query approach (Invoice-only)
     * Single query for all invoice data instead of per-BC queries
     * KEPT FOR BACKWARD COMPATIBILITY - Use processComprehensiveSnapshots() for complete visibility
     */
    // public static void processSnapshotsFromAssignedInvoices() {
    //     System.debug(
    //         '=== PROCESSING SNAPSHOTS WITH BULK OPTIMIZATION (INVOICE-ONLY) ==='
    //     );

    //     try {
    //         // Get all active Business Cases that have invoice assignments
    //         List<Business_Case__c> activeBusinessCasesWithInvoices = [
    //             SELECT
    //                 Id,
    //                 Name,
    //                 Account__c,
    //                 Account__r.Province__c,
    //                 Account__r.City__c,
    //                 Account__r.AddressLine_1__c,
    //                 Account__r.Addess_Line_2__c,
    //                 Account__r.Postal_Code__c,
    //                 Account__r.Country_Code__c,
    //                 Asset_Number__c,
    //                 Asset_Number__r.Status__c,
    //                 Asset_Number__r.Ship_To_Account__c,
    //                 Asset_Number__r.Ship_To_Account__r.SAP_Customer_Number__c,
    //                 Asset_Number__r.Ship_To_Account__r.Name,
    //                 Asset_Number__r.Ship_To_Account__r.Province__c,
    //                 Asset_Number__r.Ship_To_Account__r.City__c,
    //                 Asset_Number__r.Ship_To_Account__r.AddressLine_1__c,
    //                 Asset_Number__r.Ship_To_Account__r.Addess_Line_2__c,
    //                 Asset_Number__r.Ship_To_Account__r.Postal_Code__c,
    //                 Asset_Number__r.Ship_To_Account__r.Country_Code__c,
    //                 Customer_Number__c,
    //                 Customer_Name__c,
    //                 Supplier_Name__c,
    //                 Technology__c,
    //                 Region__c,
    //                 Monthly_Reagent_Commitment__c,
    //                 Unit_Cost__c,
    //                 Payback_Period__c,
    //                 Status__c,
    //                 Agreement_Date__c,
    //                 Margin_Percent__c,
    //                 Quantity__c,
    //                 SAP_Material_Number__c,
    //                 Machine_Type__c
    //             FROM Business_Case__c
    //             WHERE
    //                 Status__c = 'Active'
    //                 AND Id IN (
    //                     SELECT Business_Case__c
    //                     FROM Invoice_Line_Item__c
    //                     WHERE Business_Case__c != NULL
    //                 )
    //         ];

    //         if (activeBusinessCasesWithInvoices.isEmpty()) {
    //             System.debug(
    //                 '⚠️ No active Business Cases with invoice assignments found'
    //             );
    //             return;
    //         }

    //         System.debug(
    //             'Found ' +
    //                 activeBusinessCasesWithInvoices.size() +
    //                 ' Business Cases with invoice data'
    //         );

    //         // Create BC ID set for bulk query
    //         Set<Id> businessCaseIds = new Set<Id>();
    //         Map<Id, Business_Case__c> businessCaseMap = new Map<Id, Business_Case__c>();

    //         for (Business_Case__c bc : activeBusinessCasesWithInvoices) {
    //             businessCaseIds.add(bc.Id);
    //             businessCaseMap.put(bc.Id, bc);
    //         }

    //         // SINGLE BULK QUERY: Get ALL invoice data for ALL Business Cases, grouped by BC and month
    //         System.debug(
    //             'Executing single bulk query for all Business Case invoice data...'
    //         );
    //         List<AggregateResult> allInvoiceData = [
    //             SELECT
    //                 Business_Case__c,
    //                 CALENDAR_YEAR(Invoice__r.Invoice_Date__c) year,
    //                 CALENDAR_MONTH(Invoice__r.Invoice_Date__c) month,
    //                 COUNT(Id) invoiceCount,
    //                 SUM(Invoice_Value__c) totalSales
    //             FROM Invoice_Line_Item__c
    //             WHERE
    //                 Business_Case__c IN :businessCaseIds
    //                 AND Invoice_Value__c != NULL
    //             GROUP BY
    //                 Business_Case__c,
    //                 CALENDAR_YEAR(Invoice__r.Invoice_Date__c),
    //                 CALENDAR_MONTH(Invoice__r.Invoice_Date__c)
    //             ORDER BY
    //                 Business_Case__c,
    //                 CALENDAR_YEAR(Invoice__r.Invoice_Date__c),
    //                 CALENDAR_MONTH(Invoice__r.Invoice_Date__c)
    //         ];

    //         System.debug(
    //             'Bulk query returned ' +
    //                 allInvoiceData.size() +
    //                 ' month-BC combinations'
    //         );

    //         // BULK QUERY for totals till date for each BC (for enhanced analytics)
    //         System.debug(
    //             'Calculating enhanced analytics with bulk approach...'
    //         );
    //         Map<Id, Decimal> bcToTotalSales = new Map<Id, Decimal>();
    //         List<AggregateResult> totalSalesResults = [
    //             SELECT Business_Case__c, SUM(Invoice_Value__c) totalSales
    //             FROM Invoice_Line_Item__c
    //             WHERE
    //                 Business_Case__c IN :businessCaseIds
    //                 AND Invoice_Value__c != NULL
    //             GROUP BY Business_Case__c
    //         ];

    //         for (AggregateResult result : totalSalesResults) {
    //             Id bcId = (Id) result.get('Business_Case__c');
    //             Decimal totalSales = (Decimal) result.get('totalSales');
    //             bcToTotalSales.put(bcId, totalSales != null ? totalSales : 0);
    //         }

    //         // Organize data by Business Case and month
    //         Map<Id, Map<String, InvoiceMonthData>> bcToMonthlyData = new Map<Id, Map<String, InvoiceMonthData>>();
    //         Map<Id, Map<String, Decimal>> bcToRunningTotals = new Map<Id, Map<String, Decimal>>();

    //         for (AggregateResult result : allInvoiceData) {
    //             Id bcId = (Id) result.get('Business_Case__c');
    //             Integer year = (Integer) result.get('year');
    //             Integer month = (Integer) result.get('month');
    //             Integer invoiceCount = (Integer) result.get('invoiceCount');
    //             Decimal totalSales = (Decimal) result.get('totalSales');

    //             Date monthDate = Date.newInstance(year, month, 1);
    //             String monthKey = year + '-' + month;

    //             InvoiceMonthData monthData = new InvoiceMonthData();
    //             monthData.month = monthDate;
    //             monthData.invoiceCount = invoiceCount != null
    //                 ? invoiceCount
    //                 : 0;
    //             monthData.totalSales = totalSales != null ? totalSales : 0;

    //             if (!bcToMonthlyData.containsKey(bcId)) {
    //                 bcToMonthlyData.put(
    //                     bcId,
    //                     new Map<String, InvoiceMonthData>()
    //                 );
    //                 bcToRunningTotals.put(bcId, new Map<String, Decimal>());
    //             }
    //             bcToMonthlyData.get(bcId).put(monthKey, monthData);
    //         }

    //         // Calculate running totals for each BC (for cumulative sales till date)
    //         for (Id bcId : bcToMonthlyData.keySet()) {
    //             Map<String, InvoiceMonthData> monthlyData = bcToMonthlyData.get(
    //                 bcId
    //             );
    //             Map<String, Decimal> runningTotals = bcToRunningTotals.get(
    //                 bcId
    //             );

    //             List<String> sortedMonthKeys = new List<String>(
    //                 monthlyData.keySet()
    //             );
    //             sortedMonthKeys.sort();

    //             Decimal runningTotal = 0;
    //             for (String monthKey : sortedMonthKeys) {
    //                 InvoiceMonthData monthData = monthlyData.get(monthKey);
    //                 runningTotal += monthData.totalSales;
    //                 runningTotals.put(monthKey, runningTotal);
    //             }
    //         }

    //         List<Business_Case_Sales_Snapshot__c> allSnapshots = new List<Business_Case_Sales_Snapshot__c>();
    //         Integer totalMonthsProcessed = 0;

    //         // Process each Business Case using pre-loaded data
    //         for (
    //             Business_Case__c businessCase : activeBusinessCasesWithInvoices
    //         ) {
    //             try {
    //                 System.debug(
    //                     'Processing Business Case: ' + businessCase.Name
    //                 );

    //                 Map<String, InvoiceMonthData> monthlyData = bcToMonthlyData.get(
    //                     businessCase.Id
    //                 );

    //                 if (monthlyData == null || monthlyData.isEmpty()) {
    //                     System.debug(
    //                         'No invoice data found for BC: ' + businessCase.Name
    //                     );
    //                     continue;
    //                 }

    //                 System.debug(
    //                     'Found data for ' +
    //                         monthlyData.size() +
    //                         ' months for BC: ' +
    //                         businessCase.Name
    //                 );

    //                 // Create snapshots for each month that has data
    //                 for (String monthKey : monthlyData.keySet()) {
    //                     InvoiceMonthData monthData = monthlyData.get(monthKey);
    //                     Date snapshotMonth = monthData.month;

    //                     // Get running total for this month (cumulative sales till date)
    //                     Decimal totalSalesTillDate = bcToRunningTotals.get(
    //                             businessCase.Id
    //                         )
    //                         .get(monthKey);
    //                     Decimal totalSalesAllTime = bcToTotalSales.get(
    //                         businessCase.Id
    //                     );

    //                     // Create snapshot using the data we already have (NO additional queries)
    //                     Business_Case_Sales_Snapshot__c snapshot = createSnapshotFromBulkData(
    //                         businessCase,
    //                         monthData,
    //                         totalSalesTillDate,
    //                         totalSalesAllTime
    //                     );

    //                     if (snapshot != null) {
    //                         allSnapshots.add(snapshot);
    //                         totalMonthsProcessed++;
    //                         System.debug(
    //                             'Created snapshot for ' +
    //                                 businessCase.Name +
    //                                 ' - Month: ' +
    //                                 snapshotMonth.format() +
    //                                 ' - Sales: ' +
    //                                 snapshot.Total_Reagent_Sales__c
    //                         );
    //                     }
    //                 }
    //             } catch (Exception e) {
    //                 System.debug(
    //                     'Error processing Business Case ' +
    //                         businessCase.Id +
    //                         ': ' +
    //                         e.getMessage()
    //                 );
    //             }
    //         }

    //         // Bulk upsert all snapshots at once
    //         if (!allSnapshots.isEmpty()) {
    //             handleSnapshotUpsert(allSnapshots);
    //             System.debug(
    //                 '✅ Successfully processed ' +
    //                     allSnapshots.size() +
    //                     ' snapshots across ' +
    //                     totalMonthsProcessed +
    //                     ' Business Case-months'
    //             );
    //         }
    //     } catch (Exception e) {
    //         System.debug(
    //             '❌ Critical error in processSnapshotsFromAssignedInvoices: ' +
    //             e.getMessage()
    //         );
    //         throw new AuraHandledException(
    //             'Failed to process snapshots from assigned invoices: ' +
    //             e.getMessage()
    //         );
    //     }
    // }

    /**
     * Main method to process monthly snapshots from invoice data (API load workflow)
     * If snapshotMonth is null, processes all available months with invoice data
     */
    // public static void processMonthlySnapshots(Date snapshotMonth) {
    //     try {
    //         if (snapshotMonth == null) {
    //             // Process all available months with invoice data
    //             System.debug(
    //                 'Starting Business Case snapshot processing for ALL available data...'
    //             );

    //             // Step 1: Check if Business Cases are already assigned, if not assign them
    //             Integer existingAssignments = [
    //                 SELECT COUNT()
    //                 FROM Invoice_Line_Item__c
    //                 WHERE Business_Case__c != NULL AND DGroup__c = 'Reagent'
    //             ];

    //             if (existingAssignments == 0) {
    //                 System.debug(
    //                     'No existing assignments found - running Business Case assignment...'
    //                 );
    //                 assignBusinessCasesToInvoices();
    //             } else {
    //                 System.debug(
    //                     'Found ' +
    //                         existingAssignments +
    //                         ' existing assignments - skipping assignment phase'
    //                 );
    //             }

    //             // Step 2: Get the actual date range of invoice data
    //             List<AggregateResult> dateRange = [
    //                 SELECT
    //                     MIN(Invoice_Date__c) minDate,
    //                     MAX(Invoice_Date__c) maxDate
    //                 FROM Invoice__c
    //                 WHERE Invoice_Date__c != NULL
    //             ];

    //             if (
    //                 dateRange.isEmpty() || dateRange[0].get('minDate') == null
    //             ) {
    //                 System.debug('⚠️ No invoice data found');
    //                 return;
    //             }

    //             Date minInvoiceDate = (Date) dateRange[0].get('minDate');
    //             Date maxInvoiceDate = (Date) dateRange[0].get('maxDate');

    //             System.debug(
    //                 '📅 Processing snapshots for date range: ' +
    //                     minInvoiceDate +
    //                     ' to ' +
    //                     maxInvoiceDate
    //             );

    //             // Step 3: Process snapshots for all months with invoice data (NO redundant assignments)
    //             Date currentMonth = minInvoiceDate.toStartOfMonth();
    //             Date endMonth = maxInvoiceDate.toStartOfMonth();

    //             while (currentMonth <= endMonth) {
    //                 System.debug(
    //                     'Processing snapshots for: ' + currentMonth.format()
    //                 );

    //                 try {
    //                     processSnapshotsFromInvoices(currentMonth);
    //                 } catch (Exception e) {
    //                     System.debug(
    //                         '❌ Failed to process month ' +
    //                             currentMonth +
    //                             ': ' +
    //                             e.getMessage()
    //                     );
    //                 }

    //                 currentMonth = currentMonth.addMonths(1);
    //             }
    //         } else {
    //             // Process specific month (original behavior)
    //             System.debug(
    //                 'Starting Business Case snapshot processing for: ' +
    //                 snapshotMonth
    //             );

    //             // Step 1: Check if Business Cases are already assigned, if not assign them
    //             Integer existingAssignments = [
    //                 SELECT COUNT()
    //                 FROM Invoice_Line_Item__c
    //                 WHERE Business_Case__c != NULL AND DGroup__c = 'Reagent'
    //             ];

    //             if (existingAssignments == 0) {
    //                 System.debug(
    //                     'No existing assignments found - running Business Case assignment...'
    //                 );
    //                 assignBusinessCasesToInvoices();
    //             } else {
    //                 System.debug(
    //                     'Found ' +
    //                         existingAssignments +
    //                         ' existing assignments - skipping assignment phase'
    //                 );
    //             }

    //             // Step 2: Process snapshots by grouping invoices by Business Case dimensions
    //             processSnapshotsFromInvoices(snapshotMonth);
    //         }
    //     } catch (Exception e) {
    //         System.debug(
    //             'Critical error in processMonthlySnapshots: ' + e.getMessage()
    //         );
    //         throw new AuraHandledException(
    //             'Failed to process monthly snapshots: ' + e.getMessage()
    //         );
    //     }
    // }

    /**
     * Test method to process a single Business Case snapshot
     */
    // public static Business_Case_Sales_Snapshot__c testSingleBusinessCase(
    //     Id businessCaseId,
    //     Date snapshotMonth
    // ) {
    //     try {
    //         System.debug('=== TESTING SINGLE BUSINESS CASE SNAPSHOT ===');
    //         System.debug('Business Case ID: ' + businessCaseId);
    //         System.debug('Snapshot Month: ' + snapshotMonth);

    //         // Get Business Case details
    //         Business_Case__c businessCase = [
    //             SELECT
    //                 Id,
    //                 Name,
    //                 Account__c,
    //                 Account__r.Province__c,
    //                 Account__r.City__c,
    //                 Account__r.AddressLine_1__c,
    //                 Account__r.Addess_Line_2__c,
    //                 Account__r.Postal_Code__c,
    //                 Account__r.Country_Code__c,
    //                 Asset_Number__c,
    //                 Asset_Number__r.Status__c,
    //                 Asset_Number__r.Ship_To_Account__c,
    //                 Asset_Number__r.Ship_To_Account__r.SAP_Customer_Number__c,
    //                 Asset_Number__r.Ship_To_Account__r.Name,
    //                 Asset_Number__r.Ship_To_Account__r.Province__c,
    //                 Asset_Number__r.Ship_To_Account__r.City__c,
    //                 Asset_Number__r.Ship_To_Account__r.AddressLine_1__c,
    //                 Asset_Number__r.Ship_To_Account__r.Addess_Line_2__c,
    //                 Asset_Number__r.Ship_To_Account__r.Postal_Code__c,
    //                 Asset_Number__r.Ship_To_Account__r.Country_Code__c,
    //                 Customer_Number__c,
    //                 Customer_Name__c,
    //                 Supplier_Name__c,
    //                 Technology__c,
    //                 Region__c,
    //                 Monthly_Reagent_Commitment__c,
    //                 Unit_Cost__c,
    //                 Payback_Period__c,
    //                 Status__c,
    //                 Agreement_Date__c,
    //                 Margin_Percent__c
    //             FROM Business_Case__c
    //             WHERE Id = :businessCaseId
    //         ];

    //         System.debug('Business Case: ' + businessCase.Name);
    //         System.debug('Customer: ' + businessCase.Customer_Number__c);
    //         System.debug('Supplier: ' + businessCase.Supplier_Name__c);
    //         System.debug('Technology: ' + businessCase.Technology__c);
    //         System.debug('Status: ' + businessCase.Status__c);

    //         // Create snapshot for this Business Case
    //         Business_Case_Sales_Snapshot__c snapshot = createSnapshotForBusinessCase_old(
    //             businessCase,
    //             snapshotMonth
    //         );

    //         if (snapshot != null) {
    //             // Insert the snapshot
    //             insert snapshot;
    //             System.debug(
    //                 '✅ Successfully created snapshot for BC: ' +
    //                 businessCase.Name
    //             );
    //             System.debug(
    //                 'Monthly Sales: ' + snapshot.Total_Reagent_Sales__c
    //             );
    //             System.debug('YTD Sales: ' + snapshot.YTD_Sales__c);
    //             System.debug('Target Sales: ' + snapshot.Target_Sales__c);
    //             System.debug(
    //                 'Data Quality Score: ' + snapshot.Data_Quality_Score__c
    //             );

    //             return snapshot;
    //         } else {
    //             System.debug('❌ Failed to create snapshot for Business Case');
    //             return null;
    //         }
    //     } catch (Exception e) {
    //         System.debug('Error in testSingleBusinessCase: ' + e.getMessage());
    //         System.debug('Stack trace: ' + e.getStackTraceString());
    //         throw e;
    //     }
    // }

    /**
     * Reassign invoices from Individual Business Cases to their Master Business Case
     * This ensures Master BC snapshots can aggregate all invoice data
     */
    // public static Integer reassignInvoicesToMasterBusinessCases() {
    //     System.debug('=== REASSIGNING INVOICES TO MASTER BUSINESS CASES ===');

    //     // Get all Master BCs with their Individual BCs
    //     List<Business_Case__c> masterBCs = [
    //         SELECT
    //             Id,
    //             Name,
    //             Material_Number__c,
    //             (SELECT Id, Name FROM Business_Cases__r)
    //         FROM Business_Case__c
    //         WHERE
    //             Is_Master__c = TRUE
    //             AND (Status__c LIKE '%Active%'
    //             OR Status__c LIKE '%Revised%'
    //             OR Status__c LIKE '%New%')
    //     ];

    //     System.debug('Found ' + masterBCs.size() + ' Master Business Cases');

    //     Integer totalReassigned = 0;
    //     List<Invoice_Line_Item__c> invoicesToUpdate = new List<Invoice_Line_Item__c>();

    //     for (Business_Case__c master : masterBCs) {
    //         if (master.Business_Cases__r.isEmpty()) {
    //             System.debug(
    //                 '⏭️ Skipping ' + master.Name + ' - No Individual BCs'
    //             );
    //             continue;
    //         }

    //         // Collect Individual BC IDs
    //         Set<Id> individualBcIds = new Set<Id>();
    //         for (Business_Case__c indiv : master.Business_Cases__r) {
    //             individualBcIds.add(indiv.Id);
    //         }

    //         System.debug(
    //             'Processing ' +
    //                 master.Name +
    //                 ' with ' +
    //                 individualBcIds.size() +
    //                 ' Individual BCs'
    //         );

    //         // Find all invoices linked to Individual BCs
    //         List<Invoice_Line_Item__c> invoices = [
    //             SELECT Id, Business_Case__c, Invoice__r.Invoice_Date__c
    //             FROM Invoice_Line_Item__c
    //             WHERE
    //                 Business_Case__c IN :individualBcIds
    //                 AND DGroup__c = 'Reagent'
    //         ];

    //         if (!invoices.isEmpty()) {
    //             System.debug(
    //                 '  Found ' + invoices.size() + ' invoices to reassign'
    //             );

    //             // Reassign to Master BC
    //             for (Invoice_Line_Item__c inv : invoices) {
    //                 inv.Business_Case__c = master.Id;
    //                 invoicesToUpdate.add(inv);
    //                 totalReassigned++;
    //             }
    //         }
    //     }

    //     // Bulk update
    //     if (!invoicesToUpdate.isEmpty()) {
    //         System.debug(
    //             'Updating ' +
    //                 invoicesToUpdate.size() +
    //                 ' invoice assignments...'
    //         );
    //         update invoicesToUpdate;
    //         System.debug(
    //             '✅ Successfully reassigned ' +
    //                 totalReassigned +
    //                 ' invoices to Master BCs'
    //         );
    //     } else {
    //         System.debug('⚠️ No invoices needed reassignment');
    //     }

    //     return totalReassigned;
    // }

    /**
     * OPTIMIZED: Bulk assignment - Single query approach to minimize SOQL usage
     * Uses memory processing instead of per-BC queries for better governor limit compliance
     */
    public static Integer assignBusinessCasesToInvoices() {
        System.debug(
            'Starting OPTIMIZED bulk assignment with single query approach...'
        );

        // Get all active Business Cases
        List<Business_Case__c> activeBusinessCases = [
            SELECT
                Id,
                Name,
                Customer_Number__c,
                Supplier_Name__c,
                Technology__c,
                Machine_Installation__r.bill_to_account__r.SAP_Customer_Number__c,
                Machine_Installation__r.Diagnostic_Machine__r.Vendor__c,
                Machine_Installation__r.Diagnostic_Machine__r.Technology__c,
                Machine_Installation__r.Material_Number__c
            FROM Business_Case__c
            WHERE Is_Master__c = FALSE AND Master_Business_Case__c = NULL
                AND
                (Status__c like '%New%' or Status__c like '%Active%' or Status__c like '%Revised%' )
        ];

        System.debug(
            'Found ' +
                activeBusinessCases.size() +
                ' total Business Cases (all statuses)'
        );

        // Create lookup maps for efficient matching
        Map<String, List<Business_Case__c>> customerToBCMap = new Map<String, List<Business_Case__c>>();
        Map<String, String> bcToMatchingPattern = new Map<String, String>();

        for (Business_Case__c bc : activeBusinessCases) {
            String customerCode = bc.Machine_Installation__r.bill_to_account__r.SAP_Customer_Number__c;
            String supplierCode = extractSupplierCode(
                bc.Machine_Installation__r.Diagnostic_Machine__r.Vendor__c
            );
            String technologyCode = extractTechnologyCode(
                bc.Machine_Installation__r.Diagnostic_Machine__r.Technology__c
            );

            if (
                String.isNotBlank(customerCode) &&
                String.isNotBlank(supplierCode) &&
                String.isNotBlank(technologyCode)
            ) {
                String matchingKey = customerCode;
                String matchingPattern = supplierCode + '-' + technologyCode;

                //customerToBCMap.put(matchingKey, bc);
                if (!customerToBCMap.containsKey(customerCode)) {
                    customerToBCMap.put(
                        customerCode,
                        new List<Business_Case__c>()
                    );
                }
                // else
                // {
                customerToBCMap.get(customerCode).add(bc);
                // }
                System.debug(
                    '>>>>BusinessCaseSnapshotService-->assignBusinessCasesToInvoices-->customerToBCMap: ' +
                    customerToBCMap
                );
                bcToMatchingPattern.put(bc.Id, matchingPattern);

                System.debug(
                    'Registered BC: ' +
                        bc.Name +
                        ' | Customer: ' +
                        customerCode +
                        ' | Pattern: ' +
                        matchingPattern
                );
            } else {
                System.debug(
                    '⚠️ Skipping BC: ' + bc.Name + ' - Missing required codes'
                );
            }
        }

        // SINGLE BULK QUERY: Get all unassigned reagent invoices
        System.debug(
            'Executing single bulk query for all unassigned invoices...'
        );
        System.debug(
            '>>>>BusinessCaseSnapshotService-->assignBusinessCasesToInvoices-->customerToBCMap:' +
            customerToBCMap.keySet()
        );
        System.debug(
            '>>>>BusinessCaseSnapshotService-->assignBusinessCasesToInvoices-->customerToBCMap:' +
            customerToBCMap.size()
        );
        List<Invoice_Line_Item__c> allUnassignedInvoices = [
            SELECT Id, Invoice_Customer_Code__c, AG_OG__c, Business_Case__c
            FROM Invoice_Line_Item__c
            WHERE
                Business_Case__c = NULL
                AND DGroup__c = 'Reagent'
                AND Invoice_Value__c != NULL
                AND Invoice_Customer_Code__c IN :customerToBCMap.keySet()
            //LIMIT 10000
        ];

        System.debug(
            'Found ' +
                allUnassignedInvoices.size() +
                ' unassigned invoices to process'
        );

        Integer totalAssigned = 0;
        List<Invoice_Line_Item__c> allInvoicesToUpdate = new List<Invoice_Line_Item__c>();

        // Memory-based matching: Much faster than individual queries
        for (Invoice_Line_Item__c invoice : allUnassignedInvoices) {
            List<Business_Case__c> possibleBCs = customerToBCMap.get(
                invoice.Invoice_Customer_Code__c
            );
            System.debug(
                '>>>>BusinessCaseSnapshotService-->assignBusinessCasesToInvoices-->possibleBCs :' +
                possibleBCs
            );
            System.debug(
                '>>>>BusinessCaseSnapshotService-->assignBusinessCasesToInvoices-->possibleBCs size:' +
                possibleBCs.size()
            );
            if (possibleBCs != null) {
                for (Business_Case__c bc : possibleBCs) {
                    String requiredPattern = bcToMatchingPattern.get(bc.Id);
                    System.debug(
                        '>>>>BusinessCaseSnapshotService-->assignBusinessCasesToInvoices-->possibleBCs required pattern:' +
                        requiredPattern
                    );
                    System.debug(
                        '>>>>BusinessCaseSnapshotService-->assignBusinessCasesToInvoices-->possibleBCs invoice.AG_OG__c:' +
                        invoice.AG_OG__c
                    );
                    if (
                        String.isNotBlank(invoice.AG_OG__c) &&
                        invoice.AG_OG__c.startsWith(requiredPattern)
                    ) {
                        invoice.Business_Case__c = bc.Id;
                        allInvoicesToUpdate.add(invoice);
                        totalAssigned++;
                        break; // stop once we assign a BC
                    }
                }
            }

            // Business_Case__c matchingBC = customerToBCMap.get(
            //   invoice.Invoice_Customer_Code__c
            // );
            //   System.debug('>>>>BusinessCaseSnapshotService-->assignBusinessCasesToInvoices-->allUnassignedInvoices matchingBC:'+matchingBC);

            // if (matchingBC != null)
            // {
            //   String requiredPattern = bcToMatchingPattern.get(matchingBC.Id);
            //   System.debug('>>>>BusinessCaseSnapshotService-->assignBusinessCasesToInvoices-->allUnassignedInvoices requiredPattern:'+requiredPattern);
            //   System.debug('>>>>BusinessCaseSnapshotService-->assignBusinessCasesToInvoices-->allUnassignedInvoices invoice AG OG:'+invoice.AG_OG__c);
            //   if (
            //     String.isNotBlank(invoice.AG_OG__c) &&
            //     invoice.AG_OG__c.startsWith(requiredPattern)
            //   ) {
            //     invoice.Business_Case__c = matchingBC.Id;
            //     allInvoicesToUpdate.add(invoice);
            //     totalAssigned++;
            //   }
            // }
        }

        // Bulk update all assignments in ONE DML operation
        if (!allInvoicesToUpdate.isEmpty()) {
            System.debug(
                'Updating ' +
                    allInvoicesToUpdate.size() +
                    ' invoices with Business Case assignments...'
            );
            update allInvoicesToUpdate;
            System.debug(
                '✅ Successfully assigned ' +
                    totalAssigned +
                    ' invoices to Business Cases'
            );
        }

        return totalAssigned;
    }

    //assign Master Business Cases To Invoices
    public static Integer assignMasterBusinessCasesToInvoices() {
        System.debug(
            'Starting OPTIMIZED bulk assignment with single query approach...'
        );

        // Get all active Business Cases
        List<Business_Case__c> activeBusinessCases = [
            SELECT
                Id,
                Name,
                Customer_Numbera__c,
                Vendor__c,
                Technologyaa__c,
                Machine_Installation__r.bill_to_account__r.SAP_Customer_Number__c,
                Machine_Installation__r.Diagnostic_Machine__r.Vendor__c,
                Machine_Installation__r.Diagnostic_Machine__r.Technology__c,
                Material_Number__c
            FROM Business_Case__c
            WHERE
                RecordType.Name = 'Master Business Case'
                AND (Status__c LIKE '%Active%'
                OR Status__c LIKE '%Revised%'
                OR Status__c LIKE '%New%')
        ];

        System.debug(
            'Found ' +
                activeBusinessCases.size() +
                ' total Business Cases (all statuses)'
        );

        List<Business_Case__c> childbuinesscases = [
            SELECT
                Id,
                Name,
                Customer_Numbera__c,
                Vendor__c,
                Technologyaa__c,
                Machine_Installation__r.bill_to_account__r.SAP_Customer_Number__c,
                Machine_Installation__r.Diagnostic_Machine__r.Vendor__c,
                Machine_Installation__r.Diagnostic_Machine__r.Technology__c,
                Material_Number__c
            FROM Business_Case__c
            WHERE
                Master_Business_Case__c IN :activeBusinessCases
                AND (Status__c LIKE '%Active%'
                OR Status__c LIKE '%Revised%'
                OR Status__c LIKE '%New%')
        ];

        Map<Id, List<Business_Case__c>> listofchild = new Map<Id, List<Business_Case__c>>();
        for (Business_Case__c childbc : [
            SELECT
                Id,
                Name,
                Customer_Numbera__c,
                Vendor__c,
                Technologyaa__c,
                Machine_Installation__r.bill_to_account__r.SAP_Customer_Number__c,
                Machine_Installation__r.Diagnostic_Machine__r.Vendor__c,
                Machine_Installation__r.Diagnostic_Machine__r.Technology__c,
                Material_Number__c
            FROM Business_Case__c
            WHERE
                Master_Business_Case__c IN :activeBusinessCases
                AND (Status__c LIKE '%Active%'
                OR Status__c LIKE '%Revised%'
                OR Status__c LIKE '%New%')
        ]) {
        }

        System.debug(
            '>>>BusinessCaseSanpshotService-->assignMasterBusinessCasesToInvoices-->Found ' +
                activeBusinessCases.size() +
                ' total Business Cases (all statuses)'
        );

        // Create lookup maps for efficient matching
        Map<String, List<Business_Case__c>> customerToBCMap = new Map<String, List<Business_Case__c>>();
        Map<String, String> bcToMatchingPattern = new Map<String, String>();

        for (Business_Case__c bc : activeBusinessCases) {
            //String customerCode = bc.Machine_Installation__r.bill_to_account__r.SAP_Customer_Number__c;
            String customerCode = bc.Customer_Numbera__c;
            String materialNo = bc.Material_Number__c;
            String supplierCode = extractSupplierCode(bc.Vendor__c);
            String technologyCode = extractTechnologyCode(bc.Technologyaa__c);

            if (
                String.isNotBlank(customerCode) &&
                String.isNotBlank(supplierCode) &&
                String.isNotBlank(technologyCode)
            ) {
                String matchingKey = customerCode;
                String matchingPattern = supplierCode + '-' + technologyCode;

                //customerToBCMap.put(matchingKey, bc);
                if (!customerToBCMap.containsKey(customerCode)) {
                    customerToBCMap.put(
                        customerCode,
                        new List<Business_Case__c>()
                    );
                }
                // else
                // {
                customerToBCMap.get(customerCode).add(bc);
                // }

                bcToMatchingPattern.put(bc.Id, matchingPattern);

                System.debug(
                    'Registered BC: ' +
                        bc.Name +
                        ' | Customer: ' +
                        customerCode +
                        ' | Pattern: ' +
                        matchingPattern
                );
            } else {
                System.debug(
                    '⚠️ Skipping BC: ' + bc.Name + ' - Missing required codes'
                );
            }
        }

        // SINGLE BULK QUERY: Get all unassigned reagent invoices
        System.debug(
            'Executing single bulk query for all unassigned invoices...'
        );
        System.debug(
            '>>>>BusinessCaseSnapshotService-->assignBusinessCasesToInvoices-->customerToBCMap:' +
            customerToBCMap.keySet()
        );
        System.debug(
            '>>>>BusinessCaseSnapshotService-->assignBusinessCasesToInvoices-->customerToBCMap:' +
            customerToBCMap.size()
        );
        List<Invoice_Line_Item__c> allUnassignedInvoices = [
            SELECT
                Id,
                Invoice_Customer_Code__c,
                AG_OG__c,
                Business_Case__c,
                Invoice_Material_No__c
            FROM Invoice_Line_Item__c
            WHERE
                Business_Case__c = NULL
                AND DGroup__c = 'Reagent'
                AND Invoice_Value__c != NULL
                AND Invoice_Customer_Code__c IN :customerToBCMap.keySet()
            //LIMIT 10000
        ];

        System.debug(
            'Found ' +
                allUnassignedInvoices.size() +
                ' unassigned invoices to process'
        );

        Integer totalAssigned = 0;
        List<Invoice_Line_Item__c> allInvoicesToUpdate = new List<Invoice_Line_Item__c>();

        // Memory-based matching: Much faster than individual queries
        for (Invoice_Line_Item__c invoice : allUnassignedInvoices) {
            List<Business_Case__c> possibleBCs = customerToBCMap.get(
                invoice.Invoice_Customer_Code__c
            );
            System.debug(
                '>>>>BusinessCaseSnapshotService-->assignBusinessCasesToInvoices-->possibleBCs :' +
                possibleBCs
            );
            System.debug(
                '>>>>BusinessCaseSnapshotService-->assignBusinessCasesToInvoices-->possibleBCs size:' +
                possibleBCs.size()
            );
            if (possibleBCs != null) {
                for (Business_Case__c bc : possibleBCs) {
                    String requiredPattern = bcToMatchingPattern.get(bc.Id);
                    System.debug(
                        '>>>>BusinessCaseSnapshotService-->assignBusinessCasesToInvoices-->possibleBCs required pattern:' +
                        requiredPattern
                    );
                    System.debug(
                        '>>>>BusinessCaseSnapshotService-->assignBusinessCasesToInvoices-->possibleBCs invoice.AG_OG__c:' +
                        invoice.AG_OG__c
                    );
                    if (
                        String.isNotBlank(invoice.AG_OG__c) &&
                        invoice.AG_OG__c.startsWith(requiredPattern)
                    ) {
                        invoice.Business_Case__c = bc.Id;
                        allInvoicesToUpdate.add(invoice);
                        totalAssigned++;
                        System.debug(
                            '  ✅ Matched invoice ' +
                                invoice.Id +
                                ' to BC ' +
                                bc.Name
                        );
                        break; // stop once we assign a BC
                    }
                }
            }

            // Business_Case__c matchingBC = customerToBCMap.get(
            //   invoice.Invoice_Customer_Code__c
            // );
            //   System.debug('>>>>BusinessCaseSnapshotService-->assignBusinessCasesToInvoices-->allUnassignedInvoices matchingBC:'+matchingBC);

            // if (matchingBC != null)
            // {
            //   String requiredPattern = bcToMatchingPattern.get(matchingBC.Id);
            //   System.debug('>>>>BusinessCaseSnapshotService-->assignBusinessCasesToInvoices-->allUnassignedInvoices requiredPattern:'+requiredPattern);
            //   System.debug('>>>>BusinessCaseSnapshotService-->assignBusinessCasesToInvoices-->allUnassignedInvoices invoice AG OG:'+invoice.AG_OG__c);
            //   if (
            //     String.isNotBlank(invoice.AG_OG__c) &&
            //     invoice.AG_OG__c.startsWith(requiredPattern)
            //   ) {
            //     invoice.Business_Case__c = matchingBC.Id;
            //     allInvoicesToUpdate.add(invoice);
            //     totalAssigned++;
            //   }
            // }
        }

        // Bulk update all assignments in ONE DML operation
        if (!allInvoicesToUpdate.isEmpty()) {
            System.debug(
                'Updating ' +
                    allInvoicesToUpdate.size() +
                    ' invoices with Business Case assignments...'
            );
            update allInvoicesToUpdate;
            System.debug(
                '✅ Successfully assigned ' +
                    totalAssigned +
                    ' invoices to Business Cases'
            );
        }

        return totalAssigned;
    }

    /**
     * Extract supplier code from Business Case supplier name
     * Examples: "A - Boule" -> "A", "YHLO - YHLO" -> "YHLO", "E - VitalScientific" -> "E"
     */
    public static String extractSupplierCode(String supplierName) {
        if (String.isBlank(supplierName)) {
            return '';
        }

        // Handle formats like "A - Boule", "YHLO - YHLO", "E - VitalScientific"
        if (supplierName.contains(' - ')) {
            return supplierName.split(' - ')[0].trim();
        }

        // If no delimiter, return the whole string (fallback)
        return supplierName.trim();
    }

    /**
     * Extract technology code from Business Case technology name
     * Examples: "HM - Hematology" -> "HM", "IMA - Immunoassay" -> "IMA", "CC - Clinical Chemistry" -> "CC"
     */
    public static String extractTechnologyCode(String technologyName) {
        if (String.isBlank(technologyName)) {
            return '';
        }

        // Handle formats like "HM - Hematology", "IMA - Immunoassay", "CC - Clinical Chemistry"
        if (technologyName.contains(' - ')) {
            return technologyName.split(' - ')[0].trim();
        }

        // If no delimiter, return the whole string (fallback)
        return technologyName.trim();
    }

    /**
     * Step 2: Process snapshots from invoices - OPTIMIZED for governor limits
     */
    // public static void processSnapshotsFromInvoices(Date snapshotMonth) {
    //     System.debug('Processing snapshots from invoice data - OPTIMIZED...');

    //     Date monthStart = snapshotMonth.toStartOfMonth();
    //     Date monthEnd = monthStart.addMonths(1).addDays(-1);

    //     // Get ALL Business Cases with invoice activity in ONE query instead of separate aggregate
    //     List<Invoice_Line_Item__c> monthlyInvoices = [
    //         SELECT Business_Case__c, Invoice_Value__c
    //         FROM Invoice_Line_Item__c
    //         WHERE
    //             Invoice__r.Invoice_Date__c >= :monthStart
    //             AND Invoice__r.Invoice_Date__c <= :monthEnd
    //             AND Business_Case__c != NULL
    //             AND Invoice_Value__c != NULL
    //     ];

    //     if (monthlyInvoices.isEmpty()) {
    //         System.debug(
    //             'No invoices with Business Case assignments found for this month'
    //         );
    //         return;
    //     }

    //     // Get unique Business Case IDs from the results
    //     Set<Id> activeBusinessCaseIds = new Set<Id>();
    //     for (Invoice_Line_Item__c invoice : monthlyInvoices) {
    //         activeBusinessCaseIds.add(invoice.Business_Case__c);
    //     }

    //     System.debug(
    //         'Found ' +
    //             activeBusinessCaseIds.size() +
    //             ' Business Cases with invoice activity'
    //     );

    //     // Get Business Case details in ONE query
    //     Map<Id, Business_Case__c> businessCaseMap = new Map<Id, Business_Case__c>(
    //         [
    //             SELECT
    //                 Id,
    //                 Name,
    //                 Account__c,
    //                 Account__r.Province__c,
    //                 Account__r.City__c,
    //                 Account__r.AddressLine_1__c,
    //                 Account__r.Addess_Line_2__c,
    //                 Account__r.Postal_Code__c,
    //                 Account__r.Country_Code__c,
    //                 Asset_Number__c,
    //                 Asset_Number__r.Status__c,
    //                 Asset_Number__r.Ship_To_Account__c,
    //                 Asset_Number__r.Ship_To_Account__r.SAP_Customer_Number__c,
    //                 Asset_Number__r.Ship_To_Account__r.Name,
    //                 Asset_Number__r.Ship_To_Account__r.Province__c,
    //                 Asset_Number__r.Ship_To_Account__r.City__c,
    //                 Asset_Number__r.Ship_To_Account__r.AddressLine_1__c,
    //                 Asset_Number__r.Ship_To_Account__r.Addess_Line_2__c,
    //                 Asset_Number__r.Ship_To_Account__r.Postal_Code__c,
    //                 Asset_Number__r.Ship_To_Account__r.Country_Code__c,
    //                 Customer_Number__c,
    //                 Customer_Name__c,
    //                 Supplier_Name__c,
    //                 Technology__c,
    //                 Region__c,
    //                 Monthly_Reagent_Commitment__c,
    //                 Unit_Cost__c,
    //                 Payback_Period__c,
    //                 Status__c,
    //                 Agreement_Date__c,
    //                 Margin_Percent__c,
    //                 Quantity__c,
    //                 SAP_Material_Number__c,
    //                 Machine_Type__c
    //             FROM Business_Case__c
    //             WHERE Id IN :activeBusinessCaseIds
    //         ]
    //     );

    //     // Process snapshots for each Business Case
    //     List<Business_Case_Sales_Snapshot__c> snapshots = new List<Business_Case_Sales_Snapshot__c>();
    //     List<Business_Case_Exception__c> exceptions = new List<Business_Case_Exception__c>();

    //     for (Id businessCaseId : activeBusinessCaseIds) {
    //         try {
    //             Business_Case__c businessCase = businessCaseMap.get(
    //                 businessCaseId
    //             );
    //             Business_Case_Sales_Snapshot__c snapshot = createSnapshotForBusinessCase_old(
    //                 businessCase,
    //                 snapshotMonth
    //             );
    //             if (snapshot != null) {
    //                 snapshots.add(snapshot);
    //             }
    //         } catch (Exception e) {
    //             System.debug(
    //                 'Error processing Business Case ' +
    //                     businessCaseId +
    //                     ': ' +
    //                     e.getMessage()
    //             );
    //             exceptions.add(
    //                 createException(
    //                     businessCaseId,
    //                     e.getMessage(),
    //                     'Processing Error'
    //                 )
    //             );
    //         }
    //     }

    //     // Insert/Update snapshots using proper upsert logic (prevents duplicates)
    //     if (!snapshots.isEmpty()) {
    //         try {
    //             // Query for existing snapshots to enable proper upsert behavior
    //             Map<String, Business_Case_Sales_Snapshot__c> existingSnapshots = new Map<String, Business_Case_Sales_Snapshot__c>();

    //             Set<Id> businessCaseIds = new Set<Id>();
    //             for (Business_Case_Sales_Snapshot__c snapshot : snapshots) {
    //                 businessCaseIds.add(snapshot.Business_Case__c);
    //             }

    //             // Get existing snapshots for the same month and business cases
    //             for (Business_Case_Sales_Snapshot__c existing : [
    //                 SELECT Id, Business_Case__c, Snapshot_Month__c
    //                 FROM Business_Case_Sales_Snapshot__c
    //                 WHERE
    //                     Business_Case__c IN :businessCaseIds
    //                     AND Snapshot_Month__c = :snapshotMonth
    //             ]) {
    //                 String key =
    //                     existing.Business_Case__c +
    //                     '_' +
    //                     existing.Snapshot_Month__c.format();
    //                 existingSnapshots.put(key, existing);
    //             }

    //             // Update snapshots with existing IDs if found
    //             for (Business_Case_Sales_Snapshot__c snapshot : snapshots) {
    //                 String key =
    //                     snapshot.Business_Case__c +
    //                     '_' +
    //                     snapshot.Snapshot_Month__c.format();
    //                 if (existingSnapshots.containsKey(key)) {
    //                     snapshot.Id = existingSnapshots.get(key).Id;
    //                 }
    //             }

    //             // Now upsert will work properly - updates existing records, inserts new ones
    //             Database.UpsertResult[] results = Database.upsert(
    //                 snapshots,
    //                 false
    //             );

    //             Integer successCount = 0;
    //             Integer failureCount = 0;

    //             for (Database.UpsertResult result : results) {
    //                 if (result.isSuccess()) {
    //                     successCount++;
    //                 } else {
    //                     failureCount++;
    //                     // Handle upsert failures
    //                     for (Database.Error error : result.getErrors()) {
    //                         String errorMsg =
    //                             'Upsert failed: ' + error.getMessage();
    //                         // Find the failed snapshot to get Business Case ID
    //                         Integer failedIndex = 0; // This would need proper index tracking
    //                         if (failedIndex < snapshots.size()) {
    //                             Id businessCaseId = snapshots[failedIndex]
    //                                 .Business_Case__c;
    //                             exceptions.add(
    //                                 createException(
    //                                     businessCaseId,
    //                                     errorMsg,
    //                                     'Upsert Error'
    //                                 )
    //                             );
    //                         }
    //                     }
    //                 }
    //             }

    //             System.debug(
    //                 'Upsert completed: ' +
    //                     successCount +
    //                     ' success, ' +
    //                     failureCount +
    //                     ' failures'
    //             );
    //         } catch (DmlException e) {
    //             // Handle any unexpected DML failures
    //             for (Integer i = 0; i < e.getNumDml(); i++) {
    //                 String errorMsg = 'DML failed: ' + e.getDmlMessage(i);
    //                 Id businessCaseId = snapshots[e.getDmlIndex(i)]
    //                     .Business_Case__c;
    //                 exceptions.add(
    //                     createException(businessCaseId, errorMsg, 'DML Error')
    //                 );
    //             }
    //         }
    //     }

    //     // Insert exceptions if any
    //     if (!exceptions.isEmpty()) {
    //         insert exceptions;
    //         System.debug('Created ' + exceptions.size() + ' exception records');
    //     }

    //     System.debug(
    //         'Successfully processed ' + snapshots.size() + ' snapshots'
    //     );
    // }

    /**
     * Create a map of Business Cases for quick lookup during invoice matching
     */
    public static Map<String, Business_Case__c> createBusinessCaseMap() {
        List<Business_Case__c> businessCases = [
            SELECT
                Id,
                Name,
                Customer_Number__c,
                Supplier_Name__c,
                Technology__c,
                Status__c
            FROM Business_Case__c
        ];

        Map<String, Business_Case__c> businessCaseMap = new Map<String, Business_Case__c>();

        for (Business_Case__c businessCase : businessCases) {
            String key = createBusinessCaseMatchingKey(
                businessCase.Customer_Number__c,
                businessCase.Supplier_Name__c,
                businessCase.Technology__c
            );
            businessCaseMap.put(key, businessCase);

            // Debug the Business Case keys being created
            System.debug(
                'Business Case key: "' + key + '" → BC: ' + businessCase.Name
            );
            System.debug(
                '  Customer: "' +
                    businessCase.Customer_Number__c +
                    '", Supplier: "' +
                    businessCase.Supplier_Name__c +
                    '", Technology: "' +
                    businessCase.Technology__c +
                    '"'
            );
        }

        System.debug(
            'Created Business Case map with ' +
                businessCaseMap.size() +
                ' entries'
        );
        return businessCaseMap;
    }

    /**
     * Find the Business Case key for an invoice record
     * Uses Customer Code + Vendor Code (from AG_OG__c) + Technology Code (from AG_OG__c)
     */
    public static String findBusinessCaseKeyForInvoice(
        Invoice_Line_Item__c invoice
    ) {
        // Extract customer code
        String customerCode = invoice.Invoice_Customer_Code__c;

        // Extract vendor and technology codes from AG_OG__c (format: "VendorCode-TechnologyCode-*")
        String[] agogParts = extractVendorTechnologyFromAGOG(invoice.AG_OG__c);
        String vendorCode = agogParts[0];
        String technologyCode = agogParts[1];

        String matchingKey = createBusinessCaseMatchingKey(
            customerCode,
            vendorCode,
            technologyCode
        );

        System.debug(
            'Generated matching key: "' +
                matchingKey +
                '" for Invoice: ' +
                invoice.Id
        );
        System.debug(
            '  Customer: "' +
                customerCode +
                '", Vendor: "' +
                vendorCode +
                '", Technology: "' +
                technologyCode +
                '"'
        );

        return matchingKey;
    }

    /**
     * Extract vendor and technology codes from AG_OG__c field
     * Format: "VendorCode-TechnologyCode-*" (always has 2 dashes)
     * Returns: [vendorCode, technologyCode]
     */
    private static String[] extractVendorTechnologyFromAGOG(String agogValue) {
        if (String.isBlank(agogValue)) {
            return new List<String>{ '', '' };
        }

        String[] parts = agogValue.split('-');

        // Debug the parsing
        System.debug('AG_OG__c parsing: "' + agogValue + '" → Parts: ' + parts);

        if (parts.size() >= 2) {
            String vendorCode = parts[0].trim();
            String technologyCode = parts[1].trim();
            System.debug(
                'Extracted: Vendor="' +
                    vendorCode +
                    '", Technology="' +
                    technologyCode +
                    '"'
            );
            return new List<String>{ vendorCode, technologyCode };
        }

        // If format is unexpected, log exception and return empty values
        System.debug(
            'Unexpected AG_OG__c format: ' +
                agogValue +
                ' (parts count: ' +
                parts.size() +
                ')'
        );
        return new List<String>{ '', '' };
    }

    /**
     * Extract code from picklist value (format: "CODE - Description")
     * Used for Business Case picklist fields
     */
    private static String extractCodeFromPicklist(String picklistValue) {
        if (String.isBlank(picklistValue)) {
            return '';
        }

        // Find the first occurrence of " - " and take everything before it
        Integer dashIndex = picklistValue.indexOf(' - ');
        if (dashIndex > 0) {
            return picklistValue.substring(0, dashIndex).trim();
        }

        // If no " - " found, return the whole value trimmed
        return picklistValue.trim();
    }

    /**
     * Create Business Case matching key (without month for matching)
     */
    public static String createBusinessCaseMatchingKey(
        String customerCode,
        String vendorCode,
        String technologyCode
    ) {
        // Extract codes from picklist values if they contain " - "
        String extractedVendorCode = extractCodeFromPicklist(vendorCode);
        String extractedTechnologyCode = extractCodeFromPicklist(
            technologyCode
        );

        String key =
            (customerCode != null ? customerCode.trim() : '') +
            '|' +
            (extractedVendorCode != null ? extractedVendorCode.trim() : '') +
            '|' +
            (extractedTechnologyCode != null
                ? extractedTechnologyCode.trim()
                : '');

        System.debug(
            'Creating BC key from: Customer="' +
                customerCode +
                '", Vendor="' +
                vendorCode +
                '" → "' +
                extractedVendorCode +
                '", Technology="' +
                technologyCode +
                '" → "' +
                extractedTechnologyCode +
                '" = "' +
                key +
                '"'
        );

        return key;
    }

    /**
     * Create exception record for invoice matching issues
     */
    public static Business_Case_Exception__c createInvoiceException(
        Id invoiceId,
        String errorMessage,
        String exceptionType
    ) {
        Business_Case_Exception__c exceptionRecord = new Business_Case_Exception__c();
        exceptionRecord.Invoice_Line_Item__c = invoiceId; // We'll need to add this field
        exceptionRecord.Error_Message__c = errorMessage;
        exceptionRecord.Exception_Type__c = exceptionType;
        exceptionRecord.Exception_Date__c = DateTime.now();
        exceptionRecord.Resolution_Status__c = 'Open';

        return exceptionRecord;
    }

    /**
     * Create snapshot for a specific Business Case and month
     */
    public static Business_Case_Sales_Snapshot__c createSnapshotForBusinessCase(
        Business_Case__c businessCase,
        Date snapshotMonth,
        InvoiceAggregationResult invoiceData,
        Decimal ytdSales,
        Decimal totalSalesTillDate
    ) {
        try {
            // Get invoice data for this Business Case and month
            //InvoiceAggregationResult invoiceData = invoiceData;

            // Calculate YTD sales
            //Decimal ytdSales = ytdSales;
            System.debug(
                '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase'
            );
            // Create snapshot record
            Business_Case_Sales_Snapshot__c snapshot = new Business_Case_Sales_Snapshot__c();

            // Core identifiers - using Business Case ID + Month instead of complex key
            snapshot.Business_Case__c = businessCase.Id;
            snapshot.Snapshot_Month__c = snapshotMonth;
            snapshot.Snapshot_Created_Date__c = Date.today();
            snapshot.Monthly_Commitments__c = businessCase.Monthly_Reagent_Commitment__c;

            // Business Case dimensions
            System.debug(
                '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase-->businessCase.Customer_Number__c: ' +
                businessCase.Machine_Installation__r.SAP_Account_No_Bill_To__c
            );
            System.debug(
                '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase-->businessCase.Customer_Name__c: ' +
                businessCase.Machine_Installation__r.bill_to_account__r.Name
            );
            System.debug(
                '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase-->businessCase.Machine_Installation__r.Diagnostic_Machine__r.Vendor__c: ' +
                businessCase.Machine_Installation__r.Diagnostic_Machine__r.Vendor__c
            );
            System.debug(
                '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase-->businessCase.Machine_Installation__r.Diagnostic_Machine__r.Technology__c: ' +
                businessCase.Machine_Installation__r.Diagnostic_Machine__r.Technology__c
            );
            System.debug(
                '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase-->businessCase: ' +
                businessCase.Id
            );
            System.debug(
                '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase-->businessCase Name: ' +
                businessCase.Name
            );
            snapshot.Customer_Code__c = businessCase.Machine_Installation__r.SAP_Account_No_Bill_To__c !=
                null
                ? businessCase.Machine_Installation__r.SAP_Account_No_Bill_To__c
                : 'Unknown';
            snapshot.Customer_Name__c = businessCase.Machine_Installation__r.bill_to_account__r.Name !=
                null
                ? businessCase.Machine_Installation__r.bill_to_account__r.Name
                : 'Unknown';
            snapshot.Vendor__c = businessCase.Machine_Installation__r.Diagnostic_Machine__r.Vendor__c !=
                null
                ? businessCase.Machine_Installation__r.Diagnostic_Machine__r.Vendor__c
                : 'Unknown';
            snapshot.Technology__c = businessCase.Machine_Installation__r.Diagnostic_Machine__r.Technology__c !=
                null
                ? businessCase.Machine_Installation__r.Diagnostic_Machine__r.Technology__c
                : 'Unknown';
            snapshot.Region__c = businessCase.Region__c != null
                ? businessCase.Region__c
                : '';

            System.debug(
                '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase-->Region Set'
            );
            // Additional Business Case Information
            snapshot.Material_Number__c = businessCase.Machine_Installation__r.Material_Number__c;
            snapshot.Material_Description__c = businessCase.Machine_Type__c;

            // Business Case Name and Status (for snapshot-only dashboard architecture)
            snapshot.Business_Case_Name__c = businessCase.Name;
            snapshot.Business_Case_Status__c = businessCase.Status__c;
            snapshot.Machine_Status__c = businessCase.Machine_Installation__r.Status__c;

            // Customer Address Information - Capture both Bill To and Ship To Account addresses

            // Bill To Account address (direct Account on Business Case)
            snapshot.Customer_Province__c = businessCase.Machine_Installation__r.bill_to_account__r.Province__c;
            snapshot.Customer_City__c = businessCase.Machine_Installation__r.bill_to_account__r.City__c;
            snapshot.Customer_AddressLine1__c = businessCase.Machine_Installation__r.bill_to_account__r.AddressLine_1__c;
            snapshot.Customer_AddressLine2__c = '';
            snapshot.Customer_Postal_Code__c = businessCase.Machine_Installation__r.bill_to_account__r.Postal_Code__c;
            snapshot.Customer_Country__c = businessCase.Machine_Installation__r.bill_to_account__r.Country_Code__c;
            System.debug(
                '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase-->Customer Set'
            );
            // Ship To Account address (from Asset → Ship To Account)
            if (
                businessCase.Asset_Number__c != null &&
                businessCase.Asset_Number__r.Ship_To_Account__c != null
            ) {
                snapshot.Ship_To_Customer_Number__c = businessCase.Asset_Number__r.Ship_To_Account__r.SAP_Customer_Number__c;
                snapshot.Ship_To_Customer_Name__c = businessCase.Asset_Number__r.Ship_To_Account__r.Name;
                snapshot.Ship_To_Province__c = businessCase.Asset_Number__r.Ship_To_Account__r.Province__c;
                snapshot.Ship_To_City__c = businessCase.Asset_Number__r.Ship_To_Account__r.City__c;
                snapshot.Ship_To_AddressLine1__c = businessCase.Asset_Number__r.Ship_To_Account__r.AddressLine_1__c;
                snapshot.Ship_To_Address_Line_2__c = businessCase.Asset_Number__r.Ship_To_Account__r.Addess_Line_2__c;

                snapshot.Ship_To_Postal_Code__c = businessCase.Asset_Number__r.Ship_To_Account__r.Postal_Code__c;
                snapshot.Ship_To_Country__c = businessCase.Asset_Number__r.Ship_To_Account__r.Country_Code__c;
            }

            // Sales metrics
            snapshot.Total_Reagent_Sales__c = invoiceData.totalSales;
            System.debug(
                '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase-->Total_Reagent_Sales__c Set'
            );
            // Machine count based on Business Case quantity (default to 1 if empty/invalid)
            Decimal quantity = 1; // Default value
            if (String.isNotBlank(businessCase.Quantity__c)) {
                try {
                    quantity = Decimal.valueOf(businessCase.Quantity__c);
                    if (quantity <= 0) {
                        quantity = 1; // Ensure positive value
                    }
                } catch (Exception e) {
                    System.debug(
                        'Invalid quantity value for BC ' +
                            businessCase.Name +
                            ': ' +
                            businessCase.Quantity__c
                    );
                    quantity = 1; // Fallback to 1 if parsing fails
                }
            }
            System.debug(
                '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase-->Quantity Set'
            );
            snapshot.Machine_Count__c = quantity;
            System.debug(
                '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase-->Machine Count Set'
            );
            snapshot.Source_Invoice_Count__c = invoiceData.invoiceCount;
            snapshot.YTD_Sales__c = ytdSales;

             Integer currentmonth = Datetime.now().month();

            if(currentmonth != null)
            {
                if(currentmonth > 0 && currentmonth < 2)
                {
                    snapshot.Avg_YTD_Sales_Per_Month__c = ytdSales / currentmonth;
                }
                else if(currentmonth > 1 )
                {
                    snapshot.Avg_YTD_Sales_Per_Month__c = ytdSales / (currentmonth-1);
                }
            }

            // Targets and commitments
            snapshot.Target_Sales__c = businessCase.Monthly_Reagent_Commitment__c;
            // Note: Target_Achievement_Percent__c is auto-calculated via formula field
            System.debug(
                '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase-->Target_Sales__c Set'
            );
            // ==================== ENHANCED ANALYTICS FIELDS ====================

            // Calculate contract performance metrics using Agreement_Date__c
            Integer contractMonthsElapsed = calculateMonthsElapsed(
                businessCase.Agreement_Date__c, // Use proper contract start date
                snapshotMonth
            );
            System.debug(
                '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase-->contractMonthsElapsed Set : ' +
                contractMonthsElapsed
            );
            System.debug(
                '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase-->totalSalesTillDate Set : ' +
                totalSalesTillDate
            );
            // Decimal totalSalesTillDate = totalSalesTillDate;
            Decimal avgSalesPerMonth = 0;
            if (totalSalesTillDate != null) {
                if (totalSalesTillDate > 0) {
                    avgSalesPerMonth = contractMonthsElapsed > 0
                        ? totalSalesTillDate / contractMonthsElapsed
                        : 0;
                }
            } else {
                avgSalesPerMonth = contractMonthsElapsed > 0
                    ? invoiceData.totalSales / contractMonthsElapsed
                    : 0;
            }

            System.debug(
                '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase-->avgSalesPerMonth Set'
            );
            Decimal deficitCostCovered = calculateDeficitCostCovered(
                ytdSales,
                businessCase.Monthly_Reagent_Commitment__c,
                contractMonthsElapsed
            );
            System.debug(
                '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase-->deficitCostCovered Set'
            );
            String performanceStatus = determinePerformanceStatus(
                //avgSalesPerMonth
                invoiceData.totalSales,
                businessCase.Monthly_Reagent_Commitment__c
            );
            System.debug(
                '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase-->performanceStatus Set'
            );

            if (totalSalesTillDate == null) {
                totalSalesTillDate = invoiceData.totalSales;
            } else if (totalSalesTillDate <= 0) {
                totalSalesTillDate = invoiceData.totalSales;
            }
            // Enhanced Analytics Fields - Production Ready
            snapshot.Total_Reagent_Sales_Till_Date__c = totalSalesTillDate;
            snapshot.Contract_Months_Elapsed__c = contractMonthsElapsed;
            snapshot.Avg_Reagent_Sales_Per_Month__c = avgSalesPerMonth;
            snapshot.Performance_Status__c = performanceStatus;
            snapshot.Deficit_Cost_Covered__c = deficitCostCovered;
            snapshot.Margin_Percent_Snapshot__c = businessCase.Margin_Percent__c ??
                0; // Historical margin snapshot
            if(invoiceData.totalSales != null)
            {
                snapshot.Margin_On_Reagent_Sale__c =
                (invoiceData.totalSales * (businessCase.Margin_Percent__c ?? 0))/ 100; // Calculated margin amount
            }
             System.debug(
                '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase-->invoiceData.totalSales: '+invoiceData.totalSales
            );
             System.debug(
                '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase-->snapshot.Margin_On_Reagent_Sale__c: '+snapshot.Margin_On_Reagent_Sale__c
            );
            if(snapshot.Margin_Percent_Snapshot__c > 0)
            {
                snapshot.Margin_till_Date__c = (totalSalesTillDate * (snapshot.Margin_Percent_Snapshot__c ?? 0))/ 100;
            }
             System.debug(
                '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase-->totalSalesTillDate: '+totalSalesTillDate
            );
             System.debug(
                '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase-->snapshot.Margin_till_Date__c: '+snapshot.Margin_till_Date__c
            );
            // snapshot.Margin_On_Reagent_Sale__c =
            //     (invoiceData.totalSales * (businessCase.Margin_Percent__c ?? 0))/ 100; // Calculated margin amount

            // Calculate payback remaining (simplified logic)
            if (
                businessCase.Unit_Cost__c != null &&
                businessCase.Unit_Cost__c > 0
            ) {
                Decimal totalRevenue = ytdSales != null ? ytdSales : 0;
                snapshot.Payback_Remaining__c =
                    businessCase.Unit_Cost__c - totalRevenue;
                if (snapshot.Payback_Remaining__c < 0) {
                    snapshot.Payback_Remaining__c = 0; // Payback complete
                }
            }

            // Data quality
            snapshot.Data_Quality_Score__c = calculateDataQualityScore(
                invoiceData,
                businessCase
            );
            snapshot.Processing_Status__c = 'Completed';
            System.debug(
                '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase-->snapshot data: ' +
                snapshot
            );
            return snapshot;
        } catch (Exception ex) {
            System.debug(
                '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase-->Exception Message-->' +
                ex.getMessage()
            );
            System.debug(
                '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase-->Exception Cause-->' +
                ex.getCause()
            );
            return null;
        }
    }

    //Create Snapshot For Master Business Case
    public static Business_Case_Sales_Snapshot__c createSnapshotForMasterBusinessCase(
        Business_Case__c businessCase,
        Date snapshotMonth,
        InvoiceAggregationResult invoiceData,
        Decimal ytdSales,
        Decimal totalSalesTillDate
    ) {
        // Get invoice data for this Business Case and month
        //InvoiceAggregationResult invoiceData = invoiceData;

        // Calculate YTD sales
        //Decimal ytdSales = ytdSales;
        System.debug(
            '>>>>BusinessCaseSnapshotService-->createSnapshotForMasterBusinessCase'
        );
        // Create snapshot record
        Business_Case_Sales_Snapshot__c snapshot = new Business_Case_Sales_Snapshot__c();

        // Core identifiers - using Business Case ID + Month instead of complex key
        snapshot.Business_Case__c = businessCase.Id;
        snapshot.Snapshot_Month__c = snapshotMonth;
        snapshot.Snapshot_Created_Date__c = Date.today();
        snapshot.Monthly_Commitments__c = businessCase.Sum_of_Monthly_Reagent_Commitment__c;

        // Business Case dimensions
        System.debug(
            '>>>>BusinessCaseSnapshotService-->createSnapshotForMasterBusinessCase-->businessCase.Customer_Number__c: ' +
            businessCase.Customer_Numbera__c
        );
        System.debug(
            '>>>>BusinessCaseSnapshotService-->createSnapshotForMasterBusinessCase-->businessCase.Customer_Name__c: ' +
            businessCase.Customer_Namea__c
        );
        System.debug(
            '>>>>BusinessCaseSnapshotService-->createSnapshotForMasterBusinessCase-->businessCase.Machine_Installation__r.Diagnostic_Machine__r.Vendor__c: ' +
            businessCase.Business_Cases__r[0]
                .Machine_Installation__r.Diagnostic_Machine__r.Vendor__c
        );
        System.debug(
            '>>>>BusinessCaseSnapshotService-->createSnapshotForMasterBusinessCase-->businessCase.Machine_Installation__r.Diagnostic_Machine__r.Technology__c: ' +
            businessCase.Business_Cases__r[0]
                .Machine_Installation__r.Diagnostic_Machine__r.Technology__c
        );
        System.debug(
            '>>>>BusinessCaseSnapshotService-->createSnapshotForMasterBusinessCase-->businessCase: ' +
            businessCase.Id
        );
        System.debug(
            '>>>>BusinessCaseSnapshotService-->createSnapshotForMasterBusinessCase-->businessCase Name: ' +
            businessCase.Name
        );
        //Business_Cases__r.records.0
        snapshot.Customer_Code__c = businessCase.Customer_Numbera__c != null
            ? businessCase.Customer_Numbera__c
            : 'Unknown';
        snapshot.Customer_Name__c = businessCase.Customer_Namea__c != null
            ? businessCase.Customer_Namea__c
            : 'Unknown';
        snapshot.Vendor__c = businessCase.Business_Cases__r[0]
                .Machine_Installation__r.Diagnostic_Machine__r.Vendor__c != null
            ? businessCase.Business_Cases__r[0]
                  .Machine_Installation__r.Diagnostic_Machine__r.Vendor__c
            : 'Unknown';
        snapshot.Technology__c = businessCase.Business_Cases__r[0]
                .Machine_Installation__r.Diagnostic_Machine__r.Technology__c !=
            null
            ? businessCase.Business_Cases__r[0]
                  .Machine_Installation__r.Diagnostic_Machine__r.Technology__c
            : 'Unknown';
        snapshot.Region__c = businessCase.Business_Cases__r[0].Region__c != null
            ? businessCase.Business_Cases__r[0].Region__c
            : '';

        // Additional Business Case Information
        snapshot.Material_Number__c = businessCase.Material_Number__c;
        snapshot.Material_Description__c = businessCase.Material_Descriptionsa__c;

        // Business Case Name and Status (for snapshot-only dashboard architecture)
        snapshot.Business_Case_Name__c = businessCase.Name;
        snapshot.Business_Case_Status__c = businessCase.Status__c;
        snapshot.Machine_Status__c = businessCase.Business_Cases__r[0]
            .Machine_Installation__r.Status__c;

        // Customer Address Information - Capture both Bill To and Ship To Account addresses

        // Bill To Account address (direct Account on Business Case)
        snapshot.Customer_Province__c = businessCase.Business_Cases__r[0]
            .Machine_Installation__r.bill_to_account__r.Province__c;
        snapshot.Customer_City__c = businessCase.Business_Cases__r[0]
            .Machine_Installation__r.bill_to_account__r.City__c;
        snapshot.Customer_AddressLine1__c = businessCase.Business_Cases__r[0]
            .Machine_Installation__r.bill_to_account__r.AddressLine_1__c;
        snapshot.Customer_AddressLine2__c = '';
        snapshot.Customer_Postal_Code__c = businessCase.Business_Cases__r[0]
            .Machine_Installation__r.bill_to_account__r.Postal_Code__c;
        snapshot.Customer_Country__c = businessCase.Business_Cases__r[0]
            .Machine_Installation__r.bill_to_account__r.Country_Code__c;

        // Ship To Account address (from Asset → Ship To Account)
        // if (
        //   businessCase.Asset_Number__c != null &&
        //   businessCase.Asset_Number__r.Ship_To_Account__c != null
        // ) {
        //   snapshot.Ship_To_Customer_Number__c = businessCase.Asset_Number__r.Ship_To_Account__r.SAP_Customer_Number__c;
        //   snapshot.Ship_To_Customer_Name__c = businessCase.Asset_Number__r.Ship_To_Account__r.Name;
        //   snapshot.Ship_To_Province__c = businessCase.Asset_Number__r.Ship_To_Account__r.Province__c;
        //   snapshot.Ship_To_City__c = businessCase.Asset_Number__r.Ship_To_Account__r.City__c;
        //   snapshot.Ship_To_AddressLine1__c = businessCase.Asset_Number__r.Ship_To_Account__r.AddressLine_1__c;
        //   snapshot.Ship_To_Address_Line_2__c = businessCase.Asset_Number__r.Ship_To_Account__r.Addess_Line_2__c;

        //   snapshot.Ship_To_Postal_Code__c = businessCase.Asset_Number__r.Ship_To_Account__r.Postal_Code__c;
        //   snapshot.Ship_To_Country__c = businessCase.Asset_Number__r.Ship_To_Account__r.Country_Code__c;
        // }

        // Sales metrics - handle null invoiceData (no invoices for this month)
        if (invoiceData == null) {
            invoiceData = new InvoiceAggregationResult();
            invoiceData.totalSales = 0;
            invoiceData.invoiceCount = 0;
        }
        snapshot.Total_Reagent_Sales__c = invoiceData.totalSales;

        // Machine count based on Business Case quantity (default to 1 if empty/invalid)
        Decimal quantity = 1; // Default value
        if (String.isNotBlank(businessCase.Quantity__c)) {
            try {
                quantity = Decimal.valueOf(businessCase.Quantity__c);
                if (quantity <= 0) {
                    quantity = 1; // Ensure positive value
                }
            } catch (Exception e) {
                System.debug(
                    'Invalid quantity value for BC ' +
                        businessCase.Name +
                        ': ' +
                        businessCase.Quantity__c
                );
                quantity = 1; // Fallback to 1 if parsing fails
            }
        }
        snapshot.Machine_Count__c = quantity;

        snapshot.Source_Invoice_Count__c = invoiceData.invoiceCount;
        snapshot.YTD_Sales__c = ytdSales;

        Integer currentmonth = Datetime.now().month();

        if(currentmonth != null)
        {
            if(currentmonth != null)
            {
                if(currentmonth > 0 && currentmonth < 2)
                {
                    snapshot.Avg_YTD_Sales_Per_Month__c = ytdSales / currentmonth;
                }
                else if(currentmonth > 1 )
                {
                    snapshot.Avg_YTD_Sales_Per_Month__c = ytdSales / (currentmonth-1);
                }
            }
        }

        

        // Targets and commitments
        snapshot.Target_Sales__c = businessCase.Sum_of_Monthly_Reagent_Commitment__c;
        // Note: Target_Achievement_Percent__c is auto-calculated via formula field

        // ==================== ENHANCED ANALYTICS FIELDS ====================

        // Calculate contract performance metrics using Agreement_Date__c
        Integer contractMonthsElapsed = calculateMonthsElapsed(
            businessCase.Agreement_Date__c, // Use proper contract start date
            snapshotMonth
        );

        System.debug(
            '>>>>BusinessCaseSnapshotService-->createSnapshotForMasterBusinessCase-->snapshotMonth: ' +
            snapshotMonth
        );

        System.debug(
            '>>>>BusinessCaseSnapshotService-->createSnapshotForMasterBusinessCase-->businessCase.Agreement_Date__c: ' +
            businessCase.Agreement_Date__c
        );

        System.debug(
            '>>>>BusinessCaseSnapshotService-->createSnapshotForMasterBusinessCase-->contractMonthsElapsed: ' +
            contractMonthsElapsed
        );

        System.debug(
            '>>>>BusinessCaseSnapshotService-->createSnapshotForMasterBusinessCase-->totalSalesTillDate: ' +
            totalSalesTillDate
        );

        System.debug(
            '>>>>BusinessCaseSnapshotService-->createSnapshotForMasterBusinessCase-->invoiceData.totalSales: ' +
            invoiceData.totalSales
        );


        // Decimal totalSalesTillDate = totalSalesTillDate;
        
        Decimal avgSalesPerMonth = 0;
        if (totalSalesTillDate != null) {
            if (totalSalesTillDate > 0) {
                avgSalesPerMonth = contractMonthsElapsed > 0
                    ? totalSalesTillDate / contractMonthsElapsed
                    : 0;
            }
        } else {
            avgSalesPerMonth = contractMonthsElapsed > 0
                ? invoiceData.totalSales / contractMonthsElapsed
                : 0;
        }

         System.debug(
            '>>>>BusinessCaseSnapshotService-->createSnapshotForMasterBusinessCase-->avgSalesPerMonth: ' +
            avgSalesPerMonth
        );

        Decimal deficitCostCovered = calculateDeficitCostCovered(
            ytdSales,
            businessCase.Sum_of_Monthly_Reagent_Commitment__c,
            contractMonthsElapsed
        );
        String performanceStatus = determinePerformanceStatus(
            //avgSalesPerMonth,
            invoiceData.totalSales,
            businessCase.Sum_of_Monthly_Reagent_Commitment__c
        );

        // Enhanced Analytics Fields - Production Ready
        if (totalSalesTillDate == null) {
            totalSalesTillDate = invoiceData.totalSales;
        } else if (totalSalesTillDate <= 0) {
            totalSalesTillDate = invoiceData.totalSales;
        }
        snapshot.Total_Reagent_Sales_Till_Date__c = totalSalesTillDate;
        snapshot.Contract_Months_Elapsed__c = contractMonthsElapsed;
        snapshot.Avg_Reagent_Sales_Per_Month__c = avgSalesPerMonth;
        snapshot.Performance_Status__c = performanceStatus;
        snapshot.Deficit_Cost_Covered__c = deficitCostCovered;
        snapshot.Margin_Percent_Snapshot__c = businessCase.Margin_Percent__c ?? 0; // Historical margin snapshot
        if(invoiceData.totalSales != null )
        {
            snapshot.Margin_On_Reagent_Sale__c =
          ((invoiceData.totalSales * (businessCase.Margin_Percent__c ?? 0)) / 100);
        }
        
         if(snapshot.Margin_Percent_Snapshot__c > 0)
        {
            snapshot.Margin_till_Date__c = (totalSalesTillDate * (snapshot.Margin_Percent_Snapshot__c ?? 0))/ 100;
        }
         
        System.debug(
            '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase-->invoiceData.totalSales: '+invoiceData.totalSales
        );
            System.debug(
            '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase-->snapshot.Margin_On_Reagent_Sale__c: '+snapshot.Margin_On_Reagent_Sale__c
        );
        
            System.debug(
            '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase-->totalSalesTillDate: '+totalSalesTillDate
        );
            System.debug(
            '>>>>BusinessCaseSnapshotService-->createSnapshotForBusinessCase-->snapshot.Margin_till_Date__c: '+snapshot.Margin_till_Date__c
        );
         // Calculated margin amount

        // Calculate payback remaining (simplified logic)
        if (
            businessCase.Sum_of_Unit_Cost__c != null &&
            businessCase.Sum_of_Unit_Cost__c > 0
        ) {
            Decimal totalRevenue = ytdSales != null ? ytdSales : 0;
            snapshot.Payback_Remaining__c =
                businessCase.Sum_of_Unit_Cost__c - totalRevenue;
            if (snapshot.Payback_Remaining__c < 0) {
                snapshot.Payback_Remaining__c = 0; // Payback complete
            }
        }

        // Data quality
        snapshot.Data_Quality_Score__c = calculateMasterDataQualityScore(
            invoiceData,
            businessCase
        );
        snapshot.Processing_Status__c = 'Completed';
        System.debug(
            '>>>>BusinessCaseSnapshotService-->createSnapshotForMasterBusinessCase-->snapshot data: ' +
            snapshot
        );
        return snapshot;
    }

    // private static Business_Case_Sales_Snapshot__c createSnapshotForBusinessCase_old(
    //     Business_Case__c businessCase,
    //     Date snapshotMonth
    // ) {
    //     // Get invoice data for this Business Case and month
    //     InvoiceAggregationResult invoiceData = aggregateInvoiceData(
    //         businessCase.Id,
    //         snapshotMonth
    //     );

    //     // Calculate YTD sales
    //     Decimal ytdSales = calculateYTDSales(businessCase.Id, snapshotMonth);

    //     // Create snapshot record
    //     Business_Case_Sales_Snapshot__c snapshot = new Business_Case_Sales_Snapshot__c();

    //     // Core identifiers - using Business Case ID + Month instead of complex key
    //     snapshot.Business_Case__c = businessCase.Id;
    //     snapshot.Snapshot_Month__c = snapshotMonth;
    //     snapshot.Snapshot_Created_Date__c = Date.today();
    //     snapshot.Monthly_Commitments__c = businessCase.Monthly_Reagent_Commitment__c;

    //     // Business Case dimensions
    //     snapshot.Customer_Code__c = businessCase.Customer_Number__c != null
    //         ? businessCase.Customer_Number__c
    //         : 'Unknown';
    //     snapshot.Customer_Name__c = businessCase.Customer_Name__c != null
    //         ? businessCase.Customer_Name__c
    //         : 'Unknown';
    //     snapshot.Vendor__c = businessCase.Supplier_Name__c != null
    //         ? businessCase.Supplier_Name__c
    //         : 'Unknown';
    //     snapshot.Technology__c = businessCase.Technology__c != null
    //         ? businessCase.Technology__c
    //         : 'Unknown';
    //     snapshot.Region__c = businessCase.Region__c != null
    //         ? businessCase.Region__c
    //         : '';

    //     // Additional Business Case Information
    //     snapshot.Material_Number__c = businessCase.SAP_Material_Number__c;
    //     snapshot.Material_Description__c = businessCase.Machine_Type__c;

    //     // Business Case Name and Status (for snapshot-only dashboard architecture)
    //     snapshot.Business_Case_Name__c = businessCase.Name;
    //     snapshot.Business_Case_Status__c = businessCase.Status__c;
    //     snapshot.Machine_Status__c = businessCase.Asset_Number__r?.Status__c;

    //     // Customer Address Information - Capture both Bill To and Ship To Account addresses

    //     // Bill To Account address (direct Account on Business Case)
    //     snapshot.Customer_Province__c = businessCase.Account__r.Province__c;
    //     snapshot.Customer_City__c = businessCase.Account__r.City__c;
    //     snapshot.Customer_AddressLine1__c = businessCase.Account__r.AddressLine_1__c;
    //     snapshot.Customer_AddressLine2__c = businessCase.Account__r.Addess_Line_2__c;
    //     snapshot.Customer_Postal_Code__c = businessCase.Account__r.Postal_Code__c;
    //     snapshot.Customer_Country__c = businessCase.Account__r.Country_Code__c;

    //     // Ship To Account address (from Asset → Ship To Account)
    //     if (
    //         businessCase.Asset_Number__c != null &&
    //         businessCase.Asset_Number__r.Ship_To_Account__c != null
    //     ) {
    //         snapshot.Ship_To_Customer_Number__c = businessCase.Asset_Number__r.Ship_To_Account__r.SAP_Customer_Number__c;
    //         snapshot.Ship_To_Customer_Name__c = businessCase.Asset_Number__r.Ship_To_Account__r.Name;
    //         snapshot.Ship_To_Province__c = businessCase.Asset_Number__r.Ship_To_Account__r.Province__c;
    //         snapshot.Ship_To_City__c = businessCase.Asset_Number__r.Ship_To_Account__r.City__c;
    //         snapshot.Ship_To_AddressLine1__c = businessCase.Asset_Number__r.Ship_To_Account__r.AddressLine_1__c;
    //         snapshot.Ship_To_Address_Line_2__c = businessCase.Asset_Number__r.Ship_To_Account__r.Addess_Line_2__c;

    //         snapshot.Ship_To_Postal_Code__c = businessCase.Asset_Number__r.Ship_To_Account__r.Postal_Code__c;
    //         snapshot.Ship_To_Country__c = businessCase.Asset_Number__r.Ship_To_Account__r.Country_Code__c;
    //     }

    //     // Sales metrics
    //     snapshot.Total_Reagent_Sales__c = invoiceData.totalSales;

    //     // Machine count based on Business Case quantity (default to 1 if empty/invalid)
    //     Decimal quantity = 1; // Default value
    //     if (String.isNotBlank(businessCase.Quantity__c)) {
    //         try {
    //             quantity = Decimal.valueOf(businessCase.Quantity__c);
    //             if (quantity <= 0) {
    //                 quantity = 1; // Ensure positive value
    //             }
    //         } catch (Exception e) {
    //             System.debug(
    //                 'Invalid quantity value for BC ' +
    //                     businessCase.Name +
    //                     ': ' +
    //                     businessCase.Quantity__c
    //             );
    //             quantity = 1; // Fallback to 1 if parsing fails
    //         }
    //     }
    //     snapshot.Machine_Count__c = quantity;

    //     snapshot.Source_Invoice_Count__c = invoiceData.invoiceCount;
    //     snapshot.YTD_Sales__c = calculateYtdSales(
    //         businessCase.Id,
    //         snapshotMonth
    //     );

    //     // Targets and commitments
    //     snapshot.Target_Sales__c = businessCase.Monthly_Reagent_Commitment__c;
    //     // Note: Target_Achievement_Percent__c is auto-calculated via formula field

    //     // ==================== ENHANCED ANALYTICS FIELDS ====================

    //     // Calculate contract performance metrics using Agreement_Date__c
    //     Integer contractMonthsElapsed = calculateMonthsElapsed(
    //         businessCase.Agreement_Date__c, // Use proper contract start date
    //         snapshotMonth
    //     );
    //     Decimal totalSalesTillDate = calculateTotalSalesTillDate(
    //         businessCase.Id,
    //         snapshotMonth
    //     );
    //     Decimal avgSalesPerMonth = contractMonthsElapsed > 0
    //         ? totalSalesTillDate / contractMonthsElapsed
    //         : 0;
    //     Decimal deficitCostCovered = calculateDeficitCostCovered(
    //         ytdSales,
    //         businessCase.Monthly_Reagent_Commitment__c,
    //         contractMonthsElapsed
    //     );
    //     String performanceStatus = determinePerformanceStatus(
    //         avgSalesPerMonth,
    //         businessCase.Monthly_Reagent_Commitment__c
    //     );

    //     // Enhanced Analytics Fields - Production Ready
    //     snapshot.Total_Reagent_Sales_Till_Date__c = totalSalesTillDate;
    //     snapshot.Contract_Months_Elapsed__c = contractMonthsElapsed;
    //     snapshot.Avg_Reagent_Sales_Per_Month__c = avgSalesPerMonth;
    //     snapshot.Performance_Status__c = performanceStatus;
    //     snapshot.Deficit_Cost_Covered__c = deficitCostCovered;
    //     snapshot.Margin_Percent_Snapshot__c = businessCase.Margin_Percent__c ??
    //         0; // Historical margin snapshot
    //     snapshot.Margin_On_Reagent_Sale__c =
    //         invoiceData.totalSales * (businessCase.Margin_Percent__c ?? 0); // Calculated margin amount

    //     // Calculate payback remaining (simplified logic)
    //     if (
    //         businessCase.Unit_Cost__c != null &&
    //         businessCase.Unit_Cost__c > 0
    //     ) {
    //         Decimal totalRevenue = ytdSales != null ? ytdSales : 0;
    //         snapshot.Payback_Remaining__c =
    //             businessCase.Unit_Cost__c - totalRevenue;
    //         if (snapshot.Payback_Remaining__c < 0) {
    //             snapshot.Payback_Remaining__c = 0; // Payback complete
    //         }
    //     }

    //     // Data quality
    //     snapshot.Data_Quality_Score__c = calculateDataQualityScore(
    //         invoiceData,
    //         businessCase
    //     );
    //     snapshot.Processing_Status__c = 'Completed';

    //     return snapshot;
    // }
    /**
     * Aggregate invoice data for a Business Case and month
     */
    public static InvoiceAggregationResult aggregateInvoiceData(
        Id businessCaseId,
        Date snapshotMonth
    ) {
        Date monthStart = snapshotMonth.toStartOfMonth();
        Date monthEnd = monthStart.addMonths(1).addDays(-1);

        List<AggregateResult> results = [
            SELECT COUNT(Id) invoiceCount, SUM(Invoice_Value__c) totalSales
            FROM Invoice_Line_Item__c
            WHERE
                Business_Case__c = :businessCaseId
                AND Invoice__r.Invoice_Date__c >= :monthStart
                AND Invoice__r.Invoice_Date__c <= :monthEnd
                AND Invoice_Value__c != NULL
        ];

        InvoiceAggregationResult result = new InvoiceAggregationResult();
        if (!results.isEmpty() && results[0] != null) {
            result.invoiceCount = (Integer) results[0].get('invoiceCount');
            result.totalSales = (Decimal) results[0].get('totalSales');
        }

        if (result.totalSales == null)
            result.totalSales = 0;
        if (result.invoiceCount == null)
            result.invoiceCount = 0;

        return result;
    }

    /**
     * Calculate Year-to-Date sales for a Business Case
     */
    public static Decimal calculateYTDSales(
        Id businessCaseId,
        Date snapshotMonth
    ) {
        Date yearStart = Date.newInstance(snapshotMonth.year(), 1, 1);
        Date monthEnd = snapshotMonth.toStartOfMonth().addMonths(1).addDays(-1);

        List<AggregateResult> results = [
            SELECT SUM(Invoice_Value__c) ytdSales
            FROM Invoice_Line_Item__c
            WHERE
                Business_Case__c = :businessCaseId
                AND Invoice__r.Invoice_Date__c >= :yearStart
                AND Invoice__r.Invoice_Date__c <= :monthEnd
                AND Invoice_Value__c != NULL
        ];

        Decimal ytdSales = 0;
        if (!results.isEmpty() && results[0] != null) {
            ytdSales = (Decimal) results[0].get('ytdSales');
        }

        return ytdSales != null ? ytdSales : 0;
    }

    /**
     * Calculate data quality score based on completeness
     */
    public static Decimal calculateDataQualityScore(
        InvoiceAggregationResult invoiceData,
        Business_Case__c businessCase
    ) {
        Decimal score = 100; // Start with perfect score

        // Deduct points for missing data
        if (String.isBlank(businessCase.Customer_Number__c))
            score -= 20;
        if (String.isBlank(businessCase.Supplier_Name__c))
            score -= 20;
        if (String.isBlank(businessCase.Technology__c))
            score -= 20;
        if (invoiceData.invoiceCount == 0)
            score -= 30;
        if (businessCase.Monthly_Reagent_Commitment__c == null)
            score -= 10;

        return Math.max(score, 0); // Ensure non-negative
    }

    private static Decimal calculateMasterDataQualityScore(
        InvoiceAggregationResult invoiceData,
        Business_Case__c businessCase
    ) {
        Decimal score = 100; // Start with perfect score

        // Deduct points for missing data
        if (String.isBlank(businessCase.Customer_Numbera__c))
            score -= 20;
        if (
            String.isBlank(
                businessCase.Business_Cases__r[0]
                    .Machine_Installation__r.Diagnostic_Machine__r.Vendor__c
            )
        )
            score -= 20;
        if (
            String.isBlank(
                businessCase.Business_Cases__r[0]
                    .Machine_Installation__r.Diagnostic_Machine__r.Technology__c
            )
        )
            score -= 20;
        if (invoiceData.invoiceCount == 0)
            score -= 30;
        if (businessCase.Sum_of_Monthly_Reagent_Commitment__c == null)
            score -= 10;

        return Math.max(score, 0); // Ensure non-negative
    }

    /**
     * Create exception record
     */
    public static Business_Case_Exception__c createException(
        Id businessCaseId,
        String errorMessage,
        String exceptionType
    ) {
        Business_Case_Exception__c exceptionRecord = new Business_Case_Exception__c();
        exceptionRecord.Business_Case__c = businessCaseId;
        exceptionRecord.Error_Message__c = errorMessage;
        exceptionRecord.Exception_Type__c = exceptionType;
        exceptionRecord.Exception_Date__c = DateTime.now();
        exceptionRecord.Resolution_Status__c = 'Open';

        return exceptionRecord;
    }

    /**
     * OPTIMIZED: Create snapshot from bulk-calculated data (NO additional queries)
     * Uses pre-aggregated data to completely avoid SOQL limits
     */
    // private static Business_Case_Sales_Snapshot__c createSnapshotFromBulkData(
    //     Business_Case__c businessCase,
    //     InvoiceMonthData monthData,
    //     Decimal totalSalesTillDate,
    //     Decimal totalSalesAllTime
    // ) {
    //     // Create snapshot record using the aggregated data we already have
    //     Business_Case_Sales_Snapshot__c snapshot = new Business_Case_Sales_Snapshot__c();

    //     // Core identifiers
    //     snapshot.Business_Case__c = businessCase.Id;
    //     snapshot.Snapshot_Month__c = monthData.month;
    //     snapshot.Snapshot_Created_Date__c = Date.today();

    //     // Business Case dimensions
    //     snapshot.Customer_Code__c = businessCase.Customer_Number__c != null
    //         ? businessCase.Customer_Number__c
    //         : 'Unknown';
    //     snapshot.Customer_Name__c = businessCase.Customer_Name__c != null
    //         ? businessCase.Customer_Name__c
    //         : 'Unknown';
    //     snapshot.Vendor__c = businessCase.Supplier_Name__c != null
    //         ? businessCase.Supplier_Name__c
    //         : 'Unknown';
    //     snapshot.Technology__c = businessCase.Technology__c != null
    //         ? businessCase.Technology__c
    //         : 'Unknown';
    //     snapshot.Region__c = businessCase.Region__c != null
    //         ? businessCase.Region__c
    //         : '';

    //     // Additional Business Case Information
    //     snapshot.Material_Number__c = businessCase.SAP_Material_Number__c;
    //     snapshot.Material_Description__c = businessCase.Machine_Type__c;

    //     // Business Case Name and Status (for snapshot-only dashboard architecture)
    //     snapshot.Business_Case_Name__c = businessCase.Name;
    //     snapshot.Business_Case_Status__c = businessCase.Status__c;
    //     snapshot.Machine_Status__c = businessCase.Asset_Number__r?.Status__c;

    //     // Customer Address Information - Capture both Bill To and Ship To Account addresses

    //     // Bill To Account address (direct Account on Business Case)
    //     snapshot.Customer_Province__c = businessCase.Account__r.Province__c;
    //     snapshot.Customer_City__c = businessCase.Account__r.City__c;
    //     snapshot.Customer_AddressLine1__c = businessCase.Account__r.AddressLine_1__c;
    //     snapshot.Customer_AddressLine2__c = businessCase.Account__r.Addess_Line_2__c;
    //     snapshot.Customer_Postal_Code__c = businessCase.Account__r.Postal_Code__c;
    //     snapshot.Customer_Country__c = businessCase.Account__r.Country_Code__c;

    //     // Ship To Account address (from Asset → Ship To Account)
    //     if (
    //         businessCase.Asset_Number__c != null &&
    //         businessCase.Asset_Number__r.Ship_To_Account__c != null
    //     ) {
    //         snapshot.Ship_To_Customer_Number__c = businessCase.Asset_Number__r.Ship_To_Account__r.SAP_Customer_Number__c;
    //         snapshot.Ship_To_Customer_Name__c = businessCase.Asset_Number__r.Ship_To_Account__r.Name;
    //         snapshot.Ship_To_Province__c = businessCase.Asset_Number__r.Ship_To_Account__r.Province__c;
    //         snapshot.Ship_To_City__c = businessCase.Asset_Number__r.Ship_To_Account__r.City__c;
    //         snapshot.Ship_To_AddressLine1__c = businessCase.Asset_Number__r.Ship_To_Account__r.AddressLine_1__c;
    //         snapshot.Ship_To_Address_Line_2__c = businessCase.Asset_Number__r.Ship_To_Account__r.Addess_Line_2__c;
    //         snapshot.Ship_To_Postal_Code__c = businessCase.Asset_Number__r.Ship_To_Account__r.Postal_Code__c;
    //         snapshot.Ship_To_Country__c = businessCase.Asset_Number__r.Ship_To_Account__r.Country_Code__c;
    //     }

    //     // Sales metrics - using pre-aggregated data
    //     snapshot.Total_Reagent_Sales__c = monthData.totalSales;

    //     // Machine count based on Business Case quantity (default to 1 if empty/invalid)
    //     Decimal quantity = 1; // Default value
    //     if (String.isNotBlank(businessCase.Quantity__c)) {
    //         try {
    //             quantity = Decimal.valueOf(businessCase.Quantity__c);
    //             if (quantity <= 0) {
    //                 quantity = 1; // Ensure positive value
    //             }
    //         } catch (Exception e) {
    //             System.debug(
    //                 'Invalid quantity value for BC ' +
    //                     businessCase.Name +
    //                     ': ' +
    //                     businessCase.Quantity__c
    //             );
    //             quantity = 1; // Fallback to 1 if parsing fails
    //         }
    //     }
    //     snapshot.Machine_Count__c = quantity;

    //     snapshot.Source_Invoice_Count__c = monthData.invoiceCount;

    //     // ==================== ENHANCED ANALYTICS FIELDS (OPTIMIZED) ====================

    //     // YTD sales - calculate based on year of current month
    //     Date yearStart = Date.newInstance(monthData.month.year(), 1, 1);
    //     Date monthEnd = monthData.month.toStartOfMonth()
    //         .addMonths(1)
    //         .addDays(-1);

    //     // For YTD, use cumulative sales till date if within same year, otherwise calculate
    //     if (monthData.month.year() == Date.today().year()) {
    //         snapshot.YTD_Sales__c = totalSalesTillDate; // Simplified for current year
    //     } else {
    //         snapshot.YTD_Sales__c = totalSalesTillDate; // Historical YTD = cumulative till that month
    //     }

    //     // Total sales till date (pre-calculated)
    //     snapshot.Total_Reagent_Sales_Till_Date__c = totalSalesTillDate;

    //     // Contract months elapsed (calculate from agreement date to snapshot month)
    //     Integer contractMonthsElapsed = 1; // Default to 1 to avoid division by zero
    //     if (businessCase.Agreement_Date__c != null) {
    //         contractMonthsElapsed = calculateMonthsElapsedOptimized(
    //             businessCase.Agreement_Date__c,
    //             monthData.month
    //         );
    //     }
    //     snapshot.Contract_Months_Elapsed__c = contractMonthsElapsed;

    //     // Average sales per month (using cumulative data)
    //     Decimal avgSalesPerMonth = contractMonthsElapsed > 0
    //         ? totalSalesTillDate / contractMonthsElapsed
    //         : 0;
    //     snapshot.Avg_Reagent_Sales_Per_Month__c = avgSalesPerMonth;

    //     // Deficit/surplus calculation (optimized)
    //     Decimal monthlyTarget = businessCase.Monthly_Reagent_Commitment__c !=
    //         null
    //         ? businessCase.Monthly_Reagent_Commitment__c
    //         : 0;
    //     Decimal expectedSalesTillDate = monthlyTarget * contractMonthsElapsed;
    //     Decimal deficitCostCovered = totalSalesTillDate - expectedSalesTillDate;
    //     snapshot.Deficit_Cost_Covered__c = deficitCostCovered;

    //     // Performance status (optimized)
    //     if (monthlyTarget > 0) {
    //         if (avgSalesPerMonth >= monthlyTarget) {
    //             snapshot.Performance_Status__c = 'On Track';
    //         } else if (avgSalesPerMonth >= (monthlyTarget * 0.90)) {
    //             snapshot.Performance_Status__c = 'At Risk';
    //         } else {
    //             snapshot.Performance_Status__c = 'Behind';
    //         }
    //     } else {
    //         snapshot.Performance_Status__c = 'No Target Set';
    //     }

    //     // Margin calculations (using Business Case margin data)
    //     snapshot.Margin_Percent_Snapshot__c = businessCase.Margin_Percent__c !=
    //         null
    //         ? businessCase.Margin_Percent__c
    //         : 0;
    //     snapshot.Margin_On_Reagent_Sale__c =
    //         monthData.totalSales * (snapshot.Margin_Percent_Snapshot__c / 100);

    //     // Payback remaining (optimized)
    //     if (
    //         businessCase.Unit_Cost__c != null &&
    //         businessCase.Unit_Cost__c > 0
    //     ) {
    //         snapshot.Payback_Remaining__c = Math.max(
    //             0,
    //             businessCase.Unit_Cost__c - totalSalesTillDate
    //         );
    //     } else {
    //         snapshot.Payback_Remaining__c = 0;
    //     }

    //     // Targets and commitments
    //     snapshot.Target_Sales__c = monthlyTarget;

    //     // Data quality (simplified)
    //     snapshot.Data_Quality_Score__c = calculateSimpleDataQualityScore(
    //         monthData,
    //         businessCase
    //     );
    //     snapshot.Processing_Status__c = 'Completed';

    //     return snapshot;
    // }

    /**
     * Optimized months elapsed calculation (no queries)
     */
    private static Integer calculateMonthsElapsedOptimized(
        Date startDate,
        Date endDate
    ) {
        if (startDate == null || endDate == null)
            return 1;

        Integer monthsDiff = startDate.monthsBetween(endDate) + 1; // +1 to include current month
        return Math.max(1, monthsDiff); // Ensure at least 1 month
    }

    /**
     * Simplified data quality score calculation (no additional queries)
     */
    public static Decimal calculateSimpleDataQualityScore(
        InvoiceMonthData monthData,
        Business_Case__c businessCase
    ) {
        Decimal score = 100; // Start with perfect score

        // Deduct points for missing data
        if (String.isBlank(businessCase.Customer_Number__c))
            score -= 20;
        if (String.isBlank(businessCase.Supplier_Name__c))
            score -= 20;
        if (String.isBlank(businessCase.Technology__c))
            score -= 20;
        if (monthData.invoiceCount == 0)
            score -= 30;
        if (businessCase.Monthly_Reagent_Commitment__c == null)
            score -= 10;

        return Math.max(score, 0); // Ensure non-negative
    }

    /**
     * Inner class for invoice aggregation results
     */
    public class InvoiceAggregationResult {
        public Decimal totalSales = 0;
        public Integer invoiceCount = 0;
    }

    /**
     * Inner class to hold monthly invoice data
     */
    public class InvoiceMonthData {
        public Date month;
        public Integer invoiceCount = 0;
        public Decimal totalSales = 0;
    }

    /**
     * Get invoice data grouped by month for a specific Business Case
     * Much more efficient than processing month by month
     */
    // private static Map<String, InvoiceMonthData> getInvoiceDataByMonth(
    //     Id businessCaseId
    // ) {
    //     System.debug('Getting invoice data by month for BC: ' + businessCaseId);

    //     // Get ALL invoices for this Business Case in ONE query, grouped by month
    //     List<AggregateResult> monthlyResults = [
    //         SELECT
    //             CALENDAR_YEAR(Invoice__r.Invoice_Date__c) year,
    //             CALENDAR_MONTH(Invoice__r.Invoice_Date__c) month,
    //             COUNT(Id) invoiceCount,
    //             SUM(Invoice_Value__c) totalSales
    //         FROM Invoice_Line_Item__c
    //         WHERE
    //             Business_Case__c = :businessCaseId
    //             AND Invoice_Value__c != NULL
    //         GROUP BY
    //             CALENDAR_YEAR(Invoice__r.Invoice_Date__c),
    //             CALENDAR_MONTH(Invoice__r.Invoice_Date__c)
    //         ORDER BY
    //             CALENDAR_YEAR(Invoice__r.Invoice_Date__c),
    //             CALENDAR_MONTH(Invoice__r.Invoice_Date__c)
    //     ];

    //     Map<String, InvoiceMonthData> monthlyData = new Map<String, InvoiceMonthData>();

    //     for (AggregateResult result : monthlyResults) {
    //         Integer year = (Integer) result.get('year');
    //         Integer month = (Integer) result.get('month');
    //         Integer invoiceCount = (Integer) result.get('invoiceCount');
    //         Decimal totalSales = (Decimal) result.get('totalSales');

    //         Date monthDate = Date.newInstance(year, month, 1);
    //         String monthKey = year + '-' + month;

    //         InvoiceMonthData monthData = new InvoiceMonthData();
    //         monthData.month = monthDate;
    //         monthData.invoiceCount = invoiceCount != null ? invoiceCount : 0;
    //         monthData.totalSales = totalSales != null ? totalSales : 0;

    //         monthlyData.put(monthKey, monthData);

    //         System.debug(
    //             'Month: ' +
    //                 monthDate.format() +
    //                 ' | Invoices: ' +
    //                 monthData.invoiceCount +
    //                 ' | Sales: ' +
    //                 monthData.totalSales
    //         );
    //     }

    //     System.debug(
    //         'Retrieved ' +
    //             monthlyData.size() +
    //             ' months of data for Business Case: ' +
    //             businessCaseId
    //     );
    //     return monthlyData;
    // }

    /**
     * Handle upsert logic for snapshots to prevent duplicates
     */
    // private static void handleSnapshotUpsert(
    //     List<Business_Case_Sales_Snapshot__c> snapshots
    // ) {
    //     System.debug(
    //         'Handling upsert for ' + snapshots.size() + ' snapshots...'
    //     );

    //     try {
    //         // Query for existing snapshots to enable proper upsert behavior
    //         Map<String, Business_Case_Sales_Snapshot__c> existingSnapshots = new Map<String, Business_Case_Sales_Snapshot__c>();

    //         Set<Id> businessCaseIds = new Set<Id>();
    //         Set<Date> snapshotMonths = new Set<Date>();

    //         for (Business_Case_Sales_Snapshot__c snapshot : snapshots) {
    //             businessCaseIds.add(snapshot.Business_Case__c);
    //             snapshotMonths.add(snapshot.Snapshot_Month__c);
    //         }

    //         // Get existing snapshots for the same months and business cases
    //         for (Business_Case_Sales_Snapshot__c existing : [
    //             SELECT Id, Business_Case__c, Snapshot_Month__c
    //             FROM Business_Case_Sales_Snapshot__c
    //             WHERE
    //                 Business_Case__c IN :businessCaseIds
    //                 AND Snapshot_Month__c IN :snapshotMonths
    //         ]) {
    //             String key =
    //                 existing.Business_Case__c +
    //                 '_' +
    //                 existing.Snapshot_Month__c.format();
    //             existingSnapshots.put(key, existing);
    //         }

    //         System.debug(
    //             'Found ' + existingSnapshots.size() + ' existing snapshots'
    //         );

    //         // Update snapshots with existing IDs if found
    //         Integer updates = 0;
    //         Integer inserts = 0;

    //         for (Business_Case_Sales_Snapshot__c snapshot : snapshots) {
    //             String key =
    //                 snapshot.Business_Case__c +
    //                 '_' +
    //                 snapshot.Snapshot_Month__c.format();
    //             if (existingSnapshots.containsKey(key)) {
    //                 snapshot.Id = existingSnapshots.get(key).Id;
    //                 updates++;
    //             } else {
    //                 inserts++;
    //             }
    //         }

    //         System.debug('Will update: ' + updates + ', insert: ' + inserts);

    //         // Now upsert will work properly - updates existing records, inserts new ones
    //         Database.UpsertResult[] results = Database.upsert(snapshots, false);

    //         Integer successCount = 0;
    //         Integer failureCount = 0;

    //         for (Database.UpsertResult result : results) {
    //             if (result.isSuccess()) {
    //                 successCount++;
    //             } else {
    //                 failureCount++;
    //                 for (Database.Error error : result.getErrors()) {
    //                     System.debug('Upsert error: ' + error.getMessage());
    //                 }
    //             }
    //         }

    //         System.debug(
    //             'Upsert completed: ' +
    //                 successCount +
    //                 ' success, ' +
    //                 failureCount +
    //                 ' failures'
    //         );
    //     } catch (Exception e) {
    //         System.debug('Error in handleSnapshotUpsert: ' + e.getMessage());
    //         throw e;
    //     }
    // }

    /**
     * Verification method to check manually assigned Business Cases against matching logic
     * Use this to validate that manual assignments are consistent with the automated logic
     */
    public static void verifyManualBusinessCaseAssignments() {
        System.debug('=== VERIFYING MANUAL BUSINESS CASE ASSIGNMENTS ===');

        // Get all reagent sales invoices that already have Business Case assignments
        List<Invoice_Line_Item__c> assignedInvoices = [
            SELECT
                Id,
                Invoice_Customer_Code__c,
                AG_OG__c,
                DGroup__c,
                Business_Case__c
            FROM Invoice_Line_Item__c
            WHERE
                Business_Case__c != NULL
                AND Invoice_Customer_Code__c != NULL
                AND DGroup__c = 'Reagent'
                AND AG_OG__c != NULL
            LIMIT 100
        ];

        System.debug(
            'Found ' +
                assignedInvoices.size() +
                ' reagent invoices with Business Case assignments'
        );

        // Create Business Case map for validation
        Map<String, Business_Case__c> businessCaseMap = createBusinessCaseMap();

        // Get Business Case details for assigned invoices
        Set<Id> assignedBusinessCaseIds = new Set<Id>();
        for (Invoice_Line_Item__c invoice : assignedInvoices) {
            assignedBusinessCaseIds.add(invoice.Business_Case__c);
        }

        Map<Id, Business_Case__c> assignedBusinessCases = new Map<Id, Business_Case__c>(
            [
                SELECT
                    Id,
                    Name,
                    Customer_Number__c,
                    Supplier_Name__c,
                    Technology__c
                FROM Business_Case__c
                WHERE Id IN :assignedBusinessCaseIds
            ]
        );

        // Verify each assignment
        Integer correctAssignments = 0;
        Integer incorrectAssignments = 0;

        for (Invoice_Line_Item__c invoice : assignedInvoices) {
            // Generate the key our logic would create
            String expectedKey = findBusinessCaseKeyForInvoice(invoice);

            // Get the Business Case that our logic would match
            Business_Case__c expectedBusinessCase = businessCaseMap.get(
                expectedKey
            );

            // Get the manually assigned Business Case
            Business_Case__c assignedBusinessCase = assignedBusinessCases.get(
                invoice.Business_Case__c
            );

            Boolean isCorrect = false;
            if (expectedBusinessCase != null && assignedBusinessCase != null) {
                isCorrect = expectedBusinessCase.Id == assignedBusinessCase.Id;
            }

            if (isCorrect) {
                correctAssignments++;
                System.debug(
                    '✅ CORRECT: Invoice ' +
                        invoice.Id +
                        ' | Key: ' +
                        expectedKey +
                        ' | Assigned BC: ' +
                        assignedBusinessCase.Name
                );
            } else {
                incorrectAssignments++;
                System.debug('❌ MISMATCH: Invoice ' + invoice.Id);
                System.debug('   Expected Key: ' + expectedKey);
                System.debug(
                    '   Expected BC: ' +
                    (expectedBusinessCase != null
                        ? expectedBusinessCase.Name
                        : 'NONE FOUND')
                );
                System.debug(
                    '   Assigned BC: ' +
                    (assignedBusinessCase != null
                        ? assignedBusinessCase.Name
                        : 'NONE')
                );
                System.debug('   AG_OG__c: ' + invoice.AG_OG__c);
                System.debug(
                    '   Customer: ' + invoice.Invoice_Customer_Code__c
                );
            }
        }

        System.debug('=== VERIFICATION SUMMARY ===');
        System.debug('Correct Assignments: ' + correctAssignments);
        System.debug('Incorrect Assignments: ' + incorrectAssignments);
        System.debug(
            'Accuracy Rate: ' +
                (assignedInvoices.size() > 0
                    ? (correctAssignments * 100.0 / assignedInvoices.size())
                    : 0) +
                '%'
        );
    }

    // ==================== HELPER METHODS FOR ENHANCED ANALYTICS ====================

    /**
     * Calculate months elapsed since contract start
     */
    public static Integer calculateMonthsElapsed(
        Date contractStartDate,
        Date snapshotMonth
    ) {
        if (contractStartDate == null) {
            return 1; // Default to 1 month if no start date
        }

        Date contractStart = contractStartDate.toStartOfMonth();
        Date snapshotStart = snapshotMonth.toStartOfMonth();

        Integer yearDiff = snapshotStart.year() - contractStart.year();
        Integer monthDiff = snapshotStart.month() - contractStart.month();

        Integer totalMonths = (yearDiff * 12) + monthDiff + 1; // +1 to include current month

        // If contract was created after snapshot month, use the difference as positive
        // This handles cases where invoice data exists before formal contract creation
        return Math.abs(totalMonths);
    }

    /**
     * Calculate total sales from contract start to snapshot month
     */
    public static Decimal calculateTotalSalesTillDate(
        Id businessCaseId,
        Date snapshotMonth
    ) {
        Date monthEnd = snapshotMonth.toStartOfMonth().addMonths(1).addDays(-1);

        List<AggregateResult> results = [
            SELECT SUM(Invoice_Value__c) totalSales
            FROM Invoice_Line_Item__c
            WHERE
                Business_Case__c = :businessCaseId
                AND Invoice__r.Invoice_Date__c <= :monthEnd
                AND Invoice_Value__c != NULL
        ];

        Decimal totalSales = 0;
        if (!results.isEmpty() && results[0] != null) {
            totalSales = (Decimal) results[0].get('totalSales');
        }

        return totalSales != null ? totalSales : 0;
    }

    /**
     * Calculate deficit or surplus compared to target
     */
    public static Decimal calculateDeficitCostCovered(
        Decimal ytdSales,
        Decimal monthlyTarget,
        Integer monthsElapsed
    ) {
        if (
            monthlyTarget == null ||
            monthsElapsed == null ||
            monthsElapsed <= 0
        ) {
            return 0;
        }

        Decimal expectedSales = monthlyTarget * monthsElapsed;
        return (ytdSales != null ? ytdSales : 0) - expectedSales;
    }

    /**
     * Determine performance status based on average vs target
     */
    public static String determinePerformanceStatus(
        Decimal avgSalesPerMonth,
        Decimal monthlyTarget
    ) {
        if (monthlyTarget == null || monthlyTarget <= 0) {
            return 'No Target Set';
        }

        if (avgSalesPerMonth == null || avgSalesPerMonth <= 0) {
            return 'Behind';
        }

        Decimal achievementRate = avgSalesPerMonth / monthlyTarget;

        if (achievementRate >= 1.0) {
            // 100% or above considered on track
            return 'On Track';
        } else if (achievementRate >= 0.90) {
            // 90-99% considered at risk
            return 'At Risk';
        } else {
            return 'Behind';
        }
    }

    /**
     * UTILITY: Process snapshots for Business Cases without invoices
     * This method specifically handles non-invoiced Business Cases (e.g., Ordered status machines)
     * Useful for testing and ensuring dashboard shows complete Business Case coverage
     */
    // public static void processNonInvoicedBusinessCases() {
    //     System.debug('=== PROCESSING NON-INVOICED BUSINESS CASES ===');

    //     try {
    //         Date snapshotMonth = Date.today().toStartOfMonth();
    //         List<Business_Case_Sales_Snapshot__c> snapshotsToInsert = new List<Business_Case_Sales_Snapshot__c>();

    //         // Find Business Cases that DON'T have invoice assignments
    //         List<Business_Case__c> nonInvoicedBusinessCases = [
    //             SELECT
    //                 Id,
    //                 Name,
    //                 Status__c,
    //                 Account__c,
    //                 Account__r.Province__c,
    //                 Account__r.City__c,
    //                 Account__r.AddressLine_1__c,
    //                 Account__r.Addess_Line_2__c,
    //                 Account__r.Postal_Code__c,
    //                 Account__r.Country_Code__c,
    //                 Customer_Number__c,
    //                 Customer_Name__c,
    //                 Supplier_Name__c,
    //                 Technology__c,
    //                 Region__c,
    //                 SAP_Material_Number__c,
    //                 Machine_Type__c,
    //                 Quantity__c,
    //                 Monthly_Reagent_Commitment__c,
    //                 Unit_Cost__c,
    //                 Margin_Percent__c,
    //                 Agreement_Date__c,
    //                 Asset_Number__c,
    //                 Asset_Number__r.Status__c,
    //                 Asset_Number__r.Ship_To_Account__c,
    //                 Asset_Number__r.Ship_To_Account__r.SAP_Customer_Number__c,
    //                 Asset_Number__r.Ship_To_Account__r.Name,
    //                 Asset_Number__r.Ship_To_Account__r.Province__c,
    //                 Asset_Number__r.Ship_To_Account__r.City__c,
    //                 Asset_Number__r.Ship_To_Account__r.AddressLine_1__c,
    //                 Asset_Number__r.Ship_To_Account__r.Addess_Line_2__c,
    //                 Asset_Number__r.Ship_To_Account__r.Postal_Code__c,
    //                 Asset_Number__r.Ship_To_Account__r.Country_Code__c
    //             FROM Business_Case__c
    //             WHERE
    //                 Status__c = 'Active'
    //                 AND Id NOT IN (
    //                     SELECT Business_Case__c
    //                     FROM Invoice_Line_Item__c
    //                     WHERE Business_Case__c != NULL
    //                 )
    //             ORDER BY Name
    //             LIMIT 500
    //         ];

    //         if (nonInvoicedBusinessCases.isEmpty()) {
    //             System.debug('ℹ️ No non-invoiced Business Cases found');
    //             return;
    //         }

    //         System.debug(
    //             '📋 Found ' +
    //                 nonInvoicedBusinessCases.size() +
    //                 ' non-invoiced Business Cases (e.g., Ordered status machines)'
    //         );

    //         // Extract IDs for SOQL query
    //         Set<Id> nonInvoicedBusinessCaseIds = new Set<Id>();
    //         for (Business_Case__c bc : nonInvoicedBusinessCases) {
    //             nonInvoicedBusinessCaseIds.add(bc.Id);
    //         }

    //         // Check for existing snapshots to avoid duplicates
    //         Set<String> existingSnapshotKeys = new Set<String>();
    //         List<Business_Case_Sales_Snapshot__c> existingSnapshots = [
    //             SELECT Business_Case__c, Snapshot_Month__c
    //             FROM Business_Case_Sales_Snapshot__c
    //             WHERE
    //                 Business_Case__c IN :nonInvoicedBusinessCaseIds
    //                 AND Snapshot_Month__c = :snapshotMonth
    //         ];

    //         for (Business_Case_Sales_Snapshot__c existing : existingSnapshots) {
    //             existingSnapshotKeys.add(
    //                 existing.Business_Case__c +
    //                     '_' +
    //                     existing.Snapshot_Month__c?.format()
    //             );
    //         }

    //         // Create snapshots for non-invoiced Business Cases
    //         for (Business_Case__c bc : nonInvoicedBusinessCases) {
    //             String snapshotKey = bc.Id + '_' + snapshotMonth.format();

    //             if (!existingSnapshotKeys.contains(snapshotKey)) {
    //                 Business_Case_Sales_Snapshot__c snapshot = createSnapshotForBusinessCase_old(
    //                     bc,
    //                     snapshotMonth
    //                 );
    //                 if (snapshot != null) {
    //                     snapshotsToInsert.add(snapshot);
    //                     System.debug(
    //                         '📊 Created snapshot for non-invoiced BC: ' +
    //                             bc.Name +
    //                             ' | Machine Status: ' +
    //                             bc.Asset_Number__r?.Status__c +
    //                             ' | Customer: ' +
    //                             bc.Customer_Name__c
    //                     );
    //                 }
    //             }
    //         }

    //         // Bulk insert new snapshots
    //         if (!snapshotsToInsert.isEmpty()) {
    //             insert snapshotsToInsert;
    //             System.debug(
    //                 '✅ Successfully created ' +
    //                     snapshotsToInsert.size() +
    //                     ' snapshots for non-invoiced Business Cases'
    //             );
    //         } else {
    //             System.debug('ℹ️ No new non-invoiced snapshots to create');
    //         }
    //     } catch (Exception e) {
    //         System.debug(
    //             '❌ Error in processNonInvoicedBusinessCases: ' + e.getMessage()
    //         );
    //         throw new AuraHandledException(
    //             'Non-invoiced Business Case processing failed: ' +
    //             e.getMessage()
    //         );
    //     }
    // }

    // Bulk version of aggregateInvoiceData
    public static Map<String, InvoiceAggregationResult> bulkAggregateInvoiceData(
        Set<Id> businessCaseIds,
        Set<Date> snapshotMonths
    ) {
        // Precompute date ranges for each month
        Map<Date, Date> monthEndMap = new Map<Date, Date>();
        for (Date m : snapshotMonths) {
            monthEndMap.put(m, m.toStartOfMonth().addMonths(1).addDays(-1));
        }

        // Query once for all business cases + months
        List<AggregateResult> aggResults = [
            SELECT
                Business_Case__c bcId,
                CALENDAR_MONTH(Invoice__r.Invoice_Date__c) monthNum,
                CALENDAR_YEAR(Invoice__r.Invoice_Date__c) yearNum,
                COUNT(Id) invoiceCount,
                SUM(Invoice_Value__c) totalSales
            FROM Invoice_Line_Item__c
            WHERE
                Business_Case__c IN :businessCaseIds
                AND Invoice__r.Invoice_Date__c >= :Date.newInstance(1900, 1, 1) // adjust lower bound if needed
                AND Invoice_Value__c != NULL
            GROUP BY
                Business_Case__c,
                CALENDAR_YEAR(Invoice__r.Invoice_Date__c),
                CALENDAR_MONTH(Invoice__r.Invoice_Date__c)
        ];

        // Build a map keyed by BusinessCaseId + snapshotMonth
        Map<String, InvoiceAggregationResult> resultsMap = new Map<String, InvoiceAggregationResult>();

        for (AggregateResult ar : aggResults) {
            Id bcId = (Id) ar.get('bcId');
            Integer monthNum = (Integer) ar.get('monthNum');
            Integer yearNum = (Integer) ar.get('yearNum');

            Date monthStart = Date.newInstance(yearNum, monthNum, 1);
            if (!snapshotMonths.contains(monthStart))
                continue;

            String key = bcId + '_' + monthStart.format();

            InvoiceAggregationResult result = new InvoiceAggregationResult();
            result.invoiceCount = (Integer) ar.get('invoiceCount');
            result.totalSales = (Decimal) ar.get('totalSales') != null
                ? (Decimal) ar.get('totalSales')
                : 0;

            resultsMap.put(key, result);
        }

        return resultsMap;
    }

    public static Map<String, Decimal> bulkCalculateYTDSales(
        Set<Id> businessCaseIds,
        Set<Date> snapshotMonths
    ) {
        Map<String, Decimal> ytdMap = new Map<String, Decimal>();

        // Query once for all invoices for all bcIds
        List<AggregateResult> aggResults = [
            SELECT
                Business_Case__c bcId,
                CALENDAR_MONTH(Invoice__r.Invoice_Date__c) monthNum,
                CALENDAR_YEAR(Invoice__r.Invoice_Date__c) yearNum,
                SUM(Invoice_Value__c) ytdSales
            FROM Invoice_Line_Item__c
            WHERE
                Business_Case__c IN :businessCaseIds
                AND Invoice_Value__c != NULL
            GROUP BY
                Business_Case__c,
                CALENDAR_YEAR(Invoice__r.Invoice_Date__c),
                CALENDAR_MONTH(Invoice__r.Invoice_Date__c)
        ];

        // For each snapshotMonth, compute YTD up to that month
        // (You can pre-aggregate or sum in code depending on volume)
        // Simple approach: accumulate per bcId per month, then loop snapshotMonths.

        Map<Id, Map<Integer, Decimal>> bcToMonthTotals = new Map<Id, Map<Integer, Decimal>>();
        for (AggregateResult ar : aggResults) {
            Id bcId = (Id) ar.get('bcId');
            Integer monthNum = (Integer) ar.get('monthNum');
            Integer yearNum = (Integer) ar.get('yearNum');
            Decimal amt = (Decimal) ar.get('ytdSales') != null
                ? (Decimal) ar.get('ytdSales')
                : 0;

            if (!bcToMonthTotals.containsKey(bcId)) {
                bcToMonthTotals.put(bcId, new Map<Integer, Decimal>());
            }

            bcToMonthTotals.get(bcId).put(yearNum * 100 + monthNum, amt);
        }

        // Now for each snapshot month, sum up YTD
        for (Id bcId : businessCaseIds) {
            System.debug(
                '>>>>BusinessCaseSnapshotService-->bulkCalculateYTDSales-->bcId: ' +
                bcId
            );
            for (Date snap : snapshotMonths) {
                Integer keyMonth = snap.year() * 100 + snap.month();
                Decimal sumAmt = 0;
                if (bcToMonthTotals.containsKey(bcId)) {
                    for (Integer ym : bcToMonthTotals.get(bcId).keySet()) {
                        System.debug(
                            '>>>>BusinessCaseSnapshotService-->bulkCalculateYTDSales-->snap Amount: ' +
                            ym
                        );
                        if (ym <= keyMonth && ym >= snap.year() * 100 + 1) {
                            sumAmt += bcToMonthTotals.get(bcId).get(ym);
                        }
                    }
                }
                ytdMap.put(bcId + '_' + snap.format(), sumAmt);
            }
            System.debug(
                '>>>>BusinessCaseSnapshotService-->bulkCalculateYTDSales-->ytdMap: ' +
                ytdMap
            );
        }

        return ytdMap;
    }

    public static Map<String, Decimal> bulkCalculateTotalSalesTillDate(
        Set<Id> businessCaseIds,
        Set<Date> snapshotMonths
    ) {
        Map<String, Decimal> totalSalesMap = new Map<String, Decimal>();
        System.debug(
            '>>>>BusinessCaseSnapshotService-->bulkCalculateTotalSalesTillDate'
        );
        System.debug(
            '>>>>BusinessCaseSnapshotService-->bulkCalculateTotalSalesTillDate-->snaphost months: ' +
            snapshotMonths
        );

        // Build the “end date” for each BC + Month key
        Map<String, Date> bcMonthEndDates = new Map<String, Date>();
        for (Id bcId : businessCaseIds) {
            for (Date month : snapshotMonths) {
                Date monthEnd = month.toStartOfMonth().addMonths(1).addDays(-1);
                // FIX: Use month.format() to match keys used everywhere else
                String key = bcId + '_' + month.format();
                bcMonthEndDates.put(key, monthEnd);
                totalSalesMap.put(key, 0); // initialize
            }
        }

        System.debug(
            '>>>>BusinessCaseSnapshotService-->bulkCalculateTotalSalesTillDate-->bcMonthEndDates:' +
            bcMonthEndDates
        );
        System.debug(
            '>>>>BusinessCaseSnapshotService-->bulkCalculateTotalSalesTillDate-->totalSalesMap:' +
            totalSalesMap
        );

        // Get all distinct monthEnd dates
        Set<Date> allMonthEnds = new Set<Date>(bcMonthEndDates.values());

        // Query all Invoice Line Items once for all BCs and all monthEnd dates
        // (we'll filter in memory)
        List<Invoice_Line_Item__c> allInvoices = [
            SELECT
                Business_Case__c,
                Invoice_Value__c,
                Invoice__r.Invoice_Date__c
            FROM Invoice_Line_Item__c
            WHERE
                Business_Case__c IN :businessCaseIds
                AND Invoice_Value__c != NULL
                AND Invoice__r.Invoice_Date__c <= :Date.today() // broad upper bound
        ];

        System.debug(
            '>>>>BusinessCaseSnapshotService-->bulkCalculateTotalSalesTillDate-->allInvoices:' +
            allInvoices.size()
        );

        if (allInvoices.isEmpty()) {
            return totalSalesMap;
        }

        Map<Id, List<Invoice_Line_Item__c>> invoicesByBC = new Map<Id, List<Invoice_Line_Item__c>>();
        for (Invoice_Line_Item__c inv : allInvoices) {
            if (!invoicesByBC.containsKey(inv.Business_Case__c)) {
                invoicesByBC.put(
                    inv.Business_Case__c,
                    new List<Invoice_Line_Item__c>()
                );
            }
            invoicesByBC.get(inv.Business_Case__c).add(inv);
        }
        System.debug(
            '>>>>BusinessCaseSnapshotService-->bulkCalculateTotalSalesTillDate-->invoicesByBC:' +
            invoicesByBC
        );
        // Group invoices by BC and monthEnd
        // for (String key : bcMonthEndDates.keySet()) {
        //     totalSalesMap.put(key, 0); // initialize
        // }

        // for (Invoice_Line_Item__c inv : allInvoices) {
        //     for (Date monthEnd : allMonthEnds)
        //     {
        //          String monthEndKey = monthEnd.year() + '-' +
        //                      String.valueOf(monthEnd.month()).padLeft(2, '0') + '-' +
        //                      String.valueOf(monthEnd.day()).padLeft(2, '0');
        //         // build key for this BC + monthEnd
        //         String key = inv.Business_Case__c + '_' +monthEndKey;
        //         // check invoice date <= monthEnd
        //         if (bcMonthEndDates.get(key) != null && inv.Invoice__r.Invoice_Date__c <= monthEnd) {
        //             Decimal running = totalSalesMap.containsKey(key) ? totalSalesMap.get(key) : 0;
        //             totalSalesMap.put(key, running + inv.Invoice_Value__c);
        //         }
        //     }
        // }
        for (String key : bcMonthEndDates.keySet()) {
            Id bcId = (Id) key.split('_')[0];
            Date monthEnd = bcMonthEndDates.get(key);
            System.debug(
                '>>>>BusinessCaseSnapshotService-->bulkCalculateTotalSalesTillDate-->Month End Key:' +
                monthEnd
            );
            if (!invoicesByBC.containsKey(bcId))
                continue;

            Decimal total = 0;
            for (Invoice_Line_Item__c inv : invoicesByBC.get(bcId)) {
                if (inv.Invoice__r.Invoice_Date__c <= monthEnd) {
                    total += inv.Invoice_Value__c;
                }
            }

            totalSalesMap.put(key, total);
        }
        System.debug(
            '>>>>BusinessCaseSnapshotService-->bulkCalculateTotalSalesTillDate-->Final totalSalesMap:' +
            totalSalesMap
        );
        // return totalSalesMap;

        return totalSalesMap;
    }

    
}