# BusinessCaseSnapshotService.cls

**Location:** `force-app/main/default/classes/BusinessCaseSnapshotService.cls`

## Purpose

This service class is the ETL (Extract-Transform-Load) engine for the Business Case dashboard. It does two jobs in sequence:

1. **Assignment** — Links `Invoice_Line_Item__c` records to the correct `Business_Case__c` by matching the invoice's customer code and AG_OG code against the Business Case's machine installation data.
2. **Snapshot creation** — Creates monthly `Business_Case_Sales_Snapshot__c` records that denormalize all the data needed by the dashboard (sales figures, targets, margins, addresses, etc.) so the dashboard never queries live transactional tables.

Both jobs run for **Individual Business Cases** and **Master Business Cases** separately.

---

## Entry Point

```apex
BusinessCaseSnapshotService.processCompleteETL();
```

Called from the batch scheduler. Executes in this order:

| Step | Method | What it does |
|------|--------|--------------|
| 1a | `assignBusinessCasesToInvoices()` | Assigns invoice line items → Individual BCs |
| 1b | `assignMasterBusinessCasesToInvoices()` | Assigns invoice line items → Master BCs |
| 2a | `processComprehensiveSnapshots()` | Launches `BusinessCaseSnapshotBatch` (batch size 20) |
| 2b | `processMasterComprehensiveSnapshots()` | Launches `BusinessCaseMasterSnapshotBatch` (batch size 4) |

Steps 2a/2b only kick off the batch jobs — actual snapshot processing happens inside those batch classes, which call back into this service's `processBatchSnapshots()` / `processMasterBatchSnapshots()`.

---

## Phase 1 — Invoice Assignment

### How matching works (Individual BCs)

**Source:** `Invoice_Line_Item__c` where `Business_Case__c = NULL` AND `DGroup__c = 'Reagent'` AND `Invoice_Value__c != NULL`

**Matching key built from:**
- `Invoice_Customer_Code__c` → must equal BC's `Machine_Installation__r.bill_to_account__r.SAP_Customer_Number__c`
- `AG_OG__c` field on the invoice → must **start with** `<SupplierCode>-<TechnologyCode>`
  - Supplier code = text before ` - ` in `Machine_Installation__r.Diagnostic_Machine__r.Vendor__c` (e.g. `"A - Boule"` → `"A"`)
  - Technology code = text before ` - ` in `Machine_Installation__r.Diagnostic_Machine__r.Technology__c` (e.g. `"HM - Hematology"` → `"HM"`)

**Example:** Invoice with `AG_OG__c = "A-HM-123"` and `Invoice_Customer_Code__c = "C1000"` matches a BC whose bill-to SAP number is `"C1000"` and whose machine is vendor `"A - Boule"` / technology `"HM - Hematology"`.

**BC filter:** `Is_Master__c = FALSE AND Master_Business_Case__c = NULL` + status contains New/Active/Revised

### How matching works (Master BCs)

Same logic but uses fields directly on the Master BC record:
- `Customer_Numbera__c` (note the custom field, not `Customer_Number__c`)
- `Vendor__c` and `Technologyaa__c` (direct fields, not from Machine Installation)
- `Material_Number__c` also queried (but not used in the matching pattern)

**BC filter:** `RecordType.Name = 'Master Business Case'` + status contains New/Active/Revised

> **Note:** `assignMasterBusinessCasesToInvoices()` contains a redundant SOQL query (`childbuinesscases` + the inline for-loop) that does nothing (the for-loop body is empty). This is dead code.

---

## Phase 2 — Snapshot Creation

The batch classes iterate over `Business_Case__c` records in chunks and call into this service.

### `processBatchSnapshots(List<Business_Case__c> businessCases)` — Individual BCs

For each batch of BCs:

1. Queries `Invoice_Line_Item__c` (Reagent, with date) to find all invoice months per BC.
2. For BCs with no invoices, calls `determineDefaultSnapshotMonth()` → uses `Agreement_Date__c` or falls back to `2024-04-01` (hardcoded historical default).
3. Queries existing `Business_Case_Sales_Snapshot__c` records to skip duplicates (key = `BCId_MonthFormatted`).
4. Calls three bulk helpers in one pass to avoid per-BC SOQL:
   - `bulkAggregateInvoiceData()` → monthly sales + invoice count per BC+Month
   - `bulkCalculateYTDSales()` → year-to-date sales per BC+Month
   - `bulkCalculateTotalSalesTillDate()` → cumulative sales since contract start per BC+Month
