import { LightningElement, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

import getFilterOptions      from "@salesforce/apex/InvoiceDashboardController.getFilterOptions";
import getAggregatedInvoiceData from "@salesforce/apex/InvoiceDashboardController.getAggregatedInvoiceData";
import getLineItemsForGroup  from "@salesforce/apex/InvoiceDashboardController.getLineItemsForGroup";
import getAllBusinessCases    from "@salesforce/apex/InvoiceDashboardController.getAllBusinessCases";

const PAGE_SIZE         = 20;
const SUMMARY_PAGE_SIZE = 25;
const MONTH_ABBR = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];

function _currentYear() { return String(new Date().getFullYear()); }

export default class InvoiceRealizationDashboard extends LightningElement {

  @track isLoading    = true;
  @track errorMessage = null;
  @track filterOptions = {
    yearOptions: [], monthOptions: [], regionOptions: [],
    technologyOptions: [], vendorOptions: []
  };
  @track allData          = [];   // snapshot rows for selected year(s)
  @track allBusinessCases = [];   // all BCs regardless of snapshot data
  @track detailLineItems  = [];   // invoice line items fetched on-demand for selected group
  @track detailLoading    = false;

  // Years (multi-select) → server-side re-fetch; others → client-side only
  @track selectedYears      = [_currentYear()];   // array of year strings
  @track selectedMonth      = "";
  @track selectedRegion     = "";
  @track selectedTechnology = "";
  @track selectedVendor     = "";
  @track currentPage        = 1;
  @track selectedGroupKey   = null;   // custKey|techVendorKey of selected sub-row
  @track expandedCustomers  = {};     // { custKey: true } for expanded parent rows
  @track summarySearchTerm  = "";
  @track summaryCurrentPage = 1;

  // ===== LIFECYCLE =====

  connectedCallback() {
    this.fetchSnapshotData();
  }

  // ===== WIRE =====

  @wire(getFilterOptions)
  wiredFilterOptions({ data, error }) {
    if (data) {
      this.filterOptions = {
        yearOptions:       data.yearOptions       || [],
        monthOptions:      data.monthOptions      || [],
        regionOptions:     data.regionOptions     || [],
        technologyOptions: data.technologyOptions || [],
        vendorOptions:     data.vendorOptions     || []
      };
    } else if (error) {
      console.error("getFilterOptions error:", error);
    }
  }

  @wire(getAllBusinessCases)
  wiredBusinessCases({ data, error }) {
    if (data)  { this.allBusinessCases = data; }
    else if (error) { console.error("getAllBusinessCases error:", error); }
  }

  // ===== DATA =====

  // Fetch aggregated invoice data — one call per year, parallel, framework-cached per year
  fetchSnapshotData() {
    this.isLoading    = true;
    this.errorMessage = null;
    this.detailLineItems  = [];
    this._resetGroupState();

    const years = (this.selectedYears || []).map((y) => parseInt(y, 10)).filter(Boolean);
    if (!years.length) years.push(new Date().getFullYear());

    Promise.all(years.map((y) => getAggregatedInvoiceData({ year: y })))
      .then((results) => {
        const combined = [].concat(...results.map((r) => r || []));
        this.allData = combined.map((s) => ({
          ...s,
          // Map aggregated fields to standard LWC field names used by all getters
          resolvedCustomerNo: s.customerCode     || "N/A",
          invoiceValue:       s.totalValue       || 0,
          invoiceValueFmt:    this.formatM(s.totalValue),
          invoiceMonth:       s.invoiceMonthLabel,
          invoiceMonthNum:    s.invoiceMonthNum,
          invoiceYear:        s.invoiceYear,
          lineItemId:         s.rowKey,
          technology:         s.technology       || "",
          vendor:             s.vendor           || "",
          region:             s.region           || "",
          businessCaseUrl:    s.businessCaseId
            ? `/lightning/r/Business_Case__c/${s.businessCaseId}/view` : "#"
        }));
        this.isLoading = false;
      })
      .catch((error) => {
        this.isLoading    = false;
        this.errorMessage = this._extractMessage(error);
      });
  }

