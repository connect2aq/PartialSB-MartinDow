import { LightningElement, track, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";
import { loadScript } from "lightning/platformResourceLoader";
import ChartJS from "@salesforce/resourceUrl/ChartJS_4_4_0";

import getEnhancedFilterOptions from "@salesforce/apex/BusinessCaseDashboardController.getEnhancedFilterOptions";
import getSummaryMetrics from "@salesforce/apex/BusinessCaseDashboardController.getSummaryMetrics";
import getFinancialOverviewMetrics from "@salesforce/apex/BusinessCaseDashboardController.getTotalFinancialPerformanceStats";
//import getMachineStatusCounts from "@salesforce/apex/BusinessCaseDashboardController.getMachineStatusCounts";
import getUpdatedSnapshotData from "@salesforce/apex/BusinessCaseDashboardController.GetSnapshotDataUpdated";
import getMachineStatusCounts from "@salesforce/apex/BusinessCaseDashboardController.getMachineCountStatuswiseUpdated";
import getDetailedSnapshotWrapper from "@salesforce/apex/BusinessCaseDashboardController.GetDetailedSnapshotDataUpdated";

export default class BusinessCaseDashboard extends NavigationMixin(
  LightningElement
) {
  showSummary = true;
  showReport = true;
  showLoading = false;
  showSnapshotButton = true;
  showSnapshotHistory = false;

  // Chart.js Loading State
  chartJSLoaded = false;

  // State Management
  @track isLoading = true;
  @track error = null;
  @track activeTab = "investment";
  @track showCustomerModal = false;
  @track selectedCustomerData = null;
  @track filtersLoaded = false;
  @track customerViewMode = "cards"; // "cards" or "table"

  // Data Storage
  @track snapshotData = [];
  @track detailedSnapshotData=[];
  @track filteredData = [];
   @track filteredDetailedData = [];
  @track customersbybusinesscases = [];
  @track summaryMetrics = {};
  @track machineStatusCounts = []; // Original wire data
  @track machineStatusCountList = [];
  @track filteredMachineStatusCountList = [];
  @track calculatedMachineStatusCounts = []; // Calculated from filtered data
  @track financialOverviewPerformanceData = {};
  @track calculatedFinancialData = {}; // Separate property for calculated values
  @track riskAnalysis = {
    healthy: 0,
    warning: 0,
    highrisk: 0,
    critical: 0,
    ontrack: 0,
    behind: 0,
    notargetset: 0,
    atrisk: 0
  };

  // Overview Tiles Data (calculated from ALL data, not filtered)
  @track overviewMetrics = {
    totalCustomers: 0,
    onTrackCustomers: 0,
    behindTargetCustomers: 0,
    noTargetCustomers: 0,
    healthyCustomers: 0,
    warningCustomers: 0,
    highRiskCustomers: 0,
    criticalCustomers: 0
  };

  // Debug getters for filter options structure
  get monthOptionsDebug() {
    return this.monthOptions && this.monthOptions.length > 0
      ? JSON.stringify(this.monthOptions[0])
      : "empty";
  }

  // ===== CHART.JS INITIALIZATION =====

  async loadChartJS() {
    try {
      if (!this.chartJSLoaded) {
        await loadScript(this, ChartJS);
        this.chartJSLoaded = true;
        // console.log("ðŸ“ˆ Chart.js loaded successfully");
      }
    } catch (error) {
      console.error("âŒ Error loading Chart.js:", error);
      this.showToast("Error", "Failed to load Chart.js library", "error");
    }
  }

  // Prepare trend data for charts
  prepareTrendData() {
    if (!this.filteredData || this.filteredData.length === 0) {
      return {
        months: [],
        targets: [],
        actuals: []
      };
    }

    // Group data by month and aggregate targets vs actuals
    const monthlyData = new Map();

    this.filteredData.forEach((record) => {
      const monthKey =
        record.formattedMonth || this.formatMonthLabel(record.snapshotMonth);

      if (!monthlyData.has(monthKey)) {
        monthlyData.set(monthKey, {
          month: monthKey,
          totalTarget: 0,
          totalActual: 0,
          recordCount: 0
        });
      }

      const data = monthlyData.get(monthKey);
      data.totalTarget += this.safeParseNumber(
        record.targetSales || record.commitmentPerMonth || 0
      );
      data.totalActual += this.safeParseNumber(
        record.totalReagentSales || record.avgReagentSalesPerMonth || 0
      );
      data.recordCount++;
    });

    // Convert to arrays sorted by month
    const sortedData = Array.from(monthlyData.values()).sort((a, b) => {
      return new Date(a.month).getTime() - new Date(b.month).getTime();
    });

    return {
      months: sortedData.map((data) => data.month),
      targets: sortedData.map((data) => data.totalTarget),
      actuals: sortedData.map((data) => data.totalActual)
    };
  }

  // ===== DATA PROCESSING METHODS =====
  get businessCaseOptionsDebug() {
    return this.businessCasesOptions && this.businessCasesOptions.length > 0
      ? JSON.stringify(this.businessCasesOptions[0])
      : "empty";
  }
  get customerOptionsDebug() {
    return this.customerOptions && this.customerOptions.length > 0
      ? JSON.stringify(this.customerOptions[0])
      : "empty";
  }
  get regionOptionsDebug() {
    return this.regionOptions && this.regionOptions.length > 0
      ? JSON.stringify(this.regionOptions[0])
      : "empty";
  }

  get supplierOptionsDebug() {
    return this.supplierOptions && this.supplierOptions.length > 0
      ? JSON.stringify(this.supplierOptions[0])
      : "empty";
  }

  // Pagination
  @track currentPage = 1;
  @track pageSize = 50;
  @track totalRecords = 0;
   @track detailedCurrentPage = 1;
  @track detailedPageSize = 12;
  @track detailedtotalRecords = 0;

  // Filters
  @track selectedMonth = "";
  @track selectedMonthYear = "";
  @track selectedSnapshotMonth = "";
  @track selectedDateFrom = "";
  @track selectedDateTo = "";
  @track selectedCustomer = "";
  @track customerSearchTerm = "";
  @track selectedCustomers = [];
  @track popoverCustomerSearchTerm = "";
  @track showCustomerPopover = false;
  _boundOutsideClick = null;
  @track showCustomerSuggestions = false;
  @track highlightedCustomerIndex = -1;
  @track selectedRegion = "";
  @track selectedRegions = []; // Multi-select regions
  @track selectedSupplier = "";
  @track selectedSuppliers = []; // Multi-select suppliers
  @track selectedBusinessCaseStatus = "";
  @track selectedBusinessCaseStatuses = []; // Multi-select business case statuses
  @track selectedMachineStatus = "";
  @track selectedMachineStatuses = []; // Multi-select machine statuses
  @track selectedCommitmentStatus = "";
  @track selectedCommitmentStatuses = []; // Multi-select commitment statuses
  @track selectedRiskStatus = "";
  @track searchTerm = "";
  @track selectedBusinessCase = "";
  @track selectedBusinessCases = []; // Multi-select business cases

  // Filter Options - Internal arrays (not tracked)
  _monthOptions = [{ label: "All Months", value: "" }];
  _customerOptions = [{ label: "All Customers", value: "" }];
  _businessCaseOptions = [{ label: "All Business Cases", value: "" }];
  _regionOptions = [{ label: "All Regions", value: "" }];
  _supplierOptions = [{ label: "All Suppliers", value: "" }];
  _businessCaseStatusOptions = [
    { label: "All Business Case Statuses", value: "" }
  ];
  _machineStatusOptions = [{ label: "All Machine Statuses", value: "" }];
  _commitmentStatusOptions = [{ label: "All Commitment Statuses", value: "" }];
  _riskStatusOptions = [
    { label: "All Risk Levels", value: "" },
    { label: "Healthy", value: "HEALTHY" },
    { label: "Warning", value: "WARNING" },
    { label: "High Risk", value: "HIGH" },
    { label: "Critical", value: "CRITICAL" }
  ];

  // Filter Options - Getters for reactivity
  get monthOptions() {
    return this._monthOptions;
  }

  get monthYearOptions() {
    const options = [];
    const today = new Date();
    const currentYear = today.getFullYear();
    const currentMonth = today.getMonth() + 1;
    for (let i = 0; i < 24; i++) {
      let year = currentYear;
      let month = currentMonth - i;
      while (month <= 0) {
        month += 12;
        year -= 1;
      }
      const value = `${year}-${String(month).padStart(2, '0')}`;
      const label = new Date(year, month - 1, 1).toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
      options.push({ label: i === 0 ? `${label} (Current)` : label, value });
    }
    return options;
  }

  get businessCasesOptions() {
    return this._businessCaseOptions;
  }

  get customerOptions() {
    return this._customerOptions;
  }

  // Return filtered customer options based on the search term
  get customerOptionsFiltered() {
    if (!this._customerOptions || this._customerOptions.length === 0) {
      return this._customerOptions;
    }
    const term = (this.customerSearchTerm || "").trim().toLowerCase();
    if (!term) return this._customerOptions;
    return this._customerOptions.filter((opt) => {
      const label = (opt.label || "").toString().toLowerCase();
      const value = (opt.value || "").toString().toLowerCase();
      return label.includes(term) || value.includes(term);
    });
  }

  // Limit suggestions shown for performance
  get customerSuggestions() {
    try {
      const list = this.customerOptionsFiltered || [];
      return list.slice(0, 10);
    } catch {
      return [];
    }
  }

  // Options used inside the dropdown popover; include checked flag for template
  get customerOptionsForDropdown() {
    // Build the popover list with filtering and checked state
    const list = this._customerOptions || [];
    const term = (this.popoverCustomerSearchTerm || "").trim().toLowerCase();

    // Apply search filtering
    const filtered = !term
      ? list
      : list.filter((opt) => {
          const label = (opt.label || "").toString().toLowerCase();
          const value = (opt.value || "").toString().toLowerCase();
          return label.includes(term) || value.includes(term);
        });

    // Determine checked state for each option
    const selectedSet = new Set(this.selectedCustomers || []);
    const hasIndividualSelections = selectedSet.size > 0;

    return filtered.map((opt) => ({
      ...opt,
      checked:
        opt.value === "" ? !hasIndividualSelections : selectedSet.has(opt.value)
    }));
  }

  // Class binding for the SLDS combobox - when open add 'slds-is-open' so SLDS
  // styles will display the .slds-dropdown element (instead of relying on
  // global CSS hacks). Template binds class to this getter.
  get customerComboboxClass() {
    const base =
      "slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click";
    return this.showCustomerPopover ? `${base} slds-is-open` : base;
  }

  get selectedCustomersCount() {
    return this.selectedCustomers?.length || 0;
  }

  get hasSelectedCustomers() {
    return this.selectedCustomersCount > 0;
  }

  get selectedCustomerNames() {
    if (!this.selectedCustomers || this.selectedCustomers.length === 0) return '';
    return (this._customerOptions || [])
      .filter(opt => opt.value && this.selectedCustomers.includes(opt.value))
      .map(opt => opt.label)
      .join(', ');
  }

  // Check if any client-side filters are active (require calculated data instead of wire data)
  get hasActiveFilters() {
    const hasFilters =
      (this.selectedCustomers && this.selectedCustomers.length > 0) ||
      (this.selectedRegions && this.selectedRegions.length > 0) ||
      (this.selectedSuppliers && this.selectedSuppliers.length > 0) || 
      (this.selectedBusinessCases && this.selectedBusinessCases.length > 0)
      ;

    return hasFilters;
  }

  get allCustomersSelected() {
    const opts = this.customerOptionsForDropdown || [];
    return opts.length > 0 && opts.every((o) => o.checked === true);
  }

  openCustomerPopover(event) {
    if (event) event.stopPropagation();
    this.showCustomerPopover = !this.showCustomerPopover;
    if (this.showCustomerPopover) {
      // attach outside click handler
      this._boundOutsideClick = this.handleOutsideClick.bind(this);
      window.addEventListener("click", this._boundOutsideClick);
    } else {
      this.closeCustomerPopover();
    }
  }

  closeCustomerPopover() {
    this.showCustomerPopover = false;
    if (this._boundOutsideClick) {
      window.removeEventListener("click", this._boundOutsideClick);
      this._boundOutsideClick = null;
    }
  }

  handleOutsideClick(e) {
    const combobox = this.template.querySelector(".slds-combobox");
    if (combobox && !combobox.contains(e.target)) {
      this.closeCustomerPopover();
    }
  }

  handlePopoverSearchInput(event) {
    this.popoverCustomerSearchTerm = event.target.value || "";
  }

  handleToggleSelectAll(event) {
    // Prevent outside click handler from closing the popover when interacting
    // with controls inside the dropdown.
    if (event && typeof event.stopPropagation === "function") {
      event.stopPropagation();
    }
    const checked = event.target.checked;
    if (checked) {
      this.selectedCustomers = (this.customerOptionsForDropdown || []).map(
        (o) => o.value
      );
    } else {
      this.selectedCustomers = [];
    }
    this.selectedCustomer = this.selectedCustomers[0] || "";
    // Keep the popover open so the user can multi-select without it closing
    this.showCustomerPopover = true;
  }

  handleToggleCustomerSelection(event) {
    // Log the event for debugging
    // console.log("handleToggleCustomerSelection event details:", {
    //   target: event.target,
    //   datasetValue: event.target.dataset.value,
    //   checked: event.target.checked,
    //   currentSelectedCustomers: this.selectedCustomers
    // });

    // Stop event propagation
    if (event) {
      event.stopPropagation();
    }

    // Get checkbox state
    const checkbox = event.target;
    const value = checkbox.dataset.value;
    const isChecked = checkbox.checked;

    // console.log("Toggle customer selection:", {
    //   value,
    //   checked: isChecked,
    //   currentTarget: event.currentTarget,
    //   selectedCustomersBefore: [...this.selectedCustomers]
    // });

    // Initialize selection array if needed
    if (!Array.isArray(this.selectedCustomers)) {
      this.selectedCustomers = [];
    }

    // Handle selection based on value
    if (value === "") {
      // "All Customers" checkbox behavior
      if (isChecked) {
        this.selectedCustomers = [];
        // console.log("'All Customers' selected, cleared other selections");
      }
    } else {
      // Individual customer checkbox behavior
      const selectedSet = new Set(this.selectedCustomers);

      if (isChecked) {
        selectedSet.add(value);
      } else {
        selectedSet.delete(value);
      }

      this.selectedCustomers = Array.from(selectedSet);
      // console.log("Updated selections:", this.selectedCustomers);
    }

    // Keep popover open
    this.showCustomerPopover = true;

    // Log state before applying filters
    // console.log("Before applying filters:", {
    //   selectedCustomers: this.selectedCustomers,
    //   originalDataLength: this.snapshotData.length
    // });

    // Apply filters and update dashboard
    this.applyFilters();

    // Log state after applying filters
    // console.log("After applying filters:", {
    //   selectedCustomers: this.selectedCustomers,
    //   filteredDataLength: this.filteredData.length
    // });

    // Dispatch selection change event
    this.dispatchEvent(
      new CustomEvent("selectionchange", {
        detail: {
          selectedCustomers: this.selectedCustomers
        }
      })
    );
  }

  // Stop propagation on the raw click event of the checkbox and its container
  // This prevents any parent click handlers from closing the popover while allowing the change event
  handleCheckboxClick(event) {
    // Only prevent default and stop propagation if this is the initial click
    // This allows the change event to still fire but prevents bubbling to window
    if (event) {
      event.stopPropagation();
    }

    // Log the click event for debugging
    // const checkbox = event.target;
    // console.log("Checkbox clicked:", {
    //   value: checkbox.dataset.value,
    //   checked: checkbox.checked,
    //   target: checkbox,
    //   currentTarget: event.currentTarget
    // });

    // Keep popover open
    this.showCustomerPopover = true;
  }

  // Input handler for dual-listbox filter
  handleCustomerSearchInput(event) {
    this.customerSearchTerm = event.target.value || "";
    // Do not auto-apply filters; user will click Search
  }

  // Dual-listbox selection handler for multi-select customers
  handleCustomerDualChange(event) {
    this.selectedCustomers = event.detail.value || [];
    // Keep single-selection compatibility (optional): set selectedCustomer to first value
    this.selectedCustomer =
      this.selectedCustomers && this.selectedCustomers.length > 0
        ? this.selectedCustomers[0]
        : "";
  }

  get regionOptions() {
    return this._regionOptions;
  }

  get supplierOptions() {
    return this._supplierOptions;
  }

  get businessCaseStatusOptions() {
    return this._businessCaseStatusOptions;
  }

  get machineStatusOptions() {
    return this._machineStatusOptions;
  }

  get commitmentStatusOptions() {
    return this._commitmentStatusOptions;
  }

  get riskStatusOptions() {
    return this._riskStatusOptions;
  }

  // Aggregated Data
  @track regionalInvestmentData = [];
  @track supplierInvestmentData = [];
  @track customerInvestmentData = [];
  @track regionalCommitmentData = [];
  @track supplierCommitmentData = [];
  @track customerCommitmentData = [];

  // Wire Apex Methods
  wiredSnapshotResult;
  wiredFilterResult;
  wiredSummaryResult;
  wiredFinancialSummaryResult;
  wiredDetailedSnapshotResult;

  connectedCallback() {
    // console.log("ðŸš€ BusinessCaseDashboard component connected");
    // console.log("Initial filter options:", {
    //   monthOptions: this._monthOptions,
    //   customerOptions: this._customerOptions,
    //   regionOptions: this._regionOptions,
    //   supplierOptions: this._supplierOptions,
    //   businessCaseOptions: this._businessCaseOptions
    // });

    // Initialize component with empty data to prevent blank page
    this.initializeEmptyData();

    // Default Month/Year filter to current month
    const today = new Date();
    this.selectedMonthYear = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}`;
    this.setMonthYearDates(this.selectedMonthYear); // sets selectedSnapshotMonth

    // Initialize with "All Customers" selected
    this.selectedCustomers = [];

    // Load Chart.js library for trend charts
    this.loadChartJS();
  }

  // Initialize component with empty data to prevent blank page
  initializeEmptyData() {
    if (!this.snapshotData || this.snapshotData.length === 0) {
      this.snapshotData = [];
      this.filteredData = [];
      this.filteredDetailedData = [];
      this.filteredMachineStatusCountList=[];
      this.summaryMetrics = {};
      this.machineStatusCounts = [];
      this.machineStatusCountList = [];
      this.regionalInvestmentData = [];
      this.supplierInvestmentData = [];
      this.customerInvestmentData = [];
      this.regionalCommitmentData = [];
      this.supplierCommitmentData = [];
      this.customerCommitmentData = [];
      this.financialOverviewPerformanceData = {};

      // Initialize overview metrics with zero values
      this.overviewMetrics = {
        totalCustomers: 0,
        onTrackCustomers: 0,
        behindTargetCustomers: 0,
        noTargetCustomers: 0,
        healthyCustomers: 0,
        warningCustomers: 0,
        highRiskCustomers: 0,
        criticalCustomers: 0
      };

      // console.log("ðŸ“‹ Component initialized with empty data");
    }
  }

  renderedCallback() {
    // console.log("ðŸŽ¨ Component rendered - checking filter state:");
    // console.log("filtersLoaded:", this.filtersLoaded);
    // console.log("Current filter options:", {
    //   monthOptions: this.monthOptions,
    //   customerOptions: this.customerOptions,
    //   regionOptions: this.regionOptions,
    //   supplierOptions: this.supplierOptions,
    //   commitmentOptions: this.commitmentStatusOptions,
    //   businessCaseOptions: this.businessCasesOptions
    // });
    // console.log("Filter option lengths:", {
    //   monthOptions: this.monthOptions?.length || 0,
    //   customerOptions: this.customerOptions?.length || 0,
    //   regionOptions: this.regionOptions?.length || 0,
    //   supplierOptions: this.supplierOptions?.length || 0,
    //   commitmentOptions: this.commitmentStatusOptions?.length || 0,
    //   businessCaseOptions: this.commitmentStatusOptions?.length || 0
    // });

    // Check if filter elements exist in DOM
    // Get filter inputs for validation
    this.template.querySelectorAll("lightning-combobox");

    // console.log("Filter DOM elements:", {
    //   filterSection: !!filterSection,
    //   monthFilter: !!monthFilter,
    //   customerFilter: !!customerFilter,
    //   regionFilter: !!regionFilter,
    //   supplierFilter: !!supplierFilter,
    //   commitmentStatusFilter: !!commitmentStatusFilter,
    //   businessCaseFilter: !!businessCaseFilter
    // });

    // Log actual filter option values for debugging
    if (this._monthOptions && this._monthOptions.length > 0) {
      // console.log(
      //   "Month options full list:",
      //   JSON.stringify(this._monthOptions)
      // );
      // console.log(
      //   "âœ… Month options sample:",
      //   JSON.stringify(this._monthOptions.slice(0, 3))
      // );
    } else {
      // console.log("âŒ Month options empty or undefined");
    }
    if (this._customerOptions && this._customerOptions.length > 0) {
      // console.log(
      //   "âœ… Customer options sample:",
      //   JSON.stringify(this._customerOptions.slice(0, 3))
      // );
    } else {
      // console.log("âŒ Customer options empty or undefined");
    }

    // Test if combobox elements have options
    // Validate filter options are loaded
    if (this._monthOptions && this._monthOptions.length > 0) {
      // console.log("ðŸ”„ Month options available");
    }
    if (this._customerOptions && this._customerOptions.length > 0) {
      // console.log("ðŸ”„ Customer options available");
    }
  }

  // @wire(getSnapshotData)
  // wiredSnapshots(result) {
  //   console.log("ðŸ“Š Snapshot Data Wire Method Called");
  //   console.log("Snapshot result:", result);

  //   this.wiredSnapshotResult = result;
  //   if (result.data) {
  //     try {
  //       console.log(
  //         "âœ… Snapshot data received:",
  //         result.data?.length || 0,
  //         "records"
  //       );
  //       console.log("Sample snapshot data:", result.data?.[0]);
  //       this.snapshotData = result.data;
  //       this.processSnapshotData();
  //       this.error = null;
  //       this.isLoading = false; // Ensure loading stops when data is received
  //     } catch (error) {
  //       console.error("âŒ Error processing snapshot data:", error);
  //       this.handleError("Error processing snapshot data", error);
  //       this.isLoading = false; // Ensure loading stops on error
  //     }
  //   } else if (result.error) {
  //     console.error("âŒ Error loading snapshot data:", result.error);
  //     this.handleError("Error loading snapshot data", result.error);
  //     this.isLoading = false; // Ensure loading stops on error
  //   } else {
  //     console.log("â³ Snapshot data loading...");
  //   }
  // }

  @wire(getUpdatedSnapshotData, {
    DateFrom: "$selectedDateFrom",
    DateTo: "$selectedDateTo",
    Region: "",
    Supplier: "",
    BusinessCaseStatus: "",
    MachineStatus: "",
    CommitmentStatus: "",
    RiskStatus: "",
    SearchCustomer: "",
    BusinessCaseName: "",
    SnapshotMonth: "$selectedSnapshotMonth"
  })
  wiredSnapshots(result) 
  {
    console.log('getUpdatedSnapshotData-->result : '+JSON.stringify(result));
    this.wiredSnapshotResult = result;
    
    if (result.data) {
      try 
      {
        
        this.snapshotData = result.data;
        console.log('>>>>businessCaseDashboard-->getUpdatedSnapshotData-->snapshotData : '+JSON.stringify(this.snapshotData));
        this.processSnapshotData();
        this.error = null;
        this.isLoading = false; // Ensure loading stops when data is received
      } catch (error) {
        console.error("âŒ Error processing snapshot data:", {
          message: error.message,
          stack: error.stack,
          name: error.name
        });
        this.handleError("Error processing snapshot data", error);
        this.isLoading = false; // Ensure loading stops on error
      }
    } else if (result.error) {
      console.error("âŒ Error loading snapshot data:", result.error);
      this.handleError("Error loading snapshot data", result.error);
      this.isLoading = false; // Ensure loading stops on error
    } else {
      // console.log("â³ Snapshot data loading...");
    }
  }

  //GetDetailedSnapshotDataUpdated
  @wire(getDetailedSnapshotWrapper, {
    DateFrom: "$selectedDateFrom",
    DateTo: "$selectedDateTo",
    Region: "",
    Supplier: "",
    BusinessCaseStatus: "",
    MachineStatus: "",
    CommitmentStatus: "",
    RiskStatus: "",
    SearchCustomer: "",
    BusinessCaseName: "",
    SnapshotMonth: "$selectedSnapshotMonth"
  })
  wiredDetailedSnapshots(result) {
    this.wiredDetailedSnapshotResult = result;
    if (result.data) {
      try {
        this.detailedSnapshotData = result.data;
        this.processSnapshotData();
        this.error = null;
        this.isLoading = false; // Ensure loading stops when data is received
      } catch (error) {
        console.error("âŒ Error processing snapshot data:", {
          message: error.message,
          stack: error.stack,
          name: error.name
        });
        this.handleError("Error processing snapshot data", error);
        this.isLoading = false; // Ensure loading stops on error
      }
    } else if (result.error) {
      console.error("âŒ Error loading snapshot data:", result.error);
      this.handleError("Error loading snapshot data", result.error);
      this.isLoading = false; // Ensure loading stops on error
    } else {
      // console.log("â³ Snapshot data loading...");
    }
  }


  @wire(getEnhancedFilterOptions)
  wiredFilters(result) {
    // console.log("ðŸ” Enhanced Filter Options Wire Method Called");
    // console.log("Filter result:", result);

    this.wiredFilterResult = result;
    if (result.data) {
      try {
        // console.log("âœ… Enhanced filter data received:", result.data);
        // console.log(
        //   "Enhanced filter data structure:",
        //   JSON.stringify(result.data, null, 2)
        // );
        this.processEnhancedFilterOptions(result.data);
        this.error = null;
        // console.log("âœ… Enhanced filter options processed successfully");
        // Don't set isLoading to false here as other data might still be loading
      } catch (error) {
        console.error("âŒ Error processing enhanced filter options:", error);
        this.handleError("Error processing enhanced filter options", error);
      }
    } else if (result.error) {
      console.error("âŒ Error loading enhanced filter options:", result.error);
      this.handleError("Error loading enhanced filter options", result.error);
    } else {
      // console.log("â³ Enhanced filter options loading...");
    }
  }

  @wire(getSummaryMetrics)
  wiredSummary(result) {
    this.wiredSummaryResult = result;
    if (result.data) {
      try {
        this.summaryMetrics = result.data;
        this.error = null;
      } catch (error) {
        this.handleError("Error processing summary metrics", error);
      } finally {
        this.isLoading = false;
      }
    } else if (result.error) {
      this.handleError("Error loading summary metrics", result.error);
      this.isLoading = false; // Ensure loading stops on error
    } else {
      // Still loading, but let's ensure it doesn't stay loading forever
      // console.log("â³ Summary metrics loading...");
    }
  }

  @wire(getFinancialOverviewMetrics, {
    DateFrom: "$selectedDateFrom",
    DateTo: "$selectedDateTo",
    Region: "",
    Supplier: "",
    BusinessCaseStatus: "",
    MachineStatus: "",
    CommitmentStatus: "",
    RiskStatus: "$selectedRiskStatus",
    SearchCustomer: "",
    BusinessCaseName: "",
    SnapshotMonth: "$selectedSnapshotMonth"
  })
  wiredFinancialSummaryResult(result) 
  {
    console.log('>>>>businessCaseDashboard-->getFinancialOverviewMetrics-->fired');
    this.financialOverviewPerformanceData = result;
    console.log('>>>>businessCaseDashboard-->getFinancialOverviewMetrics-->selectedDateFrom: '+this.selectedDateFrom);
    console.log('>>>>businessCaseDashboard-->getFinancialOverviewMetrics-->selectedDateTo: '+this.selectedDateTo);
    console.log('>>>>businessCaseDashboard-->getFinancialOverviewMetrics-->selectedRiskStatus: '+this.selectedRiskStatus);
    
    if (result.data) {
      try {
        
        this.financialOverviewPerformanceData = result.data;
        console.log('>>>>businessCaseDashboard-->getFinancialOverviewMetrics-->financialOverviewPerformanceData: '+ JSON.stringify(this.financialOverviewPerformanceData) );
        // this.calculatedFinancialData = {
        //   financialOverviewTotalInvestment: 0,
        //   financialOverviewTotalSales: 0,
        //     financialOverviewTotalMargin: 0,
        //   costRecovery: "0%"
        // };
        this.error = null;
      } catch (error) {
        this.handleError("Error processing summary metrics", error);
      } finally {
        this.isLoading = false;
      }
    } else if (result.error) {
      this.handleError("Error loading summary metrics", result.error);
      this.isLoading = false; // Ensure loading stops on error
    } else {
      // Still loading, but let's ensure it doesn't stay loading forever
      // console.log("â³ Summary metrics loading...");
    }
  }

  @wire(getMachineStatusCounts, {
    DateFrom: "$selectedDateFrom",
    DateTo: "$selectedDateTo",
    Region: "",
    Supplier: "",
    BusinessCaseStatus: "",
    MachineStatus: "",
    CommitmentStatus: "",
    RiskStatus: "",
    SearchCustomer: "",
    BusinessCaseName: "",
    SnapshotMonth: "$selectedSnapshotMonth"
  })
  wiredMachineStatus(result) {
    if (result.data) {
      try {
        // Store wire data - never overwrite this
        this.machineStatusCounts = result.data.machineStatusCount;
        this.machineStatusCountList = result.data.machineStatusListResp;

        console.log(
          "âœ…wiredMachineStatus --> Machine status counts loaded:",
          this.machineStatusCounts
        );
        console.log(
          "âœ…wiredMachineStatus --> Machine status counts list loaded:",
          this.machineStatusCountList
        );
      } catch (error) {
        console.error("âŒ Error processing machine status counts:", error);
      }
    } else if (result.error) {
      console.error("âŒ Error loading machine status counts:", result.error);
    }
  }

  // ===== DATA PROCESSING =====

  processSnapshotData() {
    // console.log("ðŸ“Š Processing snapshot data...");
    // console.log(
    //   "Snapshot data received:",
    //   this.snapshotData?.length || 0,
    //   "records"
    // );

    if (!this.snapshotData || this.snapshotData.length === 0) {
      // console.log("âš ï¸ No snapshot data available");
      this.filteredData = [];
      this.filteredDetailedData=[];
      this.aggregateData();
      return;
    }

    // Debug: Check for missing customer 3020001237 snapshots
    // const customer3020001237Records = this.snapshotData.filter(
    //   (record) => record.customerCode === "3020001237"
    // );

    // console.log("ðŸ” Customer 3020001237 snapshot verification:");
    // console.log(
    //   `Found ${customer3020001237Records.length} records for customer 3020001237`
    // );

    // if (customer3020001237Records.length > 0) {
    //   customer3020001237Records.forEach((record, index) => {
    //     console.log(`Record ${index + 1}:`, {
    //       customerCode: record.customerCode,
    //       businessCaseName: record.businessCaseName,
    //       snapshotMonth: record.snapshotMonth,
    //       totalReagentSales: record.totalReagentSales,
    //       targetSales: record.targetSales,
    //       achievement: record.achievement
    //     });
    //   });
    // } else {
    //   console.log("ï¿½ No records found for customer 3020001237");
    //   console.log(
    //     "Expected snapshots: BCSS-0000575 (Feb), BCSS-0000576 (Mar), BCSS-0000577 (Apr)"
    //   );
    // }

    // console.log("First snapshot record sample:", this.snapshotData[0]);
    // console.log("ðŸ” Detailed field analysis of first record:");
    if (this.snapshotData[0]) {
      const firstRecord = this.snapshotData[0];
      Object.keys(firstRecord).forEach((key) => {
        if (
          key.toLowerCase().includes("performance") ||
          key.toLowerCase().includes("status") ||
          key.toLowerCase().includes("commitment")
        ) {
          // console.log(`  ${key}: ${firstRecord[key]}`);
        } 
      });
    }

    // Perform initial risk analysis on all data for filtering purposes
    this.performInitialRiskAnalysis();

    // Calculate overview metrics from ALL data (before filtering)
    this.calculateOverviewMetrics();

    // Apply filters AFTER initial risk analysis
    this.applyFilters();

    // Perform complete risk analysis on filtered data for display
    this.analyzeCustomerCommitmentRisk();

    // Generate aggregated reports AFTER filtering and risk analysis
    this.aggregateData();

    // Add sample risk data for demonstration if no risk data exists
    this.addSampleRiskDataIfNeeded();

    // console.log("ðŸ“Š Snapshot data processing completed");
    // console.log("Filtered data:", this.filteredData?.length || 0, "records");
    // console.log(
    //   "Regional investment data:",
    //   this.regionalInvestmentData?.length || 0,
    //   "records"
    // );
    // console.log("Risk analysis summary:", this.formattedRiskSummary);
  }

  getBusinessCasesByCustomer() {
    const finalrecords = [];
    if (!this.snapshotData?.length) {
      return finalrecords;
    }

    this.snapshotData.forEach((record) => {
      const currentrecord = {
        businessCaseId: record.businessCaseId,
        businessCaseName: record.businessCaseName,
        businessCaseStatus: record.businessCaseStatus,
        customerCode: record.customerCode,
        customerName: record.customerName,
        vendor: record.vendor,
        technology: record.technology,
        region: record.region,
        machineStatus: record.machineStatus,
        monthCommitment: record.monthCommitment,
        performanceStatus:
          record.performanceStatus ||
          this.getPerformanceStatus(
            record.avgReagentSalesPerMonth,
            record.monthCommitment
          ),
        formattedAchievement: record.formattedAchievement,
        customerAddressLine1: record.customerAddressLine1,
        customerAddressLine2: record.customerAddressLine2,
        customerCity: record.customerCity,
        shipToAddressLine1: record.shipToAddressLine1,
        shipToAddressLine2: record.shipToAddressLine2,
        shipToCity: record.shipToCity,
        avgReagentSalesPerMonth: record.avgReagentSalesPerMonth || 0,
        commitmentPerMonth: record.monthCommitment
      };

      let customerRiskData;
      try {
        customerRiskData = this.customerRiskAnalysis.get(
          currentrecord.customerCode
        ) || {
          riskLevel: "HEALTHY",
          consecutiveFailedMonths: 0,
          actionRequired: "Continue monitoring performance",
          riskLevelClass: this.getRiskLevelClass("HEALTHY")
        };
      } catch (error) {
        console.error("Error getting customer risk data:", {
          message: error.message,
          stack: error.stack,
          name: error.name
        });
        customerRiskData = {
          riskLevel: "HEALTHY",
          consecutiveFailedMonths: 0,
          actionRequired: "Continue monitoring performance",
          riskLevelClass: this.getRiskLevelClass("HEALTHY")
        };
      }

      currentrecord.riskStatus = customerRiskData;
      currentrecord.monthlySales = record.monthlySales;
      finalrecords.push(currentrecord);
    });

    return finalrecords;
  }

  processEnhancedFilterOptions(data) {
    // console.log("ðŸ”§ Processing enhanced filter options with data:", data);

    // Process month options
    // console.log("Processing months:", data.months);
    const monthArray = [{ label: "All Months", value: "" }];
    if (data.months && data.months.length > 0) {
      data.months.forEach((month) => {
        monthArray.push({
          label: this.formatMonthLabel(month),
          value: month
        });
      });
    }
    this._monthOptions = [...monthArray];
    // console.log("âœ… Month options assigned:", this._monthOptions.length);

    // Process customer options
    // console.log("Processing customers:", data.customers);
    const customerArray = [{ label: "All Customers", value: "" }];
    if (data.customers && data.customers.length > 0) {
      data.customers.forEach((customer) => {
        customerArray.push({
          label: `${customer.customerCode} - ${customer.customerName}`,
          value: customer.customerCode
        });
      });
    }
    this._customerOptions = [...customerArray];
    // console.log("âœ… Customer options assigned:", this._customerOptions.length);

    // Process region options
    // console.log("Processing regions:", data.regions);
    const regionArray = [{ label: "All Regions", value: "" }];
    if (data.regions && data.regions.length > 0) {
      data.regions.forEach((region) => {
        regionArray.push({
          label: region,
          value: region
        });
      });
    }
    this._regionOptions = [...regionArray];
    // console.log("âœ… Region options assigned:", this._regionOptions.length);

    // Process business cases options
    // console.log("Processing business cases:", data.businessCases);
    const businessCaseArray = [{ label: "All Business Cases", value: "" }];
    if (data.businessCases && data.businessCases.length > 0) {
      data.businessCases.forEach((businessCase) => {
        businessCaseArray.push({
          label: businessCase,
          value: businessCase
        });
      });
    }
    this._businessCaseOptions = [...businessCaseArray];
    // console.log(
    //   "âœ… Business Cases options assigned:",
    //   this._businessCaseOptions.length
    // );

    // Process supplier options
    // console.log("Processing suppliers:", data.suppliers);
    const supplierArray = [{ label: "All Suppliers", value: "" }];
    if (data.suppliers && data.suppliers.length > 0) {
      data.suppliers.forEach((supplier) => {
        supplierArray.push({
          label: supplier,
          value: supplier
        });
      });
    }
    this._supplierOptions = [...supplierArray];
    // console.log("âœ… Supplier options assigned:", this._supplierOptions.length);

    // Process Business Case Status options (NEW)
    // console.log(
    //   "Processing business case statuses:",
    //   data.businessCaseStatuses
    // );
    const businessCaseStatusArray = [
      { label: "All Business Case Statuses", value: "" }
    ];
    if (data.businessCaseStatuses && data.businessCaseStatuses.length > 0) {
      data.businessCaseStatuses.forEach((status) => {
        businessCaseStatusArray.push({
          label: status,
          value: status
        });
      });
    }
    this._businessCaseStatusOptions = [...businessCaseStatusArray];
    // console.log(
    //   "âœ… Business Case Status options assigned:",
    //   this._businessCaseStatusOptions.length
    // );

    // Process Machine Status options (NEW)
    // console.log("Processing machine statuses:", data.machineStatuses);
    const machineStatusArray = [{ label: "All Machine Statuses", value: "" }];
    if (data.machineStatuses && data.machineStatuses.length > 0) {
      data.machineStatuses.forEach((status) => {
        machineStatusArray.push({
          label: status,
          value: status
        });
      });
    }
    this._machineStatusOptions = [...machineStatusArray];
    // console.log(
    //   "âœ… Machine Status options assigned:",
    //   this._machineStatusOptions.length
    // );

    // Process Commitment Status options (NEW)
    // console.log("Processing commitment statuses:", data.performanceStatuses);
    const commitmentStatusesArray = [
      { label: "All Commitment Statuses", value: "" }
    ];
    if (data.performanceStatuses && data.performanceStatuses.length > 0) {
      data.performanceStatuses.forEach((status) => {
        commitmentStatusesArray.push({
          label: status,
          value: status
        });
      });
    }
    this._commitmentStatusOptions = [...commitmentStatusesArray];
    // console.log(
    //   "âœ… Commitment Status options assigned:",
    //   this._commitmentStatusOptions.length
    // );

    // Mark filters as loaded and force re-render
    this.filtersLoaded = true;
    // console.log("ðŸŽ¯ All enhanced filter options processed successfully");
    // console.log("ðŸ“‹ Enhanced filter options summary:");
    // console.log("  - Months:", this._monthOptions.length);
    // console.log("  - Customers:", this._customerOptions.length);
    // console.log("  - Regions:", this._regionOptions.length);
    // console.log("  - Suppliers:", this._supplierOptions.length);
    // console.log(
    //   "  - Commitment Statuses:",
    //   this._commitmentStatusOptions.length
    // );
    // console.log("  - Business Cases:", this._businessCaseOptions.length);
    // console.log(
    //   "  - Business Case Statuses:",
    //   this._businessCaseStatusOptions.length
    // );
    // console.log("  - Machine Statuses:", this._machineStatusOptions.length);
  }

  applyFilters() {
    // Analyze source data
    const uniqueStatuses = new Set();
    const uniqueCustomers = new Set();
    const uniqueRegions = new Set();
    const dataAnalysis = {
      totalRecords: 0,
      recordsWithPerformanceStatus: 0,
      recordsWithCustomerCode: 0,
      recordsWithBusinessCase: 0
    };

    this.snapshotData.forEach((record) => {
      dataAnalysis.totalRecords++;
      if (record.performanceStatus) {
        uniqueStatuses.add(record.performanceStatus);
        dataAnalysis.recordsWithPerformanceStatus++;
      }
      if (record.customerCode) {
        uniqueCustomers.add(record.customerCode);
        dataAnalysis.recordsWithCustomerCode++;
      }
      if (record.businessCaseId) {
        dataAnalysis.recordsWithBusinessCase++;
      }
      if (record.region) {
        uniqueRegions.add(record.region);
      }
    });

    let filtered = [...this.snapshotData];

    

    // Month filter
    if (this.selectedMonth) {
      filtered = filtered.filter(
        (record) => record.snapshotMonth === this.selectedMonth
      );
    }

    //For Detailed Snapshot Data Filtered
    let detailedfiltered = [...this.detailedSnapshotData];

    // Month filter
    if (this.selectedMonth) {
      detailedfiltered = detailedfiltered.filter(
        (record) => record.month === this.selectedMonth
      );
    }



    // Business Case Status filter (NEW)
    if (
      this.selectedBusinessCases &&
      this.selectedBusinessCases.length > 0
    ) {
      const plainBusinessCasesArray = Array.from(this.selectedBusinessCases);
      const selectedBusinessCasesSet = new Set(plainBusinessCasesArray);
      filtered = filtered.filter((record) =>
        selectedBusinessCasesSet.has(record.businessCaseName)
      );

      detailedfiltered = detailedfiltered.filter((record) =>
        selectedBusinessCasesSet.has(record.businessCaseName)
      );
    }

    
    // Customer filter - handle multi-select customers
    if (this.selectedCustomers && this.selectedCustomers.length > 0) {
      // Create Set from selectedCustomers for efficient lookup
      const selectedCustomerSet = new Set(this.selectedCustomers);

      // Track filter matches and misses for debugging
      let matchCounts = {};
      let mismatchCounts = {};

      // First pass - analyze records
      filtered.forEach((record) => {
        if (!record || !record.customerCode) {
          return;
        }

        if (selectedCustomerSet.has(record.customerCode)) {
          matchCounts[record.customerCode] =
            (matchCounts[record.customerCode] || 0) + 1;
        } else {
          mismatchCounts[record.customerCode] =
            (mismatchCounts[record.customerCode] || 0) + 1;
        }
      });

      detailedfiltered.forEach((record) => {
        if (!record || !record.customerCode) {
          return;
        }

        if (selectedCustomerSet.has(record.customerCode)) {
          matchCounts[record.customerCode] =
            (matchCounts[record.customerCode] || 0) + 1;
        } else {
          mismatchCounts[record.customerCode] =
            (mismatchCounts[record.customerCode] || 0) + 1;
        }
      });
      

      // Apply filter with detailed logging
      filtered = filtered.filter((record) => {
        if (!record || !record.customerCode) {
          return false;
        }

        const isSelected = selectedCustomerSet.has(record.customerCode);
        //     recordDetails: {
        //       businessCase: record.businessCaseId,
        //       status: record.performanceStatus,
        //       monthKey: record.snapshotMonth,
        //       salesValue:
        //         record.totalReagentSales || record.avgReagentSalesPerMonth
        //     }
        //   });
        // }

        return isSelected;
      });

       detailedfiltered = detailedfiltered.filter((record) => {
        if (!record || !record.customerCode) {
          return false;
        }

        const isSelected = selectedCustomerSet.has(record.customerCode);
        //     recordDetails: {
        //       businessCase: record.businessCaseId,
        //       status: record.performanceStatus,
        //       monthKey: record.snapshotMonth,
        //       salesValue:
        //         record.totalReagentSales || record.avgReagentSalesPerMonth
        //     }
        //   });
        // }

        return isSelected;
      });

      // Log final filtering results with detailed analysis
      // const customerFilterResults = {
      //   beforeFilter: {
      //     totalRecords: this.snapshotData.length,
      //     preFilteredRecords: filtered.length
      //   },
      //   filterCriteria: {
      //     selectedCustomers: [...selectedCustomerSet],
      //     selectedCustomersCount: selectedCustomerSet.size
      //   },
      //   filterResults: {
      //     matchedRecordsTotal: Object.values(matchCounts).reduce(
      //       (sum, count) => sum + count,
      //       0
      //     ),
      //     recordsPerCustomer: matchCounts,
      //     filteredRecordsCount: filtered.length
      //   },
      //   sampleData: {
      //     beforeFilter: this.snapshotData.slice(0, 2).map((r) => ({
      //       customerCode: r.customerCode,
      //       customerName: r.customerName,
      //       businessCase: r.businessCaseId,
      //       performanceStatus: r.performanceStatus,
      //       month: r.snapshotMonth
      //     })),
      //     afterFilter: filtered.slice(0, 2).map((r) => ({
      //       customerCode: r.customerCode,
      //       customerName: r.customerName,
      //       businessCase: r.businessCaseId,
      //       performanceStatus: r.performanceStatus,
      //       month: r.snapshotMonth
      //     }))
      //   }
      // };

      // console.log(
      //   "ðŸ” Customer filtering - complete analysis:",
      //   customerFilterResults
      // );

      // Additional validation of filtered data
      const duplicateCheck = new Set();
      const duplicates = filtered.filter((record) => {
        const key = `${record.customerCode}-${record.businessCaseId}-${record.snapshotMonth}`;
        if (duplicateCheck.has(key)) {
          return true;
        }
        duplicateCheck.add(key);
        return false;
      });

      if (duplicates.length > 0) 
      {
        console.warn("âš ï¸ Found duplicate records after filtering:", {
          duplicateCount: duplicates.length,
          examples: duplicates.slice(0, 2).map((r) => ({
            customerCode: r.customerCode,
            businessCase: r.businessCaseId,
            month: r.snapshotMonth
          }))
        });
      }

      // Verify all selected customers are represented in filtered data
      const missingCustomers = [...selectedCustomerSet].filter(
        (customerCode) => !filtered.some((r) => r.customerCode === customerCode)
      );

      if (missingCustomers.length > 0) {
        console.warn(
          "âš ï¸ Some selected customers missing from filtered results:",
          {
            missingCustomers,
            missingCount: missingCustomers.length,
            availableCustomers: [
              ...new Set(this.snapshotData.map((r) => r.customerCode))
            ]
          }
        );
      }
    }

    // Region filter - handle multi-select
    if (this.selectedRegions && this.selectedRegions.length > 0) {
      const plainRegionsArray = Array.from(this.selectedRegions);
      const selectedRegionSet = new Set(plainRegionsArray);

      filtered = filtered.filter((record) =>
        selectedRegionSet.has(record.region)
      );
      detailedfiltered = detailedfiltered.filter((record) =>
        selectedRegionSet.has(record.region)
      );
    }

    // Supplier filter
    if (this.selectedSuppliers && this.selectedSuppliers.length > 0) {
      const plainSuppliersArray = Array.from(this.selectedSuppliers);
      const selectedSupplierSet = new Set(plainSuppliersArray);
      filtered = filtered.filter((record) =>
        selectedSupplierSet.has(record.vendor)
      );
      detailedfiltered = detailedfiltered.filter((record) =>
        selectedSupplierSet.has(record.vendor)
      );
    }

    // Business Case Status filter (NEW)
    if (
      this.selectedBusinessCaseStatuses &&
      this.selectedBusinessCaseStatuses.length > 0
    ) {
      const plainStatusesArray = Array.from(this.selectedBusinessCaseStatuses);
      const selectedStatusSet = new Set(plainStatusesArray);
      filtered = filtered.filter((record) =>
        selectedStatusSet.has(record.businessCaseStatus)
      );
      // detailedfiltered = detailedfiltered.filter((record) =>
      //   selectedStatusSet.has(record.businessCaseStatus)
      // );
    }

    // Machine Status filter (NEW)
    if (
      this.selectedMachineStatuses &&
      this.selectedMachineStatuses.length > 0
    ) {
      const plainMachineStatusArray = Array.from(this.selectedMachineStatuses);
      const selectedMachineStatusSet = new Set(plainMachineStatusArray);
      filtered = filtered.filter((record) =>
        selectedMachineStatusSet.has(record.machineStatus)
      );
    }

    // Commitment Status filter (NEW)
    if (
      this.selectedCommitmentStatuses &&
      this.selectedCommitmentStatuses.length > 0
    ) {
      const plainCommitmentStatusArray = Array.from(
        this.selectedCommitmentStatuses
      );
      const selectedCommitmentStatusSet = new Set(plainCommitmentStatusArray);
      filtered = filtered.filter((record) =>
        selectedCommitmentStatusSet.has(record.performanceStatus)
      );
    }

    // Risk Status filter
    if (this.selectedRiskStatus) {
      filtered = filtered.filter((record) => {
        const customerRiskProfile = this.customerRiskAnalysis.get(
          record.customerCode
        );
        return (
          customerRiskProfile &&
          customerRiskProfile.riskLevel === this.selectedRiskStatus
        );
      });
    }

    // Search filter
    if (this.searchTerm) {
      const searchLower = this.searchTerm.toLowerCase();
      filtered = filtered.filter(
        (record) =>
          record.customerName.toLowerCase().includes(searchLower) ||
          record.customerCode.toLowerCase().includes(searchLower) ||
          record.region.toLowerCase().includes(searchLower) ||
          record.vendor.toLowerCase().includes(searchLower) ||
          record.technology.toLowerCase().includes(searchLower)
      );
    }

    this.filteredData = filtered;
    console.log('>>>>businessCaseDashboard-->applyFilters-->filtered data: '+JSON.stringify(this.filteredData));
    this.totalRecords = filtered.length;
    this.currentPage = 1; // Reset to first page when filters change

    this.filteredDetailedData = detailedfiltered;
    this.detailedtotalRecords = detailedfiltered.length;
    this.detailedCurrentPage = 1;

    // Handle machine status counts based on active filters (customer or region)
    if (this.hasActiveFilters) {
      // Filters are active: calculate from filtered data
      this.calculateMachineStatusCountsFromFiltered();
    } else {
      // No filters: clear calculated data (will use wire data via getter)
      this.calculatedMachineStatusCounts = [];
    }

    // Regenerate aggregated data after filtering
    this.aggregateData();

    console.log(
      "âœ… Filters applied. Final filtered data:",
      this.filteredData.length,
      "records"
    );
  }

  aggregateData() {
    // console.log(
    //   "ðŸ“ˆ Starting data aggregation with",
    //   this.filteredData?.length || 0,
    //   "filtered records"
    // );

    this.regionalInvestmentData = this.aggregateByRegion();
    this.supplierInvestmentData = this.aggregateBySupplier();
    // this.customerInvestmentData = this.aggregateByCustomer();
    this.customerInvestmentData = this.aggregateByCustomerBusinessCases().map((r, i) => ({ ...r, rowNumber: i + 1 }));
    this.regionalCommitmentData = this.aggregateCommitmentByRegion();
    this.supplierCommitmentData = this.aggregateCommitmentBySupplier();
    // this.customerCommitmentData = this.aggregateByCustomer();
    this.customerCommitmentData = this.aggregateByCustomerBusinessCases();
    this.calculateRiskBusinessCases();
    this.formatFilteredDetailedData();
    // Calculate financial overview from filtered data
    this.calculateFinancialOverview();

    // Note: Machine status counts are NOT recalculated here
    // They come from @wire(getMachineStatusCounts) by default
    // Only recalculated when customer filter is applied (see applyFilters)

    // Update total records for customer data pagination
    this.updateCustomerPagination();

    // console.log("ðŸ“ˆ Aggregation completed:");
    // console.log(
    //   "- Regional F data:",
    //   this.regionalInvestmentData?.length || 0
    // );
    // console.log(
    //   "- Supplier investment data:",
    //   this.supplierInvestmentData?.length || 0
    // );
    // console.log(
    //   "- Customer investment data:",
    //   this.customerInvestmentData?.length || 0
    // );
    // console.log(
    //   "- Regional commitment data:",
    //   this.regionalCommitmentData?.length || 0
    // );
    // console.log(
    //   "- Supplier commitment data:",
    //   this.supplierCommitmentData?.length || 0
    // );
  }

  updateCustomerPagination() {
    // Update pagination based on active tab
    if (this.activeTab === "investment") {
      this.totalRecords = this.customerInvestmentData?.length || 0;
    } else if (this.activeTab === "commitment") {
      this.totalRecords = this.customerCommitmentData?.length || 0;
    }
    this.currentPage = 1; // Reset to first page
  }

  formatFilteredDetailedData()
  {
    this.filteredDetailedData = this.filteredDetailedData.map((record) => {
        return {
            ...record,
            formattedSales: this.formatCurrency(record.totalReagentSales),
            formattedTarget: this.formatCurrency(record.monthlyCommitment),
            formattedYtdSales: this.formatCurrency(record.ytdSales),
            formattedAvgYtdSales: this.formatCurrency(record.avgYtdSales)
        };
    });
    console.log('>>>>businessCaseDashboard-->formatFilteredDetailedData-->length: '+this.filteredDetailedData.length);
    console.log('>>>>businessCaseDashboard-->formatFilteredDetailedData-->'+JSON.stringify(this.filteredDetailedData));
  }

  exportSnapshotsToExcel() 
  {
      const data = this.filteredDetailedData;
      const columns = this.detailedSnapshotColumns;

      // console.log('Exporting rows:', JSON.stringify(data));

      if (!data || data.length === 0) {
          console.warn('No data to export');
          return;
      }

      // Extract headers from column labels
      const headers = columns.map(col => col.label);

      // Build CSV rows based on fieldNames
      const rows = data.map(row =>
          columns.map(col => {
              let cellValue = row[col.fieldName];
              if (cellValue === undefined || cellValue === null) {
                  cellValue = '';
              }
              // Escape quotes in values
              cellValue = String(cellValue).replace(/"/g, '""');
              return `"${cellValue}"`;
          }).join(',')
      );

      const csvString = [headers.join(','), ...rows].join('\n');

        // Convert CSV string to a Base64-encoded data URI
        const csvDataUri = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csvString);

        // Create a temporary <a> element for download
        const link = document.createElement('a');
        link.href = csvDataUri;
        link.target = '_self';
        link.download = `BusinessCasesSalesSnapshots_${new Date().toISOString().slice(0,10)}.csv`;

        // Append it to the DOM and trigger click
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
  }

  exportPerformanceSummaryToExcel() {
    const buildSheet = (columns, data) => {
      const safeCols = (columns || []).filter(c => c.fieldName && c.label);
      const headerRow = safeCols.map(c =>
        `<Cell><Data ss:Type="String">${c.label.replace(/&/g,'&amp;').replace(/</g,'&lt;')}</Data></Cell>`
      ).join('');
      const dataRows = (data || []).map(row => {
        const cells = safeCols.map(c => {
          let v = row[c.fieldName];
          if (v === null || v === undefined) v = '';
          v = String(v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/"/g,'&quot;');
          return `<Cell><Data ss:Type="String">${v}</Data></Cell>`;
        }).join('');
        return `<Row>${cells}</Row>`;
      }).join('');
      return `<Table><Row>${headerRow}</Row>${dataRows}</Table>`;
    };

    const sheets = [
      { name: 'Regional',  cols: this.regionalCommitmentColumns,  data: this.regionalCommitmentData  },
      { name: 'Supplier',  cols: this.supplierCommitmentColumns,  data: this.supplierCommitmentData  },
      { name: 'Customer',  cols: this.customerCommitmentColumns,  data: this.customerCommitmentData  }
    ];

    const worksheets = sheets.map(s =>
      `<Worksheet ss:Name="${s.name}">${buildSheet(s.cols, s.data)}</Worksheet>`
    ).join('');

    const xml = `<?xml version="1.0"?><?mso-application progid="Excel.Sheet"?>` +
      `<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"` +
      ` xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">` +
      worksheets + `</Workbook>`;

    const dataUri = 'data:application/vnd.ms-excel;charset=utf-8,' + encodeURIComponent(xml);
    const link = document.createElement('a');
    link.href = dataUri;
    link.target = '_self';
    link.download = `PerformanceSummary_${new Date().toISOString().slice(0,10)}.xls`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  calculateFinancialOverview() {
    try {
      // Calculate financial metrics from filtered data
      // Group by business case and take the latest snapshot (highest snapshot month)
      const latestSnapshotPerBC = new Map();

      this.filteredData.forEach((record) => {
        if (!record.businessCaseId) return;

        const existing = latestSnapshotPerBC.get(record.businessCaseId);
        if (!existing || record.snapshotMonth > existing.snapshotMonth) {
          latestSnapshotPerBC.set(record.businessCaseId, record);
        }
      });

      // Now calculate totals from latest snapshots only
      let totalInvestment = 0;
      let totalSales = 0;
      let totalMargin = 0;

      latestSnapshotPerBC.forEach((record) => {
        totalInvestment += record.investment || 0;
        totalSales += record.totalReagentSalesTillDate || 0;
        totalMargin += record.marginTillDate || 0;
      });

      console.log(
        ">>>>businessCaseDashboard-->calculateFinancialOverview-->totalmargin: "+totalMargin
      );

      // Calculate cost recovery
      const costRecovery =
        totalInvestment > 0
          ? this.formatPercent((totalMargin / totalInvestment) * 100)
          : "0%";

      // Update the calculated financial data object (not the wire result)
      this.calculatedFinancialData = {
        financialOverviewTotalInvestment: totalInvestment,
        financialOverviewTotalSales: totalSales,
        financialOverviewTotalMargin: totalMargin,
        costRecovery: costRecovery
      };

      console.log("ðŸ“Š Financial Overview calculated from filtered data:", {
        totalInvestment,
        totalSales,
        totalMargin,
        costRecovery,
        recordsProcessed: this.filteredData.length,
        uniqueBusinessCases: latestSnapshotPerBC.size
      });
    } catch (error) {
      console.error("âŒ Error in calculateFinancialOverview:", {
        message: error.message,
        stack: error.stack
      });
      // Initialize with safe defaults
      this.calculatedFinancialData = {
        financialOverviewTotalInvestment: 0,
        financialOverviewTotalSales: 0,
          financialOverviewTotalMargin: 0,
        costRecovery: "0%"
      };
    }
  }

  calculateMachineStatusCountsFromFiltered() 
  {
    try {
      // Calculate machine status counts from filtered data
      const statusMap = new Map();

      console.log('>>>>businessCaseDashboard-->calculateMachineStatusCountsFromFiltered-->filtered Data: '+JSON.stringify(this.filteredData));
      console.log('>>>>businessCaseDashboard-->calculateMachineStatusCountsFromFiltered-->filtered Machine Data: '+JSON.stringify(this.filteredMachineStatusCountList));
      

      this.filteredMachineStatusCountList.forEach((record) => {
        const status = record.machineInstallationStatus || "Unknown";

        // Count each business case only once per status
        if (!statusMap.has(status)) {
          statusMap.set(status, new Set());
        }

        // if (record.businessCaseId) {
        //   statusMap.get(status).add(record.businessCaseId);
        // }
        if (record.id) {
          statusMap.get(status).add(record.id);
        }
      });

      console.log('>>>>businessCaseDashboard-->calculateMachineStatusCountsFromFiltered-->filtered Data Status Map: '+JSON.stringify(statusMap));

      // Store in separate calculated property (not overwriting wire data)
      this.calculatedMachineStatusCounts = Array.from(statusMap.entries()).map(
        ([status, businessCases]) => ({
          status: status,
          count: businessCases.size
        })
      );

      console.log('>>>>businessCaseDashboard-->calculateMachineStatusCountsFromFiltered-->filtered Data calculatedMachineStatusCounts: '+JSON.stringify(this.calculatedMachineStatusCounts));

      // console.log("ðŸ”§ Machine Status Counts calculated from filtered data:", {
      //   counts: this.calculatedMachineStatusCounts,
      //   recordsProcessed: this.filteredData.length
      // });
    } catch (error) {
      console.error("âŒ Error in calculateMachineStatusCountsFromFiltered:", {
        message: error.message,
        stack: error.stack
      });
      // Initialize with empty array as fallback
      this.calculatedMachineStatusCounts = [];
    }
  }

  // Getter to conditionally use wire data or calculated data
  get displayMachineStatusCounts() {
    // Use calculated data if any filters are active (customers or regions selected)
    return this.hasActiveFilters
      ? this.calculatedMachineStatusCounts
      : this.machineStatusCounts;
  }

  aggregateByRegion() {
    console.log(
      "ðŸ” [Investment Performance] aggregateByRegion - Starting with",
      this.filteredData.length,
      "records"
    );

    let grandTotalInvestment = 0;

    const regionMap = new Map();

    this.filteredData.forEach((record) => {
      const region = record.region || "Unknown";

      grandTotalInvestment += record.investment;

      if (!regionMap.has(region)) {
        regionMap.set(region, {
          region: region,
          businessCases: new Set(), // Track unique business cases
          totalMachineCount: 0, // Sum of machine counts
          investment: 0,
          totalSales: 0,
          marginOnSales: 0,
          commitmentPerMonth: 0,
          avgSalesPerMonth: 0,
          uniqueInvestments: new Set(), // Track unique investments per business case
          monthlyTargets: new Map(), // Track targets per month
          monthlySales: new Map(), // Track sales per month
          // Track latest snapshot for each region for proper avg calculation
          latestSnapshot: null,
          latestSnapshotMonth: null,
          ytdsales:0,
          avgYtdSales:0,
          lastYearYtdsales:0,
          lastToLastYearYtdsales:0,
          lastSixMonthlySales:{}
        });
      }

      const regionData = regionMap.get(region);

      // Only count each business case once for machine count and investment
      if (record.businessCaseId && record.machineCount > 0) {
        if (!regionData.businessCases.has(record.businessCaseId)) {
          regionData.businessCases.add(record.businessCaseId);
          regionData.totalMachineCount += record.machineCount || 0;

          // Track unique investment per business case to avoid double counting
          const investmentKey = `${record.businessCaseId}`;
          if (!regionData.uniqueInvestments.has(investmentKey)) {
            regionData.uniqueInvestments.add(investmentKey);
            // regionData.investment += record.investment || 0;
            console.log(
              `  ðŸ’° [Investment Performance] ${region}: Adding investment ${record.investment} for BC ${record.businessCaseId}`
            );
          }
        }
      }

      // Accumulate total sales and margins across all records
      // Use totalReagentSalesTillDate for cumulative sales from contract start (not monthly)
      regionData.investment += record.investment || 0;
      regionData.totalSales += record.totalReagentSalesTillDate || 0;
      regionData.marginOnSales += record.marginTillDate || 0;
      console.log('>>>>aggregateByRegion-->grandTotalInvestment-->regionData.marginOnSales -->'+JSON.stringify(regionData.marginOnSales));
      regionData.ytdsales += record.ytdSales;
      regionData.avgYtdSales += record.avgYtdSales;
      regionData.lastYearYtdsales += record.lastYearYtdSales || 0;
      regionData.lastToLastYearYtdsales += record.lastToLastYearYtdSales || 0;
      // regionData.lastSixMonthlySales = record.monthlySales;
      if (record.monthlySales && typeof record.monthlySales === 'object') 
      {
        Object.entries(record.monthlySales).forEach(([month, value]) => {
          const numericValue = this.safeParseNumber(value);
          if (!isNaN(numericValue)) {
            // Initialize month key if missing
            if (!regionData.lastSixMonthlySales[month]) {
              regionData.lastSixMonthlySales[month] = 0;
            }
            // Accumulate monthly totals
            regionData.lastSixMonthlySales[month] += numericValue;
          }
        });
      }

      // Track monthly targets and sales to calculate proper averages
      const monthKey = record.snapshotMonth || "Unknown";
      if (record.targetSales && record.targetSales > 0) {
        regionData.monthlyTargets.set(monthKey, record.targetSales);
      }
      // Use totalReagentSales for monthly performance instead of avgReagentSalesPerMonth
      // avgReagentSalesPerMonth is a cumulative average, not the actual month's sales
      if (record.totalReagentSales && record.totalReagentSales > 0) {
        regionData.monthlySales.set(monthKey, record.totalReagentSales);
      }

      // Track latest snapshot to get the correct avgReagentSalesPerMonth
      if (
        !regionData.latestSnapshotMonth ||
        monthKey > regionData.latestSnapshotMonth
      ) {
        regionData.latestSnapshot = record;
        regionData.latestSnapshotMonth = monthKey;
      }
    });

    console.log('>>>>aggregateByRegion-->grandTotalInvestment-->'+JSON.stringify(grandTotalInvestment));

    return Array.from(regionMap.values())
      .map((region) => {
        // Calculate proper monthly averages
        const targetValues = Array.from(region.monthlyTargets.values());

        region.commitmentPerMonth =
          targetValues.length > 0
            ? targetValues.reduce((sum, val) => sum + val, 0) /
              targetValues.length
            : 0;

        // Use avgReagentSalesPerMonth from the latest snapshot instead of calculating
        region.avgSalesPerMonth =
          region.latestSnapshot?.avgReagentSalesPerMonth || 0;

        const performanceStatus = this.getPerformanceStatus(
          region.avgSalesPerMonth,
          region.commitmentPerMonth
        );

        // console.log(
        //   "Final Investment cost Recovery Percent params: Total Sales: " +
        //     region.totalSales +
        //     " , Total Investment: " +
        //     region.investment
        // );

        const monthSalesFlat = {};
        if (region.lastSixMonthlySales) {
          for (const [month, value] of Object.entries(region.lastSixMonthlySales)) 
          {
            const fieldKey = month.replace(' ', '_'); // "Apr_2026" â€” must match column fieldName
            monthSalesFlat[fieldKey] = this.formatCurrency(value);
          }
        }

        const lastMonthAvgRaw = (() => {
          const vals = region.lastSixMonthlySales
            ? Object.values(region.lastSixMonthlySales).filter(v => v !== null && !isNaN(v))
            : [];
          return vals.length > 0 ? vals.reduce((s, v) => s + Number(v), 0) / vals.length : 0;
        })();

        var finalrecord = {
          ...region,
          ...monthSalesFlat,
          machines: region.totalMachineCount,
          formattedInvestment: this.formatCurrency(region.investment),
          formattedTotalSales: this.formatCurrency(region.totalSales),
          formattedPerMachineSales: this.formatCurrency(
            region.totalMachineCount > 0
              ? region.totalSales / region.totalMachineCount
              : 0
          ),
          formattedMargin: this.formatCurrency(region.marginOnSales),
          formattedYtdSales: this.formatCurrency(region.ytdsales),
          formattedLastYearYtdSales: this.formatCurrency(region.lastYearYtdsales),
          formattedLastToLastYearYtdSales: this.formatCurrency(region.lastToLastYearYtdsales),
          costRecoveryPercent: this.formatPercent(
            this.safeCalculatePercent(region.totalSales, region.investment)
          ),
          investmentSharePercent: this.calculateInvestmentShareUpdated(
            region.investment,
            grandTotalInvestment
          ),
          achievementPercent: this.formatPercent(
            this.safeCalculatePercent(
              region.avgSalesPerMonth,
              region.commitmentPerMonth
            )
          ),
          formattedCommitment: this.formatCurrency(region.commitmentPerMonth),
          formattedAvgSales: this.formatCurrency(region.avgSalesPerMonth),
          performanceStatus: performanceStatus,
          statusClass: this.getStatusClass(performanceStatus),
          lastMonthAvg: this.formatCurrency(lastMonthAvgRaw),
          lastMonthAvgCommitPercent: this.formatPercent(
            this.safeCalculatePercent(lastMonthAvgRaw, region.commitmentPerMonth)
          )
        };
        console.log('>>>>aggregateByRegion-->final record-->'+JSON.stringify(finalrecord));
        return finalrecord;
      })
      .concat(this.calculateRegionGrandTotal(Array.from(regionMap.values())));
  }

  calculateRegionGrandTotal(regions) {
    if (!regions || regions.length === 0) return [];

    console.log(
      "ðŸ” [Investment Performance] Calculating grand total from",
      regions.length,
      "regions"
    );

    const grandTotal = {
      region: "Grand Total",
      totalMachineCount: 0,
      investment: 0,
      totalSales: 0,
      marginOnSales: 0,
      ytdsales : 0,
      avgYtdSales:0,
      lastYearYtdsales: 0,
      lastToLastYearYtdsales: 0,
      commitmentPerMonth: 0,
      lastSixMonthlySales: {},
      rowClass: "slds-text-title_bold slds-theme_shade"
    };

    regions.forEach((region) => {
      grandTotal.totalMachineCount += region.totalMachineCount || 0;
      grandTotal.investment += region.investment || 0;
      console.log(
        `  ðŸ’° [Investment Performance] ${region.region}: investment=${region.investment}`
      );
      grandTotal.totalSales += region.totalSales || 0;
      grandTotal.marginOnSales += region.marginOnSales || 0;
      grandTotal.ytdsales += region.ytdsales || 0;
      grandTotal.avgYtdSales += region.avgYtdSales || 0;
      grandTotal.lastYearYtdsales += region.lastYearYtdsales || 0;
      grandTotal.lastToLastYearYtdsales += region.lastToLastYearYtdsales || 0;
      grandTotal.commitmentPerMonth += region.commitmentPerMonth || 0;

      if (region.lastSixMonthlySales) 
      {
        for (const [monthLabel, value] of Object.entries(region.lastSixMonthlySales)) {
          if (!grandTotal.lastSixMonthlySales[monthLabel]) {
            grandTotal.lastSixMonthlySales[monthLabel] = 0;
          }
          grandTotal.lastSixMonthlySales[monthLabel] += value || 0;
        }
      }
    });

    const gtRegVals = Object.values(grandTotal.lastSixMonthlySales).filter(v => v !== null && !isNaN(v));
    const gtRegLastMonthAvgRaw = gtRegVals.length > 0 ? gtRegVals.reduce((s, v) => s + Number(v), 0) / gtRegVals.length : 0;

    const totalrecord =
      {
        ...grandTotal,
        machines: grandTotal.totalMachineCount,
        formattedInvestment: this.formatCurrency(grandTotal.investment),
        formattedTotalSales: this.formatCurrency(grandTotal.totalSales),
        formattedMargin: this.formatCurrency(grandTotal.marginOnSales),
        formattedYtdSales : this.formatCurrency(grandTotal.ytdsales),
        formattedLastYearYtdSales: this.formatCurrency(grandTotal.lastYearYtdsales),
        formattedLastToLastYearYtdSales: this.formatCurrency(grandTotal.lastToLastYearYtdsales),
        costRecoveryPercent: this.formatPercent(
          this.safeCalculatePercent(
            grandTotal.totalSales,
            grandTotal.investment
          )
        ),
        investmentSharePercent: "100.00%",
        lastMonthAvg: this.formatCurrency(gtRegLastMonthAvgRaw),
        lastMonthAvgCommitPercent: this.formatPercent(
          this.safeCalculatePercent(gtRegLastMonthAvgRaw, grandTotal.commitmentPerMonth)
        )
      }
    ;

    for (const [monthLabel, value] of Object.entries(grandTotal.lastSixMonthlySales)) {
      totalrecord[monthLabel] = this.formatCurrency(value || 0);
    }

    console.log('>>>>businessCaseDashboard-->calculateRegionGrandTotal-->totalrecord: '+JSON.stringify(totalrecord));

    return [totalrecord];
  }

  aggregateBySupplier() {
    const supplierMap = new Map();

    let grandTotalInvestment = 0;

    this.filteredData.forEach((record) => {
      const supplier = record.vendor || "Unknown";

      grandTotalInvestment += record.investment;

      if (!supplierMap.has(supplier)) {
        supplierMap.set(supplier, {
          supplier: supplier,
          businessCases: new Set(), // Track unique business cases
          totalMachineCount: 0, // Sum of machine counts
          investment: 0,
          totalSales: 0,
          marginOnSales: 0,
          commitmentPerMonth: 0,
          avgSalesPerMonth: 0,
          uniqueInvestments: new Set(), // Track unique investments per business case
          monthlyTargets: new Map(), // Track targets per month
          monthlySales: new Map(), // Track sales per month
          // Track latest snapshot for each supplier for proper avg calculation
          latestSnapshot: null,
          latestSnapshotMonth: null,
          ytdsales:0,
          avgYtdSales:0,
          lastYearYtdsales:0,
          lastToLastYearYtdsales:0,
          lastSixMonthlySales:{}
        });
      }



      const supplierData = supplierMap.get(supplier);

      console.log('>>>>businessCaseDashboard-->aggregateBySupplier-->supplierData: '+JSON.stringify(supplierData));

      // Only count each business case once for machine count and investment
      if (record.businessCaseId && record.machineCount > 0) {
        if (!supplierData.businessCases.has(record.businessCaseId)) {
          supplierData.businessCases.add(record.businessCaseId);
          supplierData.totalMachineCount += record.machineCount || 0;

          // Track unique investment per business case to avoid double counting
          const investmentKey = `${record.businessCaseId}`;
          if (!supplierData.uniqueInvestments.has(investmentKey)) {
            supplierData.uniqueInvestments.add(investmentKey);
            // supplierData.investment += record.investment || 0;
          }
        }
      }

      // Accumulate total sales and margins across all records
      // Use totalReagentSalesTillDate for cumulative sales from contract start (not monthly)
      supplierData.investment += record.investment || 0;
      supplierData.totalSales += record.totalReagentSalesTillDate || 0;
      // console.log(
      //   "Supplier Investment Record: supplierData.totalSales: " +
      //     supplierData.totalSales +
      //     " , vendor:" +
      //     record.vendor
      // );
      supplierData.marginOnSales += record.marginTillDate || 0;
      supplierData.ytdsales += record.ytdSales;
      supplierData.avgYtdSales += record.avgYtdSales;
      supplierData.lastYearYtdsales += record.lastYearYtdSales || 0;
      supplierData.lastToLastYearYtdsales += record.lastToLastYearYtdSales || 0;
      supplierData.lastSixMonthlySales = record.monthlySales;
      // Track monthly targets and sales to calculate proper averages
      const monthKey = record.snapshotMonth || "Unknown";
      if (record.targetSales && record.targetSales > 0) {
        supplierData.monthlyTargets.set(monthKey, record.targetSales);
      }
      // Use totalReagentSales for monthly performance instead of avgReagentSalesPerMonth
      // avgReagentSalesPerMonth is a cumulative average, not the actual month's sales
      if (record.totalReagentSales && record.totalReagentSales > 0) {
        supplierData.monthlySales.set(monthKey, record.totalReagentSales);
      }

      // Track latest snapshot to get the correct avgReagentSalesPerMonth
      if (
        !supplierData.latestSnapshotMonth ||
        monthKey > supplierData.latestSnapshotMonth
      ) {
        supplierData.latestSnapshot = record;
        supplierData.latestSnapshotMonth = monthKey;
      }
    });

    return Array.from(supplierMap.values())
      .map((supplier) => {
        // Calculate proper monthly averages
        const targetValues = Array.from(supplier.monthlyTargets.values());

        supplier.commitmentPerMonth =
          targetValues.length > 0
            ? targetValues.reduce((sum, val) => sum + val, 0) /
              targetValues.length
            : 0;

        // Use avgReagentSalesPerMonth from the latest snapshot instead of calculating
        supplier.avgSalesPerMonth =
          supplier.latestSnapshot?.avgReagentSalesPerMonth || 0;

        const performanceStatus = this.getPerformanceStatus(
          supplier.avgSalesPerMonth,
          supplier.commitmentPerMonth
        );

        const monthSalesFlat = {};
        if (supplier.lastSixMonthlySales) {
          for (const [month, value] of Object.entries(supplier.lastSixMonthlySales)) 
          {
            const fieldKey = month.replace(' ', '_'); // "Apr_2026" â€” must match column fieldName
            monthSalesFlat[fieldKey] = this.formatCurrency(value);
          }
        }

        const supLastMonthAvgRaw = (() => {
          const vals = supplier.lastSixMonthlySales
            ? Object.values(supplier.lastSixMonthlySales).filter(v => v !== null && !isNaN(v))
            : [];
          return vals.length > 0 ? vals.reduce((s, v) => s + Number(v), 0) / vals.length : 0;
        })();

        var finalrecord = {
          ...supplier,
          ...monthSalesFlat,
          machines: supplier.totalMachineCount,
          formattedInvestment: this.formatCurrency(supplier.investment),
          formattedTotalSales: this.formatCurrency(supplier.totalSales),
          formattedPerMachineSales: this.formatCurrency(
            supplier.totalMachineCount > 0
              ? supplier.totalSales / supplier.totalMachineCount
              : 0
          ),
          formattedMargin: this.formatCurrency(supplier.marginOnSales),
          formattedYtdSales: this.formatCurrency(supplier.ytdsales),
          formattedLastYearYtdSales: this.formatCurrency(supplier.lastYearYtdsales),
          formattedLastToLastYearYtdSales: this.formatCurrency(supplier.lastToLastYearYtdsales),
          costRecoveryPercent: this.formatPercent(
            this.safeCalculatePercent(supplier.totalSales, supplier.investment)
          ),
          investmentSharePercent: this.calculateInvestmentShareUpdated(
            supplier.investment,
            grandTotalInvestment
          ),
          achievementPercent: this.formatPercent(
            this.safeCalculatePercent(
              supplier.avgSalesPerMonth,
              supplier.commitmentPerMonth
            )
          ),
          formattedCommitment: this.formatCurrency(supplier.commitmentPerMonth),
          formattedAvgSales: this.formatCurrency(supplier.avgSalesPerMonth),
          performanceStatus: performanceStatus,
          statusClass: this.getStatusClass(performanceStatus),
          lastMonthAvg: this.formatCurrency(supLastMonthAvgRaw),
          lastMonthAvgCommitPercent: this.formatPercent(
            this.safeCalculatePercent(supLastMonthAvgRaw, supplier.commitmentPerMonth)
          )
        };



        return finalrecord;
      })
      .concat(
        this.calculateSupplierGrandTotal(Array.from(supplierMap.values()))
      );
  }

  calculateSupplierGrandTotal(suppliers) {
    if (!suppliers || suppliers.length === 0) return [];

    const grandTotal = {
      supplier: "Grand Total",
      totalMachineCount: 0,
      investment: 0,
      totalSales: 0,
      marginOnSales: 0,
      ytdsales : 0,
      avgYtdSales:0,
      lastYearYtdsales: 0,
      lastToLastYearYtdsales: 0,
      commitmentPerMonth: 0,
      lastSixMonthlySales: {},
      rowClass: "slds-text-title_bold slds-theme_shade"
    };

    suppliers.forEach((supplier) => {
      grandTotal.totalMachineCount += supplier.totalMachineCount || 0;
      grandTotal.investment += supplier.investment || 0;
      grandTotal.totalSales += supplier.totalSales || 0;
      grandTotal.marginOnSales += supplier.marginOnSales || 0;
      grandTotal.ytdsales += supplier.ytdsales || 0;
      grandTotal.avgYtdSales += supplier.avgYtdSales || 0;
      grandTotal.lastYearYtdsales += supplier.lastYearYtdsales || 0;
      grandTotal.lastToLastYearYtdsales += supplier.lastToLastYearYtdsales || 0;
      grandTotal.commitmentPerMonth += supplier.commitmentPerMonth || 0;

      if (supplier.lastSixMonthlySales) 
      {
        for (const [monthLabel, value] of Object.entries(supplier.lastSixMonthlySales)) {
          if (!grandTotal.lastSixMonthlySales[monthLabel]) {
            grandTotal.lastSixMonthlySales[monthLabel] = 0;
          }
          grandTotal.lastSixMonthlySales[monthLabel] += value || 0;
        }
      }
    });

    const gtSupVals = Object.values(grandTotal.lastSixMonthlySales).filter(v => v !== null && !isNaN(v));
    const gtSupLastMonthAvgRaw = gtSupVals.length > 0 ? gtSupVals.reduce((s, v) => s + Number(v), 0) / gtSupVals.length : 0;

    const totalrecord =
      {
        ...grandTotal,
        machines: grandTotal.totalMachineCount,
        formattedInvestment: this.formatCurrency(grandTotal.investment),
        formattedTotalSales: this.formatCurrency(grandTotal.totalSales),
        formattedMargin: this.formatCurrency(grandTotal.marginOnSales),
        costRecoveryPercent: this.formatPercent(
          this.safeCalculatePercent(
            grandTotal.totalSales,
            grandTotal.investment
          )
        ),
        investmentSharePercent: "100.00%",
        formattedYtdSales : this.formatCurrency(grandTotal.ytdsales),
        formattedLastYearYtdSales: this.formatCurrency(grandTotal.lastYearYtdsales),
        formattedLastToLastYearYtdSales: this.formatCurrency(grandTotal.lastToLastYearYtdsales),
        lastMonthAvg: this.formatCurrency(gtSupLastMonthAvgRaw),
        lastMonthAvgCommitPercent: this.formatPercent(
          this.safeCalculatePercent(gtSupLastMonthAvgRaw, grandTotal.commitmentPerMonth)
        )
      }
    ;

    for (const [monthLabel, value] of Object.entries(grandTotal.lastSixMonthlySales)) {
      totalrecord[monthLabel] = this.formatCurrency(value || 0);
    }

    return [totalrecord];
  }

  // ===== COMMITMENT-SPECIFIC AGGREGATION METHODS =====

  aggregateCommitmentByRegion() 
  {
    console.log(
      "ðŸ” [Commitment Performance] aggregateCommitmentByRegion - Starting with",
      this.filteredData.length,
      "records"
    );

    const regionMap = new Map();

    this.filteredData.forEach((record, index) => 
    {
      console.log('>>>>businessCaseDashboard-->aggregateCommitmentByRegion-->record-->'+JSON.stringify(record ));
      const region = record.region || "Unknown";

      if (!regionMap.has(region)) {
        regionMap.set(region, {
          region: region,
          businessCases: new Set(),
          totalMachineCount: 0,
          investment: 0,
          totalSales: 0, // Use for current period sales
          totalCommitment: 0, // Use for current period commitments
          allMonthlySales: [], // Track all monthly sales for proper averaging
          allMonthlyTargets: [], // Track all monthly targets for proper averaging
          allAvgSalesPerMonth: [], // Track avg sales per month values
          customerCount: new Set(), // Count unique customers in this region
          recordCount: 0,
          uniqueInvestments: new Set(), // Track unique investments per business case
          lastSixMonthlySales:{},
          avgReagentSalesPerMonth : 0,
          monthlycommitment:0,
		      avgSalesPerMonth: 0
        });
      }

      const regionData = regionMap.get(region);

      // Only count each business case once for machine count and investment
      if (record.businessCaseId && record.machineCount > 0) {
        if (!regionData.businessCases.has(record.businessCaseId)) {
          regionData.businessCases.add(record.businessCaseId);
          regionData.totalMachineCount += record.machineCount || 0;

          // Track unique investment per business case to avoid double counting
          const investmentKey = `${record.businessCaseId}`;
          if (!regionData.uniqueInvestments.has(investmentKey)) {
            regionData.uniqueInvestments.add(investmentKey);
            // regionData.investment += record.investment || 0;
            console.log(
              `  ðŸ’° [Commitment Performance] ${region}: Adding investment ${record.investment} for BC ${record.businessCaseId}`
            );
          }
        }
      }

      // Track unique customers
      if (record.customerCode) {
        regionData.customerCount.add(record.customerCode);
      }

      // Aggregate monthly sales and targets for proper commitment analysis
      // Try multiple field variations to capture all data and ensure valid numbers
	  regionData.investment += record.investment || 0;
      const salesValue =
        record.totalReagentSales ||
        record.avgReagentSalesPerMonth ||
        record.totalReagentSalesTillDate ||
        0;
      const monthlySales = this.safeParseNumber(salesValue);

      const targetValue =
        record.targetSales || record.commitmentPerMonth || record.target || 0;
      const monthlyTarget = this.safeParseNumber(targetValue);

      // Track avg reagent sales per month separately
      const avgSalesValue = record.avgReagentSalesPerMonth || 0;
      
      regionData.allAvgSalesPerMonth.push(this.safeParseNumber(avgSalesValue));

      regionData.avgReagentSalesPerMonth += parseFloat( record.avgReagentSalesPerMonth || 0);

      console.log('>>>>businessCaseDashboard-->aggregateCommitmentByRegion-->record.avgReagentSalesPerMonth,regionData.avgReagentSalesPerMonth:  '+record.avgReagentSalesPerMonth+' | '+regionData.avgReagentSalesPerMonth);

      // Always add the sales value (even if 0) to ensure proper counting
      regionData.allMonthlySales.push(monthlySales);
      regionData.totalSales += record.totalReagentSalesTillDate || 0;

      // Always add the target value (even if 0) to ensure proper counting
      regionData.allMonthlyTargets.push(monthlyTarget);
      regionData.totalCommitment += monthlyTarget;

      //regionData.lastSixMonthlySales = record.monthlySales;	

      if (record.monthlySales && typeof record.monthlySales === 'object') 
      {
        Object.entries(record.monthlySales).forEach(([month, value]) => {
          const numericValue = this.safeParseNumber(value);
          if (!isNaN(numericValue)) {
            // Initialize month key if missing
            if (!regionData.lastSixMonthlySales[month]) {
              regionData.lastSixMonthlySales[month] = 0;
            }
            // Accumulate monthly totals
            regionData.lastSixMonthlySales[month] += numericValue;
          }
        });
      }

      regionData.recordCount++;

      // Debug specific region
      if (region === "South" && index < 5) {
        // console.log(`ðŸ” DEBUG: South Region Record ${index + 1}:`, {
        //   customerCode: record.customerCode,
        //   monthlySales: monthlySales,
        //   monthlyTarget: monthlyTarget,
        //   currentTotalSales: regionData.totalSales,
        //   currentTotalCommitment: regionData.totalCommitment,
        //   salesArrayLength: regionData.allMonthlySales.length,
        //   targetsArrayLength: regionData.allMonthlyTargets.length
        // });
      }
    });

    // console.log(
    //   "ðŸ” DEBUG: Region aggregation completed, processing results..."
    // );
    // console.log("ðŸ” DEBUG: Number of regions found:", regionMap.size);

    return Array.from(regionMap.values()).map((region) => {
      // Calculate proper averages for commitment analysis
      // const validSales = region.allMonthlySales.filter(
      //   (val) => !isNaN(val) && val !== null && val !== undefined
      // );
      // const SalesPerMonth =
      //   validSales.length > 0
      //     ? validSales.reduce((sum, val) => sum + Number(val), 0) /
      //       validSales.length
      //     : 0;

      // Calculate average of Avg_Reagent_Sales_Per_Month__c field
      // const validAvgSales = region.allAvgSalesPerMonth.filter(
      //   (val) => !isNaN(val) && val !== null && val !== undefined
      // );
      // const avgSalesPerMonth =
      //   validAvgSales.length > 0
      //     ? validAvgSales.reduce((sum, val) => sum + Number(val), 0) /
      //       validAvgSales.length
      //     : 0;
		
		
		  // region.avgSalesPerMonth = region.avgReagentSalesPerMonth;
          // region.latestSnapshot?.avgReagentSalesPerMonth || 0;
		  
		  
      const validTargets = region.allMonthlyTargets.filter(
        (val) => !isNaN(val) && val !== null && val !== undefined
      );

      console.log('>>>>businessCaseDashboard-->aggregateCommitmentByRegion-->validTargets:  '+JSON.stringify(validTargets));

      const avgCommitmentPerMonth =
        validTargets.length > 0
          ? validTargets.reduce((sum, val) => sum + Number(val), 0) /
            validTargets.length
          : 0;

      console.log('>>>>businessCaseDashboard-->aggregateCommitmentByRegion-->avgCommitmentPerMonth:  '+JSON.stringify(avgCommitmentPerMonth));

      const performanceStatus = this.getPerformanceStatus(
        region.avgReagentSalesPerMonth,
        avgCommitmentPerMonth
      );

      const allaveragesalespermonthsum = region.allAvgSalesPerMonth.reduce(
        (sum, value) => sum + (Number(value) || 0),
        0
      );

       console.log('>>>>businessCaseDashboard-->aggregateCommitmentByRegion-->performanceStatus:  '+JSON.stringify(performanceStatus));

      console.log('>>>>businessCaseDashboard-->aggregateCommitmentByRegion-->lastSixMonthlySales:  '+JSON.stringify(region.lastSixMonthlySales));

      const monthSalesFlat = {};
      if (region.lastSixMonthlySales) {
        for (const [month, value] of Object.entries(region.lastSixMonthlySales))
        {
          const fieldKey = month.replace(' ', '_'); // "Apr_2026" â€” must match column fieldName
          monthSalesFlat[fieldKey] = this.formatCurrency(value);
        }
      }

      const monthlySalesValues = region.lastSixMonthlySales
        ? Object.values(region.lastSixMonthlySales).filter(v => v !== null && !isNaN(v))
        : [];
      const lastMonthAvgValue = monthlySalesValues.length > 0
        ? monthlySalesValues.reduce((sum, v) => sum + Number(v), 0) / monthlySalesValues.length
        : 0;

      console.log('>>>>businessCaseDashboard-->aggregateCommitmentByRegion-->monthSalesFlat:  '+JSON.stringify(monthSalesFlat));

      // const achievePercent = (region.avgReagentSalesPerMonth / avgCommitmentPerMonth) ;

      const result = {
        ...monthSalesFlat,
        region: region.region,
        machines: region.totalMachineCount,
        investment: region.investment,
        customerCount: region.customerCount.size,
        recordCount: region.recordCount,
        // monthlySales: SalesPerMonth,
        avgReagentSalesPerMonth: region.avgReagentSalesPerMonth,
        commitmentPerMonth: avgCommitmentPerMonth,
        achievementPercent: this.formatPercent(
          this.safeCalculatePercent(
            //region.avgReagentSalesPerMonth,
            region.avgReagentSalesPerMonth,
            avgCommitmentPerMonth
          )
          // achievePercent
        ),
        formattedInvestment: this.formatCurrency(region.investment),
        formattedCommitment: this.formatCurrency(region.totalCommitment),
        // formattedMonthlySales: this.formatCurrency(avgSalesPerMonth),
        formattedAvgSales: this.formatCurrency(
         region.avgReagentSalesPerMonth
         // allaveragesalespermonthsum
        ),
        allAvgSalesPerMonth : allaveragesalespermonthsum,
        totalCommitment: region.totalCommitment,
        lastMonthAvg: this.formatCurrency(lastMonthAvgValue)
        // performanceStatus: performanceStatus,
        // statusClass: this.getStatusClass(performanceStatus)

      };

      console.log('>>>>businessCaseDashboard-->aggregateCommitmentByRegion-->result:  '+JSON.stringify(result));

      // Debug results for specific regions
      if (region.region === "South") {
        // console.log("ðŸ” DEBUG: South Region Final Result:", {
        //   region: result.region,
        //   recordCount: result.recordCount,
        //   salesArrayLength: region.allMonthlySales.length,
        //   targetsArrayLength: region.allMonthlyTargets.length,
        //   totalSalesSum: region.totalSales,
        //   totalCommitmentSum: region.totalCommitment,
        //   avgSalesPerMonth: result.avgSalesPerMonth,
        //   commitmentPerMonth: result.commitmentPerMonth,
        //   formattedAvgSales: result.formattedAvgSales,
        //   formattedCommitment: result.formattedCommitment,
        //   achievementPercent: result.achievementPercent,
        //   performanceStatus: result.performanceStatus
        // });
      }

      return result;
    }).concat(
      this.calculateCommitmentRegionGrandTotal(Array.from(regionMap.values()))
    );
  }

  calculateCommitmentRegionGrandTotal(regions) {
    if (!regions || regions.length === 0) return [];

    console.log(
      "ðŸ” [Commitment Performance] Calculating grand total from",
      regions.length,
      "regions"
    );

    const grandTotal = {
      region: "Grand Total",
      totalMachineCount: 0,
      investment: 0,
      totalSales: 0,
      totalCommitment: 0,
      allAvgSalesPerMonth: [],
      allMonthlySales: [],
      allMonthlyTargets: [],
      lastSixMonthlySales:{},
      avgMonthSalesPerMonth:0,
      totalmontlycommitment:0,
      rowClass: "slds-text-title_bold slds-theme_shade"
    };

    regions.forEach((region) => {
      grandTotal.totalMachineCount += region.totalMachineCount || 0;
      grandTotal.investment += region.investment || 0;
      console.log(
        `  ðŸ’° [Commitment Performance] ${region.region}: investment=${region.investment}`
      );
      grandTotal.allAvgSalesPerMonth.push(
        ...(region.allAvgSalesPerMonth || [])
      );
      grandTotal.allMonthlySales.push(...(region.allMonthlySales || []));
      grandTotal.allMonthlyTargets.push(...(region.allMonthlyTargets || []));
      grandTotal.avgMonthSalesPerMonth += region.avgReagentSalesPerMonth;
      grandTotal.totalmontlycommitment += region.totalCommitment;
      if (region.lastSixMonthlySales) 
      {
        for (const [monthLabel, value] of Object.entries(region.lastSixMonthlySales)) 
          {
          if (!grandTotal.lastSixMonthlySales[monthLabel]) {
            grandTotal.lastSixMonthlySales[monthLabel] = 0;
          }
          grandTotal.lastSixMonthlySales[monthLabel] += value || 0;
        }
      } 

    });

    console.log('>>>>businessCaseDashboard-->calculateCommitmentRegionGrandTotal-->grandTotal: '+JSON.stringify(grandTotal));

    // Calculate averages for grand total
    const validAvgSales = grandTotal.allAvgSalesPerMonth.filter(
      (val) => !isNaN(val) && val !== null && val !== undefined
    );
    const avgReagentSalesPerMonth =
      validAvgSales.length > 0
        ? validAvgSales.reduce((sum, val) => sum + Number(val), 0) /
          validAvgSales.length
        : 0;

    console.log('>>>>businessCaseDashboard-->calculateCommitmentRegionGrandTotal-->grandTotal avgReagentSalesPerMonth: '+JSON.stringify(avgReagentSalesPerMonth));

    const validMonthlySales = grandTotal.allMonthlySales.filter(
      (val) => !isNaN(val) && val !== null && val !== undefined
    );
    const avgMonthlySales =
      validMonthlySales.length > 0
        ? validMonthlySales.reduce((sum, val) => sum + Number(val), 0) /
          validMonthlySales.length
        : 0;

    const validTargets = grandTotal.allMonthlyTargets.filter(
      (val) => !isNaN(val) && val !== null && val !== undefined
    );
    const avgCommitment =
      validTargets.length > 0
        ? validTargets.reduce((sum, val) => sum + Number(val), 0) /
          validTargets.length
        : 0;

    const grandtotalavgMonthlySales =
      validMonthlySales.length > 0
        ? validMonthlySales.reduce((sum, val) => sum + Number(val), 0) /
          validMonthlySales.length
        : 0;

    // const grandtotalachievepercent = (grandTotal.avgMonthSalesPerMonth/ avgCommitment);

    const totalrecord = {
        ...grandTotal,
        machines: grandTotal.totalMachineCount,
        formattedInvestment: this.formatCurrency(grandTotal.investment),
        formattedCommitment: this.formatCurrency(grandTotal.totalmontlycommitment),
        formattedMonthlySales: this.formatCurrency(avgMonthlySales),
        formattedAvgSales: this.formatCurrency(grandTotal.avgMonthSalesPerMonth),
        achievementPercent: this.formatPercent(
          this.safeCalculatePercent(grandTotal.avgMonthSalesPerMonth, avgCommitment)
          // grandtotalachievepercent
        )
      };

    for (const [monthLabel, value] of Object.entries(grandTotal.lastSixMonthlySales))
    {
      totalrecord[monthLabel] = this.formatCurrency(value || 0);
    }

    const gtMonthlySalesValues = Object.values(grandTotal.lastSixMonthlySales).filter(v => v !== null && !isNaN(v));
    totalrecord.lastMonthAvg = this.formatCurrency(
      gtMonthlySalesValues.length > 0
        ? gtMonthlySalesValues.reduce((sum, v) => sum + Number(v), 0) / gtMonthlySalesValues.length
        : 0
    );

    console.log('>>>>businessCaseDashboard-->calculateCommitmentRegionGrandTotal-->totalrecord: '+JSON.stringify(totalrecord));

    return [totalrecord];
  }

  aggregateCommitmentBySupplier() 
  {
    // console.log("ðŸ” DEBUG: Starting aggregateCommitmentBySupplier()");

    const supplierMap = new Map();

    this.filteredData.forEach((record) => {
      const supplier = record.vendor || "Unknown";
      console.log('>>>>businessCaseDashboard-->aggregateCommitmentBySupplier-->record: '+JSON.stringify(record));
      if (!supplierMap.has(supplier)) {
        supplierMap.set(supplier, {
          supplier: supplier,
          businessCases: new Set(),
          totalMachineCount: 0,
          investment: 0,
          totalSales: 0,
          totalCommitment: 0,
          allMonthlySales: [],
          allMonthlyTargets: [],
          allAvgSalesPerMonth: [],
          customerCount: new Set(),
          recordCount: 0,
          lastSixMonthlySales:{},
          uniqueInvestments: new Set(),
          avgMonthlySalesPerMonth : 0,
          monthlycommitment:0
        });
      }

      const supplierData = supplierMap.get(supplier);

      // Only count each business case once for machine count and investment
      if (record.businessCaseId && record.machineCount > 0) {
        if (!supplierData.businessCases.has(record.businessCaseId)) {
          supplierData.businessCases.add(record.businessCaseId);
          supplierData.totalMachineCount += record.machineCount || 0;

          // Track unique investment per business case to avoid double counting
          const investmentKey = `${record.businessCaseId}`;
          if (!supplierData.uniqueInvestments.has(investmentKey)) {
            supplierData.uniqueInvestments.add(investmentKey);
            // supplierData.investment += record.investment || 0;
          }
        }
      }

      // Track unique customers
      if (record.customerCode) {
        supplierData.customerCount.add(record.customerCode);
      }

      supplierData.investment += record.investment || 0;
      // Aggregate monthly sales and targets - improved field handling
      const salesValue =
        record.totalReagentSales ||
        record.avgReagentSalesPerMonth ||
        record.totalReagentSalesTillDate ||
        0;
      const monthlySales = this.safeParseNumber(salesValue);

      const targetValue =
        record.targetSales || record.commitmentPerMonth || record.target || 0;
      const monthlyTarget = this.safeParseNumber(targetValue);

      // Track avg reagent sales per month separately
      const avgSalesValue = record.avgReagentSalesPerMonth || 0;
      
      supplierData.allAvgSalesPerMonth.push(
        this.safeParseNumber(avgSalesValue)
      );

      // Always add the values to ensure proper counting
      supplierData.allMonthlySales.push(monthlySales);
      // supplierData.totalSales += monthlySales;
      supplierData.totalSales += record.totalReagentSalesTillDate ||
        0;
      supplierData.monthlycommitment += record.monthCommitment || 0;

      supplierData.allMonthlyTargets.push(monthlyTarget);
      supplierData.totalCommitment += monthlyTarget;
      // supplierData.totalCommitment += monthlyTarget;

      supplierData.lastSixMonthlySales = record.monthlySales;	
      supplierData.avgMonthlySalesPerMonth += parseFloat(record.avgReagentSalesPerMonth || 0) ;

      supplierData.recordCount++;
    });

    

    return Array.from(supplierMap.values())
      .map((supplier) => 
    {
      console.log('>>>>businessCaseDashboard-->aggregateCommitmentBySupplier-->supplier data: '+JSON.stringify(supplier));
        // Calculate proper averages for commitment analysis
        const validSales = supplier.allMonthlySales.filter(
          (val) => !isNaN(val) && val !== null && val !== undefined
        );
        const avgSalesPerMonth =
          validSales.length > 0
            ? validSales.reduce((sum, val) => sum + Number(val), 0) /
              validSales.length
            : 0;

        // Calculate average of Avg_Reagent_Sales_Per_Month__c field
        const validAvgSales = supplier.allAvgSalesPerMonth.filter(
          (val) => !isNaN(val) && val !== null && val !== undefined
        );
        // const avgReagentSalesPerMonth =
        //   validAvgSales.length > 0
        //     ? validAvgSales.reduce((sum, val) => sum + Number(val), 0) /
        //       validAvgSales.length
        //     : 0;

        const validTargets = supplier.allMonthlyTargets.filter(
          (val) => !isNaN(val) && val !== null && val !== undefined
        );
        const avgCommitmentPerMonth =
          validTargets.length > 0
            ? validTargets.reduce((sum, val) => sum + Number(val), 0) /
              validTargets.length
            : 0;

        const performanceStatus = this.getPerformanceStatus(
          supplier.avgMonthlySalesPerMonth,
          avgCommitmentPerMonth
        );

        const monthSalesFlat = {};
        if (supplier.lastSixMonthlySales) {
          for (const [month, value] of Object.entries(supplier.lastSixMonthlySales)) 
          {
            const fieldKey = month.replace(' ', '_'); // "Apr_2026" â€” must match column fieldName
            monthSalesFlat[fieldKey] = this.formatCurrency(value);
          }
        }

        const supplierachievepercent = (supplier.avgMonthlySalesPerMonth / avgCommitmentPerMonth);

        const supplierMonthVals = supplier.lastSixMonthlySales
          ? Object.values(supplier.lastSixMonthlySales).filter(v => v !== null && !isNaN(v))
          : [];
        const supplierLastMonthAvg = supplierMonthVals.length > 0
          ? supplierMonthVals.reduce((s, v) => s + Number(v), 0) / supplierMonthVals.length
          : 0;

        return {
          supplier: supplier.supplier,
          machines: supplier.totalMachineCount,
          investment: supplier.investment,
          customerCount: supplier.customerCount.size,
          recordCount: supplier.recordCount,
          monthlySales: avgSalesPerMonth,
          avgReagentSalesPerMonth: supplier.avgMonthlySalesPerMonth,
          commitmentPerMonth: avgCommitmentPerMonth,
          achievementPercent: this.formatPercent(
            this.safeCalculatePercent(
              supplier.avgMonthlySalesPerMonth,
              avgCommitmentPerMonth
            )
            // supplierachievepercent
          ),
          formattedInvestment: this.formatCurrency(supplier.investment),
          formattedCommitment: this.formatCurrency(avgCommitmentPerMonth),
          formattedMonthlySales: this.formatCurrency(avgSalesPerMonth),
          formattedAvgSales: this.formatCurrency(supplier.avgMonthlySalesPerMonth),
          performanceStatus: performanceStatus,
          statusClass: this.getStatusClass(performanceStatus),
          monthlycommitment: supplier.monthlycommitment,
          lastMonthAvg: this.formatCurrency(supplierLastMonthAvg),
          ...monthSalesFlat
        };
      })
      .concat(
        this.calculateCommitmentSupplierGrandTotal(
          Array.from(supplierMap.values())
        )
      );
  }

  calculateCommitmentSupplierGrandTotal(suppliers) {
    if (!suppliers || suppliers.length === 0) return [];

    const grandTotal = {
      supplier: "Grand Total",
      totalMachineCount: 0,
      investment: 0,
      totalSales: 0,
      totalCommitment: 0,
      allAvgSalesPerMonth: [],
      allMonthlySales: [],
      allMonthlyTargets: [],
      lastSixMonthlySales:{},
      avgMonthlySales: 0,
      rowClass: "slds-text-title_bold slds-theme_shade"
    };

    suppliers.forEach((supplier) => {
      grandTotal.totalMachineCount += supplier.totalMachineCount || 0;
      grandTotal.investment += supplier.investment || 0;
      grandTotal.allAvgSalesPerMonth.push(
        ...(supplier.allAvgSalesPerMonth || [])
      );
      grandTotal.allMonthlySales.push(...(supplier.allMonthlySales || []));
      grandTotal.allMonthlyTargets.push(...(supplier.allMonthlyTargets || []));
      grandTotal.avgMonthlySales += parseFloat(supplier.avgMonthlySalesPerMonth) ;
      console.log('>>>>businessCaseDashboard-->calculateCommitmentSupplierGrandTotal-->supplier.monthlycommitment: '+supplier.monthlycommitment);
      console.log('>>>>businessCaseDashboard-->calculateCommitmentSupplierGrandTotal-->supplier.avgMonthlySalesPerMonth: '+supplier.avgMonthlySalesPerMonth);
      grandTotal.totalCommitment += supplier.monthlycommitment;
      if (supplier.lastSixMonthlySales) 
      {
        for (const [monthLabel, value] of Object.entries(supplier.lastSixMonthlySales)) {
          if (!grandTotal.lastSixMonthlySales[monthLabel]) {
            grandTotal.lastSixMonthlySales[monthLabel] = 0;
          }
          grandTotal.lastSixMonthlySales[monthLabel] += value || 0;
        }
      } 

    });

    console.log('>>>>businessCaseDashboard-->calculateCommitmentSupplierGrandTotal-->grandTotal.totalCommitment: '+grandTotal.totalCommitment);

    // Calculate averages for grand total
    const validAvgSales = grandTotal.allAvgSalesPerMonth.filter(
      (val) => !isNaN(val) && val !== null && val !== undefined
    );
    const avgReagentSalesPerMonth =
      validAvgSales.length > 0
        ? validAvgSales.reduce((sum, val) => sum + Number(val), 0) /
          validAvgSales.length
        : 0;

    const validMonthlySales = grandTotal.allMonthlySales.filter(
      (val) => !isNaN(val) && val !== null && val !== undefined
    );
    const avgMonthlySales =
      validMonthlySales.length > 0
        ? validMonthlySales.reduce((sum, val) => sum + Number(val), 0) /
          validMonthlySales.length
        : 0;

    const validTargets = grandTotal.allMonthlyTargets.filter(
      (val) => !isNaN(val) && val !== null && val !== undefined
    );
    const avgCommitment =
      validTargets.length > 0
        ? validTargets.reduce((sum, val) => sum + Number(val), 0) /
          validTargets.length
        : 0;

    const grandtotalachievepercent = (grandTotal.avgMonthlySales / avgCommitment);

    const totalrecord = 
      {
         ...grandTotal,
        machines: grandTotal.totalMachineCount,
        formattedInvestment: this.formatCurrency(grandTotal.investment),
        // formattedCommitment: this.formatCurrency(avgCommitment),
        formattedCommitment: this.formatCurrency(grandTotal.totalCommitment),
        formattedMonthlySales: this.formatCurrency(avgMonthlySales),
        formattedAvgSales: this.formatCurrency(grandTotal.avgMonthlySales),
        achievementPercent: this.formatPercent(
          this.safeCalculatePercent(grandTotal.avgMonthlySales, avgCommitment)
          // grandtotalachievepercent
        )
        
      }
    ;

    for (const [monthLabel, value] of Object.entries(grandTotal.lastSixMonthlySales)) {
      totalrecord[monthLabel] = this.formatCurrency(value || 0);
    }

    const gtCSupVals = Object.values(grandTotal.lastSixMonthlySales).filter(v => v !== null && !isNaN(v));
    totalrecord.lastMonthAvg = this.formatCurrency(
      gtCSupVals.length > 0 ? gtCSupVals.reduce((s, v) => s + Number(v), 0) / gtCSupVals.length : 0
    );

    return [totalrecord];

  }

  aggregateByCustomer() {
    const customerMap = new Map();
    // console.log(
    //   ">>>>BusinessCaseDashboard.js-->aggregateByCustomer-->filteredDate: " +
    //     this.filteredData
    // );
    // console.log(
    //   ">>>>BusinessCaseDashboard.js-->aggregateByCustomer-->filteredDate Json: " +
    //     JSON.stringify(this.filteredData)
    // );
    this.filteredData.forEach((record) => {
      const customerCode = record.customerCode || "Unknown";
      const businessCaseId = record.businessCaseId || "Unknown";
      const key = record.customerCode + "-" + record.businessCaseId; // unique combo
      // console.log(
      //   ">>>>BusinessCaseDashboard.js-->aggregateByCustomer-->record key: " +
      //     key
      // );
      if (!customerMap.has(customerCode)) {
        customerMap.set(customerCode, {
          customerCode: customerCode,
          customerName: record.customerName || "Unknown",
          businessCases: new Set(), // Track unique business cases
          businessCasesDetails: [], // Track unique business cases
          totalMachineCount: 0, // Sum of machine counts
          investment: 0,
          totalSales: 0,
          marginOnSales: 0,
          commitmentPerMonth: 0,
          avgSalesPerMonth: 0,
          uniqueInvestments: new Set(), // Track unique investments per business case
          monthlyTargets: new Map(), // Track targets per month
          monthlySales: new Map(), // Track sales per month
          // Track latest snapshot for each customer for proper avg calculation
          latestSnapshot: null,
          latestSnapshotMonth: null,
          // Preserve original performance status from database
          originalPerformanceStatus: record.performanceStatus,
          // Business case information
          businessCaseId: record.businessCaseId,
          businessCaseName:
            record.businessCaseName ||
            record.Name ||
            record.businessCaseNumber ||
            record.businessCaseId,
          businessCaseStatus: record.businessCaseStatus,
          machineStatus: record.machineStatus,
          // Customer address data
          province: record.customerProvince,
          city: record.customerCity,
          addressLine1: record.customerAddressLine1,
          addressLine2: record.customerAddressLine2,
          postalCode: record.customerPostalCode,
          country: record.customerCountry,
          // Ship To Account data
          shipToCustomerNumber: record.shipToCustomerNumber,
          shipToCustomerName: record.shipToCustomerName,
          shipToProvince: record.shipToProvince,
          shipToCity: record.shipToCity,
          shipToAddressLine1: record.shipToAddressLine1,
          shipToAddressLine2: record.shipToAddressLine2,
          shipToPostalCode: record.shipToPostalCode,
          shipToCountry: record.shipToCountry,
          region: record.region,
          technology: record.technology,
          vendor: record.vendor,
          sapMaterialNumber: record.sapMaterialNumber,
          machineType: record.machineType
        });
      }

      const customerData = customerMap.get(customerCode);

      // accumulate
      // customerData.totalMachineCount += record.machineCount || 0;
      // customerData.investment += record.investment || 0;
      // customerData.totalSales += record.totalReagentSalesTillDate || 0;
      // customerData.marginOnSales += record.marginOnReagentSale || 0;

      // const monthKey = record.snapshotMonth || "Unknown";
      // if (record.targetSales && record.targetSales > 0) {
      //   customerData.monthlyTargets.set(monthKey, record.targetSales);
      // }
      // if (record.totalReagentSales && record.totalReagentSales > 0) {
      //   customerData.monthlySales.set(monthKey, record.totalReagentSales);
      // }

      // if (
      //   !customerData.latestSnapshotMonth ||
      //   monthKey > customerData.latestSnapshotMonth
      // ) {
      //   customerData.latestSnapshot = record;
      //   customerData.latestSnapshotMonth = monthKey;
      // }

      // console.log(
      //   ">>>>BusinessCaseDashboard.js-->aggregateByCustomer-->final customerData: " +
      //     JSON.stringify(customerData)
      // );
      // Only count each business case once for machine count
      if (record.businessCaseId && record.machineCount > 0) {
        if (!customerData.businessCases.has(record.businessCaseId)) {
          customerData.businessCases.add(record.businessCaseId);
          customerData.totalMachineCount += record.machineCount || 0;
        }
      }

      // Track investment per unique business case â€” independent of machineCount
      if (record.businessCaseId) {
        const investmentKey = `${record.businessCaseId}`;
        if (!customerData.uniqueInvestments.has(investmentKey)) {
          customerData.uniqueInvestments.add(investmentKey);
          customerData.investment += record.investment || 0;
        }
      }

      // Accumulate total sales and margins across all records
      // Use totalReagentSalesTillDate for cumulative sales from contract start (not monthly)
      customerData.totalSales += record.totalReagentSalesTillDate || 0;
      customerData.marginOnSales += record.marginOnReagentSale || 0;

      // Track monthly targets and sales to calculate proper averages
      const monthKey = record.snapshotMonth || "Unknown";
      if (record.targetSales && record.targetSales > 0) {
        customerData.monthlyTargets.set(monthKey, record.targetSales);
      }
      // Use totalReagentSales for monthly performance instead of avgReagentSalesPerMonth
      // avgReagentSalesPerMonth is a cumulative average, not the actual month's sales
      if (record.totalReagentSales && record.totalReagentSales > 0) {
        customerData.monthlySales.set(monthKey, record.totalReagentSales);
      }

      // Track latest snapshot to get the correct avgReagentSalesPerMonth
      if (
        !customerData.latestSnapshotMonth ||
        monthKey > customerData.latestSnapshotMonth
      ) {
        customerData.latestSnapshot = record;
        customerData.latestSnapshotMonth = monthKey;
      }
    });

    return Array.from(customerMap.values()).map((customer) => {
      //    console.log('>>>>BusinessCaseDashboard.js-->aggregateByCustomer-->customer map customer: '+JSON.stringify(customer));
      // const targetValues = Array.from(customer.monthlyTargets.values());
      // customer.commitmentPerMonth =
      //   targetValues.length > 0
      //     ? targetValues.reduce((sum, val) => sum + val, 0) / targetValues.length
      //     : 0;

      // customer.avgSalesPerMonth =
      //   customer.latestSnapshot?.avgReagentSalesPerMonth || 0;

      // const performanceStatus =
      //   customer.originalPerformanceStatus ||
      //   this.getPerformanceStatus(
      //     customer.avgSalesPerMonth,
      //     customer.commitmentPerMonth
      //   );

      // const customerRiskData =
      //   this.customerRiskAnalysis.get(customer.customerCode) || {
      //     riskLevel: "HEALTHY",
      //     consecutiveFailedMonths: 0,
      //     actionRequired: "Continue monitoring performance",
      //     riskLevelClass: this.getRiskLevelClass("HEALTHY")
      //   };

      //old code
      // Calculate proper monthly averages
      const targetValues = Array.from(customer.monthlyTargets.values());

      customer.commitmentPerMonth =
        targetValues.length > 0
          ? targetValues.reduce((sum, val) => sum + val, 0) /
            targetValues.length
          : 0;

      // Use avgReagentSalesPerMonth from the latest snapshot instead of calculating
      customer.avgSalesPerMonth =
        customer.latestSnapshot?.avgReagentSalesPerMonth || 0;

      const performanceStatus =
        customer.originalPerformanceStatus ||
        this.getPerformanceStatus(
          customer.avgSalesPerMonth,
          customer.commitmentPerMonth
        );

      // Get risk analysis data for this customer
      const customerRiskData = this.customerRiskAnalysis.get(
        customer.customerCode
      ) || {
        riskLevel: "HEALTHY",
        consecutiveFailedMonths: 0,
        actionRequired: "Continue monitoring performance",
        riskLevelClass: this.getRiskLevelClass("HEALTHY")
      };

      return {
        ...customer,
        machines: customer.totalMachineCount, // Use the summed machine count
        formattedInvestment: this.formatCurrency(customer.investment),
        formattedTotalSales: this.formatCurrency(customer.totalSales),
        formattedPerMachineSales: this.formatCurrency(
          customer.totalMachineCount > 0
            ? customer.totalSales / customer.totalMachineCount
            : 0
        ),
        formattedMargin: this.formatCurrency(customer.marginOnSales),
        costRecoveryPercent: this.formatPercent(
          this.safeCalculatePercent(customer.totalSales, customer.investment)
        ),
        investmentSharePercent: this.calculateInvestmentShare(
          customer.investment
        ),
        achievementPercent: this.formatPercent(
          this.safeCalculatePercent(
            customer.avgSalesPerMonth,
            customer.commitmentPerMonth
          )
        ),
        formattedCommitment: this.formatCurrency(customer.commitmentPerMonth),
        formattedAvgSales: this.formatCurrency(customer.avgSalesPerMonth),
        performanceStatus: performanceStatus,
        // Risk Management Integration
        riskLevel: customerRiskData.riskLevel,
        consecutiveFailedMonths: customerRiskData.consecutiveFailedMonths,
        actionRequired: customerRiskData.actionRequired,
        riskLevelClass: customerRiskData.riskLevelClass,
        riskBadgeClass: `slds-badge ${customerRiskData.riskLevelClass}`,
        riskIcon: this.getRiskIcon(customerRiskData.riskLevel),
        riskStatusText: this.getRiskStatusText(
          customerRiskData.riskLevel,
          customerRiskData.consecutiveFailedMonths
        ),
        riskStatusTextClass: this.getRiskStatusTextClass(
          customerRiskData.riskLevel
        ),
        showRiskAction: customerRiskData.riskLevel === "CRITICAL",
        riskActionLabel:
          customerRiskData.riskLevel === "CRITICAL"
            ? "Asset Recovery Action"
            : "Monitor",
        showActionRequired: customerRiskData.riskLevel !== "HEALTHY",
        // Status indicator flags for card view - more comprehensive logic
        isOnTrack:
          performanceStatus === "On Track" ||
          performanceStatus === "OnTrack" ||
          performanceStatus === "on track",
        isBehindTarget:
          performanceStatus === "Behind Target" ||
          performanceStatus === "BehindTarget" ||
          performanceStatus === "behind target" ||
          performanceStatus === "Behind" ||
          performanceStatus === "behind",
        isBehind:
          performanceStatus === "Behind Target" ||
          performanceStatus === "BehindTarget" ||
          performanceStatus === "behind target" ||
          performanceStatus === "Behind" ||
          performanceStatus === "behind",
        isNoTarget:
          performanceStatus === "No Target Set" ||
          performanceStatus === "NoTargetSet" ||
          performanceStatus === "no target set" ||
          performanceStatus === "No Sales" ||
          performanceStatus === "NoSales" ||
          performanceStatus === "no sales" ||
          !performanceStatus ||
          performanceStatus === "" ||
          performanceStatus === null ||
          performanceStatus === undefined,
        // Status class for table view
        statusClass: this.getStatusClass(performanceStatus)
      };
    });
  }

  aggregateByCustomerBusinessCases() {
    const customerMap = new Map();
    // console.log(
    //   ">>>>BusinessCaseDashboard.js-->aggregateByCustomer-->filteredDate: " +
    //     this.filteredData
    // );
    // console.log(
    //   ">>>>BusinessCaseDashboard.js-->aggregateByCustomer-->filteredDate Json: " +
    //     JSON.stringify(this.filteredData)
    // );
    this.filteredData.forEach((record) => {
      const customerCode = record.customerCode || "Unknown";
      const businessCaseId = record.businessCaseId || "Unknown";
      const key = record.customerCode + "-" + record.businessCaseId; // unique combo
      // console.log(
      //   ">>>>BusinessCaseDashboard.js-->aggregateByCustomer-->record key: " +
      //     key
      // );
      if (!customerMap.has(businessCaseId)) {
        customerMap.set(businessCaseId, {
          customerCode: customerCode,
          customerName: record.customerName || "Unknown",
          businessCases: new Set(), // Track unique business cases
          businessCasesDetails: [], // Track unique business cases
          totalMachineCount: 0, // Sum of machine counts
          investment: 0,
          totalSales: 0,
          marginOnSales: 0,
          commitmentPerMonth: 0,
          avgSalesPerMonth: 0,
          ytdsales: 0,
          lastYearYtdsales: 0,
          lastToLastYearYtdsales: 0,
          lastSixMonthlySales: {},
          uniqueInvestments: new Set(), // Track unique investments per business case
          monthlyTargets: new Map(), // Track targets per month
          monthlySales: new Map(), // Track sales per month
          // Track latest snapshot for each customer for proper avg calculation
          latestSnapshot: null,
          latestSnapshotMonth: null,
          // Preserve original performance status from database
          originalPerformanceStatus: record.performanceStatus,
          // Business case information
          businessCaseId: record.businessCaseId || businessCaseId,
          businessCaseName:
            record.businessCaseName ||
            record.Name ||
            record.businessCaseNumber ||
            record.businessCaseId,
          businessCaseStatus: record.businessCaseStatus,
          machineStatus: record.machineStatus,
          // Customer address data
          province: record.customerProvince,
          city: record.customerCity,
          addressLine1: record.customerAddressLine1,
          addressLine2: record.customerAddressLine2,
          postalCode: record.customerPostalCode,
          country: record.customerCountry,
          // Ship To Account data
          shipToCustomerNumber: record.shipToCustomerNumber,
          shipToCustomerName: record.shipToCustomerName,
          shipToProvince: record.shipToProvince,
          shipToCity: record.shipToCity,
          shipToAddressLine1: record.shipToAddressLine1,
          shipToAddressLine2: record.shipToAddressLine2,
          shipToPostalCode: record.shipToPostalCode,
          shipToCountry: record.shipToCountry,
          region: record.region,
          technology: record.technology,
          vendor: record.vendor,
          sapMaterialNumber: record.sapMaterialNumber,
          machineType: record.machineType,
          riskStatus: record.riskStatus
        });
      }

      const customerData = customerMap.get(businessCaseId);

      // Add business case details with clickable info
      // if (record.businessCaseId && record.businessCaseName)
      // {
      //     const existing = customerData.businessCasesDetails.find(
      //         bc => bc.id === record.businessCaseId
      //     );
      //     if (!existing) {
      //         customerData.businessCasesDetails.push({
      //             id: record.businessCaseId,
      //             name: record.businessCaseName
      //         });
      //     }
      // }

      // accumulate
      // customerData.totalMachineCount += record.machineCount || 0;
      // customerData.investment += record.investment || 0;
      // customerData.totalSales += record.totalReagentSalesTillDate || 0;
      // customerData.marginOnSales += record.marginOnReagentSale || 0;

      // const monthKey = record.snapshotMonth || "Unknown";
      // if (record.targetSales && record.targetSales > 0) {
      //   customerData.monthlyTargets.set(monthKey, record.targetSales);
      // }
      // if (record.totalReagentSales && record.totalReagentSales > 0) {
      //   customerData.monthlySales.set(monthKey, record.totalReagentSales);
      // }

      // if (
      //   !customerData.latestSnapshotMonth ||
      //   monthKey > customerData.latestSnapshotMonth
      // ) {
      //   customerData.latestSnapshot = record;
      //   customerData.latestSnapshotMonth = monthKey;
      // }

      // console.log(
      //   ">>>>BusinessCaseDashboard.js-->aggregateByCustomer-->final customerData: " +
      //     JSON.stringify(customerData)
      // );
      // Only count each business case once for machine count
      if (record.businessCaseId && record.machineCount > 0) {
        if (!customerData.businessCases.has(record.businessCaseId)) {
          customerData.businessCases.add(record.businessCaseId);
          customerData.totalMachineCount += record.machineCount || 0;
        }
      }

      // Track investment per unique business case â€” independent of machineCount
      if (record.businessCaseId) {
        const investmentKey = `${record.businessCaseId}`;
        if (!customerData.uniqueInvestments.has(investmentKey)) {
          customerData.uniqueInvestments.add(investmentKey);
          customerData.investment += record.investment || 0;
        }
      }

      // Accumulate total sales and margins across all records
      // Use totalReagentSalesTillDate for cumulative sales from contract start (not monthly)
      customerData.totalSales += record.totalReagentSalesTillDate || 0;
      customerData.marginOnSales += record.marginTillDate || 0;
      customerData.ytdsales += record.ytdSales || 0;
      customerData.lastYearYtdsales += record.lastYearYtdSales || 0;
      customerData.lastToLastYearYtdsales += record.lastToLastYearYtdSales || 0;

      if (record.monthlySales && typeof record.monthlySales === 'object') {
        Object.entries(record.monthlySales).forEach(([month, value]) => {
          const numericValue = this.safeParseNumber(value);
          if (!isNaN(numericValue)) {
            if (!customerData.lastSixMonthlySales[month]) {
              customerData.lastSixMonthlySales[month] = 0;
            }
            customerData.lastSixMonthlySales[month] += numericValue;
          }
        });
      }

      // Track monthly targets and sales to calculate proper averages
      const monthKey = record.snapshotMonth || "Unknown";
      if (record.targetSales && record.targetSales > 0) {
        customerData.monthlyTargets.set(monthKey, record.targetSales);
      }
      // Use totalReagentSales for monthly performance instead of avgReagentSalesPerMonth
      // avgReagentSalesPerMonth is a cumulative average, not the actual month's sales
      if (record.totalReagentSales && record.totalReagentSales > 0) {
        customerData.monthlySales.set(monthKey, record.totalReagentSales);
      }

      // Track latest snapshot to get the correct avgReagentSalesPerMonth
      if (
        !customerData.latestSnapshotMonth ||
        monthKey > customerData.latestSnapshotMonth
      ) {
        customerData.latestSnapshot = record;
        customerData.latestSnapshotMonth = monthKey;
      }
    });

    return Array.from(customerMap.values())
      .sort((a, b) => {
        const codeA = (a.customerCode || '').toString();
        const codeB = (b.customerCode || '').toString();
        if (codeA !== codeB) return codeA.localeCompare(codeB);
        return (a.vendor || '').localeCompare(b.vendor || '');
      })
      .map((customer) => {
      //    console.log('>>>>BusinessCaseDashboard.js-->aggregateByCustomer-->customer map customer: '+JSON.stringify(customer));
      // const targetValues = Array.from(customer.monthlyTargets.values());
      // customer.commitmentPerMonth =
      //   targetValues.length > 0
      //     ? targetValues.reduce((sum, val) => sum + val, 0) / targetValues.length
      //     : 0;

      // customer.avgSalesPerMonth =
      //   customer.latestSnapshot?.avgReagentSalesPerMonth || 0;

      // const performanceStatus =
      //   customer.originalPerformanceStatus ||
      //   this.getPerformanceStatus(
      //     customer.avgSalesPerMonth,
      //     customer.commitmentPerMonth
      //   );

      // const customerRiskData =
      //   this.customerRiskAnalysis.get(customer.customerCode) || {
      //     riskLevel: "HEALTHY",
      //     consecutiveFailedMonths: 0,
      //     actionRequired: "Continue monitoring performance",
      //     riskLevelClass: this.getRiskLevelClass("HEALTHY")
      //   };

      //old code
      // Calculate proper monthly averages
      const targetValues = Array.from(customer.monthlyTargets.values());

      customer.commitmentPerMonth =
        targetValues.length > 0
          ? targetValues.reduce((sum, val) => sum + val, 0) /
            targetValues.length
          : 0;

      // Use avgReagentSalesPerMonth from the latest snapshot instead of calculating
      customer.avgSalesPerMonth =
        customer.latestSnapshot?.avgReagentSalesPerMonth || 0;

      const performanceStatus =
        customer.originalPerformanceStatus ||
        this.getPerformanceStatus(
          customer.avgSalesPerMonth,
          customer.commitmentPerMonth
        );

      // Get risk analysis data for this customer
      // const customerRiskData = this.customerRiskAnalysis.get(
      //   customer.customerCode
      // ) || {
      //   riskLevel: "HEALTHY",
      //   consecutiveFailedMonths: 0,
      //   actionRequired: "Continue monitoring performance",
      //   riskLevelClass: this.getRiskLevelClass("HEALTHY")
      // };
      // const customerRiskData = this.customerRiskAnalysis.get(
      //   customer.customerCode
      // ) || {
      //   riskLevel: "HEALTHY",
      //   consecutiveFailedMonths: 0,
      //   actionRequired: "Continue monitoring performance",
      //   riskLevelClass: this.getRiskLevelClass("HEALTHY")
      // };

      var customerRiskData;

      if (customer.riskStatus == "Healthy") {
        customerRiskData = {
          riskLevel: "HEALTHY",
          consecutiveFailedMonths: 0,
          actionRequired: "Continue monitoring performance",
          riskLevelClass: this.getRiskLevelClass("HEALTHY")
        };
      } else if (customer.riskStatus == "Warning") {
        customerRiskData = {
          riskLevel: "WARNING",
          consecutiveFailedMonths: 1,
          actionRequired: "Continue monitoring performance",
          riskLevelClass: this.getRiskLevelClass("WARNING")
        };
      } else if (customer.riskStatus == "High Risk") {
        customerRiskData = {
          riskLevel: "HIGH",
          consecutiveFailedMonths: 3,
          actionRequired: "Continue monitoring performance",
          riskLevelClass: this.getRiskLevelClass("HIGH")
        };
      } else if (customer.riskStatus == "Critical") {
        customerRiskData = {
          riskLevel: "CRITICAL",
          consecutiveFailedMonths: 1,
          actionRequired: "Quick Action Required",
          riskLevelClass: this.getRiskLevelClass("CRITICAL")
        };
      }

      if (!customerRiskData) {
        customerRiskData = {
          riskLevel: "HEALTHY",
          consecutiveFailedMonths: 0,
          actionRequired: "Continue monitoring performance",
          riskLevelClass: this.getRiskLevelClass("HEALTHY")
        };
      }

      const custLastMonthAvgRaw = (() => {
        const vals = customer.lastSixMonthlySales
          ? Object.values(customer.lastSixMonthlySales).filter(v => v !== null && !isNaN(v))
          : [];
        return vals.length > 0 ? vals.reduce((s, v) => s + Number(v), 0) / vals.length : 0;
      })();

      const monthSalesFlat = {};
      if (customer.lastSixMonthlySales) {
        for (const [month, value] of Object.entries(customer.lastSixMonthlySales)) {
          monthSalesFlat[month.replace(' ', '_')] = this.formatCurrency(value);
        }
      }

      return {
        ...customer,
        ...monthSalesFlat,
        machines: customer.totalMachineCount,
        formattedInvestment: this.formatCurrency(customer.investment),
        formattedTotalSales: this.formatCurrency(customer.totalSales),
        formattedPerMachineSales: this.formatCurrency(
          customer.totalMachineCount > 0
            ? customer.totalSales / customer.totalMachineCount
            : 0
        ),
        formattedMargin: this.formatCurrency(customer.marginOnSales),
        formattedYtdSales: this.formatCurrency(customer.ytdsales),
        formattedLastYearYtdSales: this.formatCurrency(customer.lastYearYtdsales),
        formattedLastToLastYearYtdSales: this.formatCurrency(customer.lastToLastYearYtdsales),
        costRecoveryPercent: this.formatPercent(
          this.safeCalculatePercent(customer.totalSales, customer.investment)
        ),
        investmentSharePercent: this.calculateInvestmentShare(
          customer.investment
        ),
        achievementPercent: this.formatPercent(
          this.safeCalculatePercent(
            customer.avgSalesPerMonth,
            customer.commitmentPerMonth
          )
        ),
        formattedCommitment: this.formatCurrency(customer.commitmentPerMonth),
        formattedAvgSales: this.formatCurrency(customer.avgSalesPerMonth),
        lastMonthAvg: this.formatCurrency(custLastMonthAvgRaw),
        lastMonthAvgCommitPercent: this.formatPercent(
          this.safeCalculatePercent(custLastMonthAvgRaw, customer.commitmentPerMonth)
        ),
        performanceStatus: performanceStatus,
        // Risk Management Integration
        riskLevel: customerRiskData.riskLevel,
        consecutiveFailedMonths: customerRiskData.consecutiveFailedMonths,
        actionRequired: customerRiskData.actionRequired,
        riskLevelClass: customerRiskData.riskLevelClass,
        riskBadgeClass: `slds-badge ${customerRiskData.riskLevelClass}`,
        riskIcon: this.getRiskIcon(customerRiskData.riskLevel),
        riskStatusText: this.getRiskStatusText(
          customerRiskData.riskLevel,
          customerRiskData.consecutiveFailedMonths
        ),
        riskStatusTextClass: this.getRiskStatusTextClass(
          customerRiskData.riskLevel
        ),
        showRiskAction: customerRiskData.riskLevel === "CRITICAL",
        riskActionLabel:
          customerRiskData.riskLevel === "CRITICAL"
            ? "Asset Recovery Action"
            : "Monitor",
        showActionRequired: customerRiskData.riskLevel !== "HEALTHY",
        // Status indicator flags for card view - more comprehensive logic
        isOnTrack:
          performanceStatus === "On Track" ||
          performanceStatus === "OnTrack" ||
          performanceStatus === "on track",
        isAtRisk:
          performanceStatus === "At Risk" ||
          performanceStatus === "AtRisk" ||
          performanceStatus === "at risk" ||
          performanceStatus === "atrisk" ||
          performanceStatus === "atRisk",
        isBehind:
          performanceStatus === "Behind Target" ||
          performanceStatus === "BehindTarget" ||
          performanceStatus === "behind target" ||
          performanceStatus === "Behind" ||
          performanceStatus === "behind",
        isNoTarget:
          performanceStatus === "No Target Set" ||
          performanceStatus === "NoTargetSet" ||
          performanceStatus === "no target set" ||
          performanceStatus === "No Sales" ||
          performanceStatus === "NoSales" ||
          performanceStatus === "no sales" ||
          !performanceStatus ||
          performanceStatus === "" ||
          performanceStatus === null ||
          performanceStatus === undefined,
        // Status class for table view
        statusClass: this.getStatusClass(performanceStatus)
      };
    });
  }
  //Calculate Risk Business Cases
  calculateRiskBusinessCases() {
    // console.log(
    //   ">>>>businessCaseDashboard-->calculateRiskBusinessCases-->Filtered Snapshot data length: " +
    //     JSON.stringify(this.filteredData.length)
    // );

    this.riskAnalysis.healthy = 0;
    this.riskAnalysis.warning = 0;
    this.riskAnalysis.highrisk = 0;
    this.riskAnalysis.critical = 0;
    this.riskAnalysis.ontrack = 0;
    this.riskAnalysis.behind = 0;
    this.riskAnalysis.notargetset = 0;
    this.riskAnalysis.atrisk = 0;
    this.filteredData.forEach((record) => {
      if (record.riskStatus == "Healthy") {
        this.riskAnalysis.healthy++;
      } else if (record.riskStatus == "Warning") {
        this.riskAnalysis.warning++;
      } else if (record.riskStatus == "High Risk") {
        this.riskAnalysis.highrisk++;
      } else if (record.riskStatus == "Critical") {
        this.riskAnalysis.critical++;
      }

      if (record.performanceStatus == "Behind") {
        this.riskAnalysis.behind++;
      } else if (record.performanceStatus == "No Target Set") {
        this.riskAnalysis.notargetset++;
      } else if (record.performanceStatus == "On Track") {
        this.riskAnalysis.ontrack++;
      } else if (record.performanceStatus == "At Risk") {
        this.riskAnalysis.atrisk++;
      }
    });
    // console.log(
    //   ">>>businessCaseDashboard-->calculateRiskBusinessCases-->riskAnalysis: " +
    //     JSON.stringify(this.riskAnalysis)
    // );
  }
  // ===== OVERVIEW METRICS CALCULATION =====

  calculateOverviewMetrics() {
    // console.log("ðŸ“Š Calculating overview metrics from ALL data...");
    // console.log(
    //   "ðŸ“Š Calculating overview metrics from ALL data business cases: ..." +
    //     JSON.stringify(this.snapshotData)
    // );

    if (!this.snapshotData || this.snapshotData.length === 0) {
      // console.log("âš ï¸ No snapshot data available for overview metrics");
      // this.overviewMetrics = {
      //   totalCustomers: 0,
      //   onTrackCustomers: 0,
      //   behindTargetCustomers: 0,
      //   noTargetCustomers: 0,
      //   healthyCustomers: 0,
      //   warningCustomers: 0,
      //   highRiskCustomers: 0,
      //   criticalCustomers: 0
      // };
      return;
    }

    // Calculate commitment status counts from ALL data (not filtered)
    const uniqueCustomers = {};
    this.snapshotData.forEach((record) => {
      if (record.customerCode && record.performanceStatus) {
        uniqueCustomers[record.customerCode] = record.performanceStatus;
      }
    });

    // Calculate commitment status counts from ALL data Business Case wise (not filtered)
    const uniquebusinessCases = {};
    this.snapshotData.forEach((record) => {
      // console.log(
      //   "ðŸ“Š Calculating overview metrics from ALL data unique business cases: ..." +
      //     record.businessCaseId +
      //     " : " +
      //     record.performanceStatus
      // );
      if (record.businessCaseId && record.performanceStatus) {
        uniquebusinessCases[record.businessCaseId] = record.performanceStatus;
      }
    });

    // Count customers by commitment status
    const commitmentStatusCounts = {
      onTrack: 0,
      behind: 0,
      noTargetSet: 0,
      noSales: 0
    };

    // Object.values(uniqueCustomers).forEach((status) => {
    //   switch (status) {
    //     case "On Track":
    //       commitmentStatusCounts.onTrack++;
    //       break;
    //     case "Behind":
    //       commitmentStatusCounts.behind++;
    //       break;
    //     case "No Target Set":
    //       commitmentStatusCounts.noTargetSet++;
    //       break;
    //     case "No Sales":
    //       commitmentStatusCounts.noSales++;
    //       break;
    //     default:
    //       // Handle unknown status
    //       break;
    //   }
    // });

    //By Business Case
    Object.values(uniquebusinessCases).forEach((status) => {
      switch (status) {
        case "On Track":
          commitmentStatusCounts.onTrack++;
          break;
        case "Behind":
          commitmentStatusCounts.behind++;
          break;
        case "No Target Set":
          commitmentStatusCounts.noTargetSet++;
          break;
        case "No Sales":
          commitmentStatusCounts.noSales++;
          break;
        default:
          // Handle unknown status
          break;
      }
    });

    // Calculate risk status counts from ALL data
    const riskStatusCounts = {
      healthy: 0,
      warning: 0,
      highRisk: 0,
      critical: 0
    };

    // Count risk levels from the complete risk analysis
    if (this.customerRiskAnalysis && this.customerRiskAnalysis.size > 0) {
      this.customerRiskAnalysis.forEach((riskData) => {
        switch (riskData.riskLevel) {
          case "HEALTHY":
          case "Healthy":
            riskStatusCounts.healthy++;
            break;
          case "WARNING":
          case "Warning":
            riskStatusCounts.warning++;
            break;
          case "HIGH":
          case "High Risk":
            riskStatusCounts.highRisk++;
            break;
          case "CRITICAL":
          case "Critical":
            riskStatusCounts.critical++;
            break;
          default:
            // Handle unknown risk level
            break;
        }
      });
    }

    // Update overview metrics
    this.overviewMetrics = {
      totalCustomers: Object.keys(uniqueCustomers).length,
      onTrackCustomers: commitmentStatusCounts.onTrack,
      behindTargetCustomers: commitmentStatusCounts.behind,
      noTargetCustomers:
        commitmentStatusCounts.noTargetSet + commitmentStatusCounts.noSales,
      healthyCustomers: riskStatusCounts.healthy,
      warningCustomers: riskStatusCounts.warning,
      highRiskCustomers: riskStatusCounts.highRisk,
      criticalCustomers: riskStatusCounts.critical
    };

    // console.log(
    //   "âœ… Overview metrics calculated:",
    //   JSON.stringify(this.overviewMetrics)
    // );
  }

  // ===== EVENT HANDLERS =====

  handleTabChange(event) {
    this.activeTab = event.target.value;

    // Initialize trend charts when switching to trend tabs (only if Chart.js is loaded)
    if (
      this.activeTab === "investment-trends" ||
      this.activeTab === "commitment-trends"
    ) {
      // Initialize charts in the next render cycle to ensure DOM is ready
      Promise.resolve().then(() => {
        if (this.chartJSLoaded && window.Chart) {
          this.initializeTrendCharts();
        } else {
          // console.log("Chart.js not ready yet, will initialize later");
        }
      });
    }

    this.updateCustomerPagination();
  }

  handleRefresh() {
    this.selectedMonth = "";
    const today = new Date();
    this.selectedMonthYear = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}`;
    this.setMonthYearDates(this.selectedMonthYear);
    this.selectedCustomer = "";
    this.selectedCustomers = []; // Clear multi-select customers
    this.selectedRegion = "";
    this.selectedRegions = []; // Clear multi-select regions
    this.selectedSupplier = "";
    this.selectedSuppliers = []; // Clear multi-select suppliers
    this.selectedBusinessCaseStatus = "";
    this.selectedBusinessCaseStatuses = []; // Clear multi-select business case statuses
    this.selectedMachineStatus = "";
    this.selectedMachineStatuses = []; // Clear multi-select machine statuses
    this.selectedCommitmentStatus = "";
    this.selectedCommitmentStatuses = []; // Clear multi-select commitment statuses
    this.selectedRiskStatus = "";
    this.searchTerm = "";
    this.selectedBusinessCase = "";
    this.selectedBusinessCases = []; // Clear multi-select business cases
    this.isLoading = true;
    // refreshApex(this.wiredSnapshotResult);
    return refreshApex(this.wiredSnapshotResult)
      .then(() => {
        return Promise.all([
          refreshApex(this.wiredFilterResult),
          refreshApex(this.wiredSummaryResult)
        ]);
      })
      .then(() => {
        this.showToast(
          "Success",
          "Dashboard data refreshed successfully",
          "success"
        );
      })
      .catch((error) => {
        this.handleError("Error refreshing data", error);
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  handleExport() {
    // Implementation for data export
    this.showToast("Info", "Export functionality coming soon", "info");
  }

  // Filter handlers
  setMonthYearDates(monthYear) {
    if (!monthYear) return;
    const [year, month] = monthYear.split('-').map(Number);
    const lastDay = new Date(year, month, 0); // day-0 of next month = last day of selected month
    this.selectedSnapshotMonth = `${lastDay.getFullYear()}-${String(lastDay.getMonth() + 1).padStart(2, '0')}-${String(lastDay.getDate()).padStart(2, '0')}`;
  }

  handleMonthYearChange(event) {
    this.selectedMonthYear = event.detail.value;
    this.setMonthYearDates(this.selectedMonthYear);
  }

  handleMonthChange(event) {
    this.selectedMonth = event.detail.value;
    //this.processSnapshotData();
  }

  handleDateFromChange(event) 
  {
    console.log('>>>>businessCaseDashboard-->handleDateFromChange-->selectedDateFrom: '+this.selectedDateFrom);
    this.selectedDateFrom = event.target.value;
  }

  handleDateToChange(event) {
    console.log('>>>>businessCaseDashboard-->handleDateToChange-->selectedDateTo: '+this.selectedDateFrom);
    this.selectedDateTo = event.target.value;
  }

  handleBusinessCaseChange(event) {
    this.selectedBusinessCases = event.detail.value || [];
    // Always use client-side filtering (no server-side filtering for business case)
    this.selectedBusinessCase = "";
    
       console.log('>>>>businessCaseDashboard-->handleBusinessCaseChange-->event.detail.value: '+event.detail.value);
    //get Machine filtered data for status count
    var filteredmachinedata = this.machineStatusCountList.filter(x=> x.name == event.detail.value);
    if(filteredmachinedata.length > 0)
    {
        this.filteredMachineStatusCountList = filteredmachinedata;
    }
    else{
      filteredmachinedata = this.machineStatusCountList.filter(x=> x.masterBusinessCase == event.detail.value);
      if(filteredmachinedata.length > 0)
      {
        this.filteredMachineStatusCountList = filteredmachinedata;
      }
    }
    this.calculateMachineStatusCountsFromFiltered();

    // Apply filters regardless of how many business cases are selected
    this.applyFilters();
    this.aggregateData();
  }

  handleCustomerChange(event) {
    // Handle multi-select customer change from child component
    this.selectedCustomers = event.detail.value || [];

    // Always use client-side filtering (no server-side filtering for customers)
    this.selectedCustomer = "";

    

    //get Machine filtered data for status count
    console.log('>>>>businessCaseDashboard-->handleCustomerChange-->event.detail.value: '+event.detail.value);
    var filteredmachinedata = this.machineStatusCountList.filter(x=> x.customerNumber == event.detail.value);
    console.log('>>>>businessCaseDashboard-->handleCustomerChange-->filteredmachinedata: '+JSON.stringify(filteredmachinedata));
    if(filteredmachinedata.length > 0)
    {
        this.filteredMachineStatusCountList = filteredmachinedata;
    }
    this.calculateMachineStatusCountsFromFiltered();

    // Trigger client-side filtering and aggregation
    this.applyFilters();
    this.aggregateData();
  }

  handleCustomerSearchChange(event) {
    // lightning-input search uses event.target.value
    this.customerSearchTerm = event.target.value || "";
    // Do not auto-change selectedCustomer; user will pick from filtered combobox
  }

  // Typeahead: live input handler
  handleCustomerInput(event) {
    this.customerSearchTerm = event.target.value || "";
    // Show suggestions when user types at least one character
    this.showCustomerSuggestions =
      (this.customerSearchTerm || "").trim().length > 0;
    this.highlightedCustomerIndex = -1;
  }

  // Keyboard navigation for suggestions
  handleCustomerKeyDown(event) {
    const suggestions = this.customerSuggestions || [];
    if (!suggestions.length) {
      return;
    }

    if (event.key === "ArrowDown") {
      event.preventDefault();
      this.highlightedCustomerIndex = Math.min(
        this.highlightedCustomerIndex + 1,
        suggestions.length - 1
      );
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      this.highlightedCustomerIndex = Math.max(
        this.highlightedCustomerIndex - 1,
        0
      );
    } else if (event.key === "Enter") {
      event.preventDefault();
      const idx =
        this.highlightedCustomerIndex >= 0 ? this.highlightedCustomerIndex : 0;
      const sel = suggestions[idx];
      if (sel) {
        this.selectedCustomer = sel.value;
        this.customerSearchTerm = sel.label;
        this.showCustomerSuggestions = false;
      }
    } else if (event.key === "Escape") {
      this.showCustomerSuggestions = false;
      this.highlightedCustomerIndex = -1;
    }
  }

  // When user clicks a suggestion
  handleSelectCustomer(event) {
    const li = event.currentTarget;
    const value = li.dataset.value;
    const label = li.dataset.label;
    if (value) {
      this.selectedCustomer = value;
      this.customerSearchTerm = label || value;
      this.showCustomerSuggestions = false;
    }
  }

  // Prevent losing focus before click handler on suggestions
  handleSuggestionMouseDown(event) {
    event.preventDefault();
  }

  // Hide suggestions shortly after blur (allow click to register)
  handleCustomerBlur() {
    // Hide suggestions on blur. Suggestion clicks use onmousedown to prevent blur.
    this.showCustomerSuggestions = false;
    this.highlightedCustomerIndex = -1;
  }

  // Apply all filter selections to the dashboard (Search button)
  // handleSearchClick() {
  //   // Reset to first page when applying new filters
  //   this.currentPage = 1;
  //   // Apply filters using the existing logic
  //   this.applyFilters();
  //   // Recalculate aggregates and risk analysis
  //   try {
  //     this.analyzeCustomerCommitmentRisk();
  //   } catch (e) {
  //     console.warn("analyzeCustomerCommitmentRisk failed:", e);
  //   }
  //   try {
  //     this.aggregateData();
  //   } catch (e) {
  //     console.warn("aggregateData failed:", e);
  //   }
  // }

  // Reset all filters to default and reapply (Reset button)
  handleResetFilters() {
    this.selectedMonth = "";
    this.selectedDateFrom = "";
    this.selectedDateTo = "";
    this.selectedCustomer = "";
    this.selectedCustomers = [];
    this.selectedRegion = "";
    this.selectedRegions = []; // Clear multi-select regions
    this.selectedSupplier = "";
    this.selectedSuppliers = []; // Clear multi-select suppliers
    this.selectedBusinessCaseStatus = "";
    this.selectedBusinessCaseStatuses = []; // Clear multi-select business case statuses
    this.selectedMachineStatus = "";
    this.selectedMachineStatuses = []; // Clear multi-select machine statuses
    this.selectedCommitmentStatus = "";
    this.selectedCommitmentStatuses = []; // Clear multi-select commitment statuses
    this.selectedRiskStatus = "";
    this.selectedBusinessCase = "";
    this.selectedBusinessCases = []; // Clear multi-select business cases
    this.currentPage = 1;

    // Force re-render of multi-select dropdowns
    Promise.resolve().then(() => {
      const multiSelects = this.template.querySelectorAll(
        "c-b-multi-select-dropdown"
      );
      multiSelects.forEach((dropdown) => {
        // If the custom component has a reset or clear method, call it
        if (dropdown) {
          if (typeof dropdown.reset === "function") {
            dropdown.reset();
          } else if (typeof dropdown.clear === "function") {
            dropdown.clear();
          }
        }
      });
    });

    // Reapply filters (which will now be cleared)
    this.applyFilters();
    try {
      this.analyzeCustomerCommitmentRisk();
    } catch (e) {
      console.warn("analyzeCustomerCommitmentRisk failed on reset:", e);
    }
    try {
      this.aggregateData();
    } catch (e) {
      console.warn("aggregateData failed on reset:", e);
    }
  }

  handleRegionChange(event) {
    // Handle multi-select region change
    this.selectedRegions = event.detail.value || [];

    // Always use client-side filtering (no server-side filtering for regions)
    this.selectedRegion = "";

    // Trigger client-side filtering and aggregation
    this.applyFilters();
    this.aggregateData();

    //get Machine filtered data for status count
    var filteredmachinedata = this.machineStatusCountList.filter(x=> x.region == event.detail.value);
    if(filteredmachinedata.length > 0)
    {
        this.filteredMachineStatusCountList = filteredmachinedata;
    }
    this.calculateMachineStatusCountsFromFiltered();
  }

  handleSupplierChange(event) {
    // console.log("handleSupplierChange-->event:" + event.detail.value);
    this.selectedSuppliers = event.detail.value || [];
    // Always use client-side filtering (no server-side filtering for suppliers)
    this.selectedSupplier = "";
    // Apply filters regardless of how many suppliers are selected
    this.applyFilters();
    this.aggregateData();
  }

  handleBusinessCaseStatusChange(event) {
    this.selectedBusinessCaseStatuses = event.detail.value || [];
    // Always use client-side filtering (no server-side filtering for business case status)
    this.selectedBusinessCaseStatus = "";
    // Apply filters regardless of how many statuses are selected
    this.applyFilters();
    this.aggregateData();

    //get Machine filtered data for status count
    var filteredmachinedata = this.machineStatusCountList.filter(x=> x.status == event.detail.value);
    if(filteredmachinedata.length > 0)
    {
        this.filteredMachineStatusCountList = filteredmachinedata;
    }
    this.calculateMachineStatusCountsFromFiltered();
  }

  handleMachineStatusChange(event) {
    this.selectedMachineStatuses = event.detail.value || [];
    // Always use client-side filtering (no server-side filtering for machine status)
    this.selectedMachineStatus = "";
    // Apply filters regardless of how many statuses are selected
    this.applyFilters();
    this.aggregateData();

     var filteredmachinedata = this.machineStatusCountList.filter(x=> x.machineInstallationStatus == event.detail.value);
    if(filteredmachinedata.length > 0)
    {
        this.filteredMachineStatusCountList = filteredmachinedata;
    }
    this.calculateMachineStatusCountsFromFiltered();
  }

  handleCommitmentStatusChange(event) {
    this.selectedCommitmentStatuses = event.detail.value || [];
    // Always use client-side filtering (no server-side filtering for commitment status)
    this.selectedCommitmentStatus = "";
    // Apply filters regardless of how many statuses are selected
    this.applyFilters();
    this.aggregateData();
  }

  handleRiskStatusChange(event) {
    this.selectedRiskStatus = event.detail.value;
    //this.processSnapshotData();
  }

  handleSearchChange(event) {
    this.searchTerm = event.detail.value;
    // Process data immediately without debounce
    //this.processSnapshotData();
  }

  // View mode handlers
  handleViewModeToggle(event) {
    this.customerViewMode = event.detail.value;
  }

  // Customer card action handler
  handleCustomerCardAction(event) {
    const customerCode = event.target.dataset.customerCode;

    // Find the customer data based on active tab
    let customerData;
    if (this.activeTab === "investment") {
      customerData = this.customerInvestmentData.find(
        (customer) => customer.customerCode === customerCode
      );
    } else if (this.activeTab === "commitment") {
      customerData = this.customerCommitmentData.find(
        (customer) => customer.customerCode === customerCode
      );
    }

    if (customerData) {
      this.selectedCustomerData = {
        ...customerData,
        formattedInvestment: this.formatCurrency(customerData.investment),
        formattedSales: this.formatCurrency(customerData.totalSales),
        formattedCostRecovery: customerData.costRecoveryPercent
      };
      this.showCustomerModal = true;
    }
  }

  // Handle View Business Case button click
  handleViewBusinessCase(event) {
    const customerCode = event.target.dataset.customerCode;

    // Find the customer data based on active tab to get business case ID
    let customerData;
    if (this.activeTab === "investment") {
      customerData = this.customerInvestmentData.find(
        (customer) => customer.customerCode === customerCode
      );
    } else if (this.activeTab === "commitment") {
      customerData = this.customerCommitmentData.find(
        (customer) => customer.customerCode === customerCode
      );
    }

    if (customerData) {
      // Find the business case ID from the original snapshot data
      const snapshotRecord = this.snapshotData.find(
        (record) => record.customerCode === customerCode
      );

      if (snapshotRecord && snapshotRecord.businessCaseId) {
        // Navigate to the Business Case record page
        this.navigateToRecord(snapshotRecord.businessCaseId);
      } else {
        this.showToast(
          "Warning",
          "Business Case record not found for this customer",
          "warning"
        );
      }
    }
  }

  handleViewBusinessCaseUpdated(event) {
    const businessCaseId = event.target.dataset.businessCaseId;
    // Use NavigationMixin for proper navigation
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: businessCaseId,
        actionName: "view"
      }
    });
  }

  indexIsNotLast(index, length) {
    return index < length - 1;
  }

  // Navigate to a Salesforce record
  navigateToRecord(recordId) {
    const url = `/lightning/r/Business_Case__c/${recordId}/view`;
    window.open(url, "_blank");
  }

  // Pagination handlers
  handlePreviousPage() {
    if (this.currentPage > 1) {
      this.currentPage--;
    }
  }

  handleNextPage() {
    if (this.currentPage < this.totalPages) {
      this.currentPage++;
    }
  }

  // Detailed Pagination handlers
  handleDetailedPreviousPage() {
    if (this.detailedCurrentPage > 1) {
      this.detailedCurrentPage--;
    }
  }

  handleDetailedNextPage() {
    if (this.detailedCurrentPage < this.totalDetailPages) {
      this.detailedCurrentPage++;
    }
  }

  // Row action handlers
  handleCustomerRowAction(event) {
    const action = event.detail.action;
    const row = event.detail.row;

    if (action.name === "view_details") {
      this.selectedCustomerData = {
        ...row,
        formattedInvestment: this.formatCurrency(row.investment),
        formattedSales: this.formatCurrency(row.totalSales),
        formattedCostRecovery: row.costRecoveryPercent
      };
      this.showCustomerModal = true;
    }
  }

  handleRowAction(event) {
    const action = event.detail.action;
    // const row = event.detail.row; // Commented out unused variable

    if (action.name === "view_details") {
      // Show detailed view modal
      this.showToast("Info", "Detailed view functionality coming soon", "info");
    }
  }

  closeCustomerModal() {
    this.showCustomerModal = false;
    this.selectedCustomerData = null;
  }

  // ===== UTILITY METHODS =====

  formatCurrency(amount) 
  {
    
    if (amount == null || amount === undefined || isNaN(amount)) return "Rs.0";
    const numericAmount = Number(amount);
    if (isNaN(numericAmount)) return "Rs.0";
    // const formattedNumber = new Intl.NumberFormat("en-US", {
    //   minimumFractionDigits: 0,
    //   maximumFractionDigits: 0
    // }).format(numericAmount);

    const formattedNumber = new Intl.NumberFormat("en-US", 
    {
      //style:"currency",
      // currency:"PKR",
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(numericAmount);
    
    //console.log('>>>>businessCaseDashboard-->formatCurrency-->formattednumber: '+formattedNumber);
    return "Rs." + formattedNumber;
  }

  formatPercent(percent) {
    if (percent == null || percent === undefined || isNaN(percent)) return "0%";
    const numericPercent = Number(percent);
    if (isNaN(numericPercent)) return "0%";
    return numericPercent.toFixed(1) + "%";
  }

  safeCalculatePercent(numerator, denominator) {
    if (!numerator || !denominator || denominator === 0) return 0;
    const num = Number(numerator);
    const den = Number(denominator);
    if (isNaN(num) || isNaN(den) || den === 0) return 0;
    return (num / den) * 100;
  }

  safeParseNumber(value) {
    if (value == null || value === undefined || value === "") return 0;
    const numericValue = Number(value);
    return isNaN(numericValue) ? 0 : numericValue;
  }

  formatMonthLabel(monthString) {
    if (!monthString) return "";

    try {
      // Handle different date formats
      let date;

      // Check if it's in format "M/D/YYYY" (e.g., "4/1/2024")
      if (monthString.includes("/")) {
        date = new Date(monthString);
      } else {
        // Handle other formats like "2024-04"
        date = new Date(monthString + "-01");
      }

      // Validate the date
      if (isNaN(date.getTime())) {
        console.warn("Invalid date format:", monthString);
        return monthString; // Return original string if parsing fails
      }

      return date.toLocaleDateString("en-US", {
        year: "numeric",
        month: "long"
      });
    } catch (error) {
      console.error("Error formatting month label:", error, monthString);
      return monthString; // Return original string if error occurs
    }
  }

  calculateInvestmentShare(investment) {
    if (!investment || investment === 0) return "0%";
    const total = this.summaryMetrics?.totalInvestment || 1;
    if (!total || total === 0) return "0%";

    const percentage = this.safeCalculatePercent(investment, total);
    return this.formatPercent(percentage);
  }

  calculateInvestmentShareUpdated(investment,total) 
  {
    if (!investment || investment === 0) return "0%";
    //const total = this.summaryMetrics?.totalInvestment || 1;
    if (!total || total === 0) return "0%";

    const percentage = this.safeCalculatePercent(investment, total);
    return this.formatPercent(percentage);
  }

  getPerformanceStatus(actual, target) {
    const actualNum = Number(actual) || 0;
    const targetNum = Number(target) || 0;

    // No Target Set - when target is missing, null, or zero
    if (!target || target === 0) return "No Target Set";

    // No Sales - when actual sales is zero or missing despite having a target
    if (!actual || actual === 0) return "No Sales";

    // Calculate percentage
    const percent = (actualNum / targetNum) * 100;
    if (isNaN(percent)) return "No Sales";

    // On Track - 100% or above achievement
    if (percent >= 100) return "On Track";

    // Behind - less than 100% achievement
    return "Behind";
  }

  getStatusClass(status) {
    switch (status) {
      case "On Track":
      case "OnTrack":
      case "on track":
        return "status-on-track";
      case "Behind Target":
      case "BehindTarget":
      case "behind target":
      case "Behind":
      case "behind":
        return "status-behind";
      case "No Target Set":
      case "NoTargetSet":
      case "no target set":
      case "No Sales":
      case "NoSales":
      case "no sales":
        return "status-no-target";
      default:
        return "status-unknown";
    }
  }

  handleError(message, error) {
    console.error(message, error);
    this.error = error;
    this.showToast("Error", message, "error");
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }

  // Risk Management Helper Methods
  getRiskIcon(riskLevel) {
    switch (riskLevel) {
      case "CRITICAL":
        return "utility:error";
      case "HIGH":
        return "utility:warning";
      case "WARNING":
        return "utility:info";
      case "HEALTHY":
      default:
        return "utility:success";
    }
  }

  getRiskStatusText(riskLevel, failedMonths) {
    switch (riskLevel) {
      case "CRITICAL":
        return `CRITICAL - ${failedMonths}+ Months Behind`;
      case "HIGH":
        return `HIGH RISK - ${failedMonths} Months Behind`;
      case "WARNING":
        return `WARNING - ${failedMonths} Month Behind`;
      case "HEALTHY":
      default:
        return "Meeting Commitments";
    }
  }

  // ===== COMPUTED PROPERTIES =====

  get showFilters() {
    // Always show filters, data loading state is handled by individual components
    return true;
  }

  get formattedTotalInvestment() {
    // Use calculated data if any filters are applied (customers or regions selected)
    const data = this.hasActiveFilters
      ? this.calculatedFinancialData
      : this.financialOverviewPerformanceData;
    return this.formatCurrency(data.financialOverviewTotalInvestment || 0);
  }

  get formattedTotalSales() {
    // Use calculated data if any filters are applied (customers or regions selected)
    const data = this.hasActiveFilters
      ? this.calculatedFinancialData
      : this.financialOverviewPerformanceData;
    return this.formatCurrency(data.financialOverviewTotalSales || 0);
  }

  get formattedCostRecovery() {
    // Use calculated data if any filters are applied (customers or regions selected)
    const data = this.hasActiveFilters
      ? this.calculatedFinancialData
      : this.financialOverviewPerformanceData;
    return data.costRecovery || "0%";
  }

  //financialOverviewTotalMargin
  get formattedTotalMargin() {
    // Use calculated data if any filters are applied (customers or regions selected)
    const data = this.hasActiveFilters
      ? this.calculatedFinancialData
      : this.financialOverviewPerformanceData;
    return this.formatCurrency(data.financialOverviewTotalMargin || 0);
  }

  get formattedCommitmentAchievement() {
    return this.formatPercent(this.summaryMetrics.commitmentAchievementPercent);
  }

  get totalMachines() {
    return this.summaryMetrics.totalMachines || 0;
  }

  get totalSnapshots() {
    return this.summaryMetrics.totalSnapshots || 0;
  }

  // Machine Status Count Getters
  get orderedMachines() {
    const status = this.displayMachineStatusCounts.find(
      (s) => s.status === "Initial Assessment"
    );
    return status ? status.count : 0;
  }

  get installedMachines() {
    const status = this.displayMachineStatusCounts.find(
      (s) => s.status === "Demo"
    );
    return status ? status.count : 0;
  }

  get activeMachines() {
    const status = this.displayMachineStatusCounts.find(
      (s) => s.status === "RR"
    );
    return status ? status.count : 0;
  }

  get rejectedMachines() {
    const status = this.displayMachineStatusCounts.find(
      (s) => s.status === "Return"
    );
    return status ? status.count : 0;
  }

  get inactiveMachines() {
    const status = this.displayMachineStatusCounts.find(
      (s) => s.status === "Inactive"
    );
    return status ? status.count : 0;
  }

  // Customer Commitment Status Count Getters (for overview tiles - using ALL data)
  get noTargetCustomers() {
    return this.overviewMetrics.noTargetCustomers;
  }

  get behindTargetCustomers() {
    return this.overviewMetrics.behindTargetCustomers;
  }

  get onTrackCustomers() {
    return this.overviewMetrics.onTrackCustomers;
  }

  // Keep for backward compatibility
  get behindCustomers() {
    return this.behindTargetCustomers;
  }

  // Helper method to count customers by commitment status
  getCustomerCountByCommitmentStatus(status) {
    if (!this.filteredData || this.filteredData.length === 0) {
      return 0;
    }

    // Group by customer code and get unique customers with their performance status
    const uniqueCustomers = {};
    this.filteredData.forEach((record) => {
      if (record.customerCode && record.performanceStatus) {
        uniqueCustomers[record.customerCode] = record.performanceStatus;
      }
    });

    // Count customers with the specified commitment status
    const matchingCount = Object.values(uniqueCustomers).filter(
      (performanceStatus) => performanceStatus === status
    ).length;

    return matchingCount;
  }

  get costRecoveryClass() {
    const percent = this.summaryMetrics.costRecoveryPercent || 0;
    return percent >= 100 ? "positive" : percent >= 80 ? "warning" : "negative";
  }

  get costRecoveryIcon() {
    const percent = this.summaryMetrics.costRecoveryPercent || 0;
    return percent >= 100
      ? "utility:success"
      : percent >= 80
        ? "utility:warning"
        : "utility:error";
  }

  // Risk Management Getters
  get hasCriticalCustomers() {
    return this.criticalCustomers && this.criticalCustomers.length > 0;
  }

  get hasWarningCustomers() {
    return this.warningCustomers && this.warningCustomers.length > 0;
  }

  get hasHighCustomers() {
    return this.highCustomers && this.highCustomers.length > 0;
  }

  get hasAnyRiskCustomers() {
    return (
      this.hasCriticalCustomers ||
      this.hasWarningCustomers ||
      this.hasHighCustomers
    );
  }

  get formattedRiskSummary() {
    // Use overview metrics for the tiles (calculated from ALL data, not filtered)
    // const critical = this.overviewMetrics.criticalCustomers;
    // const warning = this.overviewMetrics.warningCustomers;
    // const high = this.overviewMetrics.highRiskCustomers;
    // const healthy = this.overviewMetrics.healthyCustomers;
    const critical = this.riskAnalysis.critical;
    const warning = this.riskAnalysis.warning;
    const high = this.riskAnalysis.highrisk;
    const healthy = this.riskAnalysis.healthy;
    const total = this.overviewMetrics.totalCustomers;

    return {
      criticalCount: critical,
      warningCount: warning,
      highCount: high,
      healthyCount: healthy,
      totalCustomersAnalyzed: total,
      behindCount: this.overviewMetrics.behindTargetCustomers,
      discrepancy: this.overviewMetrics.behindTargetCustomers - warning
    };
  }

  get achievementClass() {
    const percent = this.summaryMetrics.commitmentAchievementPercent || 0;
    return percent >= 100 ? "positive" : percent >= 80 ? "warning" : "negative";
  }

  get achievementIcon() {
    const percent = this.summaryMetrics.commitmentAchievementPercent || 0;
    return percent >= 100
      ? "utility:success"
      : percent >= 80
        ? "utility:warning"
        : "utility:error";
  }

  // Pagination computed properties
  get totalPages() {
    return Math.ceil(this.totalRecords / this.pageSize);
  }

  get totalDetailPages() {
    return Math.ceil(this.detailedtotalRecords / this.detailedPageSize);
  }

  get startRecord() {
    return this.totalRecords > 0
      ? (this.currentPage - 1) * this.pageSize + 1
      : 0;
  }

  get endRecord() {
    return Math.min(this.currentPage * this.pageSize, this.totalRecords);
  }

  get isFirstPage() {
    return this.currentPage <= 1;
  }

  get isLastPage() {
    return this.currentPage >= this.totalPages;
  }

  get isDetailedFirstPage() {
    return this.detailedCurrentPage <= 1;
  }

  get isDetailedLastPage() {
    return this.detailedCurrentPage >= this.totalDetailPages;
  }

  get paginatedData() {
    const start = (this.currentPage - 1) * this.pageSize;
    const end = start + this.pageSize;
    return this.filteredData.slice(start, end);
  }

   get detailedPaginatedData() {
    const start = (this.detailedCurrentPage - 1) * this.detailedPageSize;
    const end = start + this.detailedPageSize;
    return this.filteredDetailedData.slice(start, end);
  }

  // View mode computed properties
  get isCardView() {
    return this.customerViewMode === "cards";
  }

  get isTableView() {
    return this.customerViewMode === "table";
  }

  get viewModeOptions() {
    return [
      { label: "Card View", value: "cards" },
      { label: "Table View", value: "table" }
    ];
  }

  // Customer card data for pagination
  get paginatedCustomerInvestmentData() {
    const start = (this.currentPage - 1) * this.pageSize;
    const end = start + this.pageSize;
    return this.customerInvestmentData.slice(start, end);
  }

  get paginatedCustomerCommitmentData() {
    const start = (this.currentPage - 1) * this.pageSize;
    const end = start + this.pageSize;
    // console.log(
    //   ">>>>businessCaseDashboard.js-->paginatedCustomerCommitmentData-->customerCommitmentData: " +
    //     JSON.stringify(this.customerCommitmentData)
    // );
    // console.log(
    //   ">>>>businessCaseDashboard.js-->paginatedCustomerCommitmentData-->customerCommitmentData sliced: " +
    //     JSON.stringify(this.customerCommitmentData.slice(start, end))
    // );
    return this.customerCommitmentData.slice(start, end);
  }

  // Data table columns
  get regionalInvestmentColumns()
  {
    const currentYear = new Date().getFullYear();

    const baseColumns = [
      {
        label: "Region",
        fieldName: "region",
        type: "text",
        cellAttributes: { class: { fieldName: "rowClass" } }
      },
      {
        label: "Machines",
        fieldName: "machines",
        type: "number",
        cellAttributes: { class: { fieldName: "rowClass" } }
      },
      {
        label: "Investment",
        fieldName: "formattedInvestment",
        type: "text",
        cellAttributes: { class: { fieldName: "rowClass" } }
      },
      {
        label: "Total Sales",
        fieldName: "formattedTotalSales",
        type: "text",
        cellAttributes: { class: { fieldName: "rowClass" } }
      },
      {
        label: "Monthly Commitment",
        fieldName: "formattedCommitment",
        type: "text",
        cellAttributes: { class: { fieldName: "rowClass" } }
      },
      {
        label: `${currentYear - 2} YTD`,
        fieldName: "formattedLastToLastYearYtdSales",
        type: "text",
        cellAttributes: { class: { fieldName: "rowClass" } }
      },
      {
        label: `${currentYear - 1} YTD`,
        fieldName: "formattedLastYearYtdSales",
        type: "text",
        cellAttributes: { class: { fieldName: "rowClass" } }
      },
      {
        label: `${currentYear} YTD`,
        fieldName: "formattedYtdSales",
        type: "text",
        cellAttributes: { class: { fieldName: "rowClass" } }
      },
      {
        label: "Margin",
        fieldName: "formattedMargin",
        type: "text",
        cellAttributes: { class: { fieldName: "rowClass" } }
      },
      {
        label: "Investment Share",
        fieldName: "investmentSharePercent",
        type: "text",
        cellAttributes: { class: { fieldName: "rowClass" } }
      }
    ];


    console.log('regionalInvestmentColumns-->snapshotData: '+this.snapshotData.length);

    console.log('regionalInvestmentColumns-->snapshotData: '+JSON.stringify(this.snapshotData));



    console.log('regionalInvestmentColumns-->filtered data: '+JSON.stringify(this.filteredData));

    if(this.snapshotData.length > 0)
    {
      const monthKeys = Object.keys(this.snapshotData[0].monthlySales || {}).slice().reverse();
      console.log('regionalInvestmentColumns-->monthKeys: '+JSON.stringify(monthKeys));
      const monthColumns = monthKeys.map(month => ({
            label: month,                          // "Apr 2026" â€” no underscore
            fieldName: month.replace(' ', '_'),    // "Apr_2026" â€” LWC field key
            type: 'text',
            cellAttributes: { alignment: 'right' }
        }));

        console.log('regionalInvestmentColumns-->monthColumns: '+JSON.stringify(monthColumns));

        const regInvAvgCol = {
          label: 'Last 6 Months Average',
          fieldName: 'lastMonthAvg',
          type: 'text',
          cellAttributes: { alignment: 'right' }
        };

        const regInvCommitPctCol = {
          label: 'L6M Avg vs Commitment %',
          fieldName: 'lastMonthAvgCommitPercent',
          type: 'text',
          cellAttributes: { alignment: 'right' }
        };

        var finalcolumns = [...baseColumns, ...monthColumns, regInvAvgCol, regInvCommitPctCol];

        console.log('regionalInvestmentColumns-->finalcolumns: '+JSON.stringify(finalcolumns));

        return finalcolumns;
    }

    console.log('regionalInvestmentColumns-->baseColumns: '+JSON.stringify(baseColumns));

    return baseColumns;
  }

  get supplierInvestmentColumns()
  {
    const currentYear = new Date().getFullYear();

    const baseColumns = [
      {
        label: "Supplier",
        fieldName: "supplier",
        type: "text",
        cellAttributes: { class: { fieldName: "rowClass" } }
      },
      {
        label: "Machines",
        fieldName: "machines",
        type: "number",
        cellAttributes: { class: { fieldName: "rowClass" } }
      },
      {
        label: "Investment",
        fieldName: "formattedInvestment",
        type: "text",
        cellAttributes: { class: { fieldName: "rowClass" } }
      },
      {
        label: "Total Sales",
        fieldName: "formattedTotalSales",
        type: "text",
        cellAttributes: { class: { fieldName: "rowClass" } }
      },
      {
        label: "Monthly Commitment",
        fieldName: "formattedCommitment",
        type: "text",
        cellAttributes: { class: { fieldName: "rowClass" } }
      },
      {
        label: `${currentYear - 2} YTD`,
        fieldName: "formattedLastToLastYearYtdSales",
        type: "text",
        cellAttributes: { class: { fieldName: "rowClass" } }
      },
      {
        label: `${currentYear - 1} YTD`,
        fieldName: "formattedLastYearYtdSales",
        type: "text",
        cellAttributes: { class: { fieldName: "rowClass" } }
      },
      {
        label: `${currentYear} YTD`,
        fieldName: "formattedYtdSales",
        type: "text",
        cellAttributes: { class: { fieldName: "rowClass" } }
      },
      {
        label: "Margin",
        fieldName: "formattedMargin",
        type: "text",
        cellAttributes: { class: { fieldName: "rowClass" } }
      },
      {
        label: "Investment Share",
        fieldName: "investmentSharePercent",
        type: "text",
        cellAttributes: { class: { fieldName: "rowClass" } }
      }
    ];

    console.log('supplierInvestmentColumns-->snapshotData: '+this.snapshotData.length);

    console.log('supplierInvestmentColumns-->snapshotData: '+JSON.stringify(this.snapshotData));



    console.log('supplierInvestmentColumns-->filtered data: '+JSON.stringify(this.filteredData));

    if(this.snapshotData.length > 0)
    {
      const monthKeys = Object.keys(this.snapshotData[0].monthlySales || {}).slice().reverse();
      console.log('supplierInvestmentColumns-->monthKeys: '+JSON.stringify(monthKeys));
      const monthColumns = monthKeys.map(month => ({
            label: month,                          // "Apr 2026" â€” no underscore
            fieldName: month.replace(' ', '_'),    // "Apr_2026" â€” LWC field key
            type: 'text',
            cellAttributes: { alignment: 'right' }
        }));

        console.log('supplierInvestmentColumns-->monthColumns: '+JSON.stringify(monthColumns));

        const supInvAvgCol = {
          label: 'Last 6 Months Average',
          fieldName: 'lastMonthAvg',
          type: 'text',
          cellAttributes: { alignment: 'right' }
        };

        const supInvCommitPctCol = {
          label: 'L6M Avg vs Commitment %',
          fieldName: 'lastMonthAvgCommitPercent',
          type: 'text',
          cellAttributes: { alignment: 'right' }
        };

        var finalcolumns = [...baseColumns, ...monthColumns, supInvAvgCol, supInvCommitPctCol];

        console.log('supplierInvestmentColumns-->finalcolumns: '+JSON.stringify(finalcolumns));

        return finalcolumns;
    }

    console.log('supplierInvestmentColumns-->baseColumns: '+JSON.stringify(baseColumns));

    return baseColumns;

  }

  get customerInvestmentColumns() {
    const currentYear = new Date().getFullYear();

    const baseColumns = [
      { label: "#", fieldName: "rowNumber", type: "number", initialWidth: 60, cellAttributes: { class: { fieldName: "rowClass" } } },
      { label: "Customer Number", fieldName: "customerCode", type: "text", cellAttributes: { class: { fieldName: "rowClass" } } },
      { label: "Customer Name",   fieldName: "customerName", type: "text", cellAttributes: { class: { fieldName: "rowClass" } } },
      { label: "Risk Level",      fieldName: "riskLevel",    type: "text", initialWidth: 110, cellAttributes: { class: { fieldName: "rowClass" } } },
      { label: "Supplier",        fieldName: "vendor",       type: "text", cellAttributes: { class: { fieldName: "rowClass" } } },
      { label: "Machines",        fieldName: "machines",     type: "number", cellAttributes: { class: { fieldName: "rowClass" } } },
      { label: "Investment",      fieldName: "formattedInvestment", type: "text", cellAttributes: { class: { fieldName: "rowClass" } } },
      { label: "Total Sales",     fieldName: "formattedTotalSales", type: "text", cellAttributes: { class: { fieldName: "rowClass" } } },
      { label: "Monthly Commitment", fieldName: "formattedCommitment", type: "text", cellAttributes: { class: { fieldName: "rowClass" } } },
      { label: `${currentYear - 2} YTD`, fieldName: "formattedLastToLastYearYtdSales", type: "text", cellAttributes: { class: { fieldName: "rowClass" } } },
      { label: `${currentYear - 1} YTD`, fieldName: "formattedLastYearYtdSales",       type: "text", cellAttributes: { class: { fieldName: "rowClass" } } },
      { label: `${currentYear} YTD`,     fieldName: "formattedYtdSales",               type: "text", cellAttributes: { class: { fieldName: "rowClass" } } }
    ];

    if (this.snapshotData.length > 0) {
      const monthKeys = Object.keys(this.snapshotData[0].monthlySales || {}).slice().reverse();
      const monthColumns = monthKeys.map(month => ({
        label: month,
        fieldName: month.replace(' ', '_'),
        type: 'text',
        cellAttributes: { alignment: 'right' }
      }));

      return [
        ...baseColumns,
        ...monthColumns,
        { label: 'Last 6 Months Average',    fieldName: 'lastMonthAvg',            type: 'text', cellAttributes: { alignment: 'right' } },
        { label: 'L6M Avg vs Commitment %',  fieldName: 'lastMonthAvgCommitPercent', type: 'text', cellAttributes: { alignment: 'right' } }
      ];
    }

    return baseColumns;
  }

  get regionalCommitmentColumns() 
  {
    const baseColumns = [{
        label: "Region",
        fieldName: "region",
        type: "text",
        cellAttributes: { class: { fieldName: "rowClass" } }
      },
      {
        label: "Machines",
        fieldName: "machines",
        type: "number",
        cellAttributes: { class: { fieldName: "rowClass" } }
      },
      {
        label: "Investment",
        fieldName: "formattedInvestment",
        type: "text",
        cellAttributes: { class: { fieldName: "rowClass" } }
      },
      {
        label: "Monthly Commitment",
        fieldName: "formattedCommitment",
        type: "text",
        cellAttributes: { class: { fieldName: "rowClass" } }
      },
      // {
      //   label: "Monthly Sales",
      //   fieldName: "formattedMonthlySales",
      //   type: "text",
      //   cellAttributes: { class: { fieldName: "rowClass" } }
      // },
      {
        label: "Avg Reagent Sales Per Month",
        fieldName: "formattedAvgSales",
        type: "text",
        cellAttributes: { class: { fieldName: "rowClass" } }
      },
      {
        label: "Achievement %",
        fieldName: "achievementPercent",
        type: "text",
        cellAttributes: { class: { fieldName: "rowClass" } }
      }];

    console.log('regionalCommitmentColumns-->snapshotData: '+this.snapshotData.length);

    console.log('regionalCommitmentColumns-->snapshotData: '+JSON.stringify(this.snapshotData));

    

    console.log('regionalCommitmentColumns-->filtered data: '+JSON.stringify(this.filteredData));

    if(this.snapshotData.length > 0)
    {
      const monthKeys = Object.keys(this.snapshotData[0].monthlySales || {});
      console.log('regionalCommitmentColumns-->monthKeys: '+JSON.stringify(monthKeys));
      const monthColumns = monthKeys.map(month => ({
            label: month,                          // "Apr 2026" â€” no underscore
            fieldName: month.replace(' ', '_'),    // "Apr_2026" â€” LWC field key
            type: 'text',
            cellAttributes: { alignment: 'right' }
        }));

        console.log('regionalCommitmentColumns-->monthColumns: '+JSON.stringify(monthColumns));

        const avgColumn = {
          label: 'Last 6 Months Average',
          fieldName: 'lastMonthAvg',
          type: 'text',
          cellAttributes: { alignment: 'right' }
        };

        var finalcolumns = [...baseColumns, ...monthColumns, avgColumn];

        console.log('regionalCommitmentColumns-->finalcolumns: '+JSON.stringify(finalcolumns));

        return finalcolumns;
    }

    console.log('regionalCommitmentColumns-->baseColumns: '+JSON.stringify(baseColumns));

    return baseColumns;
  }

  get supplierCommitmentColumns() 
  {

    const baseColumns = 
    [
      {
        label: "Supplier",
        fieldName: "supplier",
        type: "text",
        cellAttributes: { class: { fieldName: "rowClass" } }
      },
      {
        label: "Machines",
        fieldName: "machines",
        type: "number",
        cellAttributes: { class: { fieldName: "rowClass" } }
      },
      {
        label: "Investment",
        fieldName: "formattedInvestment",
        type: "text",
        cellAttributes: { class: { fieldName: "rowClass" } }
      },
      {
        label: "Monthly Commitment",
        fieldName: "formattedCommitment",
        type: "text",
        cellAttributes: { class: { fieldName: "rowClass" } }
      },
      // {
      //   label: "Monthly Sales",
      //   fieldName: "formattedMonthlySales",
      //   type: "text",
      //   cellAttributes: { class: { fieldName: "rowClass" } }
      // },
      {
        label: "Avg Reagent Sales Per Month",
        fieldName: "formattedAvgSales",
        type: "text",
        cellAttributes: { class: { fieldName: "rowClass" } }
      },
      {
        label: "Achievement %",
        fieldName: "achievementPercent",
        type: "text",
        cellAttributes: { class: { fieldName: "rowClass" } }
      }
    ];

    console.log('supplierCommitmentColumns-->snapshotData: '+this.snapshotData.length);

    console.log('supplierCommitmentColumns-->snapshotData: '+JSON.stringify(this.snapshotData));

    

    console.log('supplierCommitmentColumns-->filtered data: '+JSON.stringify(this.filteredData));

    if(this.snapshotData.length > 0)
    {
      const monthKeys = Object.keys(this.snapshotData[0].monthlySales || {});
      console.log('supplierCommitmentColumns-->monthKeys: '+JSON.stringify(monthKeys));
      const monthColumns = monthKeys.map(month => ({
            label: month,                          // "Apr 2026" â€” no underscore
            fieldName: month.replace(' ', '_'),    // "Apr_2026" â€” LWC field key
            type: 'text',
            cellAttributes: { alignment: 'right' }
        }));

        console.log('supplierCommitmentColumns-->monthColumns: '+JSON.stringify(monthColumns));

        const supComAvgCol = {
          label: 'Last 6 Months Average',
          fieldName: 'lastMonthAvg',
          type: 'text',
          cellAttributes: { alignment: 'right' }
        };

        var finalcolumns = [...baseColumns, ...monthColumns, supComAvgCol];

        console.log('supplierCommitmentColumns-->finalcolumns: '+JSON.stringify(finalcolumns));

        return finalcolumns;
    }

    console.log('supplierCommitmentColumns-->baseColumns: '+JSON.stringify(baseColumns));

    return baseColumns;

    
  }

  get customerCommitmentColumns() {
    return [
      // Customer Identification
      { label: "Customer Code", fieldName: "customerCode", type: "text" },
      { label: "Customer Name", fieldName: "customerName", type: "text" },
      { label: "Supplier", fieldName: "vendor", type: "text" },
      { label: "Technology", fieldName: "technology", type: "text" },
      { label: "Region", fieldName: "region", type: "text" },

      // Bill To Address (simplified)
      { label: "Bill To City", fieldName: "city", type: "text" },
      {
        label: "Bill To Address Line 1",
        fieldName: "addressLine1",
        type: "text"
      },
      {
        label: "Bill To Address Line 2",
        fieldName: "addressLine2",
        type: "text"
      },

      // Ship To Account (simplified)
      {
        label: "Ship To Customer Number",
        fieldName: "shipToCustomerNumber",
        type: "text"
      },
      {
        label: "Ship To Customer Name",
        fieldName: "shipToCustomerName",
        type: "text"
      },
      { label: "Ship To City", fieldName: "shipToCity", type: "text" },
      {
        label: "Ship To Address Line 1",
        fieldName: "shipToAddressLine1",
        type: "text"
      },
      {
        label: "Ship To Address Line 2",
        fieldName: "shipToAddressLine2",
        type: "text"
      },

      // Performance Metrics
      { label: "Machines", fieldName: "machines", type: "number" },
      {
        label: "Monthly Commitment",
        fieldName: "formattedCommitment",
        type: "text"
      },
      {
        label: "Avg Monthly Sales",
        fieldName: "formattedAvgSales",
        type: "text"
      },
      { label: "Achievement %", fieldName: "achievementPercent", type: "text" },
      {
        label: "Status",
        fieldName: "performanceStatus",
        type: "text",
        cellAttributes: {
          class: { fieldName: "statusClass" }
        }
      },
      {
        type: "action",
        typeAttributes: {
          rowActions: [{ label: "View Details", name: "view_details" }]
        }
      }
    ];
  }

  get detailedColumns() {
    return [
      { label: "Customer", fieldName: "customerName", type: "text" },
      { label: "Code", fieldName: "customerCode", type: "text" },
      { label: "Business Case", fieldName: "businessCase", type: "text" },
      { label: "Region", fieldName: "region", type: "text" },
      { label: "Supplier", fieldName: "vendor", type: "text" },
      { label: "Technology", fieldName: "technology", type: "text" },
      { label: "Month", fieldName: "formattedMonth", type: "text" },
      { label: "Sales", fieldName: "formattedSales", type: "text" },
      { label: "Target", fieldName: "formattedTarget", type: "text" },
      { label: "Achievement", fieldName: "formattedAchievement", type: "text" },
      { label: "Status", fieldName: "performanceStatus", type: "text" },
      {
        type: "action",
        typeAttributes: {
          rowActions: [{ label: "View Details", name: "view_details" }]
        }
      }
    ];
  }

  get detailedSnapshotColumns() {
    return [
      { label: "Customer", fieldName: "customerName", type: "text" },
      { label: "Code", fieldName: "customerCode", type: "text" },
      { label: "Business Case", fieldName: "businessCaseName", type: "text" },
      { label: "Region", fieldName: "region", type: "text" },
      { label: "Supplier", fieldName: "supplier", type: "text" },
      { label: "Technology", fieldName: "technology", type: "text" },
      { label: "Month", fieldName: "month", type: "text" },
      { label: "Sales", fieldName: "formattedSales", type: "text" },
      { label: "Target", fieldName: "formattedTarget", type: "text" },
      { label: "YTD Sales", fieldName: "formattedYtdSales", type: "text" },
      { label: "Avg YTD Sales", fieldName: "formattedAvgYtdSales", type: "text" }
      // ,
      // {
      //   type: "action",
      //   typeAttributes: {
      //     rowActions: [{ label: "View Details", name: "view_details" }]
      //   }
      // }
    ];
  }

  // ===== TREND ANALYSIS FUNCTIONALITY =====

  // Trend Control Properties
  @track trendViewMode = "overall"; // "overall", "regional", "supplier", "customer"
  @track selectedTimeRange = "6months"; // "3months", "6months", "12months", "all"
  @track selectedTrendSegment = "all"; // "all", "region", "supplier", "customer"

  // Risk Monitoring Properties
  @track riskMonitoringData = [];
  @track criticalCustomers = [];
  @track warningCustomers = [];
  @track highCustomers = [];
  @track customerRiskAnalysis = new Map();

  // Risk Management Columns for DataTable
  riskManagementColumns = [
    {
      label: "Business Case",
      fieldName: "businessCaseId",
      type: "url",
      typeAttributes: {
        label: { fieldName: "businessCaseName" },
        target: "_blank"
      },
      cellAttributes: { class: "slds-text-link" }
    },
    {
      label: "Customer Code",
      fieldName: "customerCode",
      type: "text",
      cellAttributes: { class: "slds-text-title_caps" }
    },
    {
      label: "Customer Name",
      fieldName: "customerName",
      type: "text",
      wrapText: true
    },
    {
      label: "Region",
      fieldName: "regionName",
      type: "text"
    },
    {
      label: "Supplier",
      fieldName: "supplierName",
      type: "text"
    },
    {
      label: "Achievement %",
      fieldName: "currentAchievementPercentage",
      type: "percent",
      typeAttributes: {
        minimumFractionDigits: 1,
        maximumFractionDigits: 1
      },
      cellAttributes: {
        class: { fieldName: "achievementClass" },
        alignment: "center"
      }
    },
    {
      label: "Failed Months",
      fieldName: "consecutiveFailedMonths",
      type: "number",
      cellAttributes: { alignment: "center" }
    },
    {
      label: "Risk Level",
      fieldName: "riskLevel",
      type: "text",
      cellAttributes: {
        class: { fieldName: "riskLevelClass" },
        alignment: "center"
      }
    },
    {
      label: "Action Required",
      fieldName: "actionRequired",
      type: "text",
      wrapText: true,
      cellAttributes: {
        class: { fieldName: "actionClass" }
      }
    }
  ];

  // Chart visibility flags
  @track showRegionalTrends = false;
  @track showSupplierTrends = false;
  @track showCustomerTrends = false;
  @track showRegionalCommitmentTrends = false;
  @track showSupplierCommitmentTrends = false;
  @track showCustomerHealthTrends = false;

  // Chart instances storage
  investmentVsSalesChart = null;
  costRecoveryChart = null;
  roiEfficiencyChart = null;
  regionalInvestmentChart = null;
  supplierInvestmentChart = null;
  customerInvestmentChart = null;
  targetVsActualChart = null;
  performanceStatusChart = null;
  achievementRateChart = null;
  regionalCommitmentChart = null;
  supplierCommitmentChart = null;
  customerHealthChart = null;

  // Trend Options
  get trendViewOptions() {
    return [
      { label: "Overall Trends", value: "overall" },
      { label: "Regional Analysis", value: "regional" },
      { label: "Supplier Analysis", value: "supplier" },
      { label: "Customer Analysis", value: "customer" }
    ];
  }

  get timeRangeOptions() {
    return [
      { label: "Last 3 Months", value: "3months" },
      { label: "Last 6 Months", value: "6months" },
      { label: "Last 12 Months", value: "12months" },
      { label: "All Time", value: "all" }
    ];
  }

  get trendSegmentOptions() {
    return [
      { label: "All Data", value: "all" },
      { label: "By Region", value: "region" },
      { label: "By Supplier", value: "supplier" },
      { label: "By Customer", value: "customer" }
    ];
  }

  // Trend Event Handlers
  handleTrendViewChange(event) {
    this.trendViewMode = event.detail.value;
    this.updateTrendVisibility();
    this.initializeTrendCharts();
  }

  handleTimeRangeChange(event) {
    this.selectedTimeRange = event.detail.value;
    this.updateTrendCharts();
  }

  handleTrendSegmentChange(event) {
    this.selectedTrendSegment = event.detail.value;
    this.updateTrendVisibility();
    this.updateTrendCharts();
  }

  // Update trend chart visibility based on selection
  updateTrendVisibility() {
    this.showRegionalTrends =
      this.trendViewMode === "regional" ||
      this.selectedTrendSegment === "region";
    this.showSupplierTrends =
      this.trendViewMode === "supplier" ||
      this.selectedTrendSegment === "supplier";
    this.showCustomerTrends =
      this.trendViewMode === "customer" ||
      this.selectedTrendSegment === "customer";

    // Commitment trends visibility
    this.showRegionalCommitmentTrends = this.showRegionalTrends;
    this.showSupplierCommitmentTrends = this.showSupplierTrends;
    this.showCustomerHealthTrends = this.showCustomerTrends;
  }

  // Initialize trend charts based on active tab
  initializeTrendCharts() {
    if (this.activeTab === "investment-trends") {
      this.initializeInvestmentTrendCharts();
    } else if (this.activeTab === "commitment-trends") {
      this.initializeCommitmentTrendCharts();
    }
  }

  // Initialize Investment Trend Charts
  initializeInvestmentTrendCharts() {
    try {
      this.createInvestmentVsSalesChart();
      this.createCostRecoveryChart();
      this.createROIEfficiencyChart();

      if (this.showRegionalTrends) {
        this.createRegionalInvestmentChart();
      }
      if (this.showSupplierTrends) {
        this.createSupplierInvestmentChart();
      }
      if (this.showCustomerTrends) {
        this.createCustomerInvestmentChart();
      }
    } catch (error) {
      console.error("Error initializing investment trend charts:", error);
    }
  }

  // Initialize Commitment Trend Charts
  initializeCommitmentTrendCharts() {
    try {
      this.createTargetVsActualChart();
      this.createPerformanceStatusChart();
      this.createAchievementRateChart();

      if (this.showRegionalCommitmentTrends) {
        this.createRegionalCommitmentChart();
      }
      if (this.showSupplierCommitmentTrends) {
        this.createSupplierCommitmentChart();
      }
      if (this.showCustomerHealthTrends) {
        this.createCustomerHealthChart();
      }
    } catch (error) {
      console.error("Error initializing commitment trend charts:", error);
    }
  }

  // Chart Creation Methods (Basic Implementation)
  createInvestmentVsSalesChart() {
    const canvas = this.template.querySelector("#investmentVsSalesChart");
    if (!canvas) return;

    // Destroy existing chart if it exists
    if (this.investmentVsSalesChart) {
      this.investmentVsSalesChart.destroy();
    }

    // TODO: Implement actual Chart.js chart with real data
  }

  createCostRecoveryChart() {
    const canvas = this.template.querySelector("#costRecoveryChart");
    if (!canvas) return;

    if (this.costRecoveryChart) {
      this.costRecoveryChart.destroy();
    }

    // TODO: Implement actual Chart.js chart
  }

  createROIEfficiencyChart() {
    const canvas = this.template.querySelector("#roiEfficiencyChart");
    if (!canvas) return;

    if (this.roiEfficiencyChart) {
      this.roiEfficiencyChart.destroy();
    }

    // TODO: Implement actual Chart.js chart
  }

  createTargetVsActualChart() {
    const canvas = this.template.querySelector("#targetVsActualChart");
    if (!canvas || !this.chartJSLoaded || !window.Chart) {
      // console.log("Canvas not found or Chart.js not loaded yet");
      return;
    }

    if (this.targetVsActualChart) {
      this.targetVsActualChart.destroy();
    }

    try {
      // Prepare data from filtered snapshot data for trend analysis
      const trendData = this.prepareTrendData();

      const ctx = canvas.getContext("2d");
      this.targetVsActualChart = new window.Chart(ctx, {
        type: "line",
        data: {
          labels: trendData.months,
          datasets: [
            {
              label: "Target Sales",
              data: trendData.targets,
              borderColor: "#1B96FF",
              backgroundColor: "rgba(27, 150, 255, 0.1)",
              tension: 0.4,
              borderWidth: 3,
              pointBackgroundColor: "#1B96FF",
              pointBorderColor: "#ffffff",
              pointBorderWidth: 2,
              pointRadius: 6
            },
            {
              label: "Actual Sales",
              data: trendData.actuals,
              borderColor: "#06D6A0",
              backgroundColor: "rgba(6, 214, 160, 0.1)",
              tension: 0.4,
              borderWidth: 3,
              pointBackgroundColor: "#06D6A0",
              pointBorderColor: "#ffffff",
              pointBorderWidth: 2,
              pointRadius: 6
            }
          ]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            title: {
              display: true,
              text: "Target vs Actual Sales Performance Over Time",
              font: {
                size: 16,
                weight: "bold"
              },
              padding: 20
            },
            legend: {
              display: true,
              position: "top",
              labels: {
                usePointStyle: true,
                padding: 20,
                font: {
                  size: 12
                }
              }
            },
            tooltip: {
              mode: "index",
              intersect: false,
              backgroundColor: "rgba(0, 0, 0, 0.8)",
              titleColor: "#ffffff",
              bodyColor: "#ffffff",
              borderColor: "#1B96FF",
              borderWidth: 1,
              cornerRadius: 8,
              displayColors: true,
              callbacks: {
                label: function (context) {
                  const value = new Intl.NumberFormat("en-US").format(
                    context.parsed.y
                  );
                  return `${context.dataset.label}: Rs.${value}`;
                }
              }
            }
          },
          scales: {
            x: {
              display: true,
              title: {
                display: true,
                text: "Month",
                font: {
                  size: 14,
                  weight: "bold"
                }
              },
              grid: {
                display: true,
                color: "rgba(0, 0, 0, 0.1)"
              }
            },
            y: {
              display: true,
              title: {
                display: true,
                text: "Sales Amount (Rs.)",
                font: {
                  size: 14,
                  weight: "bold"
                }
              },
              grid: {
                display: true,
                color: "rgba(0, 0, 0, 0.1)"
              },
              ticks: {
                callback: function (value) {
                  return "Rs." + new Intl.NumberFormat("en-US").format(value);
                }
              }
            }
          },
          interaction: {
            mode: "nearest",
            axis: "x",
            intersect: false
          }
        }
      });

      // console.log(
      //   "ðŸ“ˆ Target vs Actual chart created successfully with",
      //   trendData.months.length,
      //   "data points"
      // );
    } catch (error) {
      console.error("âŒ Error creating Target vs Actual chart:", error);
      this.showToast(
        "Error",
        "Failed to create Target vs Actual chart",
        "error"
      );
    }
  }

  createPerformanceStatusChart() {
    const canvas = this.template.querySelector("#performanceStatusChart");
    if (!canvas) return;

    if (this.performanceStatusChart) {
      this.performanceStatusChart.destroy();
    }

    // TODO: Implement actual Chart.js chart
  }

  createAchievementRateChart() {
    const canvas = this.template.querySelector("#achievementRateChart");
    if (!canvas) return;

    if (this.achievementRateChart) {
      this.achievementRateChart.destroy();
    }

    // TODO: Implement actual Chart.js chart
  }

  createRegionalInvestmentChart() {
    // TODO: Implement regional investment chart
  }

  createSupplierInvestmentChart() {
    // TODO: Implement supplier investment chart
  }

  createCustomerInvestmentChart() {
    // TODO: Implement customer investment chart
  }

  createRegionalCommitmentChart() {
    // TODO: Implement regional commitment chart
  }

  createSupplierCommitmentChart() {
    // TODO: Implement supplier commitment chart
  }

  createCustomerHealthChart() {
    // TODO: Implement customer health chart
  }

  // Update existing charts with new data
  updateTrendCharts() {
    if (this.activeTab === "investment-trends") {
      this.updateInvestmentTrendCharts();
    } else if (this.activeTab === "commitment-trends") {
      this.updateCommitmentTrendCharts();
    }
  }

  updateInvestmentTrendCharts() {
    // TODO: Update charts with filtered data based on selectedTimeRange and other filters
  }

  updateCommitmentTrendCharts() {
    // TODO: Update charts with filtered data based on selectedTimeRange and other filters
  }

  // Export handlers
  handleExportInvestmentChart() {
    this.showToast("Info", "Export functionality coming soon", "info");
  }

  handleExportCommitmentChart() {
    this.showToast("Info", "Export functionality coming soon", "info");
  }

  // Data processing methods for trends
  getTrendDataByTimeRange() {
    const filteredSnapshots = this.getFilteredTrendData();
    return this.aggregateTrendDataByMonth(filteredSnapshots);
  }

  getFilteredTrendData() {
    let startDate = new Date();

    switch (this.selectedTimeRange) {
      case "3months":
        startDate.setMonth(startDate.getMonth() - 3);
        break;
      case "6months":
        startDate.setMonth(startDate.getMonth() - 6);
        break;
      case "12months":
        startDate.setFullYear(startDate.getFullYear() - 1);
        break;
      default:
        return this.filteredData; // All time
    }

    return this.filteredData.filter((record) => {
      const recordDate = new Date(record.snapshotMonth);
      return recordDate >= startDate;
    });
  }

  aggregateTrendDataByMonth(data) {
    const monthlyData = {};

    data.forEach((record) => {
      const monthKey = record.formattedMonth;
      if (!monthlyData[monthKey]) {
        monthlyData[monthKey] = {
          month: monthKey,
          totalInvestment: 0,
          totalSales: 0,
          totalTarget: 0,
          recordCount: 0
        };
      }

      monthlyData[monthKey].totalInvestment += record.investmentValue || 0;
      monthlyData[monthKey].totalSales += record.totalReagentSalesTillDate || 0;
      monthlyData[monthKey].totalTarget += record.commitmentValue || 0;
      monthlyData[monthKey].recordCount++;
    });

    return Object.values(monthlyData).sort(
      (a, b) => new Date(a.month) - new Date(b.month)
    );
  }

  // ===== CUSTOMER COMMITMENT MONITORING & RISK ANALYSIS =====

  // Initial risk analysis method for filtering purposes (uses all snapshot data)
  performInitialRiskAnalysis() {
    // console.log("ðŸ” DEBUG: Starting performInitialRiskAnalysis");
    // console.log(
    //   "ðŸ” DEBUG: Snapshot data length:",
    //   this.snapshotData?.length || 0
    // );

    this.customerRiskAnalysis.clear();

    // Group ALL snapshot data by customer (not filtered data)
    const customerMonthlyData = this.groupDataByCustomerAndMonth(
      this.snapshotData
    );

    // console.log(
    //   "ðŸ” DEBUG: Customer monthly data size:",
    //   customerMonthlyData?.size || 0
    // );

    // Analyze each customer's trend
    for (const [
      customerCode,
      monthlyRecords
    ] of customerMonthlyData.entries()) {
      const riskProfile = this.calculateCustomerRiskProfile(
        customerCode,
        monthlyRecords
      );
      // console.log(
      //   `ðŸ” DEBUG: Customer ${customerCode} risk profile:`,
      //   riskProfile
      // );
      this.customerRiskAnalysis.set(customerCode, riskProfile);
    }

    // console.log(
    //   "ðŸ” DEBUG: Final risk analysis size:",
    //   this.customerRiskAnalysis.size
    // );
  }

  // Main method to analyze customer commitment trends
  analyzeCustomerCommitmentRisk() {
    this.criticalCustomers = [];
    this.warningCustomers = [];
    this.highCustomers = [];

    // Group data by customer
    const customerMonthlyData = this.groupDataByCustomerAndMonth();

    // Analyze each customer's trend
    for (const [
      customerCode,
      monthlyRecords
    ] of customerMonthlyData.entries()) {
      const riskProfile = this.calculateCustomerRiskProfile(
        customerCode,
        monthlyRecords
      );
      this.customerRiskAnalysis.set(customerCode, riskProfile);

      // Categorize customers based on risk level
      this.categorizeCustomerByRisk(riskProfile);
    }
  }

  // Group data by customer and month for trend analysis
  groupDataByCustomerAndMonth(dataToAnalyze = null) {
    const dataSource = dataToAnalyze || this.filteredData;
    const businessCaseData = new Map();

    const today = new Date();
    const currentMonth = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, "0")}`;

    // Debug: Check all records for customer 3020001237 before grouping
    const customer3020001237Records = dataSource.filter(
      (record) => record.customerCode === "3020001237"
    );

    if (customer3020001237Records.length > 0) {
      // console.log("ðŸ” DEBUG: All filtered records for customer 3020001237:");
      customer3020001237Records.forEach((record, index) => {
        // console.log(`Record ${index + 1}:`, {
        //   customerCode: record.customerCode,
        //   customerName: record.customerName,
        //   snapshotMonth: record.snapshotMonth,
        //   totalReagentSales: record.totalReagentSales,
        //   targetSales: record.targetSales,
        //   businessCaseId: record.businessCaseId,
        //   businessCaseName: record.businessCaseName
        // });
      });
    } else {
      // console.log(
      //   "ðŸš¨ DEBUG: No filtered records found for customer 3020001237"
      // );

      // Check if records exist in original snapshot data
      const originalRecords = this.snapshotData.filter(
        (record) => record.customerCode === "3020001237"
      );

      if (originalRecords.length > 0) {
        // console.log(
        //   "ðŸ” DEBUG: Original snapshot records for customer 3020001237 (before filtering):"
        // );
        // originalRecords.forEach((record, index) => {
        // console.log(`Original Record ${index + 1}:`, {
        //   customerCode: record.customerCode,
        //   customerName: record.customerName,
        //   snapshotMonth: record.snapshotMonth,
        //   totalReagentSales: record.totalReagentSales,
        //   targetSales: record.targetSales,
        //   businessCaseId: record.businessCaseId,
        //   businessCaseName: record.businessCaseName
        // });
        // });
      } else {
        // console.log(
        //   "ðŸš¨ DEBUG: No records found for customer 3020001237 even in original snapshot data"
        // );
      }
    }

    // console.log(
    //   ">>>>businessCaseDashboard-->groupDataByCustomerAndMonth-->datasource lenght: " +
    //     dataSource.length
    // );
    // console.log(
    //   ">>>>businessCaseDashboard-->groupDataByCustomerAndMonth-->datasource: " +
    //     JSON.stringify(dataSource)
    // );

    dataSource.forEach((record) => {
      const businessCaseId = record.businessCaseId;
      const monthKey = record.snapshotMonth;

      if (!businessCaseId || !monthKey) {
        return;
      }

      if (!businessCaseData.has(businessCaseId)) {
        businessCaseData.set(businessCaseId, new Map());
      }
      // console.log(
      //   ">>>>businessCaseDashboard-->groupDataByBusinessCaseAndMonth-->businessCase Name: ",
      //   record.businessCaseName
      // );
      const caseMonths = businessCaseData.get(businessCaseId);
      if (!caseMonths.has(monthKey)) {
        caseMonths.set(monthKey, {
          month: monthKey,
          businessCaseId: record.businessCaseId,
          businessCaseName: record.businessCaseName,
          customerCode: record.customerCode,
          customerName: record.customerName,
          region: record.region,
          vendor: record.vendor,
          businessCaseStatus: record.businessCaseStatus,
          machineStatus: record.machineStatus,
          monthlySales: 0,
          monthlyTarget: 0,
          achievement: 0,
          records: []
        });
      }
      // console.log(
      //   ">>>>businessCaseDashboard-->groupDataByBusinessCaseAndMonth-->caseMonths: ",
      //   JSON.stringify(caseMonths)
      // );

      const monthData = caseMonths.get(monthKey);

      const salesValue =
        record.totalReagentSales ||
        record.Monthly_Reagent_Sales__c ||
        record.avgReagentSalesPerMonth ||
        record.reagentSales ||
        record.monthlySales ||
        0;
      const targetValue =
        record.targetSales ||
        record.Target_Sales__c ||
        record.commitmentPerMonth ||
        record.monthlyTarget ||
        record.target ||
        0;
      monthData.monthlySales += salesValue;
      monthData.monthlyTarget += targetValue;
      monthData.records.push(record);

      // Calculate or retain achievement
      if (record.achievement !== null && record.achievement !== undefined) {
        monthData.achievement = record.achievement;
      } else if (monthData.monthlyTarget > 0) {
        monthData.achievement =
          (monthData.monthlySales / monthData.monthlyTarget) * 100;
      }
      // const customerCode = record.customerCode;
      // const monthKey = record.snapshotMonth;

      // if (!customerCode || !monthKey) {
      //   return;
      // }

      // if (!customerData.has(customerCode)) {
      //   customerData.set(customerCode, new Map());
      // }

      // const customerMonths = customerData.get(customerCode);
      // if (!customerMonths.has(monthKey)) {
      //   customerMonths.set(monthKey, {
      //     month: monthKey,
      //     customerCode: record.customerCode,
      //     customerName: record.customerName,
      //     region: record.region,
      //     vendor: record.vendor,
      //     businessCaseId: record.businessCaseId,
      //     businessCaseName: record.businessCaseName,
      //     businessCaseStatus: record.businessCaseStatus,
      //     machineStatus: record.machineStatus,
      //     monthlySales: 0,
      //     monthlyTarget: 0,
      //     achievement: 0,
      //     records: []
      //   });
      // }
      // console.log('>>>>businessCaseDashboard-->groupDataByCustomerAndMonth-->customerMonths: '+JSON.stringify(customerMonths));
      // const monthData = customerMonths.get(monthKey);

      // // Try multiple field name variations for sales and target
      // const salesValue =
      //   record.totalReagentSales ||
      //   record.Monthly_Reagent_Sales__c ||
      //   record.avgReagentSalesPerMonth ||
      //   record.reagentSales ||
      //   record.monthlySales ||
      //   0;
      // const targetValue =
      //   record.targetSales ||
      //   record.Target_Sales__c ||
      //   record.commitmentPerMonth ||
      //   record.monthlyTarget ||
      //   record.target ||
      //   0;

      // monthData.monthlySales += salesValue;
      // monthData.monthlyTarget += targetValue;
      // monthData.records.push(record);

      // // Use existing achievement if available, otherwise calculate
      // if (record.achievement !== null && record.achievement !== undefined) {
      //   monthData.achievement = record.achievement;
      // } else if (monthData.monthlyTarget > 0) {
      //   monthData.achievement =
      //     (monthData.monthlySales / monthData.monthlyTarget) * 100;
      // }
      // console.log(
      //   ">>>>businessCaseDashboard-->groupDataByCustomerAndMonth-->monthData: " +
      //     JSON.stringify(monthData)
      // );
    });

    // Convert to sorted monthly data for each customer
    // const sortedCustomerData = new Map();
    // for (const [customerCode, monthsMap] of customerData.entries()) {
    //   const sortedMonths = Array.from(monthsMap.values()).sort(
    //     (a, b) => new Date(a.month) - new Date(b.month)
    //   );
    //   sortedCustomerData.set(customerCode, sortedMonths);
    // }

    // console.log('>>>>businessCaseDashboard-->groupDataByCustomerAndMonth-->sortedCustomerData: '+JSON.stringify(sortedCustomerData));
    // ðŸ” Convert to sorted monthly data per Business Case
    const sortedBusinessCaseData = new Map();
    let count = 0;
    for (const [businessCaseId, monthsMap] of businessCaseData.entries()) {
      count++;
      const sortedMonths = Array.from(monthsMap.values()).sort(
        (a, b) => new Date(a.month) - new Date(b.month)
      );

      // âš ï¸ Check if current month is missing â†’ mark as warning
      const hasCurrentMonth = sortedMonths.some(
        (m) => m.month === currentMonth
      );
      if (!hasCurrentMonth) {
        sortedMonths.push({
          month: currentMonth,
          businessCaseId,
          businessCaseName: sortedMonths[0]?.businessCaseName || "N/A",
          status: "Behind",
          warning: true,
          monthlySales: 0,
          monthlyTarget: 0,
          achievement: 0,
          records: []
        });
      }

      sortedBusinessCaseData.set(businessCaseId, sortedMonths);
      // console.log(
      //   ">>>>businessCaseDashboard-->groupDataByBusinessCaseAndMonth-->sortedBusinessCaseData count: ",
      //   count
      // );
      // console.log(
      //   ">>>>businessCaseDashboard-->groupDataByBusinessCaseAndMonth-->sortedBusinessCaseData LENGTH: ",
      //   sortedBusinessCaseData.size
      // );
    }

    // console.log(
    //   ">>>>businessCaseDashboard-->groupDataByBusinessCaseAndMonth-->sortedBusinessCaseData: ",
    //   JSON.stringify(sortedBusinessCaseData)
    // );

    return sortedBusinessCaseData;

    // return sortedCustomerData;
  }

  // Calculate simplified risk profile for a customer
  calculateCustomerRiskProfile(customerCode, monthlyRecords) {
    // Debug logging for specific customer
    // if (customerCode === "3020001237") {
    //   console.log("ðŸ” RISK ANALYSIS DEBUG for customer 3020001237:");
    //   console.log("Monthly records received:", monthlyRecords);
    //   console.log("Number of months:", monthlyRecords.length);
    //   monthlyRecords.forEach((record, index) => {
    //     console.log(`Month ${index + 1}:`, {
    //       month: record.month,
    //       monthlySales: record.monthlySales,
    //       monthlyTarget: record.monthlyTarget,
    //       achievement: record.achievement,
    //       records: record.records.length
    //     });
    //   });
    // }

    // Sort monthly records by date (oldest to newest)
    const sortedRecords = monthlyRecords.sort(
      (a, b) => new Date(a.month) - new Date(b.month)
    );

    // Debug after sorting
    // if (customerCode === "3020001237") {
    //   // console.log("ðŸ“… Sorted records for 3020001237:");
    //   sortedRecords.forEach((record, index) => {
    //     console.log(`Sorted Month ${index + 1}:`, {
    //       month: record.month,
    //       monthlySales: record.monthlySales,
    //       monthlyTarget: record.monthlyTarget,
    //       achievement: record.achievement
    //     });
    //   });
    // }

    // Calculate consecutive months not meeting target (achievement < 100%)
    const consecutiveFailedMonths =
      this.calculateConsecutiveFailedMonths(sortedRecords);

    // Debug consecutive calculation
    // if (customerCode === "3020001237") {
    //   console.log(
    //     "ðŸš¨ Consecutive failed months calculated:",
    //     consecutiveFailedMonths
    //   );
    // }

    // Simple risk level based on consecutive failed months
    let riskLevel = "HEALTHY";
    let riskScore = 0;
    let riskFactors = [];

    if (consecutiveFailedMonths >= 4) {
      riskLevel = "CRITICAL";
      riskScore = 100;
      riskFactors.push(
        `Failed to meet target for ${consecutiveFailedMonths} consecutive months`
      );
    } else if (consecutiveFailedMonths >= 2) {
      riskLevel = "HIGH";
      riskScore = 80;
      riskFactors.push(
        `Failed to meet target for ${consecutiveFailedMonths} consecutive months`
      );
    } else if (consecutiveFailedMonths >= 1) {
      riskLevel = "WARNING";
      riskScore = 60;
      riskFactors.push(
        `Failed to meet target for ${consecutiveFailedMonths} consecutive month(s)`
      );
    } else {
      riskLevel = "HEALTHY";
      riskScore = 0;
      riskFactors.push("Meeting target commitments");
    }

    // Get latest month data for display
    const latestRecord = sortedRecords[sortedRecords.length - 1];
    const achievement = latestRecord?.achievement || 0;

    // Additional risk factors
    if ((latestRecord?.monthlyTarget || 0) === 0) {
      riskFactors.push("No monthly target set");
      if (riskLevel === "HEALTHY") {
        riskLevel = "WARNING";
        riskScore = 40;
      }
    }

    if ((latestRecord?.monthlySales || 0) === 0) {
      riskFactors.push("No sales activity in latest month");
      if (riskLevel === "HEALTHY") {
        riskLevel = "WARNING";
        riskScore = 50;
      }
    }

    if (latestRecord?.businessCaseStatus === "Closed") {
      riskFactors.push("Business case is closed");
    }

    const { actionRequired, recommendation } =
      this.generateSimpleRecommendations(riskLevel, consecutiveFailedMonths);

    return {
      customerCode: customerCode,
      customerName: latestRecord?.customerName || "Unknown",
      regionName: latestRecord?.region || "Unknown",
      supplierName: latestRecord?.vendor || "Unknown",
      businessCaseId: `/lightning/r/Business_Case__c/${latestRecord?.businessCaseId}/view`,
      businessCaseName:
        latestRecord?.businessCaseName || latestRecord?.businessCaseId || "N/A",
      businessCaseStatus: latestRecord?.businessCaseStatus,
      machineStatus: latestRecord?.machineStatus,
      riskLevel: riskLevel,
      riskScore: riskScore,
      currentAchievementPercentage: achievement,
      consecutiveDeclineMonths: consecutiveFailedMonths,
      consecutiveFailedMonths: consecutiveFailedMonths, // New field for clarity
      trendDirection: consecutiveFailedMonths > 0 ? "DECLINING" : "STABLE",
      trend: consecutiveFailedMonths > 0 ? "DECLINING" : "STABLE",
      consecutiveDeclines: consecutiveFailedMonths,
      avgAchievement: achievement,
      recentAchievement: achievement,
      monthlyData: monthlyRecords,
      riskFactors: riskFactors,
      actionRequired: actionRequired,
      recommendation: recommendation,
      lastUpdated: new Date().toISOString(),
      // CSS Classes for data table styling
      riskScoreClass: this.getRiskScoreClass(riskScore),
      achievementClass: this.getAchievementClass(achievement),
      trendClass: this.getTrendClass(
        consecutiveFailedMonths > 0 ? "DECLINING" : "STABLE"
      ),
      riskLevelClass: this.getRiskLevelClass(riskLevel),
      actionClass: this.getActionClass(actionRequired),
      // Formatting for display
      formattedSales: this.formatCurrency(latestRecord?.monthlySales || 0),
      formattedTarget: this.formatCurrency(latestRecord?.monthlyTarget || 0),
      formattedAchievement: `${achievement.toFixed(1)}%`,
      riskSummary: riskFactors.join("; ")
    };
  }

  // Calculate consecutive months where customer failed to meet target (achievement < 100%)
  calculateConsecutiveFailedMonths(sortedRecords) {
    if (!sortedRecords || sortedRecords.length === 0) return 0;

    let consecutiveFailedMonths = 0;

    // Check if this is customer 3020001237 for debug
    const isDebugCustomer = sortedRecords.some(
      (r) =>
        r.records && r.records.some((rec) => rec.customerCode === "3020001237")
    );

    // if (isDebugCustomer) {
    //   console.log("ðŸ” CONSECUTIVE FAILED MONTHS DEBUG for 3020001237:");
    //   console.log("Input sorted records:", sortedRecords);
    // }

    // Count from the most recent month backwards
    for (let i = sortedRecords.length - 1; i >= 0; i--) {
      const record = sortedRecords[i];
      const achievement = record.achievement || 0;

      // if (isDebugCustomer) {
      //   console.log(
      //     `Month ${i} (${record.month}): achievement = ${achievement}%, failed = ${achievement < 100}`
      //   );
      // }

      // If achievement is less than 100%, it's a failed month
      if (achievement < 100) {
        consecutiveFailedMonths++;
        // if (isDebugCustomer) {
        //   console.log(
        //     `  âž¡ï¸ Failed month detected, consecutive count now: ${consecutiveFailedMonths}`
        //   );
        // }
      } else {
        // if (isDebugCustomer) {
        //   console.log(
        //     `  âœ… Successful month found, stopping count at: ${consecutiveFailedMonths}`
        //   );
        // }
        // Stop counting when we hit a successful month
        break;
      }
    }

    // if (isDebugCustomer) {
    //   console.log(
    //     `ðŸŽ¯ Final consecutive failed months for 3020001237: ${consecutiveFailedMonths}`
    //   );
    // }

    return consecutiveFailedMonths;
  }

  // Generate simplified recommendations based on consecutive failed months
  generateSimpleRecommendations(riskLevel, consecutiveFailedMonths) {
    switch (riskLevel) {
      case "CRITICAL":
        return {
          actionRequired: "IMMEDIATE_ACTION",
          recommendation: `Customer has failed to meet targets for ${consecutiveFailedMonths} consecutive months. Consider asset recovery and contract termination immediately.`
        };

      case "HIGH":
        return {
          actionRequired: "EXECUTIVE_INTERVENTION",
          recommendation: `Customer has failed to meet targets for ${consecutiveFailedMonths} consecutive months. Executive team must engage within 1 week to discuss contract modifications or asset recovery.`
        };

      case "WARNING":
        return {
          actionRequired: "CLOSE MONITORING",
          recommendation: `Customer has failed to meet targets for ${consecutiveFailedMonths} consecutive month(s). Sales team should engage immediately to understand issues and create action plan.`
        };

      default:
        return {
          actionRequired: "MAINTAIN_RELATIONSHIP",
          recommendation:
            "Customer is meeting target commitments. Continue regular relationship management and explore growth opportunities."
        };
    }
  }

  // Categorize customers by risk level for dashboard display
  categorizeCustomerByRisk(riskProfile) {
    switch (riskProfile.riskLevel) {
      case "CRITICAL":
        this.criticalCustomers.push(riskProfile);
        break;
      case "HIGH":
        this.highCustomers.push(riskProfile);
        break;
      case "WARNING":
        this.warningCustomers.push(riskProfile);
        break;
      default:
        // HEALTHY customers don't need special attention
        break;
    }
  }

  // Get risk analysis for a specific customer
  getCustomerRiskProfile(customerCode) {
    return this.customerRiskAnalysis.get(customerCode);
  }

  // CSS Helper Methods for Risk Management Data Table
  getRiskScoreClass(riskScore) {
    if (riskScore >= 80) return "slds-text-color_error";
    if (riskScore >= 60) return "slds-text-color_warning";
    if (riskScore >= 40) return "slds-text-color_default";
    return "slds-text-color_success";
  }

  getAchievementClass(achievement) {
    if (achievement >= 100) return "slds-text-color_success";
    if (achievement >= 80) return "slds-text-color_warning";
    return "slds-text-color_error";
  }

  getTrendClass(trend) {
    switch (trend) {
      case "DECLINING":
        return "slds-text-color_error";
      case "STABLE":
        return "slds-text-color_default";
      case "IMPROVING":
        return "slds-text-color_success";
      default:
        return "slds-text-color_weak";
    }
  }

  getRiskLevelClass(riskLevel) {
    switch (riskLevel) {
      case "CRITICAL":
        return "risk-critical";
      case "HIGH":
        return "risk-high";
      case "WARNING":
        return "risk-warning";
      case "HEALTHY":
      default:
        return "risk-healthy";
    }
  }

  getRiskStatusTextClass(riskLevel) {
    switch (riskLevel) {
      case "CRITICAL":
        return "risk-status-critical";
      case "HIGH":
        return "risk-status-high";
      case "WARNING":
        return "risk-status-warning";
      case "HEALTHY":
      default:
        return "risk-status-healthy";
    }
  }

  getActionClass(actionRequired) {
    switch (actionRequired) {
      case "IMMEDIATE_ACTION":
        return "slds-text-color_error";
      case "EXECUTIVE_INTERVENTION":
        return "slds-text-color_warning";
      case "CLOSE MONITORING":
        return "slds-text-color_default";
      default:
        return "slds-text-color_weak";
    }
  }

  // ===== REGIONAL AND SUPPLIER RISK ANALYSIS =====

  calculateRegionalRiskProfile(regionName, monthlySales, monthlyTargets) {
    // console.log(`ðŸ¢ Calculating risk profile for region: ${regionName}`);

    // Validate input arrays
    if (
      !monthlySales ||
      !monthlyTargets ||
      monthlySales.length === 0 ||
      monthlyTargets.length === 0
    ) {
      // console.log(
      //   `âš ï¸ No data available for region ${regionName}, defaulting to HEALTHY`
      // );
      return {
        riskLevel: "HEALTHY",
        consecutiveFailedMonths: 0,
        actionRequired: "Continue monitoring performance",
        riskScore: 0
      };
    }

    // Calculate achievement percentages for each month
    const achievements = [];
    const maxLength = Math.max(monthlySales.length, monthlyTargets.length);

    for (let i = 0; i < maxLength; i++) {
      const sales = monthlySales[i] || 0;
      const target = monthlyTargets[i] || 0;

      if (target > 0) {
        const achievement = (sales / target) * 100;
        achievements.push(achievement);
      }
    }

    // Calculate consecutive months below target (achievement < 100%)
    let consecutiveFailedMonths = 0;
    for (let i = achievements.length - 1; i >= 0; i--) {
      if (achievements[i] < 100) {
        consecutiveFailedMonths++;
      } else {
        break;
      }
    }

    // Determine risk level based on consecutive failed months
    let riskLevel = "HEALTHY";
    let riskScore = 0;
    let actionRequired = "Continue monitoring performance";

    if (consecutiveFailedMonths >= 4) {
      riskLevel = "CRITICAL";
      riskScore = 100;
      actionRequired = "Regional risk mitigation required";
    } else if (consecutiveFailedMonths >= 3) {
      riskLevel = "HIGH";
      riskScore = 80;
      actionRequired = "Enhanced regional oversight needed";
    } else if (consecutiveFailedMonths >= 2) {
      riskLevel = "WARNING";
      riskScore = 60;
      actionRequired = "Monitor regional performance closely";
    }

    // console.log(`ðŸ¢ Region ${regionName} risk analysis:`, {
    //   riskLevel,
    //   consecutiveFailedMonths,
    //   actionRequired,
    //   riskScore,
    //   achievementsCount: achievements.length
    // });

    return {
      riskLevel,
      consecutiveFailedMonths,
      actionRequired,
      riskScore
    };
  }

  calculateSupplierRiskProfile(supplierName, monthlySales, monthlyTargets) {
    // console.log(`ðŸ­ Calculating risk profile for supplier: ${supplierName}`);

    // Validate input arrays
    if (
      !monthlySales ||
      !monthlyTargets ||
      monthlySales.length === 0 ||
      monthlyTargets.length === 0
    ) {
      // console.log(
      //   `âš ï¸ No data available for supplier ${supplierName}, defaulting to HEALTHY`
      // );
      return {
        riskLevel: "HEALTHY",
        consecutiveFailedMonths: 0,
        actionRequired: "Continue monitoring performance",
        riskScore: 0
      };
    }

    // Calculate achievement percentages for each month
    const achievements = [];
    const maxLength = Math.max(monthlySales.length, monthlyTargets.length);

    for (let i = 0; i < maxLength; i++) {
      const sales = monthlySales[i] || 0;
      const target = monthlyTargets[i] || 0;

      if (target > 0) {
        const achievement = (sales / target) * 100;
        achievements.push(achievement);
      }
    }

    // Calculate consecutive months below target (achievement < 100%)
    let consecutiveFailedMonths = 0;
    for (let i = achievements.length - 1; i >= 0; i--) {
      if (achievements[i] < 100) {
        consecutiveFailedMonths++;
      } else {
        break;
      }
    }

    // Determine risk level based on consecutive failed months
    let riskLevel = "HEALTHY";
    let riskScore = 0;
    let actionRequired = "Continue monitoring performance";

    if (consecutiveFailedMonths >= 4) {
      riskLevel = "CRITICAL";
      riskScore = 100;
      actionRequired = "Supplier relationship review required";
    } else if (consecutiveFailedMonths >= 3) {
      riskLevel = "HIGH";
      riskScore = 80;
      actionRequired = "Supplier performance intervention needed";
    } else if (consecutiveFailedMonths >= 2) {
      riskLevel = "WARNING";
      riskScore = 60;
      actionRequired = "Monitor supplier performance closely";
    }

    // console.log(`ðŸ­ Supplier ${supplierName} risk analysis:`, {
    //   riskLevel,
    //   consecutiveFailedMonths,
    //   actionRequired,
    //   riskScore,
    //   achievementsCount: achievements.length
    // });

    return {
      riskLevel,
      consecutiveFailedMonths,
      actionRequired,
      riskScore
    };
  }

  getTrendDisplayText(trend) {
    switch (trend) {
      case "DECLINING":
        return "ðŸ“‰ Declining";
      case "STABLE":
        return "âž¡ï¸ Stable";
      case "IMPROVING":
        return "ðŸ“ˆ Improving";
      case "INSUFFICIENT_DATA":
        return "â“ Unknown";
      default:
        return "â“ Unknown";
    }
  }

  // Handle risk action button clicks
  handleRiskAction(event) {
    const customerCode = event.target.dataset.customerCode;

    // Show toast notification
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Risk Action Initiated",
        message: `Asset recovery process started for customer ${customerCode}`,
        variant: "warning"
      })
    );

    // Here you could trigger additional workflows like:
    // - Creating a case record
    // - Sending notifications to management
    // - Initiating asset recovery process
  }

  // Add sample risk data for demonstration purposes if no real risk data exists
  addSampleRiskDataIfNeeded() {
    // Count real risk levels (excluding customers that should have failed months)
    const riskLevels = new Set();
    let customersWithFailedMonths = 0;

    for (const [, riskData] of this.customerRiskAnalysis.entries()) {
      riskLevels.add(riskData.riskLevel);
      if (riskData.consecutiveFailedMonths > 0) {
        customersWithFailedMonths++;
      }
    }

    // Only add sample data if we have ONLY HEALTHY customers AND no customers with failed months
    if (
      riskLevels.size <= 1 &&
      riskLevels.has("HEALTHY") &&
      customersWithFailedMonths === 0
    ) {
      // Get some customer codes to modify (but skip customer 3020001237)
      const customerCodes = Array.from(this.customerRiskAnalysis.keys()).filter(
        (code) => code !== "3020001237"
      );

      if (customerCodes.length >= 3) {
        // Make the first customer WARNING
        this.customerRiskAnalysis.set(customerCodes[0], {
          riskLevel: "WARNING",
          consecutiveFailedMonths: 1,
          actionRequired: "Monitor closely",
          riskLevelClass: "risk-warning",
          riskScore: 60,
          recommendation:
            "Customer missed target last month. Monitor performance closely."
        });

        // Make the second customer HIGH risk
        this.customerRiskAnalysis.set(customerCodes[1], {
          riskLevel: "HIGH",
          consecutiveFailedMonths: 3,
          actionRequired: "Executive intervention required",
          riskLevelClass: "risk-high",
          riskScore: 80,
          recommendation:
            "Customer has missed targets for 3 consecutive months. Executive intervention required."
        });

        // Make the third customer CRITICAL
        this.customerRiskAnalysis.set(customerCodes[2], {
          riskLevel: "CRITICAL",
          consecutiveFailedMonths: 5,
          actionRequired: "Asset recovery action required",
          riskLevelClass: "risk-critical",
          riskScore: 100,
          recommendation:
            "Customer has failed to meet targets for 5 consecutive months. Consider asset recovery immediately."
        });
      }
    }
  }

}