5. Calls `createSnapshotForBusinessCase()` for each new BC+Month combination.
6. Inserts via `Database.insert(list, false)` (partial success — failures logged, not thrown).

### `processMasterBatchSnapshots(List<Business_Case__c> businessCases)` — Master BCs

Same flow as above but:
- Filters the incoming list to only Masters that have child BCs (`Business_Cases__r` subquery not empty).
- Calls `createSnapshotForMasterBusinessCase()` instead.
- Uses `Sum_of_Monthly_Reagent_Commitment__c`, `Sum_of_Unit_Cost__c`, `Customer_Numbera__c`, `Customer_Namea__c` — the rollup/formula fields on Master BC.
- Reads vendor/technology/address from the **first child BC** (`Business_Cases__r[0]`), which can throw an index exception if the subquery returns nothing.

---

## Snapshot Fields Populated

| Snapshot Field | Source |
|---|---|
| `Business_Case__c` | BC Id |
| `Snapshot_Month__c` | First day of the invoice month |
| `Snapshot_Created_Date__c` | `Date.today()` |
| `Customer_Code__c` | `Machine_Installation__r.SAP_Account_No_Bill_To__c` |
| `Customer_Name__c` | `Machine_Installation__r.bill_to_account__r.Name` |
| `Vendor__c` | `Machine_Installation__r.Diagnostic_Machine__r.Vendor__c` |
| `Technology__c` | `Machine_Installation__r.Diagnostic_Machine__r.Technology__c` |
| `Region__c` | `Business_Case__r.Region__c` |
| `Material_Number__c` | `Machine_Installation__r.Material_Number__c` |
| `Material_Description__c` | `Business_Case__r.Machine_Type__c` |
| `Business_Case_Name__c` | `Business_Case__r.Name` |
| `Business_Case_Status__c` | `Business_Case__r.Status__c` |
| `Machine_Status__c` | `Machine_Installation__r.Status__c` |
| `Customer_Province/City/Address/PostalCode/Country` | Bill-to account fields |
| `Ship_To_*` fields | `Asset_Number__r.Ship_To_Account__r.*` (only if asset + ship-to exist) |
| `Total_Reagent_Sales__c` | Monthly invoice total from `bulkAggregateInvoiceData` |
| `Machine_Count__c` | `Quantity__c` parsed as Decimal, default 1 |
| `Source_Invoice_Count__c` | Count of invoices in the month |
| `YTD_Sales__c` | From `bulkCalculateYTDSales` |
| `Avg_YTD_Sales_Per_Month__c` | `YTD / (currentMonth - 1)` — uses runtime month, not snapshot month |
| `Target_Sales__c` | `Monthly_Reagent_Commitment__c` |
| `Monthly_Commitments__c` | Same as Target_Sales |
| `Total_Reagent_Sales_Till_Date__c` | From `bulkCalculateTotalSalesTillDate` |
| `Contract_Months_Elapsed__c` | Months from `Agreement_Date__c` to snapshot month |
| `Avg_Reagent_Sales_Per_Month__c` | `totalSalesTillDate / contractMonthsElapsed` |
| `Performance_Status__c` | 'On Track' / 'At Risk' / 'Behind' / 'No Target Set' |
| `Deficit_Cost_Covered__c` | `YTD - (monthlyTarget × monthsElapsed)` |
| `Margin_Percent_Snapshot__c` | `Margin_Percent__c` at time of snapshot |
| `Margin_On_Reagent_Sale__c` | `monthSales × marginPercent / 100` |
| `Margin_till_Date__c` | `totalSalesTillDate × marginPercent / 100` |
| `Payback_Remaining__c` | `Unit_Cost__c - YTD_Sales`, floor 0 |
| `Data_Quality_Score__c` | Score out of 100 (see below) |
| `Processing_Status__c` | `'Completed'` |

### Data Quality Score (Individual BC)

Starts at 100, deducts:
- -20 if `Customer_Number__c` blank
- -20 if `Supplier_Name__c` blank
- -20 if `Technology__c` blank
- -30 if no invoices in month
- -10 if `Monthly_Reagent_Commitment__c` null

---

## Key Helper Methods

