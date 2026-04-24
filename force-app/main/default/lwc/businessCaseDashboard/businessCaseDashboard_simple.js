import { LightningElement, track } from "lwc";

export default class BusinessCaseDashboard extends LightningElement {
  @track isLoading = false;
  @track activeTab = "commitment";
  @track chartJSLoaded = false;

  // Sample data for testing
  @track overviewMetrics = {
    totalCustomers: 25,
    onTrackCustomers: 15,
    behindTargetCustomers: 8,
    noTargetCustomers: 2,
    healthyCustomers: 18,
    warningCustomers: 5,
    highRiskCustomers: 1,
    criticalCustomers: 1
  };

  connectedCallback() {
    console.log("🚀 Simple BusinessCaseDashboard component connected");
    this.isLoading = false; // Ensure not loading
  }

  handleTabChange(event) {
    this.activeTab = event.target.value;
    console.log("Tab changed to:", this.activeTab);
  }

  handleRefresh() {
    console.log("Refresh clicked");
    this.showToast("Success", "Dashboard refreshed", "success");
  }

  handleExport() {
    console.log("Export clicked");
    this.showToast("Info", "Export functionality coming soon", "info");
  }

  showToast(title, message, variant) {
    console.log(`Toast: ${title} - ${message} (${variant})`);
  }

  // Simple formatting methods
  formatCurrency(value) {
    if (!value) return "$0.00";
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD'
    }).format(value);
  }

  formatPercent(value) {
    if (!value) return "0%";
    return `${Math.round(value)}%`;
  }

  // Computed properties with sample data
  get formattedTotalInvestment() {
    return this.formatCurrency(1250000);
  }

  get formattedTotalSales() {
    return this.formatCurrency(950000);
  }

  get formattedTotalMargin() {
    return this.formatCurrency(285000);
  }

  get costRecoveryRate() {
    return this.formatPercent(76);
  }
}