  // Fetch invoice line items for a selected group (customer + vendor) on demand
  fetchGroupDetail(customerCode, vendor) {
    this.detailLoading   = true;
    this.detailLineItems = [];

    const years = (this.selectedYears || []).map((y) => parseInt(y, 10)).filter(Boolean);
    if (!years.length) years.push(new Date().getFullYear());

    Promise.all(years.map((y) => getLineItemsForGroup({ year: y, customerCode, vendor })))
      .then((results) => {
        const combined = [].concat(...results.map((r) => r || []));
        this.detailLineItems = combined.map((li) => ({
          ...li,
          invoiceDateFormatted: this.formatDate(li.invoiceDate),
          invoiceValueFmt:      this.formatM(li.invoiceValue),
          invoiceUrl:           li.invoiceId      ? `/lightning/r/Invoice__c/${li.invoiceId}/view`           : "#",
          businessCaseUrl:      li.businessCaseId ? `/lightning/r/Business_Case__c/${li.businessCaseId}/view` : "#",
          resolvedCustomerNo:   li.businessCaseCustomerNo || li.customerCode || "N/A"
        }));
        this.detailLoading = false;
      })
      .catch((error) => {
        this.detailLoading   = false;
        this.errorMessage    = this._extractMessage(error);
      });
  }

  // ===== FILTERS =====

  get filteredMonthOptions() {
    const years = this.selectedYears || [];
    if (!years.length) return this.filterOptions.monthOptions || [];
    // show months that belong to any of the selected years
    return (this.filterOptions.monthOptions || []).filter(
      (o) => years.some((y) => o.label.endsWith(y))
    );
  }

  get filteredData() {
    return this.allData.filter((li) => {
      if (this.selectedMonth) {
        const parts    = this.selectedMonth.split(" ");
        const monthNum = MONTH_ABBR.indexOf(parts[0]) + 1;
        if (li.invoiceMonthNum !== monthNum) return false;
      }
      if (this.selectedRegion     && li.region     !== this.selectedRegion)     return false;
      if (this.selectedTechnology && li.technology !== this.selectedTechnology) return false;
      if (this.selectedVendor     && li.vendor     !== this.selectedVendor)     return false;
      return true;
    });
  }

  get hasFilteredData() { return this.filteredData.length > 0; }
  get hasError()        { return !!this.errorMessage; }

  // ===== TWO-LEVEL GROUPED TABLE (Customer → Technology+Vendor) =====

