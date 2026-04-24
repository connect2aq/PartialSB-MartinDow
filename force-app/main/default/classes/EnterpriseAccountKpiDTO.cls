public class EnterpriseAccountKpiDTO {
  @AuraEnabled
  public String accountId;
  @AuraEnabled
  public String name;
  @AuraEnabled
  public String sapNumber;
  @AuraEnabled
  public String addressLine1;
  @AuraEnabled
  public String city;

  // 9 KPIs
  @AuraEnabled
  public String accountSegment;
  @AuraEnabled
  public Decimal totalSalesYTD;
  @AuraEnabled
  public Decimal totalSalesMTD;
  @AuraEnabled
  public Integer openOpportunityCount;
  @AuraEnabled
  public Decimal openOpportunityAmount;
  @AuraEnabled
  public Decimal opportunityToSalesConversionYTD;
  @AuraEnabled
  public Decimal opportunityToSalesConversionMTD;
  @AuraEnabled
  public Integer visitsYTDCompleted;
  @AuraEnabled
  public Integer visitsYTDPlanned;
  @AuraEnabled
  public Integer visitsMTDCompleted;
  @AuraEnabled
  public Integer visitsMTDPlanned;
  @AuraEnabled
  public Integer openComplaints;

  // Enterprise-level Diagnostic Machines KPIs
  @AuraEnabled
  public Integer diagnosticOrdered;
  @AuraEnabled
  public Integer diagnosticInstalled;
  @AuraEnabled
  public Integer diagnosticActive;
  @AuraEnabled
  public Integer diagnosticRejected;
  @AuraEnabled
  public Integer diagnosticInactive;

  // List of functional accounts
  @AuraEnabled
  public List<FunctionalAccountKpiDTO> functionalAccounts;

  public EnterpriseAccountKpiDTO() {
    functionalAccounts = new List<FunctionalAccountKpiDTO>();
  }
}