| Method | Purpose |
|---|---|
| `extractSupplierCode(String)` | Extracts prefix before ` - ` (e.g. `"A - Boule"` → `"A"`) |
| `extractTechnologyCode(String)` | Same pattern for technology picklist values |
| `determineSnapshotMonth(Id)` | For a single BC Id: returns most recent Reagent invoice month, or today's month if none |
| `determineDefaultSnapshotMonth(BC)` | For BCs with no invoices: `Agreement_Date__c` month, or `2024-04-01` fallback |
| `getAllInvoiceMonths(Id)` | All distinct Reagent invoice months for one BC (used by legacy code, not main batch path) |
| `calculateMonthsElapsed(Date, Date)` | `abs((yearDiff×12) + monthDiff + 1)` — takes absolute value to handle pre-contract invoices |
| `calculateDeficitCostCovered(ytd, target, months)` | `ytd - (target × months)` |
| `determinePerformanceStatus(sales, target)` | ≥100% → On Track, ≥90% → At Risk, <90% → Behind |
| `bulkAggregateInvoiceData(bcIds, months)` | Single aggregate SOQL for monthly totals across all BCs |
| `bulkCalculateYTDSales(bcIds, months)` | Single aggregate SOQL then in-memory YTD accumulation |
| `bulkCalculateTotalSalesTillDate(bcIds, months)` | Single raw SOQL then in-memory cumulative sum per BC+month |
| `verifyManualBusinessCaseAssignments()` | Debug utility — checks 100 already-assigned invoices against the matching logic |

---

## Inner Classes

```apex
public class InvoiceAggregationResult {
    public Decimal totalSales = 0;
    public Integer invoiceCount = 0;
}

public class InvoiceMonthData {
    public Date month;
    public Integer invoiceCount = 0;
    public Decimal totalSales = 0;
}
```

---

## Important Caveats / Known Issues

1. **`Avg_YTD_Sales_Per_Month__c` uses the runtime month, not the snapshot month.** When backfilling historical snapshots, this field will be wrong.

2. **Master BC snapshot reads vendor/tech/address from `Business_Cases__r[0]`.** If a Master BC has no children in the subquery (or the subquery is not eager-loaded), this throws a `ListIndexOutOfBounds` exception. The try-catch in `processMasterBatchSnapshots` catches this and sets `snapshot = null`, so the snapshot is silently skipped.

3. **`determineDefaultSnapshotMonth` has a hardcoded fallback of `2024-04-01`.** This was intentional at implementation time ("most invoice data is from that timeframe") but will age out.

4. **`assignMasterBusinessCasesToInvoices` runs a redundant query** into `childbuinesscases` and a for-loop that does nothing.

5. **Snapshots are only ever inserted, never updated.** The duplicate-check key (`BCId_MonthFormatted`) prevents re-creation, but if data changes (new invoices for an old month), the snapshot is stale unless manually deleted and re-run.

6. **`@TestVisible static Boolean forceException`** allows test classes to trigger the exception path in `processCompleteETL()`.

---

## Related Classes

| Class | Role |
|---|---|
| `BusinessCaseSnapshotBatch` | Batch executor for Individual BC snapshots; calls `processBatchSnapshots()` |
| `BusinessCaseMasterSnapshotBatch` | Batch executor for Master BC snapshots; calls `processMasterBatchSnapshots()` |
| `BusinessCaseDashboardController` | LWC controller that reads `Business_Case_Sales_Snapshot__c` for the dashboard |
| `BusinessCaseMasterSnapshotBatch` | Batch with size 4 (small due to complex subquery on Master BCs) |

---

## Data Flow Summary

```
[Scheduler / Manual trigger]
        │
        ▼
processCompleteETL()
        │
        ├── assignBusinessCasesToInvoices()
        │       Invoice_Line_Item__c (unassigned Reagent)
        │       matched by: CustomerCode + AG_OG starts with SupplierCode-TechCode
        │       → updates Business_Case__c field on matched invoices
        │
        ├── assignMasterBusinessCasesToInvoices()
        │       same pattern but for Master BC records
        │
        ├── processComprehensiveSnapshots()
        │       → executes BusinessCaseSnapshotBatch (size 20)
        │              for each chunk of Business_Case__c records:
        │              → processBatchSnapshots()
        │                 → bulkAggregateInvoiceData / bulkCalculateYTDSales / bulkCalculateTotalSalesTillDate
        │                 → createSnapshotForBusinessCase() per BC+Month
        │                 → Database.insert(snapshots, false)
        │
        └── processMasterComprehensiveSnapshots()
                → executes BusinessCaseMasterSnapshotBatch (size 4)
                       for each chunk of Master Business_Case__c records:
                       → processMasterBatchSnapshots()
                          → same bulk helpers
                          → createSnapshotForMasterBusinessCase() per BC+Month
                          → Database.insert(snapshots, false)
```
