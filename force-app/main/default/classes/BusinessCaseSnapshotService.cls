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
            try {
                Integer assignmentCount = assignBusinessCasesToInvoices();

                Integer masterassignmentCount = assignMasterBusinessCasesToInvoices();

                processComprehensiveSnapshots();
                processMasterComprehensiveSnapshots();
            } catch (Exception e) {
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
        try {
            BusinessCaseSnapshotBatch job = new BusinessCaseSnapshotBatch();
            Id jobId = System.Database.executeBatch(job, 20);
        } catch (Exception e) {
            throw e;
        }
    }

    //Process Master Comprehensive Screenshot
    public static void processMasterComprehensiveSnapshots() {
        try {
            BusinessCaseMasterSnapshotBatch job = new BusinessCaseMasterSnapshotBatch();
            Id jobId = System.Database.executeBatch(job, 4);
        } catch (Exception e) {
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
                return invoiceMonth;
            } else {
                // No invoices found, use current month for non-invoiced Business Cases
                Date currentMonth = Date.today().toStartOfMonth();
                return currentMonth;
            }
        } catch (Exception e) {
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
                return agreementMonth;
            }

            // Priority 2: Use a recent historical month instead of current month (to avoid 2025 dates)
            // Use April 2024 as default since most invoice data is from that timeframe
            Date defaultMonth = Date.newInstance(2024, 4, 1);
            return defaultMonth;
        } catch (Exception e) {
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
            }

            return monthsList;
        } catch (Exception e) {
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
        try {
            List<Business_Case_Sales_Snapshot__c> snapshotsToInsert = new List<Business_Case_Sales_Snapshot__c>();

            // Get invoice months for this batch only
            Set<Id> bcIds = new Set<Id>();
            for (Business_Case__c bc : businessCases) {
                bcIds.add(bc.Id);
            }

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
                }
            }

            // Query all existing snapshots in one go for this batch
            List<Business_Case_Sales_Snapshot__c> existingSnapshots = [
                SELECT Business_Case__c, Snapshot_Month__c
                FROM Business_Case_Sales_Snapshot__c
                WHERE
                    Business_Case__c IN :bcIds
                    AND Snapshot_Month__c IN :allMonths
            ];

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
                for (Date month : bcToMonths.get(bc.Id)) {
                    String key = bc.Id + '_' + month.format();
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
                            snapshot = null;
                        }

                        if (snapshot != null) {
                            snapshotsToInsert.add(snapshot);
                        }
                    }
                }
            }

            // Insert snapshots
            if (!snapshotsToInsert.isEmpty()) {
                Database.insert(snapshotsToInsert, false);
            }

            return snapshotsToInsert.size();
        } catch (Exception ex) {
            return 0;
        }
    }

    //Process Master Business Batch Snapshots
    public static Integer processMasterBatchSnapshots(
        List<Business_Case__c> businessCases
    ) {
        try {
            List<Business_Case__c> mastersWithIndividuals = new List<Business_Case__c>();
            for (Business_Case__c bc : businessCases) {
                if (!bc.Business_Cases__r.isEmpty()) {
                    mastersWithIndividuals.add(bc);
                }
            }

            List<Business_Case_Sales_Snapshot__c> snapshotsToInsert = new List<Business_Case_Sales_Snapshot__c>();

            // Get invoice months for this batch only
            Set<Id> bcIds = new Set<Id>();
            for (Business_Case__c bc : mastersWithIndividuals) {
                bcIds.add(bc.Id);
            }

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
                }
            }

            // Query all existing snapshots in one go for this batch
            List<Business_Case_Sales_Snapshot__c> existingSnapshots = [
                SELECT Business_Case__c, Snapshot_Month__c
                FROM Business_Case_Sales_Snapshot__c
                WHERE
                    Business_Case__c IN :bcIds
                    AND Snapshot_Month__c IN :allMonths
            ];

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
                for (Date month : bcToMonths.get(bc.Id)) {
                    String key = bc.Id + '_' + month.format();
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
                            snapshot = null;
                        }

                        if (snapshot != null) {
                            snapshotsToInsert.add(snapshot);
                        }
                    }
                }
            }

            // Insert snapshots
            if (!snapshotsToInsert.isEmpty()) {
                Database.insert(snapshotsToInsert, false);
            }

            return snapshotsToInsert.size();
        } catch (Exception ex) {
            return 0;
        }
    }

    /**
     * OPTIMIZED: Bulk assignment - Single query approach to minimize SOQL usage
     * Uses memory processing instead of per-BC queries for better governor limit compliance
     */
    public static Integer assignBusinessCasesToInvoices() {
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
                String matchingPattern = supplierCode + '-' + technologyCode;

                if (!customerToBCMap.containsKey(customerCode)) {
                    customerToBCMap.put(
                        customerCode,
                        new List<Business_Case__c>()
                    );
                }
                customerToBCMap.get(customerCode).add(bc);
                bcToMatchingPattern.put(bc.Id, matchingPattern);
            }
        }

        // SINGLE BULK QUERY: Get all unassigned reagent invoices
        List<Invoice_Line_Item__c> allUnassignedInvoices = [
            SELECT Id, Invoice_Customer_Code__c, AG_OG__c, Business_Case__c
            FROM Invoice_Line_Item__c
            WHERE
                Business_Case__c = NULL
                AND DGroup__c = 'Reagent'
                AND Invoice_Value__c != NULL
                AND Invoice_Customer_Code__c IN :customerToBCMap.keySet()
        ];

        Integer totalAssigned = 0;
        List<Invoice_Line_Item__c> allInvoicesToUpdate = new List<Invoice_Line_Item__c>();

        // Memory-based matching: Much faster than individual queries
        for (Invoice_Line_Item__c invoice : allUnassignedInvoices) {
            List<Business_Case__c> possibleBCs = customerToBCMap.get(
                invoice.Invoice_Customer_Code__c
            );
            if (possibleBCs != null) {
                for (Business_Case__c bc : possibleBCs) {
                    String requiredPattern = bcToMatchingPattern.get(bc.Id);
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
        }

        // Bulk update all assignments in ONE DML operation
        if (!allInvoicesToUpdate.isEmpty()) {
            update allInvoicesToUpdate;
        }

        return totalAssigned;
    }

    //assign Master Business Cases To Invoices
    public static Integer assignMasterBusinessCasesToInvoices() {
        // Get all active Master Business Cases
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

        // Create lookup maps for efficient matching
        Map<String, List<Business_Case__c>> customerToBCMap = new Map<String, List<Business_Case__c>>();
        Map<String, String> bcToMatchingPattern = new Map<String, String>();

        for (Business_Case__c bc : activeBusinessCases) {
            String customerCode = bc.Customer_Numbera__c;
            String supplierCode = extractSupplierCode(bc.Vendor__c);
            String technologyCode = extractTechnologyCode(bc.Technologyaa__c);

            if (
                String.isNotBlank(customerCode) &&
                String.isNotBlank(supplierCode) &&
                String.isNotBlank(technologyCode)
            ) {
                String matchingPattern = supplierCode + '-' + technologyCode;

                if (!customerToBCMap.containsKey(customerCode)) {
                    customerToBCMap.put(
                        customerCode,
                        new List<Business_Case__c>()
                    );
                }
                customerToBCMap.get(customerCode).add(bc);
                bcToMatchingPattern.put(bc.Id, matchingPattern);
            }
        }

        // SINGLE BULK QUERY: Get all unassigned reagent invoices
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
        ];

        Integer totalAssigned = 0;
        List<Invoice_Line_Item__c> allInvoicesToUpdate = new List<Invoice_Line_Item__c>();

        // Memory-based matching: Much faster than individual queries
        for (Invoice_Line_Item__c invoice : allUnassignedInvoices) {
            List<Business_Case__c> possibleBCs = customerToBCMap.get(
                invoice.Invoice_Customer_Code__c
            );
            if (possibleBCs != null) {
                for (Business_Case__c bc : possibleBCs) {
                    String requiredPattern = bcToMatchingPattern.get(bc.Id);
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
        }

        // Bulk update all assignments in ONE DML operation
        if (!allInvoicesToUpdate.isEmpty()) {
            update allInvoicesToUpdate;
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
        }

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

        if (parts.size() >= 2) {
            String vendorCode = parts[0].trim();
            String technologyCode = parts[1].trim();
            return new List<String>{ vendorCode, technologyCode };
        }

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
            // Create snapshot record
            Business_Case_Sales_Snapshot__c snapshot = new Business_Case_Sales_Snapshot__c();

            // Core identifiers - using Business Case ID + Month instead of complex key
            snapshot.Business_Case__c = businessCase.Id;
            snapshot.Snapshot_Month__c = snapshotMonth.addMonths(1).addDays(-1);
            snapshot.Snapshot_Created_Date__c = Date.today();
            snapshot.Monthly_Commitments__c = businessCase.Monthly_Reagent_Commitment__c;

            // Business Case dimensions
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

            // Ship To Account address (from Asset -> Ship To Account)
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

            // Machine count based on Business Case quantity (default to 1 if empty/invalid)
            Decimal quantity = 1; // Default value
            if (String.isNotBlank(businessCase.Quantity__c)) {
                try {
                    quantity = Decimal.valueOf(businessCase.Quantity__c);
                    if (quantity <= 0) {
                        quantity = 1; // Ensure positive value
                    }
                } catch (Exception e) {
                    quantity = 1; // Fallback to 1 if parsing fails
                }
            }
            snapshot.Machine_Count__c = quantity;
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

            // ==================== ENHANCED ANALYTICS FIELDS ====================

            // Calculate contract performance metrics using Agreement_Date__c
            Integer contractMonthsElapsed = calculateMonthsElapsed(
                businessCase.Agreement_Date__c, // Use proper contract start date
                snapshotMonth
            );

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

            Decimal deficitCostCovered = calculateDeficitCostCovered(
                ytdSales,
                businessCase.Monthly_Reagent_Commitment__c,
                contractMonthsElapsed
            );
            String performanceStatus = determinePerformanceStatus(
                invoiceData.totalSales,
                businessCase.Monthly_Reagent_Commitment__c
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
            if(snapshot.Margin_Percent_Snapshot__c > 0)
            {
                snapshot.Margin_till_Date__c = (totalSalesTillDate * (snapshot.Margin_Percent_Snapshot__c ?? 0))/ 100;
            }

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
            return snapshot;
        } catch (Exception ex) {
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
        // Create snapshot record
        Business_Case_Sales_Snapshot__c snapshot = new Business_Case_Sales_Snapshot__c();

        // Core identifiers - using Business Case ID + Month instead of complex key
        snapshot.Business_Case__c = businessCase.Id;
        snapshot.Snapshot_Month__c = snapshotMonth.addMonths(1).addDays(-1);
        snapshot.Snapshot_Created_Date__c = Date.today();
        snapshot.Monthly_Commitments__c = businessCase.Sum_of_Monthly_Reagent_Commitment__c;

        // Business Case dimensions
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

        Decimal deficitCostCovered = calculateDeficitCostCovered(
            ytdSales,
            businessCase.Sum_of_Monthly_Reagent_Commitment__c,
            contractMonthsElapsed
        );
        String performanceStatus = determinePerformanceStatus(
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
        return snapshot;
    }

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
     * Verification method to check manually assigned Business Cases against matching logic
     * Use this to validate that manual assignments are consistent with the automated logic
     */
    public static void verifyManualBusinessCaseAssignments() {
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
            } else {
                incorrectAssignments++;
            }
        }
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
                AND Invoice__r.Invoice_Date__c >= :Date.newInstance(1900, 1, 1)
                AND Invoice_Value__c != NULL
                AND DGroup__c = 'Reagent'
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
                AND DGroup__c = 'Reagent'
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
            for (Date snap : snapshotMonths) {
                Integer keyMonth = snap.year() * 100 + snap.month();
                Decimal sumAmt = 0;
                if (bcToMonthTotals.containsKey(bcId)) {
                    for (Integer ym : bcToMonthTotals.get(bcId).keySet()) {
                        if (ym <= keyMonth && ym >= snap.year() * 100 + 1) {
                            sumAmt += bcToMonthTotals.get(bcId).get(ym);
                        }
                    }
                }
                ytdMap.put(bcId + '_' + snap.format(), sumAmt);
            }
        }

        return ytdMap;
    }

    public static Map<String, Decimal> bulkCalculateTotalSalesTillDate(
        Set<Id> businessCaseIds,
        Set<Date> snapshotMonths
    ) {
        Map<String, Decimal> totalSalesMap = new Map<String, Decimal>();

        // Build the "end date" for each BC + Month key
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
                AND DGroup__c = 'Reagent'
                AND Invoice__r.Invoice_Date__c <= :Date.today()
        ];

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

        for (String key : bcMonthEndDates.keySet()) {
            Id bcId = (Id) key.split('_')[0];
            Date monthEnd = bcMonthEndDates.get(key);
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

        return totalSalesMap;
    }

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
     * Assign unassigned Reagent invoices to Business Cases for a single customer code.
     * Individual BCs are tried first; Master BCs fill any remaining unmatched invoices.
     * Returns the number of invoice line items linked.
     */
    public static Integer assignInvoicesForCustomer(String customerCode) {
        if (String.isBlank(customerCode)) return 0;
        Map<String, Integer> results = assignInvoicesForCustomerList(
            new List<String>{ customerCode }
        );
        return results.containsKey(customerCode) ? results.get(customerCode) : 0;
    }

    /**
     * Bulk version of assignInvoicesForCustomer.
     * Uses exactly 3 SOQL queries regardless of how many customer codes are supplied,
     * keeping well within governor limits.
     * Returns a map of customerCode -> number of invoices linked.
     */
    public static Map<String, Integer> assignInvoicesForCustomerList(
        List<String> customerCodes
    ) {
        Map<String, Integer> results = new Map<String, Integer>();
        if (customerCodes == null || customerCodes.isEmpty()) return results;

        Set<String> customerSet = new Set<String>(customerCodes);

        // ── Query 1: Standalone Individual Business Cases (no master) ────────
        // Only BCs with no Master_Business_Case__c — mirrors assignBusinessCasesToInvoices
        // which also filters Master_Business_Case__c = NULL so child BCs are never
        // linked directly when a Master BC exists for the same customer+pattern.
        List<Business_Case__c> individualBCs = [
            SELECT
                Id,
                Name,
                Machine_Installation__r.bill_to_account__r.SAP_Customer_Number__c,
                Machine_Installation__r.Diagnostic_Machine__r.Vendor__c,
                Machine_Installation__r.Diagnostic_Machine__r.Technology__c
            FROM Business_Case__c
            WHERE
                Is_Master__c = FALSE
                AND Master_Business_Case__c = NULL
                AND (Status__c LIKE '%New%'
                    OR Status__c LIKE '%Active%'
                    OR Status__c LIKE '%Revised%')
                AND Machine_Installation__r.bill_to_account__r.SAP_Customer_Number__c
                    IN :customerSet
        ];

        // Map: customerCode -> (pattern -> first matching Individual BC)
        Map<String, Map<String, Business_Case__c>> individualMap =
            new Map<String, Map<String, Business_Case__c>>();

        for (Business_Case__c bc : individualBCs) {
            String custCode = bc.Machine_Installation__r.bill_to_account__r.SAP_Customer_Number__c;
            String supplierCode = extractSupplierCode(
                bc.Machine_Installation__r.Diagnostic_Machine__r.Vendor__c
            );
            String technologyCode = extractTechnologyCode(
                bc.Machine_Installation__r.Diagnostic_Machine__r.Technology__c
            );
            if (String.isBlank(supplierCode) || String.isBlank(technologyCode)) continue;

            String pattern = supplierCode + '-' + technologyCode;
            if (!individualMap.containsKey(custCode)) {
                individualMap.put(custCode, new Map<String, Business_Case__c>());
            }
            // First BC wins per customer+pattern (consistent with existing bulk assignment)
            if (!individualMap.get(custCode).containsKey(pattern)) {
                individualMap.get(custCode).put(pattern, bc);
            }
        }

        // ── Query 2: Master Business Cases for these customers ────────────────
        List<Business_Case__c> masterBCs = [
            SELECT
                Id,
                Name,
                Customer_Numbera__c,
                Vendor__c,
                Technologyaa__c
            FROM Business_Case__c
            WHERE
                RecordType.Name = 'Master Business Case'
                AND (Status__c LIKE '%Active%'
                    OR Status__c LIKE '%Revised%'
                    OR Status__c LIKE '%New%')
                AND Customer_Numbera__c IN :customerSet
        ];

        // Map: customerCode -> (pattern -> first matching Master BC)
        Map<String, Map<String, Business_Case__c>> masterMap =
            new Map<String, Map<String, Business_Case__c>>();

        for (Business_Case__c bc : masterBCs) {
            String custCode = bc.Customer_Numbera__c;
            String supplierCode = extractSupplierCode(bc.Vendor__c);
            String technologyCode = extractTechnologyCode(bc.Technologyaa__c);
            if (String.isBlank(supplierCode) || String.isBlank(technologyCode)) continue;

            String pattern = supplierCode + '-' + technologyCode;
            if (!masterMap.containsKey(custCode)) {
                masterMap.put(custCode, new Map<String, Business_Case__c>());
            }
            if (!masterMap.get(custCode).containsKey(pattern)) {
                masterMap.get(custCode).put(pattern, bc);
            }
        }

        if (individualMap.isEmpty() && masterMap.isEmpty()) return results;

        // ── Query 3: All unassigned Reagent invoices for these customers ──────
        List<Invoice_Line_Item__c> unassignedInvoices = [
            SELECT Id, Invoice_Customer_Code__c, AG_OG__c
            FROM Invoice_Line_Item__c
            WHERE
                Business_Case__c = NULL
                AND DGroup__c = 'Reagent'
                AND Invoice_Value__c != NULL
                AND Invoice_Customer_Code__c IN :customerSet
        ];

        List<Invoice_Line_Item__c> invoicesToUpdate = new List<Invoice_Line_Item__c>();

        for (Invoice_Line_Item__c invoice : unassignedInvoices) {
            String custCode = invoice.Invoice_Customer_Code__c;
            if (String.isBlank(invoice.AG_OG__c)) continue;

            Boolean assigned = false;

            // Master BC always wins — link to Master if one exists for this customer+pattern
            if (masterMap.containsKey(custCode)) {
                for (String pattern : masterMap.get(custCode).keySet()) {
                    if (invoice.AG_OG__c.startsWith(pattern)) {
                        invoice.Business_Case__c = masterMap.get(custCode).get(pattern).Id;
                        invoicesToUpdate.add(invoice);
                        results.put(
                            custCode,
                            (results.containsKey(custCode) ? results.get(custCode) : 0) + 1
                        );
                        assigned = true;
                        break;
                    }
                }
            }

            // Fall back to standalone Individual BC only if no Master BC matched
            if (!assigned && individualMap.containsKey(custCode)) {
                for (String pattern : individualMap.get(custCode).keySet()) {
                    if (invoice.AG_OG__c.startsWith(pattern)) {
                        invoice.Business_Case__c = individualMap.get(custCode).get(pattern).Id;
                        invoicesToUpdate.add(invoice);
                        results.put(
                            custCode,
                            (results.containsKey(custCode) ? results.get(custCode) : 0) + 1
                        );
                        break;
                    }
                }
            }
        }

        if (!invoicesToUpdate.isEmpty()) {
            update invoicesToUpdate;
        }

        return results;
    }

    /**
     * Process invoice assignment for all 93 customers from the
     * Tracking sheet for Reagent Rental of Machines - Mar 2026.
     * Run from Developer Console:
     *   Map<String,Integer> r = BusinessCaseSnapshotService.assignInvoicesFromTrackingSheet();
     */
    public static Map<String, Integer> assignInvoicesFromTrackingSheet() {
        List<String> customerCodes = new List<String>{
            '3020000013', '3020000022', '3020000072', '3020000084', '3020000088',
            '3020000114', '3020000125', '3020000135', '3020000166', '3020000176',
            '3020000190', '3020000206', '3020000209', '3020000314', '3020000379',
            '3020000386', '3020000393', '3020000394', '3020000439', '3020000447',
            '3020000477', '3020000491', '3020000515', '3020000539', '3020000547',
            '3020000580', '3020000605', '3020000633', '3020000645', '3020000647',
            '3020000664', '3020000678', '3020000685', '3020000692', '3020000701',
            '3020000719', '3020000734', '3020000736', '3020000753', '3020000764',
            '3020000771', '3020000776', '3020000811', '3020000816', '3020000823',
            '3020000845', '3020000881', '3020000888', '3020000896', '3020000917',
            '3020000936', '3020000943', '3020000960', '3020000979', '3020000987',
            '3020000998', '3020001019', '3020001042', '3020001047', '3020001067',
            '3020001074', '3020001083', '3020001086', '3020001092', '3020001102',
            '3020001115', '3020001124', '3020001131', '3020001141', '3020001174',
            '3020001175', '3020001192', '3020001221', '3020001224', '3020001230',
            '3020001237', '3020001238', '3020001255', '3020001280', '3020001357',
            '3020001382', '3020001384', '3020001399', '3020001430', '3020001475',
            '3020001479', '3020001511', '3020001552', '3020001659', '3020001748',
            '3020001809', '3020001811', '3020001814'
        };
        return assignInvoicesForCustomerList(customerCodes);
    }

    // =========================================================================
    // CUSTOMER-CENTRIC SNAPSHOT PROCESSING
    // =========================================================================

    /**
     * Process missing historical snapshots for a customer (normal incremental run).
     */
    public static void processSnapshotsForCustomer(String customerCode) {
        processSnapshotsForCustomer(customerCode, false);
    }

    /**
     * Process historical snapshots for a customer.
     * forceRecalculate = false : only creates snapshots for months not yet snapshotted (incremental).
     * forceRecalculate = true  : recalculates ALL months from Agreement Date and updates existing
     *                            snapshot records in place — use after fixing invoice data.
     * Writes Agreement_Date__c back to the BC if missing, using the first invoice date.
     * Never processes the current month — only completed months.
     */
    public static void processSnapshotsForCustomer(String customerCode, Boolean forceRecalculate) {
        if (String.isBlank(customerCode)) return;

        Date currentMonthStart  = Date.today().toStartOfMonth();
        Date lastCompletedMonth = currentMonthStart.addMonths(-1);

        List<Business_Case__c> masterBCs     = queryMasterBCsForCustomer(customerCode);
        List<Business_Case__c> individualBCs = queryIndividualBCsForCustomer(customerCode);

        List<Business_Case__c> allBCs = new List<Business_Case__c>();
        allBCs.addAll(masterBCs);
        allBCs.addAll(individualBCs);
        if (allBCs.isEmpty()) return;

        Set<Id> bcIds = new Set<Id>();
        for (Business_Case__c bc : allBCs) bcIds.add(bc.Id);

        Map<Id, Date> firstInvoiceDates  = getFirstInvoiceDates(bcIds);
        backfillAgreementDates(allBCs, firstInvoiceDates);

        Map<Id, Date> lastSnapshotMonths = forceRecalculate
            ? new Map<Id, Date>()
            : getLastSnapshotMonths(bcIds);

        Set<Id> masterBCIds = new Set<Id>();
        for (Business_Case__c bc : masterBCs) masterBCIds.add(bc.Id);

        Map<Id, List<Date>> bcToMonths      = new Map<Id, List<Date>>();
        Set<Date>           allMonthsNeeded = new Set<Date>();

        for (Business_Case__c bc : allBCs) {
            Date startDate = bc.Agreement_Date__c;
            if (startDate == null) continue;

            Date startMonth  = startDate.toStartOfMonth();
            Date lastSnap    = lastSnapshotMonths.get(bc.Id);
            // toStartOfMonth() handles both old (1st) and new (last-day) stored formats
            Date processFrom = (lastSnap == null) ? startMonth : lastSnap.toStartOfMonth().addMonths(1);

            if (processFrom > lastCompletedMonth) continue;

            List<Date> months = generateMonthRange(processFrom, lastCompletedMonth);
            bcToMonths.put(bc.Id, months);
            allMonthsNeeded.addAll(months);
        }

        if (bcToMonths.isEmpty()) return;

        Map<String, InvoiceAggregationResult> invoiceMap = bulkAggregateInvoiceData(bcIds, allMonthsNeeded);
        Map<String, Decimal>                  ytdMap     = bulkCalculateYTDSales(bcIds, allMonthsNeeded);
        Map<String, Decimal>                  totalMap   = bulkCalculateTotalSalesTillDate(bcIds, allMonthsNeeded);

        // When recalculating, map existing snapshot Ids so we UPDATE instead of INSERT
        Map<String, Id> existingSnapshotIds = new Map<String, Id>();
        if (forceRecalculate) {
            for (Business_Case_Sales_Snapshot__c snap : [
                SELECT Id, Business_Case__c, Snapshot_Month__c
                FROM Business_Case_Sales_Snapshot__c
                WHERE Business_Case__c IN :bcIds
            ]) {
                String key = snap.Business_Case__c + '_' + snap.Snapshot_Month__c.toStartOfMonth().format();
                existingSnapshotIds.put(key, snap.Id);
            }
        }

        Map<Id, Business_Case__c> bcMap = new Map<Id, Business_Case__c>();
        for (Business_Case__c bc : allBCs) bcMap.put(bc.Id, bc);

        List<Business_Case_Sales_Snapshot__c> toInsert = new List<Business_Case_Sales_Snapshot__c>();
        List<Business_Case_Sales_Snapshot__c> toUpdate = new List<Business_Case_Sales_Snapshot__c>();

        for (Id bcId : bcToMonths.keySet()) {
            Business_Case__c bc       = bcMap.get(bcId);
            Boolean          isMaster = masterBCIds.contains(bcId);

            for (Date month : bcToMonths.get(bcId)) {
                String                   key = bcId + '_' + month.format();
                InvoiceAggregationResult inv = invoiceMap.containsKey(key) ? invoiceMap.get(key) : new InvoiceAggregationResult();
                Decimal ytd   = ytdMap.containsKey(key)   ? ytdMap.get(key)   : 0;
                Decimal total = totalMap.containsKey(key) ? totalMap.get(key) : 0;

                try {
                    Business_Case_Sales_Snapshot__c snap = isMaster
                        ? createSnapshotForMasterBusinessCase(bc, month, inv, ytd, total)
                        : createSnapshotForBusinessCase(bc, month, inv, ytd, total);

                    if (snap != null) {
                        if (forceRecalculate && existingSnapshotIds.containsKey(key)) {
                            snap.Id = existingSnapshotIds.get(key);
                            toUpdate.add(snap);
                        } else {
                            toInsert.add(snap);
                        }
                    }
                } catch (Exception e) { }
            }
        }

        if (!toInsert.isEmpty()) Database.insert(toInsert, false);
        if (!toUpdate.isEmpty()) Database.update(toUpdate, false);
    }

    /**
     * Dashboard query: returns a unified list of snapshot data for a customer and date range.
     * Historical months (before current month) come from the snapshot table.
     * Current month is queried live from Invoice_Line_Item__c and returned as unsaved snapshot objects.
     */
    public static List<Business_Case_Sales_Snapshot__c> getSnapshotsForDashboard(
        String customerCode,
        Date   filterStartDate,
        Date   filterEndDate
    ) {
        if (String.isBlank(customerCode) || filterStartDate == null || filterEndDate == null) {
            return new List<Business_Case_Sales_Snapshot__c>();
        }

        Date currentMonthStart = Date.today().toStartOfMonth();
        List<Business_Case_Sales_Snapshot__c> results = new List<Business_Case_Sales_Snapshot__c>();

        Set<Id> bcIds = getBCIdsForCustomer(customerCode);
        if (bcIds.isEmpty()) return results;

        // Historical portion — snapshot table
        if (filterStartDate < currentMonthStart) {
            Date histStartMonth = filterStartDate.toStartOfMonth();
            Date histEndMonth   = (filterEndDate < currentMonthStart ? filterEndDate : currentMonthStart.addDays(-1)).toStartOfMonth();

            results.addAll([
                SELECT Id, Business_Case__c, Snapshot_Month__c,
                       Total_Reagent_Sales__c, YTD_Sales__c, Total_Reagent_Sales_Till_Date__c,
                       Target_Sales__c, Performance_Status__c, Contract_Months_Elapsed__c,
                       Avg_Reagent_Sales_Per_Month__c, Avg_YTD_Sales_Per_Month__c,
                       Deficit_Cost_Covered__c, Margin_Percent_Snapshot__c,
                       Margin_On_Reagent_Sale__c, Margin_till_Date__c, Payback_Remaining__c,
                       Business_Case_Name__c, Business_Case_Status__c, Machine_Status__c,
                       Customer_Code__c, Customer_Name__c, Vendor__c, Technology__c,
                       Region__c, Machine_Count__c, Source_Invoice_Count__c,
                       Monthly_Commitments__c, Material_Number__c, Material_Description__c,
                       Snapshot_Created_Date__c, Processing_Status__c
                FROM Business_Case_Sales_Snapshot__c
                WHERE Business_Case__c IN :bcIds
                AND   Snapshot_Month__c >= :histStartMonth
                AND   Snapshot_Month__c <= :histEndMonth
                ORDER BY Business_Case__c, Snapshot_Month__c ASC
            ]);
        }

        // Current month — live query
        if (filterEndDate >= currentMonthStart) {
            results.addAll(buildLiveSnapshots(customerCode, currentMonthStart));
        }

        return results;
    }

    // ── Private Helpers ───────────────────────────────────────────────────────

    private static List<Business_Case__c> queryMasterBCsForCustomer(String customerCode) {
        return [
            SELECT Id, Name, Agreement_Date__c, Status__c, Quantity__c,
                   Customer_Numbera__c, Customer_Namea__c, Vendor__c, Technologyaa__c,
                   Material_Number__c, Material_Descriptionsa__c,
                   Sum_of_Monthly_Reagent_Commitment__c, Sum_of_Unit_Cost__c, Margin_Percent__c,
                   (SELECT Id, Region__c,
                           Machine_Installation__r.Diagnostic_Machine__r.Vendor__c,
                           Machine_Installation__r.Diagnostic_Machine__r.Technology__c,
                           Machine_Installation__r.Status__c,
                           Machine_Installation__r.bill_to_account__r.Province__c,
                           Machine_Installation__r.bill_to_account__r.City__c,
                           Machine_Installation__r.bill_to_account__r.AddressLine_1__c,
                           Machine_Installation__r.bill_to_account__r.Postal_Code__c,
                           Machine_Installation__r.bill_to_account__r.Country_Code__c
                    FROM Business_Cases__r LIMIT 1)
            FROM Business_Case__c
            WHERE RecordType.Name = 'Master Business Case'
            AND Customer_Numbera__c = :customerCode
            AND (Status__c LIKE '%Active%' OR Status__c LIKE '%Revised%' OR Status__c LIKE '%New%')
        ];
    }

    private static List<Business_Case__c> queryIndividualBCsForCustomer(String customerCode) {
        return [
            SELECT Id, Name, Agreement_Date__c, Status__c, Quantity__c,
                   Customer_Number__c, Supplier_Name__c, Technology__c,
                   Monthly_Reagent_Commitment__c, Unit_Cost__c, Margin_Percent__c,
                   Region__c, Machine_Type__c,
                   Machine_Installation__r.SAP_Account_No_Bill_To__c,
                   Machine_Installation__r.bill_to_account__r.SAP_Customer_Number__c,
                   Machine_Installation__r.bill_to_account__r.Name,
                   Machine_Installation__r.bill_to_account__r.Province__c,
                   Machine_Installation__r.bill_to_account__r.City__c,
                   Machine_Installation__r.bill_to_account__r.AddressLine_1__c,
                   Machine_Installation__r.bill_to_account__r.Postal_Code__c,
                   Machine_Installation__r.bill_to_account__r.Country_Code__c,
                   Machine_Installation__r.Diagnostic_Machine__r.Vendor__c,
                   Machine_Installation__r.Diagnostic_Machine__r.Technology__c,
                   Machine_Installation__r.Material_Number__c,
                   Machine_Installation__r.Status__c,
                   Asset_Number__c,
                   Asset_Number__r.Ship_To_Account__c,
                   Asset_Number__r.Ship_To_Account__r.SAP_Customer_Number__c,
                   Asset_Number__r.Ship_To_Account__r.Name,
                   Asset_Number__r.Ship_To_Account__r.Province__c,
                   Asset_Number__r.Ship_To_Account__r.City__c,
                   Asset_Number__r.Ship_To_Account__r.AddressLine_1__c,
                   Asset_Number__r.Ship_To_Account__r.Addess_Line_2__c,
                   Asset_Number__r.Ship_To_Account__r.Postal_Code__c,
                   Asset_Number__r.Ship_To_Account__r.Country_Code__c
            FROM Business_Case__c
            WHERE Is_Master__c = FALSE
            AND Master_Business_Case__c = NULL
            AND Machine_Installation__r.bill_to_account__r.SAP_Customer_Number__c = :customerCode
            AND (Status__c LIKE '%Active%' OR Status__c LIKE '%Revised%' OR Status__c LIKE '%New%')
        ];
    }

    private static Map<Id, Date> getFirstInvoiceDates(Set<Id> bcIds) {
        Map<Id, Date> result = new Map<Id, Date>();
        for (AggregateResult ar : [
            SELECT Business_Case__c bcId, MIN(Invoice__r.Invoice_Date__c) firstDate
            FROM Invoice_Line_Item__c
            WHERE Business_Case__c IN :bcIds
            AND Invoice__r.Invoice_Date__c != NULL
            AND DGroup__c = 'Reagent'
            GROUP BY Business_Case__c
        ]) {
            result.put((Id) ar.get('bcId'), (Date) ar.get('firstDate'));
        }
        return result;
    }

    private static Map<Id, Date> getLastSnapshotMonths(Set<Id> bcIds) {
        Map<Id, Date> result = new Map<Id, Date>();
        for (AggregateResult ar : [
            SELECT Business_Case__c bcId, MAX(Snapshot_Month__c) lastMonth
            FROM Business_Case_Sales_Snapshot__c
            WHERE Business_Case__c IN :bcIds
            GROUP BY Business_Case__c
        ]) {
            result.put((Id) ar.get('bcId'), (Date) ar.get('lastMonth'));
        }
        return result;
    }

    private static List<Date> generateMonthRange(Date startMonth, Date endMonth) {
        List<Date> months   = new List<Date>();
        Date       current  = startMonth.toStartOfMonth();
        Date       rangeEnd = endMonth.toStartOfMonth();
        while (current <= rangeEnd) {
            months.add(current);
            current = current.addMonths(1);
        }
        return months;
    }

    private static void backfillAgreementDates(List<Business_Case__c> allBCs, Map<Id, Date> firstInvoiceDates) {
        List<Business_Case__c> toUpdate = new List<Business_Case__c>();
        for (Business_Case__c bc : allBCs) {
            if (bc.Agreement_Date__c == null && firstInvoiceDates.containsKey(bc.Id)) {
                bc.Agreement_Date__c = firstInvoiceDates.get(bc.Id);
                toUpdate.add(new Business_Case__c(Id = bc.Id, Agreement_Date__c = firstInvoiceDates.get(bc.Id)));
            }
        }
        if (!toUpdate.isEmpty()) update toUpdate;
    }

    private static Set<Id> getBCIdsForCustomer(String customerCode) {
        Set<Id> ids = new Set<Id>();
        for (Business_Case__c bc : [
            SELECT Id
            FROM Business_Case__c
            WHERE (RecordType.Name = 'Master Business Case' AND Customer_Numbera__c = :customerCode)
            OR    (Is_Master__c = FALSE AND Master_Business_Case__c = NULL
                   AND Machine_Installation__r.bill_to_account__r.SAP_Customer_Number__c = :customerCode)
        ]) {
            ids.add(bc.Id);
        }
        return ids;
    }

    private static List<Business_Case_Sales_Snapshot__c> buildLiveSnapshots(String customerCode, Date month) {
        List<Business_Case__c> masterBCs     = queryMasterBCsForCustomer(customerCode);
        List<Business_Case__c> individualBCs = queryIndividualBCsForCustomer(customerCode);

        List<Business_Case__c> allBCs = new List<Business_Case__c>();
        allBCs.addAll(masterBCs);
        allBCs.addAll(individualBCs);
        if (allBCs.isEmpty()) return new List<Business_Case_Sales_Snapshot__c>();

        Set<Id> bcIds     = new Set<Id>();
        Set<Id> masterIds = new Set<Id>();
        for (Business_Case__c bc : allBCs)  bcIds.add(bc.Id);
        for (Business_Case__c bc : masterBCs) masterIds.add(bc.Id);

        Set<Date> months = new Set<Date>{ month };

        Map<String, InvoiceAggregationResult> invoiceMap = bulkAggregateInvoiceData(bcIds, months);
        Map<String, Decimal>                  ytdMap     = bulkCalculateYTDSales(bcIds, months);
        Map<String, Decimal>                  totalMap   = bulkCalculateTotalSalesTillDate(bcIds, months);

        List<Business_Case_Sales_Snapshot__c> live = new List<Business_Case_Sales_Snapshot__c>();
        for (Business_Case__c bc : allBCs) {
            String                   key = bc.Id + '_' + month.format();
            InvoiceAggregationResult inv = invoiceMap.containsKey(key) ? invoiceMap.get(key) : new InvoiceAggregationResult();
            Decimal ytd   = ytdMap.containsKey(key)   ? ytdMap.get(key)   : 0;
            Decimal total = totalMap.containsKey(key) ? totalMap.get(key) : 0;
            try {
                Business_Case_Sales_Snapshot__c snap = masterIds.contains(bc.Id)
                    ? createSnapshotForMasterBusinessCase(bc, month, inv, ytd, total)
                    : createSnapshotForBusinessCase(bc, month, inv, ytd, total);
                if (snap != null) live.add(snap);
            } catch (Exception e) { }
        }
        return live;
    }
}