  get groupedData() {
    // Level 1: group by Customer
    const custMap = new Map();
    this.filteredData.forEach((li) => {
      const cKey = li.resolvedCustomerNo || "N/A";
      if (!custMap.has(cKey)) {
        custMap.set(cKey, {
          customerNo:   li.resolvedCustomerNo || "N/A",
          customerName: li.customerName       || "—",
          totalValue: 0, lineCount: 0, invoiceIds: new Set(),
          subGroups: new Map()
        });
      }
      const cust = custMap.get(cKey);
      cust.totalValue += li.invoiceValue || 0;
      cust.lineCount++;
      const ckKey = li.lineItemId || li.invoiceId;
      if (ckKey) cust.invoiceIds.add(ckKey);

      // Level 2: sub-group by Vendor (snapshots don't have Technology)
      const sKey = (li.vendor || "—");
      if (!cust.subGroups.has(sKey)) {
        cust.subGroups.set(sKey, {
          vendor:  li.vendor  || "—",
          region:  li.region  || "—",
          totalValue: 0, totalQty: 0, lineCount: 0, snapshotIds: new Set()
        });
      }
      const sub = cust.subGroups.get(sKey);
      sub.totalValue += li.invoiceValue || 0;
      sub.lineCount++;
      sub.snapshotIds.add(li.lineItemId);
    });

    // Flatten into renderable rows (parent + children when expanded)
    const rows = [];
    const sortedCusts = Array.from(custMap.entries()).sort((a, b) => b[1].totalValue - a[1].totalValue);

    sortedCusts.forEach(([cKey, cust]) => {
      const isExpanded = !!this.expandedCustomers[cKey];
      // Derive region from any sub-group
      const firstSub = cust.subGroups.size > 0 ? cust.subGroups.values().next().value : null;
      rows.push({
        key:          "cust_" + cKey,
        rowType:      "customer",
        customerKey:  cKey,
        customerNo:   cust.customerNo,
        customerName: cust.customerName,
        region:       firstSub ? firstSub.region : "—",
        invoiceCount: cust.invoiceIds.size,
        lineCount:    cust.lineCount,
        totalValue:   cust.totalValue,
        totalValueFmt: this.formatM(cust.totalValue),
        subGroupCount: cust.subGroups.size,
        isExpanded,
        expandIcon:   isExpanded ? "utility:chevrondown" : "utility:chevronright",
        isCustomerRow: true,
        isSubRow:      false
      });

      if (isExpanded) {
        const sortedSubs = Array.from(cust.subGroups.entries()).sort((a, b) => b[1].totalValue - a[1].totalValue);
        sortedSubs.forEach(([vendorKey, sub]) => {
          const sKey    = "—\x00" + vendorKey;   // placeholder tech + vendor for key compat
          const fullKey = cKey + "\x01" + sKey;
          const isSelected = fullKey === this.selectedGroupKey;
          rows.push({
            key:          "sub_" + fullKey,
            rowType:      "subgroup",
            groupKey:     fullKey,
            vendor:       sub.vendor,
            region:       sub.region,
            invoiceCount: sub.snapshotIds.size,
            lineCount:    sub.lineCount,
            totalQtyFmt:  "—",
            totalValue:   sub.totalValue,
            totalValueFmt: this.formatM(sub.totalValue),
            isSelected,
            rowClass:     isSelected ? "sub-row sub-row-selected" : "sub-row",
            isCustomerRow: false,
            isSubRow:      true
          });
        });
      }
    });

    return rows;
  }

  get hasGroupedData()  { return this.filteredData.length > 0; }
  get groupedCount()    { return Object.keys(this._customerCount()).length; }
  _customerCount() {
    const s = new Set(this.filteredData.map((li) => li.resolvedCustomerNo || "N/A"));
    return Object.fromEntries([...s].map((k) => [k, 1]));
  }

  // ===== DETAIL FOR SELECTED SUB-GROUP =====

  get selectedGroupLineItems() { return this.detailLineItems; }
  get hasSelectedGroup()       { return !!this.selectedGroupKey; }
  get hasDetailLineItems()     { return this.detailLineItems.length > 0; }
  get selectedGroupLabel() {
    if (!this.selectedGroupKey) return "";
    const [cKey, sKey] = this.selectedGroupKey.split("\x01");
    const vendor       = sKey.split("\x00")[1] || "";
    return `${cKey} · ${vendor}`;
  }

  // ===== KPI =====

  get kpi() {
    const data       = this.filteredData;
    const totalValue = data.reduce((s, li) => s + (li.invoiceValue || 0), 0);
    const bcSet      = new Set(data.filter((li) => li.businessCaseId).map((li) => li.businessCaseId));
    const custSet    = new Set(data.filter((li) => li.resolvedCustomerNo !== "N/A").map((li) => li.resolvedCustomerNo));
    // Snapshot rows use lineItemId (snapshotId); fallback to invoiceId for raw invoice rows
    const snapSet    = new Set(data.map((li) => li.lineItemId || li.invoiceId).filter(Boolean));
    return {
      totalLineItems:        data.length,
      totalInvoices:         snapSet.size,
      totalValueFmt:         this.formatM(totalValue),
      distinctBusinessCases: this.allBusinessCases.length,  // total BCs ever
      distinctCustomers:     custSet.size
    };
  }

