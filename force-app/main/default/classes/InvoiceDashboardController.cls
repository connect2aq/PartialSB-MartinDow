public with sharing class InvoiceDashboardController {

    // ===== WRAPPER CLASSES =====

    public class OptionWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public OptionWrapper(String lbl, String val) {
            this.label = lbl;
            this.value = val;
        }
    }

    public class FilterOptionsWrapper {
        @AuraEnabled public List<OptionWrapper> yearOptions;
        @AuraEnabled public List<OptionWrapper> monthOptions;
        @AuraEnabled public List<OptionWrapper> regionOptions;
        @AuraEnabled public List<OptionWrapper> technologyOptions;
        @AuraEnabled public List<OptionWrapper> vendorOptions;
    }

    public class SnapshotRowWrapper {
        @AuraEnabled public String  snapshotId;
        @AuraEnabled public String  businessCaseId;
        @AuraEnabled public String  businessCaseName;
        @AuraEnabled public String  customerCode;
        @AuraEnabled public String  customerName;
        @AuraEnabled public String  region;
        @AuraEnabled public String  vendor;
        @AuraEnabled public Date    snapshotMonth;
        @AuraEnabled public String  snapshotMonthLabel;  // 'Jan 2025'
        @AuraEnabled public Integer snapshotYear;
        @AuraEnabled public Integer snapshotMonthNum;
        @AuraEnabled public Decimal totalSales;          // Total_Reagent_Sales__c
        @AuraEnabled public Decimal ytdSales;
        @AuraEnabled public Decimal targetSales;
        @AuraEnabled public Decimal margin;
    }

    public class BusinessCaseWrapper {
        @AuraEnabled public String  businessCaseId;
        @AuraEnabled public String  businessCaseName;
        @AuraEnabled public String  customerNo;
        @AuraEnabled public String  region;
        @AuraEnabled public String  status;
    }

    public class AggregatedRowWrapper {
        @AuraEnabled public String  rowKey;           // composite key: bcId_yr_mo_vendor_tech
        @AuraEnabled public String  businessCaseId;
        @AuraEnabled public String  businessCaseName;
        @AuraEnabled public String  customerCode;     // from BC.Customer_Number__c
        @AuraEnabled public String  region;
        @AuraEnabled public String  vendor;
        @AuraEnabled public String  technology;
        @AuraEnabled public Integer invoiceYear;
        @AuraEnabled public Integer invoiceMonthNum;
        @AuraEnabled public String  invoiceMonthLabel; // e.g. 'Jan 2025'
        @AuraEnabled public Decimal totalValue;        // SUM(Invoice_Value__c)
        @AuraEnabled public Integer lineCount;         // COUNT of line items
        @AuraEnabled public Integer invoiceCount;      // COUNT_DISTINCT of invoices
    }

    public class InvoiceLineWrapper {
        @AuraEnabled public String lineItemId;
        @AuraEnabled public String lineItemName;
        @AuraEnabled public String invoiceId;
        @AuraEnabled public String invoiceNumber;
        @AuraEnabled public Date   invoiceDate;
        @AuraEnabled public String invoiceMonth;    // 'Jan 2025'
        @AuraEnabled public Integer invoiceYear;
        @AuraEnabled public Integer invoiceMonthNum;
        @AuraEnabled public String customerCode;    // from line item or invoice header
        @AuraEnabled public String customerName;
        @AuraEnabled public Decimal invoiceValue;   // Invoice_Value__c
        @AuraEnabled public Decimal netPrice;       // Invoice_Net_Price__c
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public String materialNo;
        @AuraEnabled public String materialDesc;
        @AuraEnabled public String technology;
        @AuraEnabled public String vendor;
        @AuraEnabled public String materialGroup;
        @AuraEnabled public String businessCaseId;
        @AuraEnabled public String businessCaseName;
        @AuraEnabled public String businessCaseCustomerNo;
        @AuraEnabled public String region;
    }

    // ===== MONTH HELPER =====

    private static final List<String> MONTH_NAMES = new List<String>{
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
    };

    // ===== FILTER OPTIONS =====

    @AuraEnabled(cacheable=true)
    public static FilterOptionsWrapper getFilterOptions() {
        try {
            FilterOptionsWrapper result = new FilterOptionsWrapper();

            // Year / Month options from Invoice header dates
            Map<Integer, Set<Integer>> yearMonthMap = new Map<Integer, Set<Integer>>();
            for (AggregateResult ar : [
                SELECT
                    CALENDAR_YEAR(Invoice_Date__c) yr,
                    CALENDAR_MONTH(Invoice_Date__c) mo
                FROM Invoice__c
                WHERE Invoice_Date__c != NULL
                GROUP BY CALENDAR_YEAR(Invoice_Date__c), CALENDAR_MONTH(Invoice_Date__c)
                ORDER BY CALENDAR_YEAR(Invoice_Date__c) ASC, CALENDAR_MONTH(Invoice_Date__c) ASC
            ]) {
                Integer yr = (Integer) ar.get('yr');
                Integer mo = (Integer) ar.get('mo');
                if (!yearMonthMap.containsKey(yr)) {
                    yearMonthMap.put(yr, new Set<Integer>());
                }
                yearMonthMap.get(yr).add(mo);
            }

            List<Integer> sortedYears = new List<Integer>(yearMonthMap.keySet());
            sortedYears.sort();

            List<OptionWrapper> yearOptions  = new List<OptionWrapper>();
            List<OptionWrapper> monthOptions = new List<OptionWrapper>();
            Set<String> monthsAdded = new Set<String>();

            for (Integer yr : sortedYears) {
                yearOptions.add(new OptionWrapper(String.valueOf(yr), String.valueOf(yr)));
                List<Integer> months = new List<Integer>(yearMonthMap.get(yr));
                months.sort();
                for (Integer mo : months) {
                    String label = MONTH_NAMES[mo - 1] + ' ' + yr;
                    if (!monthsAdded.contains(label)) {
                        monthOptions.add(new OptionWrapper(label, label));
                        monthsAdded.add(label);
                    }
                }
            }

            // Region options — query Business_Case__c directly to avoid GROUP BY on relationship traversal
            List<OptionWrapper> regionOptions = new List<OptionWrapper>();
            Set<String> regionSeen = new Set<String>();
            Set<Id> bcIdsWithInvoices = new Set<Id>();
            for (AggregateResult ar : [
                SELECT Business_Case__c bc
                FROM Invoice_Line_Item__c
                WHERE Business_Case__c != NULL
                GROUP BY Business_Case__c
            ]) {
                bcIdsWithInvoices.add((Id) ar.get('bc'));
            }
            if (!bcIdsWithInvoices.isEmpty()) {
                for (Business_Case__c bc : [
                    SELECT Region__c
                    FROM Business_Case__c
                    WHERE Id IN :bcIdsWithInvoices
                      AND Region__c != NULL
                    ORDER BY Region__c ASC
                ]) {
                    if (!regionSeen.contains(bc.Region__c)) {
                        regionOptions.add(new OptionWrapper(bc.Region__c, bc.Region__c));
                        regionSeen.add(bc.Region__c);
                    }
                }
            }

            // Technology options
            List<OptionWrapper> technologyOptions = new List<OptionWrapper>();
            Set<String> techSeen = new Set<String>();
            for (AggregateResult ar : [
                SELECT Technology__c tech
                FROM Invoice_Line_Item__c
                WHERE Technology__c != NULL
                GROUP BY Technology__c
                ORDER BY Technology__c ASC
            ]) {
                String tech = (String) ar.get('tech');
                if (String.isNotBlank(tech) && !techSeen.contains(tech)) {
                    technologyOptions.add(new OptionWrapper(tech, tech));
                    techSeen.add(tech);
                }
            }

            // Vendor options
            List<OptionWrapper> vendorOptions = new List<OptionWrapper>();
            Set<String> vendorSeen = new Set<String>();
            for (AggregateResult ar : [
                SELECT Vendor__c ven
                FROM Invoice_Line_Item__c
                WHERE Vendor__c != NULL
                GROUP BY Vendor__c
                ORDER BY Vendor__c ASC
            ]) {
                String ven = (String) ar.get('ven');
                if (String.isNotBlank(ven) && !vendorSeen.contains(ven)) {
                    vendorOptions.add(new OptionWrapper(ven, ven));
                    vendorSeen.add(ven);
                }
            }

            result.yearOptions       = yearOptions;
            result.monthOptions      = monthOptions;
            result.regionOptions     = regionOptions;
            result.technologyOptions = technologyOptions;
            result.vendorOptions     = vendorOptions;

            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error loading filter options: ' + e.getMessage());
        }
    }

    // ===== INVOICE LINE ITEM DATA =====

    @AuraEnabled(cacheable=true)
    public static List<InvoiceLineWrapper> getInvoiceData(Integer year) {
        try {
            List<InvoiceLineWrapper> wrappers = new List<InvoiceLineWrapper>();

            Integer qYear     = (year != null && year > 0) ? year : Date.today().year();
            Date    startDate = Date.newInstance(qYear, 1, 1);
            Date    endDate   = Date.newInstance(qYear + 1, 1, 1);

            List<Invoice_Line_Item__c> lineItems = [
                SELECT
                    Id,
                    Name,
                    Invoice__c,
                    Invoice__r.Name,
                    Invoice__r.Invoice_Number__c,
                    Invoice__r.Invoice_Date__c,
                    Invoice__r.Invoice_Customer_Code__c,
                    Invoice__r.Invoice_Customer_Name__c,
                    Invoice_Customer_Code__c,
                    Invoice_Value__c,
                    Invoice_Net_Price__c,
                    Invoice_Quantity__c,
                    Invoice_Material_No__c,
                    Invoice_Material_Description__c,
                    Invoice_Description__c,
                    Technology__c,
                    Vendor__c,
                    Material_Group__c,
                    Business_Case__c,
                    Business_Case__r.Name,
                    Business_Case__r.Customer_Number__c,
                    Business_Case__r.Region__c
                FROM Invoice_Line_Item__c
                WHERE Invoice__r.Invoice_Date__c >= :startDate
                  AND Invoice__r.Invoice_Date__c <  :endDate
                ORDER BY Invoice__r.Invoice_Date__c DESC
            ];

            for (Invoice_Line_Item__c li : lineItems) {
                InvoiceLineWrapper w = new InvoiceLineWrapper();
                w.lineItemId    = li.Id;
                w.lineItemName  = li.Name;
                w.invoiceId     = li.Invoice__c;
                w.invoiceValue  = li.Invoice_Value__c  != null ? li.Invoice_Value__c  : 0;
                w.netPrice      = li.Invoice_Net_Price__c != null ? li.Invoice_Net_Price__c : 0;
                w.quantity      = li.Invoice_Quantity__c;
                w.materialNo    = li.Invoice_Material_No__c;
                w.materialDesc  = li.Invoice_Material_Description__c;
                w.technology    = li.Technology__c;
                w.vendor        = li.Vendor__c;
                w.materialGroup = li.Material_Group__c;

                // Customer code: prefer line item field, fall back to invoice header
                w.customerCode = String.isNotBlank(li.Invoice_Customer_Code__c)
                    ? li.Invoice_Customer_Code__c
                    : (li.Invoice__r != null ? li.Invoice__r.Invoice_Customer_Code__c : null);

                if (li.Invoice__r != null) {
                    w.invoiceNumber = li.Invoice__r.Invoice_Number__c;
                    w.invoiceDate   = li.Invoice__r.Invoice_Date__c;
                    w.customerName  = li.Invoice__r.Invoice_Customer_Name__c;

                    if (li.Invoice__r.Invoice_Date__c != null) {
                        w.invoiceYear     = li.Invoice__r.Invoice_Date__c.year();
                        w.invoiceMonthNum = li.Invoice__r.Invoice_Date__c.month();
                        w.invoiceMonth    = MONTH_NAMES[w.invoiceMonthNum - 1] + ' ' + w.invoiceYear;
                    }
                }

                if (li.Business_Case__c != null) {
                    w.businessCaseId       = li.Business_Case__c;
                    w.businessCaseName     = li.Business_Case__r.Name;
                    w.businessCaseCustomerNo = li.Business_Case__r.Customer_Number__c;
                    w.region               = li.Business_Case__r.Region__c;
                }

                wrappers.add(w);
            }

            return wrappers;
        } catch (Exception e) {
            throw new AuraHandledException('Error loading invoice data: ' + e.getMessage());
        }
    }

    // ===== ALL BUSINESS CASES =====

    @AuraEnabled(cacheable=true)
    public static List<BusinessCaseWrapper> getAllBusinessCases() {
        try {
            List<BusinessCaseWrapper> result = new List<BusinessCaseWrapper>();
            for (Business_Case__c bc : [
                SELECT Id, Name, Customer_Number__c, Region__c, Status__c
                FROM Business_Case__c
                ORDER BY Name ASC
            ]) {
                BusinessCaseWrapper w = new BusinessCaseWrapper();
                w.businessCaseId   = bc.Id;
                w.businessCaseName = bc.Name;
                w.customerNo       = bc.Customer_Number__c;
                w.region           = bc.Region__c;
                w.status           = bc.Status__c;
                result.add(w);
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error loading business cases: ' + e.getMessage());
        }
    }

    // ===== AGGREGATED INVOICE DATA (primary fast source — server-side aggregation) =====

    @AuraEnabled(cacheable=true)
    public static List<AggregatedRowWrapper> getAggregatedInvoiceData(Integer year) {
        try {
            Integer qYear     = (year != null && year > 0) ? year : Date.today().year();
            Date    startDate = Date.newInstance(qYear, 1, 1);
            Date    endDate   = Date.newInstance(qYear + 1, 1, 1);

            List<AggregatedRowWrapper> rows = new List<AggregatedRowWrapper>();
            Set<Id> bcIds = new Set<Id>();

            // Step 1: aggregate Invoice_Line_Item__c by BC + month + vendor + technology
            for (AggregateResult ar : [
                SELECT
                    Business_Case__c                           bcId,
                    CALENDAR_YEAR(Invoice__r.Invoice_Date__c)  yr,
                    CALENDAR_MONTH(Invoice__r.Invoice_Date__c) mo,
                    Vendor__c                                  ven,
                    Technology__c                              tech,
                    SUM(Invoice_Value__c)                      totalVal,
                    COUNT(Id)                                  lineCount,
                    COUNT_DISTINCT(Invoice__c)                 invCount
                FROM Invoice_Line_Item__c
                WHERE Invoice__r.Invoice_Date__c >= :startDate
                  AND Invoice__r.Invoice_Date__c <  :endDate
                GROUP BY
                    Business_Case__c,
                    CALENDAR_YEAR(Invoice__r.Invoice_Date__c),
                    CALENDAR_MONTH(Invoice__r.Invoice_Date__c),
                    Vendor__c,
                    Technology__c
            ]) {
                AggregatedRowWrapper w = new AggregatedRowWrapper();
                w.businessCaseId  = (String)  ar.get('bcId');
                w.invoiceYear     = (Integer) ar.get('yr');
                w.invoiceMonthNum = (Integer) ar.get('mo');
                w.vendor          = (String)  ar.get('ven');
                w.technology      = (String)  ar.get('tech');
                w.totalValue      = ar.get('totalVal') != null ? (Decimal) ar.get('totalVal') : 0;
                w.lineCount       = (Integer) ar.get('lineCount');
                w.invoiceCount    = (Integer) ar.get('invCount');

                if (w.invoiceYear != null && w.invoiceMonthNum != null) {
                    w.invoiceMonthLabel = MONTH_NAMES[w.invoiceMonthNum - 1] + ' ' + w.invoiceYear;
                }
                w.rowKey = (String.isNotBlank(w.businessCaseId) ? w.businessCaseId : 'null')
                         + '_' + w.invoiceYear
                         + '_' + w.invoiceMonthNum
                         + '_' + (w.vendor != null ? w.vendor : '')
                         + '_' + (w.technology != null ? w.technology : '');

                if (String.isNotBlank(w.businessCaseId)) bcIds.add((Id) w.businessCaseId);
                rows.add(w);
            }

            // Step 2: enrich rows with BC name, customer number, region
            if (!bcIds.isEmpty()) {
                Map<Id, Business_Case__c> bcMap = new Map<Id, Business_Case__c>([
                    SELECT Id, Name, Customer_Number__c, Region__c
                    FROM Business_Case__c
                    WHERE Id IN :bcIds
                ]);
                for (AggregatedRowWrapper w : rows) {
                    if (String.isNotBlank(w.businessCaseId)) {
                        Business_Case__c bc = bcMap.get((Id) w.businessCaseId);
                        if (bc != null) {
                            w.businessCaseName = bc.Name;
                            w.customerCode     = bc.Customer_Number__c;
                            w.region           = bc.Region__c;
                        }
                    }
                }
            }

            return rows;
        } catch (Exception e) {
            throw new AuraHandledException('Error loading aggregated invoice data: ' + e.getMessage());
        }
    }

    // ===== SNAPSHOT DATA (kept for reference) =====

    @AuraEnabled(cacheable=true)
    public static List<SnapshotRowWrapper> getSnapshotData(Integer year) {
        try {
            Integer qYear     = (year != null && year > 0) ? year : Date.today().year();
            Date    startDate = Date.newInstance(qYear, 1, 1);
            Date    endDate   = Date.newInstance(qYear + 1, 1, 1);

            List<SnapshotRowWrapper> result = new List<SnapshotRowWrapper>();

            for (Business_Case_Sales_Snapshot__c s : [
                SELECT
                    Id,
                    Business_Case__c,
                    Business_Case__r.Name,
                    Customer_Code__c,
                    Customer_Name__c,
                    Region__c,
                    Vendor__c,
                    Snapshot_Month__c,
                    Total_Reagent_Sales__c,
                    YTD_Sales__c,
                    Target_Sales__c,
                    Margin_On_Reagent_Sale__c
                FROM Business_Case_Sales_Snapshot__c
                WHERE Snapshot_Month__c >= :startDate
                  AND Snapshot_Month__c <  :endDate
                  AND Processing_Status__c = 'Completed'
                ORDER BY Snapshot_Month__c DESC
            ]) {
                SnapshotRowWrapper w = new SnapshotRowWrapper();
                w.snapshotId       = s.Id;
                w.businessCaseId   = s.Business_Case__c;
                w.businessCaseName = s.Business_Case__r != null ? s.Business_Case__r.Name : null;
                w.customerCode     = s.Customer_Code__c;
                w.customerName     = s.Customer_Name__c;
                w.region           = s.Region__c;
                w.vendor           = s.Vendor__c;
                w.snapshotMonth    = s.Snapshot_Month__c;
                w.totalSales       = s.Total_Reagent_Sales__c != null ? s.Total_Reagent_Sales__c : 0;
                w.ytdSales         = s.YTD_Sales__c;
                w.targetSales      = s.Target_Sales__c;
                w.margin           = s.Margin_On_Reagent_Sale__c;

                if (s.Snapshot_Month__c != null) {
                    w.snapshotYear     = s.Snapshot_Month__c.year();
                    w.snapshotMonthNum = s.Snapshot_Month__c.month();
                    w.snapshotMonthLabel = MONTH_NAMES[w.snapshotMonthNum - 1] + ' ' + w.snapshotYear;
                }
                result.add(w);
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error loading snapshot data: ' + e.getMessage());
        }
    }

    // ===== INVOICE LINE ITEMS ON DEMAND (detail drill-down only) =====

    @AuraEnabled(cacheable=true)
    public static List<InvoiceLineWrapper> getLineItemsForGroup(
        Integer year, String customerCode, String vendor
    ) {
        try {
            Integer qYear     = (year != null && year > 0) ? year : Date.today().year();
            Date    startDate = Date.newInstance(qYear, 1, 1);
            Date    endDate   = Date.newInstance(qYear + 1, 1, 1);

            List<InvoiceLineWrapper> wrappers = new List<InvoiceLineWrapper>();
            List<Invoice_Line_Item__c> lineItems = [
                SELECT
                    Id, Name,
                    Invoice__c,
                    Invoice__r.Invoice_Number__c,
                    Invoice__r.Invoice_Date__c,
                    Invoice__r.Invoice_Customer_Code__c,
                    Invoice__r.Invoice_Customer_Name__c,
                    Invoice_Customer_Code__c,
                    Invoice_Value__c,
                    Invoice_Net_Price__c,
                    Invoice_Quantity__c,
                    Invoice_Material_No__c,
                    Invoice_Material_Description__c,
                    Technology__c,
                    Vendor__c,
                    Business_Case__c,
                    Business_Case__r.Name,
                    Business_Case__r.Customer_Number__c,
                    Business_Case__r.Region__c
                FROM Invoice_Line_Item__c
                WHERE Invoice__r.Invoice_Date__c >= :startDate
                  AND Invoice__r.Invoice_Date__c <  :endDate
                  AND (Invoice__r.Invoice_Customer_Code__c = :customerCode
                       OR Invoice_Customer_Code__c            = :customerCode
                       OR Business_Case__r.Customer_Number__c = :customerCode)
                  AND Vendor__c = :vendor
                ORDER BY Invoice__r.Invoice_Date__c DESC
                LIMIT 2000
            ];

            for (Invoice_Line_Item__c li : lineItems) {
                InvoiceLineWrapper w = new InvoiceLineWrapper();
                w.lineItemId    = li.Id;
                w.lineItemName  = li.Name;
                w.invoiceId     = li.Invoice__c;
                w.invoiceValue  = li.Invoice_Value__c != null  ? li.Invoice_Value__c  : 0;
                w.netPrice      = li.Invoice_Net_Price__c != null ? li.Invoice_Net_Price__c : 0;
                w.quantity      = li.Invoice_Quantity__c;
                w.materialNo    = li.Invoice_Material_No__c;
                w.materialDesc  = li.Invoice_Material_Description__c;
                w.technology    = li.Technology__c;
                w.vendor        = li.Vendor__c;
                w.customerCode  = String.isNotBlank(li.Invoice_Customer_Code__c)
                    ? li.Invoice_Customer_Code__c
                    : (li.Invoice__r != null ? li.Invoice__r.Invoice_Customer_Code__c : null);
                if (li.Invoice__r != null) {
                    w.invoiceNumber = li.Invoice__r.Invoice_Number__c;
                    w.invoiceDate   = li.Invoice__r.Invoice_Date__c;
                    w.customerName  = li.Invoice__r.Invoice_Customer_Name__c;
                    if (li.Invoice__r.Invoice_Date__c != null) {
                        w.invoiceYear     = li.Invoice__r.Invoice_Date__c.year();
                        w.invoiceMonthNum = li.Invoice__r.Invoice_Date__c.month();
                        w.invoiceMonth    = MONTH_NAMES[w.invoiceMonthNum - 1] + ' ' + w.invoiceYear;
                    }
                }
                if (li.Business_Case__c != null) {
                    w.businessCaseId         = li.Business_Case__c;
                    w.businessCaseName       = li.Business_Case__r.Name;
                    w.businessCaseCustomerNo = li.Business_Case__r.Customer_Number__c;
                    w.region                 = li.Business_Case__r.Region__c;
                }
                wrappers.add(w);
            }
            return wrappers;
        } catch (Exception e) {
            throw new AuraHandledException('Error loading line items: ' + e.getMessage());
        }
    }
}