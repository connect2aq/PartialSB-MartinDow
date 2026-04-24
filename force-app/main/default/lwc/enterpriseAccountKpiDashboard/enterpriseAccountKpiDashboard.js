import { LightningElement, api, wire } from "lwc";
import getEnterpriseAccountKpiData from "@salesforce/apex/EnterpriseAccountKpiService.getEnterpriseAccountKpiData";

export default class EnterpriseAccountKpiDashboard extends LightningElement {
  @api recordId;
  enterpriseKpiTiles = [];
  functionalAccounts = [];
  error;

  get safeRecordId() {
    return this.recordId ? this.recordId : undefined;
  }

  @wire(getEnterpriseAccountKpiData, { enterpriseAccountId: "$safeRecordId" })
  wiredKpiData({ error, data }) {
    // Debug: log the recordId value
    console.log("EnterpriseAccountKpiDashboard recordId:", this.recordId);
    // Prevent processing if recordId is missing
    if (!this.recordId) {
      this.error =
        "No record selected. Please add this component to a record page.";
      this.enterpriseKpi = undefined;
      this.enterpriseKpiTiles = [];
      this.functionalAccounts = [];
      return;
    }
    if (data) {
      console.log("KPI data received:", data);
      this.error = undefined;
      this.enterpriseKpi = data;
      // Format numbers to two decimal places for enterprise tiles
      const format2 = (v) => {
        if (v === undefined || v === null || v === "") return v;
        const n = Number(v);
        return isNaN(n) ? v : n.toFixed(2);
      };

      this.enterpriseKpiTiles = [
        { label: "Sales YTD", value: format2(data.totalSalesYTD) },
        { label: "Sales MTD", value: format2(data.totalSalesMTD) },
        {
          label: "Open Opps (Amount)",
          value:
            data.openOpportunityCount + " (" + data.openOpportunityAmount + ")"
        },
        {
          label: "Opp→Sales YTD",
          value: format2(data.opportunityToSalesConversionYTD) + "%"
        },
        {
          label: "Opp→Sales MTD",
          value: format2(data.opportunityToSalesConversionMTD) + "%"
        },
        {
          label: "Visits YTD (C / P)",
          value: data.visitsYTDCompleted + " / " + data.visitsYTDPlanned
        },
        {
          label: "Visits MTD (C / P)",
          value: data.visitsMTDCompleted + " / " + data.visitsMTDPlanned
        },
        { label: "Open Complaints", value: data.openComplaints }
      ];
      // Add hasDiagnostics property and formatted values to each functional account
      this.functionalAccounts = (data.functionalAccounts || []).map((func) => ({
        ...func,
        totalSalesYTDFormatted: format2(func.totalSalesYTD),
        totalSalesMTDFormatted: format2(func.totalSalesMTD),
        opportunityToSalesConversionYTDFormatted: format2(
          func.opportunityToSalesConversionYTD
        ),
        opportunityToSalesConversionMTDFormatted: format2(
          func.opportunityToSalesConversionMTD
        ),
        hasDiagnostics:
          (func.diagnosticOrdered && func.diagnosticOrdered > 0) ||
          (func.diagnosticInstalled && func.diagnosticInstalled > 0) ||
          (func.diagnosticActive && func.diagnosticActive > 0) ||
          (func.diagnosticRejected && func.diagnosticRejected > 0) ||
          (func.diagnosticInactive && func.diagnosticInactive > 0)
      }));
    } else if (error) {
      this.error =
        "Error loading KPIs: " +
        (error.body && error.body.message ? error.body.message : error);
    }
  }
  get hasEnterpriseDiagnostics() {
    console.log("Checking for enterprise diagnostics");
    console.log("key", this.enterpriseKpi);
    console.log("value", this.enterpriseKpi?.diagnosticOrdered);
    const kpi = this.enterpriseKpi;
    return (
      kpi &&
      (kpi.diagnosticOrdered !== undefined ||
        kpi.diagnosticInstalled !== undefined ||
        kpi.diagnosticActive !== undefined ||
        kpi.diagnosticRejected !== undefined ||
        kpi.diagnosticInactive !== undefined)
    );
  }
}