  // ===== TREND BARS =====

  get trendBars() {
    const years    = this.selectedYears || [String(new Date().getFullYear())];
    const yearNum  = parseInt(years[0], 10) || new Date().getFullYear();
    const monthMap = {};
    MONTH_ABBR.forEach((m, i) => {
      monthMap[i + 1] = { label: m, value: 0, count: new Set() };
    });

    this.filteredData.forEach((li) => {
      const mo = li.invoiceMonthNum;
      if (mo && monthMap[mo]) {
        monthMap[mo].value += li.invoiceValue || 0;
        if (li.invoiceId) monthMap[mo].count.add(li.invoiceId);
      }
    });

    const maxVal = Math.max(...Object.values(monthMap).map((e) => e.value), 1);

    return MONTH_ABBR.map((m, i) => {
      const e   = monthMap[i + 1];
      const pct = Math.round((e.value / maxVal) * 100);
      return {
        key:      m + yearNum,
        label:    m,
        valueFmt: e.value > 0 ? this.formatM(e.value) : "",
        count:    e.count.size,
        barStyle: `height:${Math.max(pct, e.value > 0 ? 4 : 0)}%; min-height:${e.value > 0 ? 4 : 0}px;`
      };
    });
  }

  get hasTrendData() { return this.allData.length > 0; }

  // ===== SUMMARY TABLE — all BCs merged with invoice totals =====

  get summaryTableData() {
    // Build invoice totals map keyed by businessCaseId
    const totalsMap = new Map();
    this.filteredData.forEach((li) => {
      const key = li.businessCaseId;
      if (!key) return;
      if (!totalsMap.has(key)) {
        totalsMap.set(key, {
          customerName: li.customerName || "N/A",
          lineCount:    0,
          invoiceCount: new Set(),
          totalValue:   0
        });
      }
      const t = totalsMap.get(key);
      t.lineCount++;
      t.totalValue += li.invoiceValue || 0;
      // Use snapshotId (lineItemId) for snapshot data; fall back to invoiceId for raw invoice rows
      const countKey = li.lineItemId || li.invoiceId;
      if (countKey) t.invoiceCount.add(countKey);
    });

    // Build rows from ALL business cases
    const rows = this.allBusinessCases.map((bc) => {
      const t = totalsMap.get(bc.businessCaseId);
      return {
        key:              bc.businessCaseId,
        businessCaseId:   bc.businessCaseId,
        businessCaseName: bc.businessCaseName || "—",
        businessCaseUrl:  `/lightning/r/Business_Case__c/${bc.businessCaseId}/view`,
        customerNo:       bc.customerNo  || "—",
        customerName:     (t && t.customerName) || "—",
        region:           bc.region      || "—",
        status:           bc.status      || "—",
        invoiceCount:     t ? t.invoiceCount.size : 0,
        lineCount:        t ? t.lineCount          : 0,
        totalValue:       t ? t.totalValue         : 0,
        totalValueFmt:    t && t.totalValue > 0 ? this.formatM(t.totalValue) : "—",
        hasInvoices:      !!t && t.totalValue > 0
      };
    });

    // Sort: BCs with invoice data first (by value desc), then remaining BCs
    rows.sort((a, b) => b.totalValue - a.totalValue);
    return rows;
  }

  get hasSummaryData() { return this.allBusinessCases.length > 0; }

  // Summary table search + pagination
  get filteredSummaryData() {
    const term = (this.summarySearchTerm || "").toLowerCase().trim();
    if (!term) return this.summaryTableData;
    return this.summaryTableData.filter((row) =>
      (row.businessCaseName || "").toLowerCase().includes(term) ||
      (row.customerNo       || "").toLowerCase().includes(term) ||
      (row.customerName     || "").toLowerCase().includes(term) ||
      (row.region           || "").toLowerCase().includes(term) ||
      (row.status           || "").toLowerCase().includes(term)
    );
  }

