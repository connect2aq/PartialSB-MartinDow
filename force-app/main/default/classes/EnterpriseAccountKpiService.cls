public with sharing class EnterpriseAccountKpiService {
  @AuraEnabled(cacheable=true)
  public static EnterpriseAccountKpiDTO getEnterpriseAccountKpiData(
    Id enterpriseAccountId
  ) {
    try {
      // Null check for input
      if (enterpriseAccountId == null) {
        throw new AuraHandledException('Enterprise Account Id cannot be null.');
      }
      // 1. Query all functional accounts under the enterprise account
      List<Account> functionalAccounts = [
        SELECT
          Id,
          Name,
          SAP_Customer_Number__c,
          AddressLine_1__c,
          City__c,
          Combined_Segment__c
        FROM Account
        WHERE Enterprise_Account__c = :enterpriseAccountId
      ];
      List<Id> functionalAccountIds = new List<Id>();
      for (Account acc : functionalAccounts) {
        functionalAccountIds.add(acc.Id);
      }

      // Diagnostic Machines KPIs
      // We'll use Status__c to count machines by status for each functional account
      Map<Id, Integer> diagnosticOrderedMap = new Map<Id, Integer>();
      Map<Id, Integer> diagnosticInstalledMap = new Map<Id, Integer>();
      Map<Id, Integer> diagnosticActiveMap = new Map<Id, Integer>();
      Map<Id, Integer> diagnosticRejectedMap = new Map<Id, Integer>();
      Map<Id, Integer> diagnosticInactiveMap = new Map<Id, Integer>();
      if (!functionalAccountIds.isEmpty()) {
        for (AggregateResult ar : [
          SELECT AccountId__c accId, Status__c status, COUNT(Id) cnt
          FROM MD_Asset__c
          WHERE AccountId__c IN :functionalAccountIds
          GROUP BY AccountId__c, Status__c
        ]) {
          Id accId = (Id) ar.get('accId');
          String status = (String) ar.get('status');
          Integer cnt = (Integer) ar.get('cnt');
          if (status == 'Ordered') {
            diagnosticOrderedMap.put(accId, cnt);
          } else if (status == 'Installed') {
            diagnosticInstalledMap.put(accId, cnt);
          } else if (status == 'Active') {
            diagnosticActiveMap.put(accId, cnt);
          } else if (status == 'Rejected') {
            diagnosticRejectedMap.put(accId, cnt);
          } else if (status == 'Inactive') {
            diagnosticInactiveMap.put(accId, cnt);
          }
        }
      }

      // 2. Query KPIs for all functional accounts in bulk
      // Total Sales (YTD) from Invoice_Line_Item__c.Price__c grouped by Invoice__r.Functional_Account__c
      Map<Id, Decimal> salesYTDMap = new Map<Id, Decimal>();
      for (AggregateResult ar : [
        SELECT
          Invoice__r.Functional_Account__c accId,
          SUM(Invoice_Value__c) totalSalesYTD
        FROM Invoice_Line_Item__c
        WHERE
          Invoice__r.Functional_Account__c IN :functionalAccountIds
          AND CALENDAR_YEAR(CreatedDate) = :Date.today().year()
        GROUP BY Invoice__r.Functional_Account__c
      ]) {
        salesYTDMap.put(
          (Id) ar.get('accId'),
          (Decimal) ar.get('totalSalesYTD')
        );
      }

      // Total Sales (MTD) from Invoice_Line_Item__c.Price__c grouped by Invoice__r.Functional_Account__c
      Map<Id, Decimal> salesMTDMap = new Map<Id, Decimal>();
      for (AggregateResult ar : [
        SELECT
          Invoice__r.Functional_Account__c accId,
          SUM(Invoice_Value__c) totalSalesMTD
        FROM Invoice_Line_Item__c
        WHERE
          Invoice__r.Functional_Account__c IN :functionalAccountIds
          AND CALENDAR_YEAR(CreatedDate) = :Date.today().year()
          AND CALENDAR_MONTH(CreatedDate) = :Date.today().month()
        GROUP BY Invoice__r.Functional_Account__c
      ]) {
        salesMTDMap.put(
          (Id) ar.get('accId'),
          (Decimal) ar.get('totalSalesMTD')
        );
      }

      // Open Opportunities (count and amount)
      Map<Id, Integer> openOppCountMap = new Map<Id, Integer>();
      Map<Id, Decimal> openOppAmountMap = new Map<Id, Decimal>();
      for (AggregateResult ar : [
        SELECT Account_Name__c accId, COUNT(Id) cnt, SUM(Amount__c) amt
        FROM MD_Opportunity__c
        WHERE
          Account_Name__c IN :functionalAccountIds
          AND Stage__c NOT IN ('Close_Opportunity')
        GROUP BY Account_Name__c
      ]) {
        openOppCountMap.put((Id) ar.get('accId'), (Integer) ar.get('cnt'));
        openOppAmountMap.put((Id) ar.get('accId'), (Decimal) ar.get('amt'));
      }
      // Opportunity to Sales Conversion (YTD)
      // Numerator: # of Closed Won Opps with at least one related Invoice__c (via Invoice__c.BusinessOpportunity__c)
      // Denominator: # of Closed Won Opps
      Map<Id, Set<Id>> closedWonOppsYTDMap = new Map<Id, Set<Id>>();
      for (MD_Opportunity__c opp : [
        SELECT Id, Account_Name__c
        FROM MD_Opportunity__c
        WHERE
          Account_Name__c IN :functionalAccountIds
          AND Close_Won_Or_Close_Lost__c = 'Close Won'
          AND CALENDAR_YEAR(Close_Date__c) = :Date.today().year()
      ]) {
        if (!closedWonOppsYTDMap.containsKey(opp.Account_Name__c)) {
          closedWonOppsYTDMap.put(opp.Account_Name__c, new Set<Id>());
        }
        closedWonOppsYTDMap.get(opp.Account_Name__c).add(opp.Id);
      }

      // Find which Closed Won Opps have at least one related Invoice__c (via BusinessOpportunity__c)
      Set<Id> allClosedWonOppIdsYTD = new Set<Id>();
      for (Set<Id> oppIds : closedWonOppsYTDMap.values()) {
        allClosedWonOppIdsYTD.addAll(oppIds);
      }
      Set<Id> oppsWithInvoiceYTD = new Set<Id>();
      if (!allClosedWonOppIdsYTD.isEmpty()) {
        for (AggregateResult ar : [
          SELECT BusinessOpportunity__c oppId
          FROM Invoice__c
          WHERE BusinessOpportunity__c IN :allClosedWonOppIdsYTD
          GROUP BY BusinessOpportunity__c
        ]) {
          oppsWithInvoiceYTD.add((Id) ar.get('oppId'));
        }
      }
      Map<Id, Decimal> oppToSalesYTDMap = new Map<Id, Decimal>();
      for (Id accId : functionalAccountIds) {
        Set<Id> oppIds = closedWonOppsYTDMap.containsKey(accId)
          ? closedWonOppsYTDMap.get(accId)
          : new Set<Id>();
        Integer denom = oppIds.size();
        Integer numer = 0;
        for (Id oppId : oppIds) {
          if (oppsWithInvoiceYTD.contains(oppId)) {
            numer++;
          }
        }
        Decimal pct = (denom > 0) ? ((Decimal) numer / denom) * 100 : 0;
        oppToSalesYTDMap.put(accId, pct);
      }

      // Opportunity to Sales Conversion (MTD)
      // Numerator: # of Closed Won Opps with at least one related Invoice__c (via Invoice__c.BusinessOpportunity__c)
      // Denominator: # of Closed Won Opps
      Map<Id, Set<Id>> closedWonOppsMTDMap = new Map<Id, Set<Id>>();
      for (MD_Opportunity__c opp : [
        SELECT Id, Account_Name__c
        FROM MD_Opportunity__c
        WHERE
          Account_Name__c IN :functionalAccountIds
          AND Close_Won_Or_Close_Lost__c = 'Close Won'
          AND CALENDAR_YEAR(Close_Date__c) = :Date.today().year()
          AND CALENDAR_MONTH(Close_Date__c) = :Date.today().month()
      ]) {
        if (!closedWonOppsMTDMap.containsKey(opp.Account_Name__c)) {
          closedWonOppsMTDMap.put(opp.Account_Name__c, new Set<Id>());
        }
        closedWonOppsMTDMap.get(opp.Account_Name__c).add(opp.Id);
      }

      Set<Id> allClosedWonOppIdsMTD = new Set<Id>();
      for (Set<Id> oppIds : closedWonOppsMTDMap.values()) {
        allClosedWonOppIdsMTD.addAll(oppIds);
      }
      Set<Id> oppsWithInvoiceMTD = new Set<Id>();
      if (!allClosedWonOppIdsMTD.isEmpty()) {
        for (AggregateResult ar : [
          SELECT BusinessOpportunity__c oppId
          FROM Invoice__c
          WHERE BusinessOpportunity__c IN :allClosedWonOppIdsMTD
          GROUP BY BusinessOpportunity__c
        ]) {
          oppsWithInvoiceMTD.add((Id) ar.get('oppId'));
        }
      }
      Map<Id, Decimal> oppToSalesMTDMap = new Map<Id, Decimal>();
      for (Id accId : functionalAccountIds) {
        Set<Id> oppIds = closedWonOppsMTDMap.containsKey(accId)
          ? closedWonOppsMTDMap.get(accId)
          : new Set<Id>();
        Integer denom = oppIds.size();
        Integer numer = 0;
        for (Id oppId : oppIds) {
          if (oppsWithInvoiceMTD.contains(oppId)) {
            numer++;
          }
        }
        Decimal pct = (denom > 0) ? ((Decimal) numer / denom) * 100 : 0;
        oppToSalesMTDMap.put(accId, pct);
      }

      // Visits YTD (Completed/Planned)
      Map<Id, Integer> visitsYTDCompletedMap = new Map<Id, Integer>();
      Map<Id, Integer> visitsYTDPlannedMap = new Map<Id, Integer>();
      for (AggregateResult ar : [
        SELECT Account__c accId, Status__c status, COUNT(Id) cnt
        FROM Event
        WHERE
          Account__c IN :functionalAccountIds
          AND ActivityDate = THIS_YEAR
          AND Status__c IN ('Completed', 'Plan')
        GROUP BY Account__c, Status__c
      ]) {
        Id accId = (Id) ar.get('accId');
        String status = (String) ar.get('status');
        Integer cnt = (Integer) ar.get('cnt');
        if (status == 'Completed') {
          visitsYTDCompletedMap.put(accId, cnt);
        } else if (status == 'Plan') {
          visitsYTDPlannedMap.put(accId, cnt);
        }
      }
      // Visits MTD (Completed/Planned)
      Map<Id, Integer> visitsMTDCompletedMap = new Map<Id, Integer>();
      Map<Id, Integer> visitsMTDPlannedMap = new Map<Id, Integer>();
      for (AggregateResult ar : [
        SELECT AccountId accId, Status__c status, COUNT(Id) cnt
        FROM Event
        WHERE
          AccountId IN :functionalAccountIds
          AND ActivityDate = THIS_MONTH
          AND Status__c IN ('Completed', 'Plan')
        GROUP BY AccountId, Status__c
      ]) {
        Id accId = (Id) ar.get('accId');
        String status = (String) ar.get('status');
        Integer cnt = (Integer) ar.get('cnt');
        if (status == 'Completed') {
          visitsMTDCompletedMap.put(accId, cnt);
        } else if (status == 'Plan') {
          visitsMTDPlannedMap.put(accId, cnt);
        }
      }

      // Example: Open Complaints
      Map<Id, Integer> openComplaintsMap = new Map<Id, Integer>();
      for (AggregateResult ar : [
        SELECT AccountId__c accId, COUNT(Id) cnt
        FROM MD_Case__c
        WHERE AccountId__c IN :functionalAccountIds AND Status__c != 'Closure'
        GROUP BY AccountId__c
      ]) {
        openComplaintsMap.put((Id) ar.get('accId'), (Integer) ar.get('cnt'));
      }

      // 3. Build FunctionalAccountKpiDTOs and aggregate for enterprise
      List<FunctionalAccountKpiDTO> funcDtos = new List<FunctionalAccountKpiDTO>();
      Decimal entTotalSalesYTD = 0;
      Decimal entTotalSalesMTD = 0;
      Integer entOpenOppCount = 0;
      Decimal entOpenOppAmount = 0;
      Integer entOpenComplaints = 0;
      Integer entVisitsYTDCompleted = 0;
      Integer entVisitsYTDPlanned = 0;
      Integer entVisitsMTDCompleted = 0;
      Integer entVisitsMTDPlanned = 0;

      Decimal entOpportunityToSalesConversionYTD = 0;
      Decimal entOpportunityToSalesConversionMTD = 0;
      // Enterprise-level diagnostic KPIs
      Integer entDiagnosticOrdered = 0;
      Integer entDiagnosticInstalled = 0;
      Integer entDiagnosticActive = 0;
      Integer entDiagnosticRejected = 0;
      Integer entDiagnosticInactive = 0;

      for (Account acc : functionalAccounts) {
        FunctionalAccountKpiDTO fDto = new FunctionalAccountKpiDTO();
        fDto.accountId = acc != null && acc.Id != null ? acc.Id : '';
        fDto.name = acc != null && acc.Name != null ? acc.Name : '';
        fDto.sapNumber = acc != null &&
          acc.SAP_Customer_Number__c != null
          ? acc.SAP_Customer_Number__c
          : '';
        fDto.addressLine1 = acc != null &&
          acc.AddressLine_1__c != null
          ? acc.AddressLine_1__c
          : '';
        fDto.city = acc != null && acc.City__c != null ? acc.City__c : '';
        fDto.accountSegment = acc != null &&
          acc.Combined_Segment__c != null
          ? acc.Combined_Segment__c
          : '';

        fDto.totalSalesYTD = (salesYTDMap != null &&
          salesYTDMap.containsKey(acc.Id) &&
          salesYTDMap.get(acc.Id) != null)
          ? salesYTDMap.get(acc.Id)
          : 0;
        fDto.totalSalesMTD = (salesMTDMap != null &&
          salesMTDMap.containsKey(acc.Id) &&
          salesMTDMap.get(acc.Id) != null)
          ? salesMTDMap.get(acc.Id)
          : 0;
        fDto.openOpportunityCount = (openOppCountMap != null &&
          openOppCountMap.containsKey(acc.Id) &&
          openOppCountMap.get(acc.Id) != null)
          ? openOppCountMap.get(acc.Id)
          : 0;
        fDto.openOpportunityAmount = (openOppAmountMap != null &&
          openOppAmountMap.containsKey(acc.Id) &&
          openOppAmountMap.get(acc.Id) != null)
          ? openOppAmountMap.get(acc.Id)
          : 0;
        fDto.openComplaints = (openComplaintsMap != null &&
          openComplaintsMap.containsKey(acc.Id) &&
          openComplaintsMap.get(acc.Id) != null)
          ? openComplaintsMap.get(acc.Id)
          : 0;

        fDto.visitsYTDCompleted = (visitsYTDCompletedMap != null &&
          visitsYTDCompletedMap.containsKey(acc.Id) &&
          visitsYTDCompletedMap.get(acc.Id) != null)
          ? visitsYTDCompletedMap.get(acc.Id)
          : 0;
        fDto.visitsYTDPlanned = (visitsYTDPlannedMap != null &&
          visitsYTDPlannedMap.containsKey(acc.Id) &&
          visitsYTDPlannedMap.get(acc.Id) != null)
          ? visitsYTDPlannedMap.get(acc.Id)
          : 0;
        fDto.visitsMTDCompleted = (visitsMTDCompletedMap != null &&
          visitsMTDCompletedMap.containsKey(acc.Id) &&
          visitsMTDCompletedMap.get(acc.Id) != null)
          ? visitsMTDCompletedMap.get(acc.Id)
          : 0;
        fDto.visitsMTDPlanned = (visitsMTDPlannedMap != null &&
          visitsMTDPlannedMap.containsKey(acc.Id) &&
          visitsMTDPlannedMap.get(acc.Id) != null)
          ? visitsMTDPlannedMap.get(acc.Id)
          : 0;

        fDto.opportunityToSalesConversionYTD = (oppToSalesYTDMap != null &&
          oppToSalesYTDMap.containsKey(acc.Id) &&
          oppToSalesYTDMap.get(acc.Id) != null)
          ? oppToSalesYTDMap.get(acc.Id)
          : 0;
        fDto.opportunityToSalesConversionMTD = (oppToSalesMTDMap != null &&
          oppToSalesMTDMap.containsKey(acc.Id) &&
          oppToSalesMTDMap.get(acc.Id) != null)
          ? oppToSalesMTDMap.get(acc.Id)
          : 0;

        // Diagnostic KPIs
        fDto.diagnosticOrdered = (diagnosticOrderedMap != null &&
          diagnosticOrderedMap.containsKey(acc.Id) &&
          diagnosticOrderedMap.get(acc.Id) != null)
          ? diagnosticOrderedMap.get(acc.Id)
          : 0;
        fDto.diagnosticInstalled = (diagnosticInstalledMap != null &&
          diagnosticInstalledMap.containsKey(acc.Id) &&
          diagnosticInstalledMap.get(acc.Id) != null)
          ? diagnosticInstalledMap.get(acc.Id)
          : 0;
        fDto.diagnosticActive = (diagnosticActiveMap != null &&
          diagnosticActiveMap.containsKey(acc.Id) &&
          diagnosticActiveMap.get(acc.Id) != null)
          ? diagnosticActiveMap.get(acc.Id)
          : 0;
        fDto.diagnosticRejected = (diagnosticRejectedMap != null &&
          diagnosticRejectedMap.containsKey(acc.Id) &&
          diagnosticRejectedMap.get(acc.Id) != null)
          ? diagnosticRejectedMap.get(acc.Id)
          : 0;
        fDto.diagnosticInactive = (diagnosticInactiveMap != null &&
          diagnosticInactiveMap.containsKey(acc.Id) &&
          diagnosticInactiveMap.get(acc.Id) != null)
          ? diagnosticInactiveMap.get(acc.Id)
          : 0;
        // TODO: Add other KPIs and diagnostic KPIs as needed

        // Aggregate for enterprise diagnostic KPIs
        entDiagnosticOrdered += fDto.diagnosticOrdered;
        entDiagnosticInstalled += fDto.diagnosticInstalled;
        entDiagnosticActive += fDto.diagnosticActive;
        entDiagnosticRejected += fDto.diagnosticRejected;
        entDiagnosticInactive += fDto.diagnosticInactive;

        funcDtos.add(fDto);

        // Aggregate for enterprise
        entTotalSalesYTD += fDto.totalSalesYTD;
        entTotalSalesMTD += fDto.totalSalesMTD;
        entOpenOppCount += fDto.openOpportunityCount;
        entOpenOppAmount += fDto.openOpportunityAmount;
        entOpenComplaints += fDto.openComplaints;
        entVisitsYTDCompleted += fDto.visitsYTDCompleted;
        entVisitsYTDPlanned += fDto.visitsYTDPlanned;
        entVisitsMTDCompleted += fDto.visitsMTDCompleted;
        entVisitsMTDPlanned += fDto.visitsMTDPlanned;
        entOpportunityToSalesConversionYTD += fDto.opportunityToSalesConversionYTD;
        entOpportunityToSalesConversionMTD += fDto.opportunityToSalesConversionMTD;
      }

      // 4. Query enterprise account details
      List<Account> entAccs = [
        SELECT
          Id,
          Name,
          SAP_Customer_Number__c,
          AddressLine_1__c,
          City__c,
          Combined_Segment__c
        FROM Account
        WHERE Id = :enterpriseAccountId
        LIMIT 1
      ];
      if (entAccs.isEmpty()) {
        throw new AuraHandledException(
          'Enterprise Account not found for Id: ' +
          String.valueOf(enterpriseAccountId)
        );
      }
      Account entAcc = entAccs[0];

      // 5. Populate EnterpriseAccountKpiDTO
      EnterpriseAccountKpiDTO dto = new EnterpriseAccountKpiDTO();
      dto.accountId = entAcc.Id;
      dto.name = entAcc.Name;
      dto.sapNumber = entAcc.SAP_Customer_Number__c;
      dto.addressLine1 = entAcc.AddressLine_1__c;
      dto.city = entAcc.City__c;
      dto.accountSegment = entAcc.Combined_Segment__c;
      dto.totalSalesYTD = entTotalSalesYTD;
      dto.totalSalesMTD = entTotalSalesMTD;
      dto.openOpportunityCount = entOpenOppCount;
      dto.openOpportunityAmount = entOpenOppAmount;
      dto.openComplaints = entOpenComplaints;
      dto.visitsYTDCompleted = entVisitsYTDCompleted;
      dto.visitsYTDPlanned = entVisitsYTDPlanned;
      dto.visitsMTDCompleted = entVisitsMTDCompleted;
      dto.visitsMTDPlanned = entVisitsMTDPlanned;
      dto.opportunityToSalesConversionYTD = functionalAccountIds.size() > 0
        ? (entOpportunityToSalesConversionYTD / functionalAccountIds.size())
        : 0;
      dto.opportunityToSalesConversionMTD = functionalAccountIds.size() > 0
        ? (entOpportunityToSalesConversionMTD / functionalAccountIds.size())
        : 0;
      // Add enterprise-level diagnostic KPIs
      dto.diagnosticOrdered = entDiagnosticOrdered;
      dto.diagnosticInstalled = entDiagnosticInstalled;
      dto.diagnosticActive = entDiagnosticActive;
      dto.diagnosticRejected = entDiagnosticRejected;
      dto.diagnosticInactive = entDiagnosticInactive;

      dto.functionalAccounts = funcDtos;

      // TODO: Add other aggregated KPIs as needed

      System.debug(
        'EnterpriseAccountKpiService DTO about to return: ' +
        JSON.serialize(dto)
      );
      return dto;
    } catch (Exception ex) {
      System.debug('EnterpriseAccountKpiService ERROR: ' + ex.getMessage());
      System.debug(
        'EnterpriseAccountKpiService STACK: ' + ex.getStackTraceString()
      );
      throw new AuraHandledException(
        'Error in getEnterpriseAccountKpiData: ' + ex.getMessage()
      );
    }
  }
}