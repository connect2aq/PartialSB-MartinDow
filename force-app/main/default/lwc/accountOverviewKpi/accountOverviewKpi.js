import { LightningElement, api, wire, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getAccountSegment from "@salesforce/apex/AccountKpiController.getAccountSegment";
import getSalesKpi from "@salesforce/apex/AccountKpiController.getSalesKpi";
import getOpenOpportunities from "@salesforce/apex/AccountKpiController.getOpenOpportunities";
import getOpportunityToSalesConversionYTD from "@salesforce/apex/AccountKpiController.getOpportunityToSalesConversionYTD";
import getOpportunityToSalesConversionMTD from "@salesforce/apex/AccountKpiController.getOpportunityToSalesConversionMTD";
import getVisitStatsYTD from "@salesforce/apex/AccountKpiController.getVisitStatsYTD";
import getVisitStatsMTD from "@salesforce/apex/AccountKpiController.getVisitStatsMTD";
import getCreditProfiles from "@salesforce/apex/AccountKpiController.getCreditProfiles";
import getOpenComplaints from "@salesforce/apex/AccountKpiController.getOpenComplaints";
import getAssetStageCounts from "@salesforce/apex/AccountKpiController.getAssetStageCounts";

export default class AccountOverviewKpi extends LightningElement {
  @api recordId;
  @track opportunityToSalesConversionYTD = 0;
  @track opportunityToSalesConversionMTD = 0;
  @track visitStatsYTD = { completed: 0, plan: 0 };
  @track visitStatsMTD = { completed: 0, scheduled: 0 };
  @track creditProfileTiles = [];
  @track openComplaints = 0;

  @track assetStageCounts = null;
  @track showAssetsSection = false;

  accountSegment;

  division = null;

  // Sales KPIs
  totalSalesYTD = 0;
  totalSalesMTD = 0;

  openOpportunityCount = 0;
  openOpportunityAmount = 0;

  connectedCallback() {
    this.handleRefresh();
  }

  get tiles() {
    const formatPKR = (val) => {
      if (val === null || val === undefined) return "—";
      return "PKR " + Number(val).toLocaleString("en-US");
    };
    // Base tiles
    let tiles = [
      { label: "Account Segment", value: this.accountSegment },
      { label: "Total Sales (YTD)", value: formatPKR(this.totalSalesYTD) },
      { label: "Total Sales (MTD)", value: formatPKR(this.totalSalesMTD) },
      {
        label: "Open Opportunities",
        value:
          this.openOpportunityCount +
          " (" +
          formatPKR(this.openOpportunityAmount) +
          ")"
      },
      {
        label: "Opportunity to Sales Conversion (YTD)",
        value: this.opportunityToSalesConversionYTD + "%"
      },
      {
        label: "Opportunity to Sales Conversion (MTD)",
        value: this.opportunityToSalesConversionMTD + "%"
      },
      {
        label: "Visits YTD (Completed / Planned)",
        value: `${this.visitStatsYTD.completed} / ${this.visitStatsYTD.plan}`
      },
      {
        label: "Visits MTD (Completed / Planned)",
        value: `${this.visitStatsMTD.completed} / ${this.visitStatsMTD.scheduled}`
      },
      { label: "Open Complaints", value: this.openComplaints },

      // Credit profile tiles (may be more than one)
      ...this.creditProfileTiles
    ];
    // Add a class property for wide credit tiles
    return tiles.map((tile) => {
      if (tile.label && tile.label.includes("Outstanding / Credit Limit")) {
        return { ...tile, wide: true };
      }
      return { ...tile, wide: false };
    });
  }

  get assetTiles() {
    if (!this.assetStageCounts) return [];
    return [
      { label: "Ordered", value: this.assetStageCounts.Ordered },
      { label: "Installed", value: this.assetStageCounts.Installed },
      { label: "Active", value: this.assetStageCounts.Active },
      { label: "Rejected", value: this.assetStageCounts.Rejected },
      { label: "Inactive", value: this.assetStageCounts.Inactive }
    ];
  }

  loadAccountSegment() {
    console.log("Calling getAccountSegment with recordId:", this.recordId);
    getAccountSegment({ accountId: this.recordId })
      .then((segment) => {
        console.log("getAccountSegment result:", segment);
        this.accountSegment = segment;
        // Optionally, fetch division if needed for UI logic
        this.division = segment && segment.division ? segment.division : null;
      })
      .catch((error) => {
        this.accountSegment = "—";
        console.error("Error loading Account Segment:", error);
      });
  }
  loadAssetStageCounts() {
    getAssetStageCounts({ accountId: this.recordId })
      .then((result) => {
        this.assetStageCounts = result;
        // Show section if any count > 0 (or always if division is Diagnostic)
        this.showAssetsSection = Object.values(result).some((v) => v > 0);
      })
      .catch((error) => {
        this.assetStageCounts = null;
        this.showAssetsSection = false;
        console.error("Error loading asset stage counts:", error);
      });
  }

  loadSalesKpi() {
    getSalesKpi({ accountId: this.recordId })
      .then((data) => {
        this.totalSalesYTD = data.totalSalesYTD;
        this.totalSalesMTD = data.totalSalesMTD;
      })
      .catch((error) => {
        console.error("Error fetching sales KPIs:", error);
      });
  }

  loadOpenOpportunities() {
    getOpenOpportunities({ accountId: this.recordId })
      .then((data) => {
        this.openOpportunityCount = data.count;
        this.openOpportunityAmount = data.amount;
      })
      .catch((error) => {
        console.error("Error fetching open opportunities:", error);
      });
  }

  loadOpportunityToSalesConversion() {
    getOpportunityToSalesConversionYTD({ accountId: this.recordId })
      .then((result) => {
        this.opportunityToSalesConversionYTD = result;
      })
      .catch((error) => {
        this.opportunityToSalesConversionYTD = 0;
        console.error(
          "Error fetching Opportunity to Sales Conversion YTD:",
          error
        );
      });
    getOpportunityToSalesConversionMTD({ accountId: this.recordId })
      .then((result) => {
        this.opportunityToSalesConversionMTD = result;
      })
      .catch((error) => {
        this.opportunityToSalesConversionMTD = 0;
        console.error(
          "Error fetching Opportunity to Sales Conversion MTD:",
          error
        );
      });
  }

  loadVisitsYTD() {
    getVisitStatsYTD({ accountId: this.recordId })
      .then((result) => {
        this.visitStatsYTD.completed = result.completed || 0;
        this.visitStatsYTD.plan = result.plan || 0;
        console.log("Visits YTD loaded:", this.visitStatsYTD);
      })
      .catch((error) => {
        console.error("Error loading Visits YTD:", error);
      });
  }

  loadVisitsMTD() {
    getVisitStatsMTD({ accountId: this.recordId })
      .then((result) => {
        this.visitStatsMTD.completed = result.completed || 0;
        this.visitStatsMTD.scheduled = result.scheduled || 0;
      })
      .catch((error) => {
        console.error("Error loading Visits MTD:", error);
      });
  }

  loadCreditProfiles() {
    getCreditProfiles({ accountId: this.recordId })
      .then((data) => {
        if (!data || data.length === 0) {
          this.creditProfileTiles = [
            {
              label: "Outstanding / Credit Limit",
              value: "No credit profiles found"
            }
          ];
          return;
        }
        const formatPKR = (val) => {
          if (val === null || val === undefined) return "—";
          return "PKR " + Number(val).toLocaleString("en-US");
        };
        this.creditProfileTiles = data.map((item) => {
          const percent =
            item.percentage != null ? ` (${item.percentage}%)` : "";
          return {
            label: `Outstanding / Credit Limit\n${item.segment}`,
            value: `${formatPKR(item.outstanding)} / ${formatPKR(item.limit)}${percent}`
          };
        });
      })
      .catch((error) => {
        console.error("Error fetching credit profiles:", error);
      });
  }

  loadOpenComplaints() {
    getOpenComplaints({ accountId: this.recordId })
      .then((count) => {
        this.openComplaints = count;
      })
      .catch((error) => {
        this.openComplaints = 0;
        console.error("Error loading open complaints:", error);
      });
  }

  handleRefresh() {
    console.log(
      "Refreshing Account Overview KPIs for recordId:",
      this.recordId
    );
    this.loadAccountSegment();
    this.loadSalesKpi();
    this.loadOpenOpportunities();
    this.loadOpportunityToSalesConversion();
    this.loadVisitsYTD();
    this.loadVisitsMTD();
    this.loadCreditProfiles();
    this.loadOpenComplaints();
    this.loadAssetStageCounts();
  }
}