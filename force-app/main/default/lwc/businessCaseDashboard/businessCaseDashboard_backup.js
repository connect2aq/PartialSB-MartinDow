import { LightningElement, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";
import { loadScript } from "lightning/platformResourceLoader";
import ChartJS from "@salesforce/resourceUrl/ChartJS_4_4_0";
// import getSnapshotData from "@salesforce/apex/BusinessCaseDashboardController.getSnapshotData";
import getEnhancedFilterOptions from "@salesforce/apex/BusinessCaseDashboardController.getEnhancedFilterOptions";
import getSummaryMetrics from "@salesforce/apex/BusinessCaseDashboardController.getSummaryMetrics";
import getMachineStatusCounts from "@salesforce/apex/BusinessCaseDashboardController.getMachineStatusCounts";

export default class BusinessCaseDashboard extends LightningElement {
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
  @track activeTab = "commitment";
  @track showCustomerModal = false;
  @track selectedCustomerData = null;
  @track filtersLoaded = false;
  @track customerViewMode = "cards"; // "cards" or "table"

  // Data Storage
  @track snapshotData = [];
  @track filteredData = [];
  @track summaryMetrics = {};
  @track machineStatusCounts = [];

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
        console.log("📈 Chart.js loaded successfully");
      }
    } catch (error) {
      console.error("❌ Error loading Chart.js:", error);
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
  @track pageSize = 12;
  @track totalRecords = 0;

  // Filters
  @track selectedMonth = "";
  @track selectedCustomer = "";
  @track selectedRegion = "";
  @track selectedSupplier = "";
  @track selectedBusinessCaseStatus = "";
  @track selectedMachineStatus = "";
  @track selectedCommitmentStatus = "";
  @track selectedRiskStatus = "";
  @track searchTerm = "";

  // Filter Options - Internal arrays (not tracked)
  _monthOptions = [{ label: "All Months", value: "" }];
  _customerOptions = [{ label: "All Customers", value: "" }];
  _regionOptions = [{ label: "All Regions", value: "" }];
  _supplierOptions = [{ label: "All Suppliers", value: "" }];
  _businessCaseStatusOptions = [
    { label: "All Business Case Statuses", value: "" }
  ];
  _machineStatusOptions = [{ label: "All Machine Statuses", value: "" }];
  _commitmentStatusOptions = [
    { label: "All Commitment Statuses", value: "" },
    { label: "On Track", value: "On Track" },
    { label: "Behind", value: "Behind" },
    { label: "No Target Set", value: "No Target Set" },
    { label: "No Sales", value: "No Sales" }
  ];
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

  get customerOptions() {
    return this._customerOptions;
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

  connectedCallback() {
    console.log("🚀 BusinessCaseDashboard component connected");
    console.log("Initial filter options:", {
      monthOptions: this._monthOptions,
      customerOptions: this._customerOptions,
      regionOptions: this._regionOptions,
      supplierOptions: this._supplierOptions
    });

    // Initialize component with empty data to prevent blank page
    this.initializeEmptyData();

    // Load Chart.js library for trend charts
    this.loadChartJS();
  }

  // Initialize component with empty data to prevent blank page
  initializeEmptyData() {
    if (!this.snapshotData || this.snapshotData.length === 0) {
      this.snapshotData = [];
      this.filteredData = [];
      this.summaryMetrics = {};
      this.machineStatusCounts = [];
      this.regionalInvestmentData = [];
      this.supplierInvestmentData = [];
      this.customerInvestmentData = [];
      this.regionalCommitmentData = [];
      this.supplierCommitmentData = [];
      this.customerCommitmentData = [];

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

      console.log("📋 Component initialized with empty data");
    }
  }

  renderedCallback() {
    console.log("🎨 Component rendered - checking filter state:");
    console.log("filtersLoaded:", this.filtersLoaded);
    console.log("Current filter options:", {
      monthOptions: this.monthOptions,
      customerOptions: this.customerOptions,
      regionOptions: this.regionOptions,
      supplierOptions: this.supplierOptions
    });
    console.log("Filter option lengths:", {
      monthOptions: this.monthOptions?.length || 0,
      customerOptions: this.customerOptions?.length || 0,
      regionOptions: this.regionOptions?.length || 0,
      supplierOptions: this.supplierOptions?.length || 0
    });

    // Check if filter elements exist in DOM
    const filterSection = this.template.querySelector(
      'lightning-card[title="Filters"]'
    );
    const monthFilter = this.template.querySelector(
      'lightning-combobox[name="monthFilter"]'
    );
    const customerFilter = this.template.querySelector(
      'lightning-combobox[name="customerFilter"]'
    );
    const regionFilter = this.template.querySelector(
      'lightning-combobox[name="regionFilter"]'
    );
    const supplierFilter = this.template.querySelector(
      'lightning-combobox[name="supplierFilter"]'
    );

    console.log("Filter DOM elements:", {
      filterSection: !!filterSection,
      monthFilter: !!monthFilter,
      customerFilter: !!customerFilter,
      regionFilter: !!regionFilter,
      supplierFilter: !!supplierFilter
    });

    // Log actual filter option values for debugging
    if (this._monthOptions && this._monthOptions.length > 0) {
      console.log(
        "✅ Month options sample:",
        JSON.stringify(this._monthOptions.slice(0, 3))
      );
    } else {
      console.log("❌ Month options empty or undefined");
    }
    if (this._customerOptions && this._customerOptions.length > 0) {
      console.log(
        "✅ Customer options sample:",
        JSON.stringify(this._customerOptions.slice(0, 3))
      );
    } else {
      console.log("❌ Customer options empty or undefined");
    }

    // Test if combobox elements have options
    if (monthFilter && this._monthOptions && this._monthOptions.length > 0) {
      console.log("🔄 Month filter element found, options should be available");
    }
    if (
      customerFilter &&
      this._customerOptions &&
      this._customerOptions.length > 0
    ) {
      console.log(
        "🔄 Customer filter element found, options should be available"
      );
    }
  }

  // @wire(getSnapshotData)
  // wiredSnapshots(result) {
  //   console.log("📊 Snapshot Data Wire Method Called");
  //   console.log("Snapshot result:", result);

  //   this.wiredSnapshotResult = result;
  //   if (result.data) {
  //     try {
  //       console.log(
  //         "✅ Snapshot data received:",
  //         result.data?.length || 0,
  //         "records"
  //       );
  //       console.log("Sample snapshot data:", result.data?.[0]);
  //       this.snapshotData = result.data;
  //       this.processSnapshotData();
  //       this.error = null;
  //       this.isLoading = false; // Ensure loading stops when data is received
  //     } catch (error) {
  //       console.error("❌ Error processing snapshot data:", error);
  //       this.handleError("Error processing snapshot data", error);
  //       this.isLoading = false; // Ensure loading stops on error
  //     }
  //   } else if (result.error) {
  //     console.error("❌ Error loading snapshot data:", result.error);
  //     this.handleError("Error loading snapshot data", result.error);
  //     this.isLoading = false; // Ensure loading stops on error
  //   } else {
  //     console.log("⏳ Snapshot data loading...");
  //   }
  // }

  @wire(getEnhancedFilterOptions)
  wiredFilters(result) {
    console.log("🔍 Enhanced Filter Options Wire Method Called");
    console.log("Filter result:", result);

    this.wiredFilterResult = result;
    if (result.data) {
      try {
        console.log("✅ Enhanced filter data received:", result.data);
        console.log(
          "Enhanced filter data structure:",
          JSON.stringify(result.data, null, 2)
        );
        this.processEnhancedFilterOptions(result.data);
        this.error = null;
        console.log("✅ Enhanced filter options processed successfully");
        // Don't set isLoading to false here as other data might still be loading
      } catch (error) {
        console.error("❌ Error processing enhanced filter options:", error);
        this.handleError("Error processing enhanced filter options", error);
      }
    } else if (result.error) {
      console.error("❌ Error loading enhanced filter options:", result.error);
      this.handleError("Error loading enhanced filter options", result.error);
    } else {
      console.log("⏳ Enhanced filter options loading...");
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
      console.log("⏳ Summary metrics loading...");
    }
  }

  @wire(getMachineStatusCounts)
  wiredMachineStatus(result) {
    if (result.data) {
      try {
        this.machineStatusCounts = result.data;
        console.log(
          "✅ Machine status counts loaded:",
          this.machineStatusCounts
        );
      } catch (error) {
        console.error("❌ Error processing machine status counts:", error);
      }
    } else if (result.error) {
      console.error("❌ Error loading machine status counts:", result.error);
    }
  }

  // ===== DATA PROCESSING =====

  processSnapshotData() {
    console.log("📊 Processing snapshot data...");
    console.log(
      "Snapshot data received:",
      this.snapshotData?.length || 0,
      "records"
    );

    if (!this.snapshotData || this.snapshotData.length === 0) {
      console.log("⚠️ No snapshot data available");
      this.filteredData = [];
      this.aggregateData();
      return;
    }

    // Debug: Check for missing customer 3020001237 snapshots
    const customer3020001237Records = this.snapshotData.filter(
      (record) => record.customerCode === "3020001237"
    );

    console.log("🔍 Customer 3020001237 snapshot verification:");
    console.log(
      `Found ${customer3020001237Records.length} records for customer 3020001237`
    );

    if (customer3020001237Records.length > 0) {
      customer3020001237Records.forEach((record, index) => {
        console.log(`Record ${index + 1}:`, {
          customerCode: record.customerCode,
          businessCaseName: record.businessCaseName,
          snapshotMonth: record.snapshotMonth,
          totalReagentSales: record.totalReagentSales,
          targetSales: record.targetSales,
          achievement: record.achievement
        });
      });
    } else {
      console.log("� No records found for customer 3020001237");
      console.log(
        "Expected snapshots: BCSS-0000575 (Feb), BCSS-0000576 (Mar), BCSS-0000577 (Apr)"
      );
    }

    console.log("First snapshot record sample:", this.snapshotData[0]);
    console.log("🔍 Detailed field analysis of first record:");
    if (this.snapshotData[0]) {
      const firstRecord = this.snapshotData[0];
      Object.keys(firstRecord).forEach((key) => {
        if (
          key.toLowerCase().includes("performance") ||
          key.toLowerCase().includes("status") ||
          key.toLowerCase().includes("commitment")
        ) {
          console.log(`  ${key}: ${firstRecord[key]}`);
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

    console.log("📊 Snapshot data processing completed");
    console.log("Filtered data:", this.filteredData?.length || 0, "records");
    console.log(
      "Regional investment data:",
      this.regionalInvestmentData?.length || 0,
      "records"
    );
    console.log("Risk analysis summary:", this.formattedRiskSummary);
  }

  processEnhancedFilterOptions(data) {
    console.log("🔧 Processing enhanced filter options with data:", data);

    // Process month options
    console.log("Processing months:", data.months);
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
    console.log("✅ Month options assigned:", this._monthOptions.length);

    // Process customer options
    console.log("Processing customers:", data.customers);
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
    console.log("✅ Customer options assigned:", this._customerOptions.length);

    // Process region options
    console.log("Processing regions:", data.regions);
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
    console.log("✅ Region options assigned:", this._regionOptions.length);

    // Process supplier options
    console.log("Processing suppliers:", data.suppliers);
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
    console.log("✅ Supplier options assigned:", this._supplierOptions.length);

    // Process Business Case Status options (NEW)
    console.log(
      "Processing business case statuses:",
      data.businessCaseStatuses
    );
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
    console.log(
      "✅ Business Case Status options assigned:",
      this._businessCaseStatusOptions.length
    );

    // Process Machine Status options (NEW)
    console.log("Processing machine statuses:", data.machineStatuses);
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
    console.log(
      "✅ Machine Status options assigned:",
      this._machineStatusOptions.length
    );

    // Mark filters as loaded and force re-render
    this.filtersLoaded = true;
    console.log("🎯 All enhanced filter options processed successfully");
    console.log("📋 Enhanced filter options summary:");
    console.log("  - Months:", this._monthOptions.length);
    console.log("  - Customers:", this._customerOptions.length);
    console.log("  - Regions:", this._regionOptions.length);
    console.log("  - Suppliers:", this._supplierOptions.length);
    console.log(
      "  - Business Case Statuses:",
      this._businessCaseStatusOptions.length
    );
    console.log("  - Machine Statuses:", this._machineStatusOptions.length);
  }

  applyFilters() {
    console.log(
      "🔍 Applying filters to",
      this.snapshotData?.length || 0,
      "records"
    );

    // Log all unique performance status values in the original data
    const uniqueStatuses = new Set();
    this.snapshotData.forEach((record) => {
      if (record.performanceStatus) {
        uniqueStatuses.add(record.performanceStatus);
      }
    });
    console.log(
      "🎯 Unique performance status values in data:",
      Array.from(uniqueStatuses)
    );
    console.log("🎯 Number of unique statuses found:", uniqueStatuses.size);
    console.log(
      "🎯 Sample records with performance status:",
      this.snapshotData.slice(0, 5).map((r) => ({
        customerCode: r.customerCode,
        performanceStatus: r.performanceStatus,
        businessCaseStatus: r.businessCaseStatus,
        machineStatus: r.machineStatus
      }))
    );

    let filtered = [...this.snapshotData];

    // Month filter
    if (this.selectedMonth) {
      filtered = filtered.filter(
        (record) => record.snapshotMonth === this.selectedMonth
      );
      console.log("After month filter:", filtered.length, "records");
    }

    // Customer filter
    if (this.selectedCustomer) {
      filtered = filtered.filter(
        (record) => record.customerCode === this.selectedCustomer
      );
      console.log("After customer filter:", filtered.length, "records");
    }

    // Region filter
    if (this.selectedRegion) {
      filtered = filtered.filter(
        (record) => record.region === this.selectedRegion
      );
      console.log("After region filter:", filtered.length, "records");
    }

    // Supplier filter
    if (this.selectedSupplier) {
      filtered = filtered.filter(
        (record) => record.vendor === this.selectedSupplier
      );
      console.log("After supplier filter:", filtered.length, "records");
    }

    // Business Case Status filter (NEW)
    if (this.selectedBusinessCaseStatus) {
      filtered = filtered.filter(
        (record) =>
          record.businessCaseStatus === this.selectedBusinessCaseStatus
      );
      console.log(
        "After business case status filter:",
        filtered.length,
        "records"
      );
    }

    // Machine Status filter (NEW)
    if (this.selectedMachineStatus) {
      filtered = filtered.filter(
        (record) => record.machineStatus === this.selectedMachineStatus
      );
      console.log("After machine status filter:", filtered.length, "records");
    }

    // Commitment Status filter (NEW)
    if (this.selectedCommitmentStatus) {
      console.log(
        "🔍 Applying commitment status filter:",
        this.selectedCommitmentStatus
      );
      console.log(
        "Sample records before filter:",
        filtered.slice(0, 2).map((r) => ({
          customerCode: r.customerCode,
          performanceStatus: r.performanceStatus
        }))
      );

      filtered = filtered.filter(
        (record) => record.performanceStatus === this.selectedCommitmentStatus
      );
      console.log(
        "After commitment status filter:",
        filtered.length,
        "records"
      );
      console.log(
        "Sample records after filter:",
        filtered.slice(0, 2).map((r) => ({
          customerCode: r.customerCode,
          performanceStatus: r.performanceStatus
        }))
      );
    }

    // Risk Status filter
    if (this.selectedRiskStatus) {
      console.log("🔍 Applying risk status filter:", this.selectedRiskStatus);
      filtered = filtered.filter((record) => {
        const customerRiskProfile = this.customerRiskAnalysis.get(
          record.customerCode
        );
        return (
          customerRiskProfile &&
          customerRiskProfile.riskLevel === this.selectedRiskStatus
        );
      });
      console.log("After risk status filter:", filtered.length, "records");
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
      console.log("After search filter:", filtered.length, "records");
    }

    this.filteredData = filtered;
    this.totalRecords = filtered.length;
    this.currentPage = 1; // Reset to first page when filters change
    console.log(
      "✅ Filters applied. Final filtered data:",
      this.filteredData.length,
      "records"
    );
  }

  aggregateData() {
    console.log(
      "📈 Starting data aggregation with",
      this.filteredData?.length || 0,
      "filtered records"
    );

    this.regionalInvestmentData = this.aggregateByRegion();
    this.supplierInvestmentData = this.aggregateBySupplier();
    this.customerInvestmentData = this.aggregateByCustomer();

    this.regionalCommitmentData = this.aggregateCommitmentByRegion();
    this.supplierCommitmentData = this.aggregateCommitmentBySupplier();
    this.customerCommitmentData = this.aggregateByCustomer();

    // Update total records for customer data pagination
    this.updateCustomerPagination();

    console.log("📈 Aggregation completed:");
    console.log(
      "- Regional investment data:",
      this.regionalInvestmentData?.length || 0
    );
    console.log(
      "- Supplier investment data:",
      this.supplierInvestmentData?.length || 0
    );
    console.log(
      "- Customer investment data:",
      this.customerInvestmentData?.length || 0
    );
    console.log(
      "- Regional commitment data:",
      this.regionalCommitmentData?.length || 0
    );
    console.log(
      "- Supplier commitment data:",
      this.supplierCommitmentData?.length || 0
    );
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

  aggregateByRegion() {
    const regionMap = new Map();

    this.filteredData.forEach((record) => {
      const region = record.region || "Unknown";

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
          latestSnapshotMonth: null
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
            regionData.investment += record.investment || 0;
          }
        }
      }

      // Accumulate total sales and margins across all records
      // Use totalReagentSalesTillDate for cumulative sales from contract start (not monthly)
      regionData.totalSales += record.totalReagentSalesTillDate || 0;
      regionData.marginOnSales += record.marginOnReagentSale || 0;

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

    return Array.from(regionMap.values()).map((region) => {
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

      return {
        ...region,
        machines: region.totalMachineCount, // Use the summed machine count
        formattedInvestment: this.formatCurrency(region.investment),
        formattedTotalSales: this.formatCurrency(region.totalSales),
        formattedPerMachineSales: this.formatCurrency(
          region.totalMachineCount > 0
            ? region.totalSales / region.totalMachineCount
            : 0
        ),
        formattedMargin: this.formatCurrency(region.marginOnSales),
        costRecoveryPercent: this.formatPercent(
          this.safeCalculatePercent(region.totalSales, region.investment)
        ),
        investmentSharePercent: this.calculateInvestmentShare(
          region.investment
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
        statusClass: this.getStatusClass(performanceStatus)
      };
    });
  }

  aggregateBySupplier() {
    const supplierMap = new Map();

    this.filteredData.forEach((record) => {
      const supplier = record.vendor || "Unknown";

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
          latestSnapshotMonth: null
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
            supplierData.investment += record.investment || 0;
          }
        }
      }

      // Accumulate total sales and margins across all records
      // Use totalReagentSalesTillDate for cumulative sales from contract start (not monthly)
      supplierData.totalSales += record.totalReagentSalesTillDate || 0;
      supplierData.marginOnSales += record.marginOnReagentSale || 0;

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

    return Array.from(supplierMap.values()).map((supplier) => {
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

      return {
        ...supplier,
        machines: supplier.totalMachineCount, // Use the summed machine count
        formattedInvestment: this.formatCurrency(supplier.investment),
        formattedTotalSales: this.formatCurrency(supplier.totalSales),
        formattedPerMachineSales: this.formatCurrency(
          supplier.totalMachineCount > 0
            ? supplier.totalSales / supplier.totalMachineCount
            : 0
        ),
        formattedMargin: this.formatCurrency(supplier.marginOnSales),
        costRecoveryPercent: this.formatPercent(
          this.safeCalculatePercent(supplier.totalSales, supplier.investment)
        ),
        investmentSharePercent: this.calculateInvestmentShare(
          supplier.investment
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
        statusClass: this.getStatusClass(performanceStatus)
      };
    });
  }

  // ===== COMMITMENT-SPECIFIC AGGREGATION METHODS =====

  aggregateCommitmentByRegion() {
    console.log("🔍 DEBUG: Starting aggregateCommitmentByRegion()");
    console.log(
      "🔍 DEBUG: Filtered data length:",
      this.filteredData?.length || 0
    );

    const regionMap = new Map();

    this.filteredData.forEach((record, index) => {
      const region = record.region || "Unknown";

      // Debug first few records
      if (index < 3) {
        console.log(`🔍 DEBUG: Record ${index + 1}:`, {
          region: region,
          customerCode: record.customerCode,
          totalReagentSales: record.totalReagentSales,
          avgReagentSalesPerMonth: record.avgReagentSalesPerMonth,
          targetSales: record.targetSales,
          commitmentPerMonth: record.commitmentPerMonth,
          performanceStatus: record.performanceStatus
        });
      }

      if (!regionMap.has(region)) {
        regionMap.set(region, {
          region: region,
          businessCases: new Set(),
          totalMachineCount: 0,
          totalSales: 0, // Use for current period sales
          totalCommitment: 0, // Use for current period commitments
          allMonthlySales: [], // Track all monthly sales for proper averaging
          allMonthlyTargets: [], // Track all monthly targets for proper averaging
          customerCount: new Set(), // Count unique customers in this region
          recordCount: 0
        });
      }

      const regionData = regionMap.get(region);

      // Only count each business case once for machine count
      if (record.businessCaseId) {
        if (!regionData.businessCases.has(record.businessCaseId)) {
          regionData.businessCases.add(record.businessCaseId);
          regionData.totalMachineCount += record.machineCount || 0;
        }
      }

      // Track unique customers
      if (record.customerCode) {
        regionData.customerCount.add(record.customerCode);
      }

      // Aggregate monthly sales and targets for proper commitment analysis
      // Try multiple field variations to capture all data and ensure valid numbers
      const salesValue =
        record.totalReagentSales ||
        record.avgReagentSalesPerMonth ||
        record.totalReagentSalesTillDate ||
        0;
      const monthlySales = this.safeParseNumber(salesValue);

      const targetValue =
        record.targetSales || record.commitmentPerMonth || record.target || 0;
      const monthlyTarget = this.safeParseNumber(targetValue);

      // Always add the sales value (even if 0) to ensure proper counting
      regionData.allMonthlySales.push(monthlySales);
      regionData.totalSales += monthlySales;

      // Always add the target value (even if 0) to ensure proper counting
      regionData.allMonthlyTargets.push(monthlyTarget);
      regionData.totalCommitment += monthlyTarget;

      regionData.recordCount++;

      // Debug specific region
      if (region === "South" && index < 5) {
        console.log(`🔍 DEBUG: South Region Record ${index + 1}:`, {
          customerCode: record.customerCode,
          monthlySales: monthlySales,
          monthlyTarget: monthlyTarget,
          currentTotalSales: regionData.totalSales,
          currentTotalCommitment: regionData.totalCommitment,
          salesArrayLength: regionData.allMonthlySales.length,
          targetsArrayLength: regionData.allMonthlyTargets.length
        });
      }
    });

    console.log(
      "🔍 DEBUG: Region aggregation completed, processing results..."
    );
    console.log("🔍 DEBUG: Number of regions found:", regionMap.size);

    const results = Array.from(regionMap.values()).map((region) => {
      // Calculate proper averages for commitment analysis
      const validSales = region.allMonthlySales.filter(
        (val) => !isNaN(val) && val !== null && val !== undefined
      );
      const avgSalesPerMonth =
        validSales.length > 0
          ? validSales.reduce((sum, val) => sum + Number(val), 0) /
            validSales.length
          : 0;

      const validTargets = region.allMonthlyTargets.filter(
        (val) => !isNaN(val) && val !== null && val !== undefined
      );
      const avgCommitmentPerMonth =
        validTargets.length > 0
          ? validTargets.reduce((sum, val) => sum + Number(val), 0) /
            validTargets.length
          : 0;

      const performanceStatus = this.getPerformanceStatus(
        avgSalesPerMonth,
        avgCommitmentPerMonth
      );

      const result = {
        region: region.region,
        machines: region.totalMachineCount,
        customerCount: region.customerCount.size,
        recordCount: region.recordCount,
        avgSalesPerMonth: avgSalesPerMonth,
        commitmentPerMonth: avgCommitmentPerMonth,
        achievementPercent: this.formatPercent(
          this.safeCalculatePercent(avgSalesPerMonth, avgCommitmentPerMonth)
        ),
        formattedCommitment: this.formatCurrency(avgCommitmentPerMonth),
        formattedAvgSales: this.formatCurrency(avgSalesPerMonth),
        performanceStatus: performanceStatus,
        statusClass: this.getStatusClass(performanceStatus)
      };

      // Debug results for specific regions
      if (region.region === "South") {
        console.log("🔍 DEBUG: South Region Final Result:", {
          region: result.region,
          recordCount: result.recordCount,
          salesArrayLength: region.allMonthlySales.length,
          targetsArrayLength: region.allMonthlyTargets.length,
          totalSalesSum: region.totalSales,
          totalCommitmentSum: region.totalCommitment,
          avgSalesPerMonth: result.avgSalesPerMonth,
          commitmentPerMonth: result.commitmentPerMonth,
          formattedAvgSales: result.formattedAvgSales,
          formattedCommitment: result.formattedCommitment,
          achievementPercent: result.achievementPercent,
          performanceStatus: result.performanceStatus
        });
      }

      return result;
    });

    console.log(
      "🔍 DEBUG: Final commitment aggregation results:",
      results.length,
      "regions"
    );
    return results;
  }

  aggregateCommitmentBySupplier() {
    console.log("🔍 DEBUG: Starting aggregateCommitmentBySupplier()");

    const supplierMap = new Map();

    this.filteredData.forEach((record) => {
      const supplier = record.vendor || "Unknown";

      if (!supplierMap.has(supplier)) {
        supplierMap.set(supplier, {
          supplier: supplier,
          businessCases: new Set(),
          totalMachineCount: 0,
          totalSales: 0,
          totalCommitment: 0,
          allMonthlySales: [],
          allMonthlyTargets: [],
          customerCount: new Set(),
          recordCount: 0
        });
      }

      const supplierData = supplierMap.get(supplier);

      // Only count each business case once for machine count
      if (record.businessCaseId) {
        if (!supplierData.businessCases.has(record.businessCaseId)) {
          supplierData.businessCases.add(record.businessCaseId);
          supplierData.totalMachineCount += record.machineCount || 0;
        }
      }

      // Track unique customers
      if (record.customerCode) {
        supplierData.customerCount.add(record.customerCode);
      }

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

      // Always add the values to ensure proper counting
      supplierData.allMonthlySales.push(monthlySales);
      supplierData.totalSales += monthlySales;

      supplierData.allMonthlyTargets.push(monthlyTarget);
      supplierData.totalCommitment += monthlyTarget;

      supplierData.recordCount++;
    });

    return Array.from(supplierMap.values()).map((supplier) => {
      // Calculate proper averages for commitment analysis
      const validSales = supplier.allMonthlySales.filter(
        (val) => !isNaN(val) && val !== null && val !== undefined
      );
      const avgSalesPerMonth =
        validSales.length > 0
          ? validSales.reduce((sum, val) => sum + Number(val), 0) /
            validSales.length
          : 0;

      const validTargets = supplier.allMonthlyTargets.filter(
        (val) => !isNaN(val) && val !== null && val !== undefined
      );
      const avgCommitmentPerMonth =
        validTargets.length > 0
          ? validTargets.reduce((sum, val) => sum + Number(val), 0) /
            validTargets.length
          : 0;

      const performanceStatus = this.getPerformanceStatus(
        avgSalesPerMonth,
        avgCommitmentPerMonth
      );

      return {
        supplier: supplier.supplier,
        machines: supplier.totalMachineCount,
        customerCount: supplier.customerCount.size,
        recordCount: supplier.recordCount,
        avgSalesPerMonth: avgSalesPerMonth,
        commitmentPerMonth: avgCommitmentPerMonth,
        achievementPercent: this.formatPercent(
          this.safeCalculatePercent(avgSalesPerMonth, avgCommitmentPerMonth)
        ),
        formattedCommitment: this.formatCurrency(avgCommitmentPerMonth),
        formattedAvgSales: this.formatCurrency(avgSalesPerMonth),
        performanceStatus: performanceStatus,
        statusClass: this.getStatusClass(performanceStatus)
      };
    });
  }

  aggregateByCustomer() {
    const customerMap = new Map();

    this.filteredData.forEach((record) => {
      const customerCode = record.customerCode || "Unknown";

      if (!customerMap.has(customerCode)) {
        customerMap.set(customerCode, {
          customerCode: customerCode,
          customerName: record.customerName || "Unknown",
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

      // Only count each business case once for machine count and investment
      if (record.businessCaseId && record.machineCount > 0) {
        if (!customerData.businessCases.has(record.businessCaseId)) {
          customerData.businessCases.add(record.businessCaseId);
          customerData.totalMachineCount += record.machineCount || 0;

          // Track unique investment per business case to avoid double counting
          const investmentKey = `${record.businessCaseId}`;
          if (!customerData.uniqueInvestments.has(investmentKey)) {
            customerData.uniqueInvestments.add(investmentKey);
            customerData.investment += record.investment || 0;
          }
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

  // ===== OVERVIEW METRICS CALCULATION =====

  calculateOverviewMetrics() {
    console.log("📊 Calculating overview metrics from ALL data...");

    if (!this.snapshotData || this.snapshotData.length === 0) {
      console.log("⚠️ No snapshot data available for overview metrics");
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
      return;
    }

    // Calculate commitment status counts from ALL data (not filtered)
    const uniqueCustomers = {};
    this.snapshotData.forEach((record) => {
      if (record.customerCode && record.performanceStatus) {
        uniqueCustomers[record.customerCode] = record.performanceStatus;
      }
    });

    // Count customers by commitment status
    const commitmentStatusCounts = {
      onTrack: 0,
      behind: 0,
      noTargetSet: 0,
      noSales: 0
    };

    Object.values(uniqueCustomers).forEach((status) => {
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

    console.log("✅ Overview metrics calculated:", this.overviewMetrics);
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
          console.log("Chart.js not ready yet, will initialize later");
        }
      });
    }

    this.updateCustomerPagination();
  }

  handleRefresh() {
    this.isLoading = true;
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
  handleMonthChange(event) {
    this.selectedMonth = event.detail.value;
    this.processSnapshotData();
  }

  handleCustomerChange(event) {
    this.selectedCustomer = event.detail.value;
    this.processSnapshotData();
  }

  handleRegionChange(event) {
    this.selectedRegion = event.detail.value;
    this.processSnapshotData();
  }

  handleSupplierChange(event) {
    this.selectedSupplier = event.detail.value;
    this.processSnapshotData();
  }

  handleBusinessCaseStatusChange(event) {
    this.selectedBusinessCaseStatus = event.detail.value;
    this.processSnapshotData();
  }

  handleMachineStatusChange(event) {
    this.selectedMachineStatus = event.detail.value;
    this.processSnapshotData();
  }

  handleCommitmentStatusChange(event) {
    this.selectedCommitmentStatus = event.detail.value;
    this.processSnapshotData();
  }

  handleRiskStatusChange(event) {
    this.selectedRiskStatus = event.detail.value;
    this.processSnapshotData();
  }

  handleSearchChange(event) {
    this.searchTerm = event.detail.value;
    // Process data immediately without debounce
    this.processSnapshotData();
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

  formatCurrency(amount) {
    if (amount == null || amount === undefined || isNaN(amount)) return "Rs.0";
    const numericAmount = Number(amount);
    if (isNaN(numericAmount)) return "Rs.0";
    const formattedNumber = new Intl.NumberFormat("en-US", {
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(numericAmount);
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
    return this.formatCurrency(this.summaryMetrics.totalInvestment);
  }

  get formattedTotalSales() {
    return this.formatCurrency(this.summaryMetrics.totalSales);
  }

  get formattedCostRecovery() {
    return this.formatPercent(this.summaryMetrics.costRecoveryPercent);
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
    const status = this.machineStatusCounts.find((s) => s.status === "Ordered");
    return status ? status.count : 0;
  }

  get installedMachines() {
    const status = this.machineStatusCounts.find(
      (s) => s.status === "Installed"
    );
    return status ? status.count : 0;
  }

  get activeMachines() {
    const status = this.machineStatusCounts.find((s) => s.status === "Active");
    return status ? status.count : 0;
  }

  get rejectedMachines() {
    const status = this.machineStatusCounts.find(
      (s) => s.status === "Rejected"
    );
    return status ? status.count : 0;
  }

  get inactiveMachines() {
    const status = this.machineStatusCounts.find(
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
    const critical = this.overviewMetrics.criticalCustomers;
    const warning = this.overviewMetrics.warningCustomers;
    const high = this.overviewMetrics.highRiskCustomers;
    const healthy = this.overviewMetrics.healthyCustomers;
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

  get paginatedData() {
    const start = (this.currentPage - 1) * this.pageSize;
    const end = start + this.pageSize;
    return this.filteredData.slice(start, end);
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
    return this.customerCommitmentData.slice(start, end);
  }

  // Data table columns
  get regionalInvestmentColumns() {
    return [
      { label: "Region", fieldName: "region", type: "text" },
      { label: "Machines", fieldName: "machines", type: "number" },
      { label: "Investment", fieldName: "formattedInvestment", type: "text" },
      { label: "Total Sales", fieldName: "formattedTotalSales", type: "text" },
      {
        label: "Per Machine Sales",
        fieldName: "formattedPerMachineSales",
        type: "text"
      },
      { label: "Margin", fieldName: "formattedMargin", type: "text" },
      {
        label: "Cost Recovery",
        fieldName: "costRecoveryPercent",
        type: "text"
      },
      {
        label: "Investment Share",
        fieldName: "investmentSharePercent",
        type: "text"
      }
    ];
  }

  get supplierInvestmentColumns() {
    return [
      { label: "Supplier", fieldName: "supplier", type: "text" },
      { label: "Machines", fieldName: "machines", type: "number" },
      { label: "Investment", fieldName: "formattedInvestment", type: "text" },
      { label: "Total Sales", fieldName: "formattedTotalSales", type: "text" },
      {
        label: "Per Machine Sales",
        fieldName: "formattedPerMachineSales",
        type: "text"
      },
      { label: "Margin", fieldName: "formattedMargin", type: "text" },
      {
        label: "Cost Recovery",
        fieldName: "costRecoveryPercent",
        type: "text"
      },
      {
        label: "Investment Share",
        fieldName: "investmentSharePercent",
        type: "text"
      }
    ];
  }

  get customerInvestmentColumns() {
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
      { label: "Investment", fieldName: "formattedInvestment", type: "text" },
      { label: "Total Sales", fieldName: "formattedTotalSales", type: "text" },
      {
        label: "Per Machine Sales",
        fieldName: "formattedPerMachineSales",
        type: "text"
      },
      { label: "Margin", fieldName: "formattedMargin", type: "text" },
      {
        label: "Cost Recovery",
        fieldName: "costRecoveryPercent",
        type: "text"
      },
      {
        label: "Investment Share",
        fieldName: "investmentSharePercent",
        type: "text"
      },
      {
        type: "action",
        typeAttributes: {
          rowActions: [{ label: "View Details", name: "view_details" }]
        }
      }
    ];
  }

  get regionalCommitmentColumns() {
    return [
      { label: "Region", fieldName: "region", type: "text" },
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
      }
    ];
  }

  get supplierCommitmentColumns() {
    return [
      { label: "Supplier", fieldName: "supplier", type: "text" },
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
      }
    ];
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
      console.log("Canvas not found or Chart.js not loaded yet");
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

      console.log(
        "📈 Target vs Actual chart created successfully with",
        trendData.months.length,
        "data points"
      );
    } catch (error) {
      console.error("❌ Error creating Target vs Actual chart:", error);
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
    console.log("🔍 DEBUG: Starting performInitialRiskAnalysis");
    console.log(
      "🔍 DEBUG: Snapshot data length:",
      this.snapshotData?.length || 0
    );

    this.customerRiskAnalysis.clear();

    // Group ALL snapshot data by customer (not filtered data)
    const customerMonthlyData = this.groupDataByCustomerAndMonth(
      this.snapshotData
    );

    console.log(
      "🔍 DEBUG: Customer monthly data size:",
      customerMonthlyData?.size || 0
    );

    // Analyze each customer's trend
    for (const [
      customerCode,
      monthlyRecords
    ] of customerMonthlyData.entries()) {
      const riskProfile = this.calculateCustomerRiskProfile(
        customerCode,
        monthlyRecords
      );
      console.log(
        `🔍 DEBUG: Customer ${customerCode} risk profile:`,
        riskProfile
      );
      this.customerRiskAnalysis.set(customerCode, riskProfile);
    }

    console.log(
      "🔍 DEBUG: Final risk analysis size:",
      this.customerRiskAnalysis.size
    );
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
    const customerData = new Map();

    // Debug: Check all records for customer 3020001237 before grouping
    const customer3020001237Records = dataSource.filter(
      (record) => record.customerCode === "3020001237"
    );

    if (customer3020001237Records.length > 0) {
      console.log("🔍 DEBUG: All filtered records for customer 3020001237:");
      customer3020001237Records.forEach((record, index) => {
        console.log(`Record ${index + 1}:`, {
          customerCode: record.customerCode,
          customerName: record.customerName,
          snapshotMonth: record.snapshotMonth,
          totalReagentSales: record.totalReagentSales,
          targetSales: record.targetSales,
          businessCaseId: record.businessCaseId,
          businessCaseName: record.businessCaseName
        });
      });
    } else {
      console.log(
        "🚨 DEBUG: No filtered records found for customer 3020001237"
      );

      // Check if records exist in original snapshot data
      const originalRecords = this.snapshotData.filter(
        (record) => record.customerCode === "3020001237"
      );

      if (originalRecords.length > 0) {
        console.log(
          "🔍 DEBUG: Original snapshot records for customer 3020001237 (before filtering):"
        );
        originalRecords.forEach((record, index) => {
          console.log(`Original Record ${index + 1}:`, {
            customerCode: record.customerCode,
            customerName: record.customerName,
            snapshotMonth: record.snapshotMonth,
            totalReagentSales: record.totalReagentSales,
            targetSales: record.targetSales,
            businessCaseId: record.businessCaseId,
            businessCaseName: record.businessCaseName
          });
        });
      } else {
        console.log(
          "🚨 DEBUG: No records found for customer 3020001237 even in original snapshot data"
        );
      }
    }

    dataSource.forEach((record) => {
      const customerCode = record.customerCode;
      const monthKey = record.snapshotMonth;

      if (!customerCode || !monthKey) {
        return;
      }

      if (!customerData.has(customerCode)) {
        customerData.set(customerCode, new Map());
      }

      const customerMonths = customerData.get(customerCode);
      if (!customerMonths.has(monthKey)) {
        customerMonths.set(monthKey, {
          month: monthKey,
          customerCode: customerCode,
          customerName: record.customerName,
          region: record.region,
          vendor: record.vendor,
          businessCaseId: record.businessCaseId,
          businessCaseName: record.businessCaseName,
          businessCaseStatus: record.businessCaseStatus,
          machineStatus: record.machineStatus,
          monthlySales: 0,
          monthlyTarget: 0,
          achievement: 0,
          records: []
        });
      }

      const monthData = customerMonths.get(monthKey);

      // Try multiple field name variations for sales and target
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

      // Use existing achievement if available, otherwise calculate
      if (record.achievement !== null && record.achievement !== undefined) {
        monthData.achievement = record.achievement;
      } else if (monthData.monthlyTarget > 0) {
        monthData.achievement =
          (monthData.monthlySales / monthData.monthlyTarget) * 100;
      }
    });

    // Convert to sorted monthly data for each customer
    const sortedCustomerData = new Map();
    for (const [customerCode, monthsMap] of customerData.entries()) {
      const sortedMonths = Array.from(monthsMap.values()).sort(
        (a, b) => new Date(a.month) - new Date(b.month)
      );
      sortedCustomerData.set(customerCode, sortedMonths);
    }

    return sortedCustomerData;
  }

  // Calculate simplified risk profile for a customer
  calculateCustomerRiskProfile(customerCode, monthlyRecords) {
    // Debug logging for specific customer
    if (customerCode === "3020001237") {
      console.log("🔍 RISK ANALYSIS DEBUG for customer 3020001237:");
      console.log("Monthly records received:", monthlyRecords);
      console.log("Number of months:", monthlyRecords.length);
      monthlyRecords.forEach((record, index) => {
        console.log(`Month ${index + 1}:`, {
          month: record.month,
          monthlySales: record.monthlySales,
          monthlyTarget: record.monthlyTarget,
          achievement: record.achievement,
          records: record.records.length
        });
      });
    }

    // Sort monthly records by date (oldest to newest)
    const sortedRecords = monthlyRecords.sort(
      (a, b) => new Date(a.month) - new Date(b.month)
    );

    // Debug after sorting
    if (customerCode === "3020001237") {
      console.log("📅 Sorted records for 3020001237:");
      sortedRecords.forEach((record, index) => {
        console.log(`Sorted Month ${index + 1}:`, {
          month: record.month,
          monthlySales: record.monthlySales,
          monthlyTarget: record.monthlyTarget,
          achievement: record.achievement
        });
      });
    }

    // Calculate consecutive months not meeting target (achievement < 100%)
    const consecutiveFailedMonths =
      this.calculateConsecutiveFailedMonths(sortedRecords);

    // Debug consecutive calculation
    if (customerCode === "3020001237") {
      console.log(
        "🚨 Consecutive failed months calculated:",
        consecutiveFailedMonths
      );
    }

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

    if (isDebugCustomer) {
      console.log("🔍 CONSECUTIVE FAILED MONTHS DEBUG for 3020001237:");
      console.log("Input sorted records:", sortedRecords);
    }

    // Count from the most recent month backwards
    for (let i = sortedRecords.length - 1; i >= 0; i--) {
      const record = sortedRecords[i];
      const achievement = record.achievement || 0;

      if (isDebugCustomer) {
        console.log(
          `Month ${i} (${record.month}): achievement = ${achievement}%, failed = ${achievement < 100}`
        );
      }

      // If achievement is less than 100%, it's a failed month
      if (achievement < 100) {
        consecutiveFailedMonths++;
        if (isDebugCustomer) {
          console.log(
            `  ➡️ Failed month detected, consecutive count now: ${consecutiveFailedMonths}`
          );
        }
      } else {
        if (isDebugCustomer) {
          console.log(
            `  ✅ Successful month found, stopping count at: ${consecutiveFailedMonths}`
          );
        }
        // Stop counting when we hit a successful month
        break;
      }
    }

    if (isDebugCustomer) {
      console.log(
        `🎯 Final consecutive failed months for 3020001237: ${consecutiveFailedMonths}`
      );
    }

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
    console.log(`🏢 Calculating risk profile for region: ${regionName}`);

    // Validate input arrays
    if (
      !monthlySales ||
      !monthlyTargets ||
      monthlySales.length === 0 ||
      monthlyTargets.length === 0
    ) {
      console.log(
        `⚠️ No data available for region ${regionName}, defaulting to HEALTHY`
      );
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

    console.log(`🏢 Region ${regionName} risk analysis:`, {
      riskLevel,
      consecutiveFailedMonths,
      actionRequired,
      riskScore,
      achievementsCount: achievements.length
    });

    return {
      riskLevel,
      consecutiveFailedMonths,
      actionRequired,
      riskScore
    };
  }

  calculateSupplierRiskProfile(supplierName, monthlySales, monthlyTargets) {
    console.log(`🏭 Calculating risk profile for supplier: ${supplierName}`);

    // Validate input arrays
    if (
      !monthlySales ||
      !monthlyTargets ||
      monthlySales.length === 0 ||
      monthlyTargets.length === 0
    ) {
      console.log(
        `⚠️ No data available for supplier ${supplierName}, defaulting to HEALTHY`
      );
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

    console.log(`🏭 Supplier ${supplierName} risk analysis:`, {
      riskLevel,
      consecutiveFailedMonths,
      actionRequired,
      riskScore,
      achievementsCount: achievements.length
    });

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
        return "📉 Declining";
      case "STABLE":
        return "➡️ Stable";
      case "IMPROVING":
        return "📈 Improving";
      case "INSUFFICIENT_DATA":
        return "❓ Unknown";
      default:
        return "❓ Unknown";
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