  get paginatedSummaryData() {
    const start = (this.summaryCurrentPage - 1) * SUMMARY_PAGE_SIZE;
    return this.filteredSummaryData.slice(start, start + SUMMARY_PAGE_SIZE);
  }

  get summaryTotalPages()      { return Math.max(1, Math.ceil(this.filteredSummaryData.length / SUMMARY_PAGE_SIZE)); }
  get summaryIsPrevDisabled()  { return this.summaryCurrentPage <= 1; }
  get summaryIsNextDisabled()  { return this.summaryCurrentPage >= this.summaryTotalPages; }
  get summaryPageInfo()        { return `Page ${this.summaryCurrentPage} of ${this.summaryTotalPages} (${this.filteredSummaryData.length} records)`; }

  // ===== TRENDING TECHNOLOGY (right sidebar) =====

  get trendingTech() {
    const techMap = new Map();
    this.filteredData.forEach((li) => {
      const tech = li.technology || "Unknown";
      if (!techMap.has(tech)) {
        techMap.set(tech, { value: 0, bcSet: new Set(), custSet: new Set(), lineCount: 0 });
      }
      const t = techMap.get(tech);
      t.value += li.invoiceValue || 0;
      t.lineCount++;
      if (li.businessCaseId) t.bcSet.add(li.businessCaseId);
      if (li.resolvedCustomerNo && li.resolvedCustomerNo !== "N/A") t.custSet.add(li.resolvedCustomerNo);
    });

    const items = Array.from(techMap.entries())
      .map(([tech, t]) => ({
        key:      tech,
        label:    tech,
        value:    t.value,
        valueFmt: this.formatM(t.value),
        bcCount:  t.bcSet.size,
        custCount: t.custSet.size,
        lineCount: t.lineCount
      }))
      .sort((a, b) => b.value - a.value);

    const maxVal = items.length > 0 ? items[0].value : 1;
    return items.slice(0, 10).map((item, idx) => ({
      ...item,
      rank:     idx + 1,
      barStyle: `width:${Math.max(Math.round((item.value / maxVal) * 100), 4)}%;`
    }));
  }

  get hasTechTrend() { return this.trendingTech.length > 0; }

  get topTechLabel() {
    return this.trendingTech.length > 0 ? this.trendingTech[0].label : "";
  }

  // Top customers for the #1 technology
  get topTechCustomers() {
    if (this.trendingTech.length === 0) return [];
    const topTech = this.trendingTech[0].label;

    const custMap = new Map();
    this.filteredData
      .filter((li) => (li.technology || "Unknown") === topTech)
      .forEach((li) => {
        const cust = li.resolvedCustomerNo !== "N/A" ? li.resolvedCustomerNo : (li.customerName || "Unknown");
        if (!custMap.has(cust)) custMap.set(cust, { value: 0, name: li.customerName || cust });
        custMap.get(cust).value += li.invoiceValue || 0;
      });

    const items = Array.from(custMap.entries())
      .map(([key, c]) => ({ key, label: c.name || key, value: c.value, valueFmt: this.formatM(c.value) }))
      .sort((a, b) => b.value - a.value);

    const maxVal = items.length > 0 ? items[0].value : 1;
    return items.slice(0, 8).map((item) => ({
      ...item,
      barStyle: `width:${Math.max(Math.round((item.value / maxVal) * 100), 4)}%;`
    }));
  }

  get hasTopTechCustomers() { return this.topTechCustomers.length > 0; }

  // ===== PAGINATION (detail table) =====

  get totalPages()     { return Math.max(1, Math.ceil(this.selectedGroupLineItems.length / PAGE_SIZE)); }
  get paginatedData()  { const s = (this.currentPage - 1) * PAGE_SIZE; return this.selectedGroupLineItems.slice(s, s + PAGE_SIZE); }
  get isPrevDisabled() { return this.currentPage <= 1; }
  get isNextDisabled() { return this.currentPage >= this.totalPages; }
  handlePrevPage()     { if (!this.isPrevDisabled) this.currentPage--; }
  handleNextPage()     { if (!this.isNextDisabled) this.currentPage++; }

