public with sharing class AccountKpiController {
  /**
   * Returns a map of asset stage counts for the given account, but only if the account is in the 'Diagnostic' division.
   * Stages: Ordered, Installed, Active, Rejected, Inactive (Status__c field)
   */
  @AuraEnabled
  public static Map<String, Integer> getAssetStageCounts(Id accountId) {
    Map<String, Integer> stageCounts = new Map<String, Integer>();
    stageCounts.put('Ordered', 0);
    stageCounts.put('Installed', 0);
    stageCounts.put('Active', 0);
    stageCounts.put('Rejected', 0);
    stageCounts.put('Inactive', 0);

    // // Check if the account is in the Diagnostic division
    // No need to check division here as it is commented out
    // String division = [
    //   SELECT Id, Division__c
    //   FROM Account
    //   WHERE Id = :accountId
    //   LIMIT 1
    // ]
    // .Division__c;
    // if (division == null || !division.equalsIgnoreCase('Diagnostic')) {
    //   return stageCounts; // Return all zeros if not Diagnostic
    // }

    // Query assets for this account and count by Status__c
    for (AggregateResult ar : [
      SELECT Status__c, COUNT(Id) cnt
      FROM MD_Asset__c
      WHERE
        AccountId__c = :accountId
        AND Status__c IN (
          'Ordered',
          'Installed',
          'Active',
          'Rejected',
          'Inactive'
        )
      GROUP BY Status__c
    ]) {
      String status = (String) ar.get('Status__c');
      Integer cnt = (Integer) ar.get('cnt');
      if (stageCounts.containsKey(status)) {
        stageCounts.put(status, cnt);
      }
    }
    return stageCounts;
  }

  @AuraEnabled
  public static Decimal getOpportunityToSalesConversionYTD(Id accountId) {
    Date today = Date.today();
    Date startOfYear = Date.newInstance(today.year(), 1, 1);
    // Fetch Closed Won Opportunities for this year
    List<Id> closedWonOppIds = new List<Id>();
    for (MD_Opportunity__c opp : [
      SELECT Id
      FROM MD_Opportunity__c
      WHERE
        Close_Won_Or_Close_Lost__c = 'Close Won'
        AND Account_Name__c = :accountId
        AND CreatedDate >= :startOfYear
    ]) {
      closedWonOppIds.add(opp.Id);
    }
    if (closedWonOppIds.isEmpty())
      return 0;
    // Fetch Opportunity IDs from Invoices for this year
    Set<Id> invoicedOppIds = new Set<Id>();
    for (AggregateResult ar : [
      SELECT BusinessOpportunity__c
      FROM Invoice__c
      WHERE
        BusinessOpportunity__c IN :closedWonOppIds
        AND CreatedDate >= :startOfYear
      GROUP BY BusinessOpportunity__c
    ]) {
      invoicedOppIds.add((Id) ar.get('BusinessOpportunity__c'));
    }
    Integer convertedCount = invoicedOppIds.size();
    Decimal conversionRate =
      ((Decimal) convertedCount / closedWonOppIds.size()) * 100;
    return conversionRate.setScale(2);
  }

  @AuraEnabled
  public static Decimal getOpportunityToSalesConversionMTD(Id accountId) {
    Date today = Date.today();
    Date startOfMonth = Date.newInstance(today.year(), today.month(), 1);
    // Fetch Closed Won Opportunities for this month
    List<Id> closedWonOppIds = new List<Id>();
    for (MD_Opportunity__c opp : [
      SELECT Id
      FROM MD_Opportunity__c
      WHERE
        Close_Won_Or_Close_Lost__c = 'Close Won'
        AND Account_Name__c = :accountId
        AND CreatedDate >= :startOfMonth
    ]) {
      closedWonOppIds.add(opp.Id);
    }
    if (closedWonOppIds.isEmpty())
      return 0;
    // Fetch Opportunity IDs from Invoices for this month
    Set<Id> invoicedOppIds = new Set<Id>();
    for (AggregateResult ar : [
      SELECT BusinessOpportunity__c
      FROM Invoice__c
      WHERE
        BusinessOpportunity__c IN :closedWonOppIds
        AND CreatedDate >= :startOfMonth
      GROUP BY BusinessOpportunity__c
    ]) {
      invoicedOppIds.add((Id) ar.get('BusinessOpportunity__c'));
    }
    Integer convertedCount = invoicedOppIds.size();
    Decimal conversionRate =
      ((Decimal) convertedCount / closedWonOppIds.size()) * 100;
    return conversionRate.setScale(2);
  }

  @AuraEnabled
  public static Integer getOpenComplaints(Id accountId) {
    // Adjust the status value if your org uses a different closed status
    return [
      SELECT COUNT()
      FROM MD_Case__c
      WHERE
        AccountId__c = :accountId
        AND (Status__c != 'Closure'
        OR Status__c = NULL)
    ];
  }

  @AuraEnabled
  public static List<Map<String, Object>> getCreditProfiles(Id accountId) {
    List<Credit_Profile__c> creditProfiles = [
      SELECT Id, Credit_Segment__c, Outstanding_Amount__c, Credit_Limit__c
      FROM Credit_Profile__c
      WHERE Account__c = :accountId
    ];

    List<Map<String, Object>> results = new List<Map<String, Object>>();
    for (Credit_Profile__c profile : creditProfiles) {
      Decimal outstanding = profile.Outstanding_Amount__c != null
        ? profile.Outstanding_Amount__c
        : 0;
      Decimal creditLimit = profile.Credit_Limit__c != null
        ? profile.Credit_Limit__c
        : 0;
      Decimal percentage = creditLimit > 0
        ? (outstanding / creditLimit) * 100
        : 0;

      Map<String, Object> mapEntry = new Map<String, Object>();
      mapEntry.put('segment', profile.Credit_Segment__c);
      mapEntry.put('outstanding', outstanding);
      mapEntry.put('limit', creditLimit);
      mapEntry.put('percentage', percentage.setScale(0));
      results.add(mapEntry);
    }

    return results;
  }

  @AuraEnabled
  public static Map<String, Integer> getVisitStatsMTD(Id accountId) {
    Date firstDayOfMonth = Date.today().toStartOfMonth();
    Date firstDayNextMonth = firstDayOfMonth.addMonths(1);

    List<Event> events = [
      SELECT Id, Status__c
      FROM Event
      WHERE
        Account__c = :accountId
        AND StartDateTime >= :firstDayOfMonth
        AND StartDateTime < :firstDayNextMonth
        AND Status__c IN ('Completed', 'Plan')
    ];

    Integer completed = 0;
    Integer scheduled = 0;

    for (Event ev : events) {
      if (ev.Status__c == 'Completed') {
        completed++;
      } else if (ev.Status__c == 'Plan') {
        scheduled++;
      }
    }

    return new Map<String, Integer>{
      'completed' => completed,
      'scheduled' => scheduled
    };
  }

  @AuraEnabled
  public static Map<String, Integer> getVisitStatsYTD(Id accountId) {
    Date today = Date.today();
    Date startOfYearDate = Date.newInstance(today.year(), 1, 1);
    DateTime startOfYear = DateTime.newInstance(
      startOfYearDate,
      Time.newInstance(0, 0, 0, 0)
    );

    List<Event> events = [
      SELECT Id, Status__c
      FROM Event
      WHERE
        Account__c = :accountId
        AND StartDateTime >= :startOfYear
        AND Status__c IN ('Completed', 'Plan')
    ];

    Integer completed = 0;
    Integer plan = 0;

    for (Event ev : events) {
      if (ev.Status__c == 'Completed') {
        completed++;
      } else if (ev.Status__c == 'Plan') {
        plan++;
      }
    }

    return new Map<String, Integer>{ 'completed' => completed, 'plan' => plan };
  }

  @AuraEnabled
  public static String getAccountSegment(Id accountId) {
    if (accountId == null)
      return null;
    Account acc = [
      SELECT Combined_Segment__c
      FROM Account
      WHERE Id = :accountId
      LIMIT 1
    ];
    return acc.Combined_Segment__c;
  }

  @AuraEnabled
  public static Map<String, Decimal> getSalesKpi(Id accountId) {
    Map<String, Decimal> kpiData = new Map<String, Decimal>{
      'totalSalesYTD' => 0,
      'totalSalesMTD' => 0
    };

    if (accountId == null)
      return kpiData;

    Date today = Date.today();
    Date startOfYear = Date.newInstance(today.year(), 1, 1);
    Date startOfMonth = Date.newInstance(today.year(), today.month(), 1);

    AggregateResult[] results = [
      SELECT
        CALENDAR_MONTH(Invoice__r.CreatedDate) month,
        CALENDAR_YEAR(Invoice__r.CreatedDate) year,
        SUM(Invoice_Value__c) total
      FROM Invoice_Line_Item__c
      WHERE
        Invoice__r.Functional_Account__c = :accountId
        AND Invoice__r.CreatedDate >= :startOfYear
      GROUP BY
        CALENDAR_YEAR(Invoice__r.CreatedDate),
        CALENDAR_MONTH(Invoice__r.CreatedDate)
    ];

    for (AggregateResult ar : results) {
      Integer year = (Integer) ar.get('year');
      Integer month = (Integer) ar.get('month');
      Decimal total = (Decimal) ar.get('total');

      if (year == today.year()) {
        kpiData.put('totalSalesYTD', kpiData.get('totalSalesYTD') + total);
        if (month == today.month()) {
          kpiData.put('totalSalesMTD', kpiData.get('totalSalesMTD') + total);
        }
      }
    }

    return kpiData;
  }

  @AuraEnabled
  public static Map<String, Object> getOpenOpportunities(Id accountId) {
    List<AggregateResult> result = [
      SELECT COUNT(Id) totalCount, SUM(Amount__c) totalAmount
      FROM MD_Opportunity__c
      WHERE
        Account_Name__c = :accountId
        AND Stage__c NOT IN ('Close_Opportunity')
    ];

    Map<String, Object> response = new Map<String, Object>();
    if (!result.isEmpty()) {
      AggregateResult ar = result[0];
      response.put('count', (Integer) ar.get('totalCount'));
      response.put(
        'amount',
        (Decimal) (ar.get('totalAmount') != null ? ar.get('totalAmount') : 0)
      );
    } else {
      response.put('count', 0);
      response.put('amount', 0);
    }
    system.debug('aq: ' + response);
    return response;
  }

  @AuraEnabled
  public static Decimal getOpportunityToSalesConversion(Id accountId) {
    // Fetch Closed Won Opportunities related to the account
    List<Id> closedWonOppIds = new List<Id>();

    for (MD_Opportunity__c opp : [
      SELECT Id
      FROM MD_Opportunity__c
      WHERE
        Close_Won_Or_Close_Lost__c = 'Close Won'
        AND Account_Name__c = :accountId
    ]) {
      closedWonOppIds.add(opp.Id);
    }

    if (closedWonOppIds.isEmpty())
      return 0;

    // Fetch Opportunity IDs from Invoices
    Set<Id> invoicedOppIds = new Set<Id>();
    for (AggregateResult ar : [
      SELECT BusinessOpportunity__c
      FROM Invoice__c
      WHERE BusinessOpportunity__c IN :closedWonOppIds
      GROUP BY BusinessOpportunity__c
    ]) {
      invoicedOppIds.add((Id) ar.get('BusinessOpportunity__c'));
    }

    Integer convertedCount = invoicedOppIds.size();
    Decimal conversionRate =
      ((Decimal) convertedCount / closedWonOppIds.size()) * 100;
    return conversionRate.setScale(2);
  }
}