  // ===== HANDLERS =====

  // dual-listbox returns array of selected values
  handleYearChange(e) {
    this.selectedYears = e.detail.value;
    this.selectedMonth = "";
    this.currentPage   = 1;
    this.selectedGroupKey = null;
    this.fetchSnapshotData();
  }

  get selectedYearLabel() {
    return (this.selectedYears || []).join(", ") || _currentYear();
  }

  handleMonthChange(e)      { this.selectedMonth      = e.detail.value; this._resetGroupState(); }
  handleRegionChange(e)     { this.selectedRegion     = e.detail.value; this._resetGroupState(); }
  handleTechnologyChange(e) { this.selectedTechnology = e.detail.value; this._resetGroupState(); }
  handleVendorChange(e)     { this.selectedVendor     = e.detail.value; this._resetGroupState(); }

  _resetGroupState() {
    this.currentPage       = 1;
    this.selectedGroupKey  = null;
    this.expandedCustomers = {};
    this.summaryCurrentPage = 1;
  }

  handleCustomerExpand(e) {
    const cKey = e.currentTarget.dataset.ckey;
    // Spread to new object to trigger LWC reactivity
    const updated = { ...this.expandedCustomers };
    if (updated[cKey]) {
      delete updated[cKey];
    } else {
      updated[cKey] = true;
    }
    this.expandedCustomers = updated;
    this.selectedGroupKey  = null;
    this.currentPage       = 1;
  }

  handleGroupRowClick(e) {
    const key = e.currentTarget.dataset.key;
    if (this.selectedGroupKey === key) {
      this.selectedGroupKey  = null;
      this.detailLineItems   = [];
      this.currentPage       = 1;
      return;
    }
    this.selectedGroupKey = key;
    this.currentPage      = 1;
    // key = custKey + \x01 + placeholder\x00vendor
    const [cKey, sKey] = key.split("\x01");
    const vendor       = sKey.split("\x00")[1] || "";
    this.fetchGroupDetail(cKey, vendor);
  }

  handleClearGroupSelection() {
    this.selectedGroupKey = null;
    this.currentPage      = 1;
  }

  handleSummarySearch(e)    { this.summarySearchTerm = e.detail.value; this.summaryCurrentPage = 1; }
  handleSummaryPrevPage()   { if (!this.summaryIsPrevDisabled) this.summaryCurrentPage--; }
  handleSummaryNextPage()   { if (!this.summaryIsNextDisabled) this.summaryCurrentPage++; }

  handleClearFilters() {
    const defaultYear       = [_currentYear()];
    const needsRefetch      = JSON.stringify(this.selectedYears) !== JSON.stringify(defaultYear);
    this.selectedYears      = defaultYear;
    this.selectedMonth      = "";
    this.selectedRegion     = "";
    this.selectedTechnology = "";
    this.selectedVendor     = "";
    this.selectedGroupKey   = null;
    this.currentPage        = 1;
    if (needsRefetch) this.fetchSnapshotData();
  }

  handleRefresh() { this.detailLineItems = []; this.fetchSnapshotData(); }

  // ===== HELPERS =====

  _extractMessage(error) {
    if (typeof error === "string") return error;
    if (error?.body?.message)      return error.body.message;
    if (error?.message)            return error.message;
    return JSON.stringify(error);
  }

  formatDate(dateStr) {
    if (!dateStr) return "—";
    const d = new Date(dateStr);
    if (isNaN(d.getTime())) return dateStr;
    return d.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
  }

  // Format as millions: 3,545,655,206.66 → 3,545.66M
  formatM(value) {
    if (value === null || value === undefined) return "—";
    if (value === 0) return "0.00";
    const inM = value / 1_000_000;
    return new Intl.NumberFormat("en-US", {
      minimumFractionDigits: 2, maximumFractionDigits: 2
    }).format(inM) + "M";
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}