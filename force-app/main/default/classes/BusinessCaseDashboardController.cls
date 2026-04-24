public with sharing class BusinessCaseDashboardController {
    /**
     * Get all business case data from snapshots only (Snapshot-Only Architecture)
     * This method now uses purely snapshot data for consistent performance and single source of truth
     */
    // @AuraEnabled(cacheable=true)
    // public static List<SnapshotWrapper> getSnapshotData() {
    //     try {
    //         // System.debug(
    //         //     '>>>>BusinessCaseDashboardController-->getSnapshotData'
    //         // );
    //         List<SnapshotWrapper> wrappers = new List<SnapshotWrapper>();

    //         Map<Id, Date> bcToLatestMonth = new Map<Id, Date>();

    //         for (AggregateResult ar : [
    //             SELECT Business_Case__c bc, MAX(Snapshot_Month__c) maxMonth
    //             FROM Business_Case_Sales_Snapshot__c
    //             WHERE
    //                 Processing_Status__c = 'Completed'
    //                 AND Business_Case__r.Is_Master__c = FALSE
    //                 AND (Business_Case__r.Status__c LIKE '%Active%'
    //                 OR Business_Case__r.Status__c LIKE '%Revised%'
    //                 OR Business_Case__r.Status__c LIKE '%New%')
    //             GROUP BY Business_Case__c
    //         ]) {
    //             bcToLatestMonth.put(
    //                 (Id) ar.get('bc'),
    //                 (Date) ar.get('maxMonth')
    //             );
    //         }

    //         List<Business_Case_Sales_Snapshot__c> snapshots = [
    //             SELECT
    //                 Id,
    //                 Business_Case__c,
    //                 Business_Case_Name__c,
    //                 Business_Case_Status__c,
    //                 Machine_Status__c,
    //                 Customer_Code__c,
    //                 Customer_Name__c,
    //                 Vendor__c,
    //                 Technology__c,
    //                 Region__c,
    //                 Material_Number__c,
    //                 Material_Description__c,
    //                 Customer_Province__c,
    //                 Customer_City__c,
    //                 Customer_AddressLine1__c,
    //                 Customer_AddressLine2__c,
    //                 Customer_Postal_Code__c,
    //                 Customer_Country__c,
    //                 Ship_To_Customer_Number__c,
    //                 Ship_To_Customer_Name__c,
    //                 Ship_To_Province__c,
    //                 Ship_To_City__c,
    //                 Ship_To_AddressLine1__c,
    //                 Ship_To_Address_Line_2__c,
    //                 Ship_To_Postal_Code__c,
    //                 Ship_To_Country__c,
    //                 Snapshot_Month__c,
    //                 Total_Reagent_Sales__c,
    //                 Target_Sales__c,
    //                 Machine_Count__c,
    //                 Per_Machine_Sales__c,
    //                 Source_Invoice_Count__c,
    //                 YTD_Sales__c,
    //                 Total_Reagent_Sales_Till_Date__c,
    //                 Contract_Months_Elapsed__c,
    //                 Avg_Reagent_Sales_Per_Month__c,
    //                 Performance_Status__c,
    //                 Deficit_Cost_Covered__c,
    //                 Margin_Percent_Snapshot__c,
    //                 Margin_On_Reagent_Sale__c,
    //                 Payback_Remaining__c,
    //                 Data_Quality_Score__c,
    //                 Processing_Status__c,
    //                 Snapshot_Created_Date__c,
    //                 Monthly_Commitments__c,
    //                 Business_Case__r.Unit_Cost__c
    //             FROM Business_Case_Sales_Snapshot__c
    //             WHERE
    //                 Processing_Status__c = 'Completed'
    //                 AND Business_Case__r.Is_Master__c = FALSE
    //                 AND (Business_Case__r.Status__c LIKE '%Active%'
    //                 OR Business_Case__r.Status__c LIKE '%Revised%'
    //                 OR Business_Case__r.Status__c LIKE '%New%')
    //             ORDER BY Snapshot_Month__c DESC, Snapshot_Created_Date__c DESC
    //         ];

    //         // System.debug(
    //         //     '>>>>BusinessCaseDashboardController-->getSnapshotData-->snapshots: ' +
    //         //     snapshots.size()
    //         // );

    //         List<Business_Case_Sales_Snapshot__c> filteredSnapshots = new List<Business_Case_Sales_Snapshot__c>();

    //         for (Business_Case_Sales_Snapshot__c s : snapshots) {
    //             if (
    //                 bcToLatestMonth.containsKey(s.Business_Case__c) &&
    //                 s.Snapshot_Month__c ==
    //                 bcToLatestMonth.get(s.Business_Case__c)
    //             ) {
    //                 filteredSnapshots.add(s);
    //             }
    //         }
    //         // System.debug(
    //         //     '>>>>BusinessCaseDashboardController-->getSnapshotData-->filteredSnapshots: ' +
    //         //     filteredSnapshots.size()
    //         // );
    //         snapshots = filteredSnapshots;

    //         System.debug(
    //             '🔍 Total snapshots after filtering to latest month: ' +
    //             snapshots.size()
    //         );

    //         // ADDITIONAL FILTER: Keep only the most recent snapshot per Business Case
    //         // (in case there are multiple snapshots for the same month)
    //         Map<Id, Business_Case_Sales_Snapshot__c> latestSnapshotPerBC = new Map<Id, Business_Case_Sales_Snapshot__c>();

    //         for (Business_Case_Sales_Snapshot__c s : snapshots) {
    //             if (!latestSnapshotPerBC.containsKey(s.Business_Case__c)) {
    //                 // First snapshot for this BC
    //                 latestSnapshotPerBC.put(s.Business_Case__c, s);
    //             } else {
    //                 // Compare Snapshot_Created_Date__c to keep the latest
    //                 Business_Case_Sales_Snapshot__c existing = latestSnapshotPerBC.get(
    //                     s.Business_Case__c
    //                 );
    //                 if (
    //                     s.Snapshot_Created_Date__c >
    //                     existing.Snapshot_Created_Date__c
    //                 ) {
    //                     latestSnapshotPerBC.put(s.Business_Case__c, s);
    //                 }
    //             }
    //         }

    //         // Replace snapshots with deduplicated list
    //         snapshots = latestSnapshotPerBC.values();

    //         System.debug(
    //             '🔍 Unique Business Cases after deduplication: ' +
    //             snapshots.size()
    //         );

    //         // Process ALL snapshots to create wrapper objects for risk management
    //         for (Business_Case_Sales_Snapshot__c snapshot : snapshots) {
    //             SnapshotWrapper wrapper = new SnapshotWrapper();

    //             // Core Business Case information from snapshot
    //             wrapper.businessCaseId = snapshot.Business_Case__c;
    //             wrapper.businessCaseName = snapshot.Business_Case_Name__c;
    //             wrapper.businessCaseStatus = snapshot.Business_Case_Status__c;
    //             wrapper.customerCode = snapshot.Customer_Code__c;
    //             wrapper.customerName = snapshot.Customer_Name__c;
    //             wrapper.vendor = snapshot.Vendor__c;
    //             wrapper.technology = snapshot.Technology__c;
    //             wrapper.region = snapshot.Region__c;
    //             wrapper.materialNumber = snapshot.Material_Number__c;
    //             wrapper.materialDescription = snapshot.Material_Description__c;
    //             wrapper.machineStatus = snapshot.Machine_Status__c;

    //             // Customer Address Information from snapshot
    //             wrapper.customerProvince = snapshot.Customer_Province__c;
    //             wrapper.customerCity = snapshot.Customer_City__c;
    //             wrapper.customerAddressLine1 = snapshot.Customer_AddressLine1__c;
    //             wrapper.customerAddressLine2 = snapshot.Customer_AddressLine2__c;
    //             wrapper.customerPostalCode = snapshot.Customer_Postal_Code__c;
    //             wrapper.customerCountry = snapshot.Customer_Country__c;

    //             // Ship To Account Information from snapshot
    //             wrapper.shipToCustomerNumber = snapshot.Ship_To_Customer_Number__c;
    //             wrapper.shipToCustomerName = snapshot.Ship_To_Customer_Name__c;
    //             wrapper.shipToProvince = snapshot.Ship_To_Province__c;
    //             wrapper.shipToCity = snapshot.Ship_To_City__c;
    //             wrapper.shipToAddressLine1 = snapshot.Ship_To_AddressLine1__c;
    //             wrapper.shipToAddressLine2 = snapshot.Ship_To_Address_Line_2__c;
    //             wrapper.shipToPostalCode = snapshot.Ship_To_Postal_Code__c;
    //             wrapper.shipToCountry = snapshot.Ship_To_Country__c;

    //             // Sales metrics from snapshot - all data comes from single source
    //             wrapper.id = snapshot.Id;
    //             wrapper.totalReagentSales = snapshot.Total_Reagent_Sales__c;
    //             wrapper.targetSales = snapshot.Target_Sales__c;
    //             wrapper.ytdSales = snapshot.YTD_Sales__c;
    //             wrapper.totalReagentSalesTillDate = snapshot.Total_Reagent_Sales_Till_Date__c;
    //             wrapper.marginOnReagentSale = snapshot.Margin_On_Reagent_Sale__c;
    //             wrapper.paybackRemaining = snapshot.Payback_Remaining__c;
    //             wrapper.machineCount = snapshot.Machine_Count__c;
    //             wrapper.perMachineSales = snapshot.Per_Machine_Sales__c;
    //             wrapper.contractMonthsElapsed = snapshot.Contract_Months_Elapsed__c;
    //             wrapper.avgReagentSalesPerMonth = snapshot.Avg_Reagent_Sales_Per_Month__c;
    //             wrapper.performanceStatus = snapshot.Performance_Status__c;
    //             wrapper.deficitCostCovered = snapshot.Deficit_Cost_Covered__c;
    //             wrapper.marginPercentSnapshot = snapshot.Margin_Percent_Snapshot__c;
    //             wrapper.dataQualityScore = snapshot.Data_Quality_Score__c;
    //             wrapper.snapshotMonth = snapshot.Snapshot_Month__c?.format();
    //             wrapper.formattedMonth = formatMonthLabel(
    //                 snapshot.Snapshot_Month__c
    //             );
    //             wrapper.investment = calculateInvestment(snapshot);

    //             // Formatted fields for display
    //             wrapper.formattedSales = formatCurrency(
    //                 wrapper.totalReagentSales
    //             );
    //             wrapper.formattedTarget = formatCurrency(wrapper.targetSales);
    //             wrapper.formattedAchievement = formatPercent(
    //                 calculateAchievementPercent(
    //                     wrapper.totalReagentSales,
    //                     wrapper.targetSales
    //                 )
    //             );

    //             wrappers.add(wrapper);
    //         }

    //         return wrappers;
    //     } catch (Exception e) {
    //         throw new AuraHandledException(
    //             'Error retrieving business case data: ' + e.getMessage()
    //         );
    //     }
    // }

    /**
     * Get filter options for dropdowns
     */
    @AuraEnabled(cacheable=true)
    public static FilterOptions getFilterOptions() {
        try {
            FilterOptions options = new FilterOptions();

            // Initialize collections
            Set<String> monthSet = new Set<String>();
            Set<String> regionSet = new Set<String>();
            Set<String> supplierSet = new Set<String>();
            Map<String, String> customerMap = new Map<String, String>(); // Code -> Name

            // Single query to get all filter data
            List<Business_Case_Sales_Snapshot__c> snapshots = [
                SELECT
                    Snapshot_Month__c,
                    Customer_Code__c,
                    Customer_Name__c,
                    Region__c,
                    Vendor__c
                FROM Business_Case_Sales_Snapshot__c
                WHERE
                    Processing_Status__c = 'Completed'
                    AND (Snapshot_Month__c != NULL
                    OR Customer_Code__c != NULL
                    OR Region__c != NULL
                    OR Vendor__c != NULL)
                ORDER BY
                    Snapshot_Month__c DESC,
                    Customer_Name__c,
                    Region__c,
                    Vendor__c
            ];

            // Process all records in a single loop
            for (Business_Case_Sales_Snapshot__c snapshot : snapshots) {
                // Collect months
                if (snapshot.Snapshot_Month__c != null) {
                    monthSet.add(snapshot.Snapshot_Month__c.format());
                }

                // Collect customers (avoid duplicates by using map)
                if (
                    String.isNotBlank(snapshot.Customer_Code__c) &&
                    String.isNotBlank(snapshot.Customer_Name__c)
                ) {
                    customerMap.put(
                        snapshot.Customer_Code__c,
                        snapshot.Customer_Name__c
                    );
                }

                // Collect regions
                if (String.isNotBlank(snapshot.Region__c)) {
                    regionSet.add(snapshot.Region__c);
                }

                // Collect suppliers/vendors
                if (String.isNotBlank(snapshot.Vendor__c)) {
                    supplierSet.add(snapshot.Vendor__c);
                }
            }

            // Convert sets to sorted lists
            options.months = new List<String>(monthSet);
            options.months.sort();
            options.months = reverseList(options.months); // Most recent first

            options.regions = new List<String>(regionSet);
            options.regions.sort();

            options.suppliers = new List<String>(supplierSet);
            options.suppliers.sort();

            // Convert customer map to sorted list of CustomerOption objects
            options.customers = new List<CustomerOption>();
            List<String> customerCodes = new List<String>(customerMap.keySet());
            customerCodes.sort();

            for (String code : customerCodes) {
                CustomerOption customer = new CustomerOption();
                customer.customerCode = code;
                customer.customerName = customerMap.get(code);
                options.customers.add(customer);
            }

            return options;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Error retrieving filter options: ' + e.getMessage()
            );
        }
    }

    // Helper method to reverse list order

    public static List<String> reverseList(List<String> inputList) {
        List<String> reversedList = new List<String>();
        for (Integer i = inputList.size() - 1; i >= 0; i--) {
            reversedList.add(inputList[i]);
        }
        return reversedList;
    }

    //Get Total Investment of all Business Cases
    //Date startDate, Date endDate, String region, String customer, String vendor,
    // String businessCaseStatus, String machineStatus, String commitmentStatus, String riskStatus
    @AuraEnabled(cacheable=true)
    public static FinancialOverviewPerformanceStats getTotalFinancialPerformanceStats(
        String DateFrom,
        String DateTo,
        String Region,
        String Supplier,
        String BusinessCaseStatus,
        String MachineStatus,
        String CommitmentStatus,
        String RiskStatus,
        String SearchCustomer,
        String BusinessCaseName
    ) {
        try {
            String whereBCClause = '';
            String whereBCSClause = '';
            String wheremasterClause = '';
            String whereMasterBCSClause = '';

            // Date From Filter - Filter snapshots from a specific date onwards
            if (!String.isBlank(DateFrom)) {
                Date parsedDateFrom = Date.valueOf(DateFrom);
                String formattedDateFrom =
                    parsedDateFrom.year() +
                    '-' +
                    String.valueOf(parsedDateFrom.month()).leftPad(2, '0') +
                    '-' +
                    String.valueOf(parsedDateFrom.day()).leftPad(2, '0');

                if (String.isBlank(whereBCSClause)) {
                    whereBCSClause =
                        ' WHERE Snapshot_Month__c >= ' + formattedDateFrom;
                } else {
                    whereBCSClause +=
                        ' AND Snapshot_Month__c >= ' + formattedDateFrom;
                }

                if (String.isBlank(whereMasterBCSClause)) {
                    whereMasterBCSClause =
                        ' WHERE Snapshot_Month__c >= ' + formattedDateFrom;
                } else {
                    whereMasterBCSClause +=
                        ' AND Snapshot_Month__c >= ' + formattedDateFrom;
                }

                System.debug(
                    'getTotalFinancialPerformanceStats - Date From filter: ' +
                    formattedDateFrom
                );
            }

            // Date To Filter - Filter snapshots up to a specific date
            if (!String.isBlank(DateTo)) {
                Date parsedDateTo = Date.valueOf(DateTo);
                String formattedDateTo =
                    parsedDateTo.year() +
                    '-' +
                    String.valueOf(parsedDateTo.month()).leftPad(2, '0') +
                    '-' +
                    String.valueOf(parsedDateTo.day()).leftPad(2, '0');

                if (String.isBlank(whereBCSClause)) {
                    whereBCSClause =
                        ' WHERE Snapshot_Month__c <= ' + formattedDateTo;
                } else {
                    whereBCSClause +=
                        ' AND Snapshot_Month__c <= ' + formattedDateTo;
                }

                if (String.isBlank(whereMasterBCSClause)) {
                    whereMasterBCSClause =
                        ' WHERE Snapshot_Month__c <= ' + formattedDateTo;
                } else {
                    whereMasterBCSClause +=
                        ' AND Snapshot_Month__c <= ' + formattedDateTo;
                }

                System.debug(
                    'getTotalFinancialPerformanceStats - Date To filter: ' +
                    formattedDateTo
                );
            }

            if (!String.isBlank(Region) && Region != 'All Regions') {
                if (String.isBlank(whereBCClause)) {
                    whereBCClause = ' WHERE Region__c = \'' + Region + '\'';
                } else {
                    whereBCClause += ' AND Region__c = \'' + Region + '\'';
                }

                if (String.isBlank(whereBCSClause)) {
                    whereBCSClause =
                        ' WHERE Business_Case__r.Region__c = \'' +
                        Region +
                        '\'';
                } else {
                    whereBCSClause +=
                        ' AND Business_Case__r.Region__c = \'' +
                        Region +
                        '\'';
                }
            }
            if (
                !String.isBlank(SearchCustomer) &&
                SearchCustomer != 'All Customers'
            ) {
                String scustomer = '';
                if (SearchCustomer.contains(' - ')) {
                    scustomer = SearchCustomer.split(' - ')[0];
                    scustomer = scustomer.trim();
                }
                if (String.isBlank(whereBCClause)) {
                    whereBCClause =
                        ' WHERE Customer_Number__c = \'' +
                        SearchCustomer +
                        '\'';
                } else {
                    whereBCClause +=
                        ' AND Customer_Number__c = \'' +
                        SearchCustomer +
                        '\'';
                }
                if (String.isBlank(wheremasterClause)) {
                    wheremasterClause =
                        ' WHERE Customer_Numbera__c = \'' +
                        SearchCustomer +
                        '\'';
                } else {
                    wheremasterClause +=
                        ' AND Customer_Numbera__c = \'' +
                        SearchCustomer +
                        '\'';
                }
                if (String.isBlank(whereMasterBCSClause)) {
                    whereMasterBCSClause =
                        ' WHERE Customer_Code__c = \'' +
                        SearchCustomer +
                        '\'';
                } else {
                    whereMasterBCSClause +=
                        ' AND Customer_Code__c = \'' +
                        SearchCustomer +
                        '\'';
                }

                if (String.isBlank(whereBCSClause)) {
                    whereBCSClause =
                        ' WHERE Customer_Code__c = \'' +
                        SearchCustomer +
                        '\'';
                } else {
                    whereBCSClause +=
                        ' AND Customer_Code__c = \'' +
                        SearchCustomer +
                        '\'';
                }
            }
            if (
                !String.isBlank(BusinessCaseStatus) &&
                BusinessCaseStatus != 'All Business Case Statuses'
            ) {
                String sbusinesscasestatus = '';
                // System.debug(
                //     '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->BusinessCaseStatus: ' +
                //     BusinessCaseStatus
                // );
                sbusinesscasestatus = BusinessCaseStatus.trim();

                if (String.isBlank(whereBCClause)) {
                    whereBCClause =
                        ' WHERE Status__c  = \'' +
                        sbusinesscasestatus +
                        '\' ';
                } else {
                    whereBCClause +=
                        ' AND Status__c  = \'' +
                        sbusinesscasestatus +
                        '\'';
                }

                if (String.isBlank(whereBCSClause)) {
                    whereBCSClause =
                        ' WHERE Business_Case__r.Status__c = \'' +
                        sbusinesscasestatus +
                        '\'';
                } else {
                    whereBCSClause +=
                        ' AND Business_Case__r.Status__c = \'' +
                        sbusinesscasestatus +
                        '\'';
                }
            } else {
                if (String.isBlank(whereBCClause)) {
                    whereBCClause = ' WHERE (Status__c  LIKE \'%Active%\' OR Status__c LIKE \'%Revised%\' OR Status__c LIKE \'%New%\') ';
                } else {
                    whereBCClause += ' AND (Status__c  LIKE \'%Active%\' OR Status__c LIKE \'%Revised%\' OR Status__c LIKE \'%New%\')';
                }

                //  if (String.isBlank(whereBCSClause)) {
                //       whereBCSClause = ' WHERE (Business_Case__r.Status__c  LIKE \'%Active%\' OR Business_Case__r.Status__c LIKE \'%Revised%\' OR Business_Case__r.Status__c LIKE \'%New%\')';
                //   } else {
                //       whereBCSClause += ' AND (Business_Case__r.Status__c  LIKE \'%Active%\' OR Business_Case__r.Status__c LIKE \'%Revised%\' OR Business_Case__r.Status__c LIKE \'%New%\')';
                //   }
            }

            if (
                !String.isBlank(MachineStatus) &&
                MachineStatus != 'All Machine Statuses'
            ) {
                String smachinestatus = '';
                smachinestatus = MachineStatus.trim();

                if (String.isBlank(whereBCClause)) {
                    whereBCClause =
                        ' WHERE Machine_Installation__r.Status__c  = \'' +
                        smachinestatus +
                        '\'';
                } else {
                    whereBCClause +=
                        ' AND Machine_Installation__r.Status__c  = \'' +
                        smachinestatus +
                        '\'';
                }

                if (String.isBlank(whereBCSClause)) {
                    whereBCSClause =
                        ' WHERE Business_Case__r.Machine_Installation__r.Status__c = \'' +
                        smachinestatus +
                        '\'';
                } else {
                    whereBCSClause +=
                        ' AND Business_Case__r.Machine_Installation__r.Status__c = \'' +
                        smachinestatus +
                        '\'';
                }
            }

            if (
                !String.isBlank(CommitmentStatus) &&
                CommitmentStatus != 'All Commitment Statuses'
            ) {
                String scommitmenttatus = '';
                scommitmenttatus = CommitmentStatus.trim();

                whereBCSClause +=
                    ' AND Performance_Status__c  = \'' +
                    scommitmenttatus +
                    '\'';
            }

            if (!String.isBlank(Supplier) && Supplier != 'All Suppliers') {
                String ssupplier = '';
                if (Supplier.contains(' - ')) {
                    ssupplier = Supplier.split(' - ')[0];
                    ssupplier = ssupplier.trim();
                }

                whereBCSClause += ' AND Vendor__c  = \'' + Supplier + '\'';
            }

            if (
                !String.isBlank(BusinessCaseName) &&
                BusinessCaseName != 'All Business Cases'
            ) {
                String sbcname = '';
                sbcname = BusinessCaseName.trim();

                if (String.isBlank(whereBCClause)) {
                    whereBCClause = ' WHERE Name  = \'' + sbcname + '\'';
                } else {
                    whereBCClause += ' AND Name  = \'' + sbcname + '\'';
                }
                if (String.isBlank(wheremasterClause)) {
                    wheremasterClause = ' WHERE Name  = \'' + sbcname + '\'';
                } else {
                    wheremasterClause += ' AND Name  = \'' + sbcname + '\'';
                }
                if (String.isBlank(whereMasterBCSClause)) {
                    whereMasterBCSClause =
                        ' WHERE Business_Case__r.Name  = \'' +
                        sbcname +
                        '\'';
                } else {
                    whereMasterBCSClause +=
                        ' AND Business_Case__r.Name  = \'' +
                        sbcname +
                        '\'';
                }

                if (String.isBlank(whereBCSClause)) {
                    whereBCSClause =
                        ' WHERE Business_Case__r.Name = \'' +
                        sbcname +
                        '\'';
                } else {
                    whereBCSClause +=
                        ' AND Business_Case__r.Name = \'' +
                        sbcname +
                        '\'';
                }
            }
            if (String.isBlank(wheremasterClause)) {
                wheremasterClause = ' WHERE RecordType.Name = \'Master Business Case\'';
            } else {
                wheremasterClause += ' AND RecordType.Name = \'Master Business Case\'';
            }
            if (String.isBlank(whereBCClause)) {
                //masterClause = ' WHERE RecordType.Name = \'Master Business Case\'';
            } else {
                //masterClause = whereBCClause + ' AND RecordType.Name = \'Master Business Case\'';
            }
            //String masterBCSClause = whereBCSClause + ' AND Business_Case__r.RecordType.Name = \'Master Business Case\'';
            if (String.isBlank(whereMasterBCSClause)) {
                whereMasterBCSClause = ' WHERE Business_Case__r.RecordType.Name = \'Master Business Case\'';
            } else {
                whereMasterBCSClause =
                    whereMasterBCSClause +
                    ' AND Business_Case__r.RecordType.Name = \'Master Business Case\'';
            }

            if (String.isBlank(whereBCClause)) {
                whereBCClause = ' WHERE Is_Master__c = false and Master_Business_Case__c = null';
            } else {
                whereBCClause += ' AND Is_Master__c = false and Master_Business_Case__c = null';
            }
            if (String.isBlank(whereBCSClause)) {
                whereBCSClause = ' WHERE Business_Case__r.Is_Master__c = false and Business_Case__r.Master_Business_Case__c = null ';
            } else {
                whereBCSClause += ' AND Business_Case__r.Is_Master__c = false and Business_Case__r.Master_Business_Case__c = null';
            }
            // System.debug(
            //     '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->whereBCClause: ' +
            //     whereBCClause
            // );
            Integer rrcount = 0;
            String bcaggregatequery =
                'Select SUM(Unit_Cost__c) totalInvestment from Business_Case__c ' +
                whereBCClause;
            System.debug(
                '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->bcaggregatequery: ' +
                bcaggregatequery
            );
            String bcaggregatequeryforquantity =
                'Select Quantity__c from Business_Case__c ' +
                whereBCClause;
            System.debug(
                '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->bcaggregatequeryforquantity: ' +
                bcaggregatequeryforquantity
            );
            AggregateResult totalInvestmentAmount = Database.query(
                bcaggregatequery
            );
            List<Business_Case__c> bclistforquantity = Database.query(
                bcaggregatequeryforquantity
            );

            FinancialOverviewPerformanceStats fstats = new FinancialOverviewPerformanceStats();
            //AggregateResult totalInvestmentAmount = [Select SUM(Total_Unit_Cost__c) totalInvestment from Business_Case__c where Status__c != 'Closed'];
            if (totalInvestmentAmount != null) {
                fstats.financialOverviewTotalInvestment = (Decimal) totalInvestmentAmount.get(
                    'totalInvestment'
                );
            } else {
                fstats.financialOverviewTotalInvestment = 0.00;
            }

            if(bclistforquantity.size() > 0)
            {
                for(Business_Case__c bcqty : bclistforquantity)
                {
                    if(bcqty.Quantity__c != null)
                    {
                        rrcount += Integer.valueOf(bcqty.Quantity__c);
                    }
                }
            }

            // System.debug(
            //     '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->For Individual fstats.financialOverviewTotalInvestment: ' +
            //     fstats.financialOverviewTotalInvestment
            // );

            // //Fetching Master Business Cases Total Investment
            // System.debug(
            //     '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->masterClause: ' +
            //     wheremasterClause
            // );
            String masterbcaggregatequery =
                'Select SUM(Sum_of_Unit_Cost__c) totalInvestment from Business_Case__c ' +
                wheremasterClause;
            System.debug(
                '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->master bcaggregatequery: ' +
                masterbcaggregatequery
            );

            String masterbcaggregatequeryforquantity =
                'Select Quantity__c from Business_Case__c ' +
                wheremasterClause;
            System.debug(
                '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->masterbcaggregatequeryforquantity: ' +
                masterbcaggregatequeryforquantity
            );

            AggregateResult totalMasterInvestmentAmount = Database.query(
                masterbcaggregatequery
            );
            List<Business_Case__c> masterbclistforquantity = Database.query(
                masterbcaggregatequeryforquantity
            );
            // System.debug(
            //     '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->totalMasterInvestmentAmount: ' +
            //     totalMasterInvestmentAmount
            // );
            if (totalMasterInvestmentAmount != null) {
                try {
                    if (
                        totalMasterInvestmentAmount.get('totalInvestment') !=
                        null
                    ) {
                        // System.debug(
                        //     '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->For Master fstats.financialOverviewTotalInvestment setting var '
                        // );
                        // System.debug(
                        //     '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->For Master stats.financialOverviewTotalInvestment: ' +
                        //     fstats.financialOverviewTotalInvestment
                        // );
                        if (fstats.financialOverviewTotalInvestment == null) {
                            fstats.financialOverviewTotalInvestment = 0.00;
                        }
                        fstats.financialOverviewTotalInvestment =
                            fstats.financialOverviewTotalInvestment +
                            ((Decimal) totalMasterInvestmentAmount.get(
                                'totalInvestment'
                            ));
                        // System.debug(
                        //     '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->For Master fstats.financialOverviewTotalInvestment: ' +
                        //     fstats.financialOverviewTotalInvestment
                        // );
                    }
                } catch (Exception ee) {
                    System.debug(
                        '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->For Master fstats.financialOverviewTotalInvestment Exception: ' +
                            ee.getMessage() +
                            ' - ' +
                            ee.getCause()
                    );
                }
            } else {
                // System.debug(
                //     '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->totalMasterInvestmentAmount else: ' +
                //     totalMasterInvestmentAmount
                // );
            }
            if(masterbclistforquantity.size() > 0)
            {
                for(Business_Case__c mbcqty : masterbclistforquantity)
                {
                    if(mbcqty.Quantity__c != null)
                    {
                        rrcount += Integer.valueOf(mbcqty.Quantity__c);
                    }
                }
            }

            if(rrcount > 0)
            {
                fstats.machineCount = rrcount;
            }
            else{
                fstats.machineCount = 0;
            }

            //Total_Reagent_Sales_Till_Date__c
            Date firstdayofthismonth = Date.today().toStartOfMonth();
            Datetime fdt = DateTime.newInstance(firstdayofthismonth, Time.newInstance(0,0,0,0));
            String firstday = fdt.format('yyyy-MM-dd');
            System.debug(
                '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->firstdayofthismonth: ' +
                firstday
            );
            if(String.isNotBlank(whereBCSClause))
            {
                whereBCSClause = whereBCSClause + ' AND Snapshot_Month__c < '+firstday+'';
            }
            else{
                whereBCSClause = ' WHERE Snapshot_Month__c < '+firstday+'';
            }

            System.debug(
                '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->whereBCSClause: ' +
                whereBCSClause
            );
           


            String bcsnapshotquery =
                'SELECT Id,Total_Reagent_Sales_Till_Date__c,Total_Reagent_Sales__c,Business_Case__c,YTD_Sales__c,Margin_till_Date__c FROM Business_Case_Sales_Snapshot__c ' +
                whereBCSClause +
                ' order by Snapshot_Month__c desc';
            System.debug(
                '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->bcsnapshotquery: ' +
                bcsnapshotquery
            );

            List<Business_Case_Sales_Snapshot__c> bcsnapshot = Database.query(
                bcsnapshotquery
            );

            System.debug('>>>>Query returned snapshots: ' + bcsnapshot.size());

            //List<Business_Case_Sales_Snapshot__c> bcsnapshot = [SELECT Id,Total_Reagent_Sales_Till_Date__c,Total_Reagent_Sales__c,Business_Case__c FROM Business_Case_Sales_Snapshot__c order by CreatedDate desc];
            if (bcsnapshot != null) {
                Map<Id, Business_Case_Sales_Snapshot__c> latestchildbyParent = new Map<Id, Business_Case_Sales_Snapshot__c>();

                for (Business_Case_Sales_Snapshot__c snapshot : bcsnapshot) {
                    if (
                        !latestchildbyParent.containsKey(
                            snapshot.Business_Case__c
                        )
                    ) {
                        latestchildbyParent.put(
                            snapshot.Business_Case__c,
                            snapshot
                        );
                    }
                }
                // System.debug(
                //     '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->latestchildbyParent: ' +
                //     latestchildbyParent
                // );
                Decimal totalSales = 0.00;
                 Decimal totalMargin = 0;

                for (
                    Business_Case_Sales_Snapshot__c snapshot : latestchildbyParent.values()
                ) {
                    // System.debug(
                    //     '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->Total_Reagent_Sales_Till_Date__c: ' +
                    //         snapshot.Business_Case__c +
                    //         ' - ' +
                    //         snapshot.Total_Reagent_Sales_Till_Date__c
                    // );

                    totalSales += (snapshot.Total_Reagent_Sales_Till_Date__c !=
                        null
                        ? snapshot.Total_Reagent_Sales_Till_Date__c
                        : 0);
                    totalMargin += (snapshot.Margin_till_Date__c != null
                        ? snapshot.Margin_till_Date__c
                        : 0);
                }
                System.debug(
                    '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->totalSales: ' +
                    totalSales
                );
                if (totalSales > 0) {
                    fstats.financialOverviewTotalSales = totalSales;
                } else {
                    fstats.financialOverviewTotalSales = 0.00;
                }
                if(totalMargin > 0)
                {
                    fstats.financialOverviewTotalMargin = totalMargin;
                }
                else{
                    fstats.financialOverviewTotalMargin = 0.00;
                }
            } else {
                fstats.financialOverviewTotalSales = 0.00;
                fstats.financialOverviewTotalMargin = 0.00;
            }

             


            // System.debug(
            //     '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->Individual fstats.financialOverviewTotalSales: ' +
            //     fstats.financialOverviewTotalSales
            // );

            //For Master Business Case Sales Snapshot

            // System.debug(
            //     '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->whereMasterBCSClause: ' +
            //     whereMasterBCSClause
            // );
            String masterbcsnapshotquery =
                'SELECT Id,Total_Reagent_Sales_Till_Date__c,Total_Reagent_Sales__c,Business_Case__c,YTD_Sales__c,Margin_till_Date__c FROM Business_Case_Sales_Snapshot__c ' +
                whereMasterBCSClause +
                ' order by Snapshot_Month__c desc';
            System.debug(
                '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->masterbcsnapshotquery: ' +
                masterbcsnapshotquery
            );

            List<Business_Case_Sales_Snapshot__c> masterbcsnapshot = Database.query(
                masterbcsnapshotquery
            );

            System.debug(
                '>>>>Master query returned snapshots: ' +
                masterbcsnapshot.size()
            );

            if (masterbcsnapshot != null) {
                Map<Id, Business_Case_Sales_Snapshot__c> masterlatestchildbyParent = new Map<Id, Business_Case_Sales_Snapshot__c>();

                for (
                    Business_Case_Sales_Snapshot__c snapshot : masterbcsnapshot
                ) {
                    if (
                        !masterlatestchildbyParent.containsKey(
                            snapshot.Business_Case__c
                        )
                    ) {
                        masterlatestchildbyParent.put(
                            snapshot.Business_Case__c,
                            snapshot
                        );
                    }
                }
                // System.debug(
                //     '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->masterlatestchildbyParent: ' +
                //     masterlatestchildbyParent
                // );
                Decimal totalSales = 0.00;
                 Decimal totalMargin = 0;
                for (
                    Business_Case_Sales_Snapshot__c snapshot : masterlatestchildbyParent.values()
                ) {
                    // System.debug(
                    //     '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->Master Total_Reagent_Sales_Till_Date__c: ' +
                    //         snapshot.Business_Case__c +
                    //         ' - ' +
                    //         snapshot.Total_Reagent_Sales_Till_Date__c
                    // );

                    totalSales += (snapshot.Total_Reagent_Sales_Till_Date__c !=
                        null
                        ? snapshot.Total_Reagent_Sales_Till_Date__c
                        : 0);
                     totalMargin += (snapshot.Margin_till_Date__c != null
                        ? snapshot.Margin_till_Date__c
                        : 0);
                }
                System.debug(
                    '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->Master totalSales: ' +
                    totalSales
                );
                if (totalSales > 0) {
                    fstats.financialOverviewTotalSales =
                        fstats.financialOverviewTotalSales + totalSales;
                }
                 if(totalMargin > 0)
                {
                    fstats.financialOverviewTotalMargin = fstats.financialOverviewTotalMargin + totalMargin;
                }
                
            }

            // String bcsnapshotcostrecoveryquery =
            //     'SELECT SUM(Margin_On_Reagent_Sale__c) totalMargin FROM Business_Case_Sales_Snapshot__c ' +
            //     whereBCSClause +
            //     ' ';
            // System.debug(
            //     '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->bcsnapshotcostrecoveryquery: ' +
            //     bcsnapshotcostrecoveryquery
            // );

            // AggregateResult bcsnapshotcostcovery = Database.query(
            //     bcsnapshotcostrecoveryquery
            // );

            // System.debug('>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats--> bcsnapshotcostcovery Query returned snapshots: ' + bcsnapshotcostcovery);

            // Decimal totalMargin = 0;

            // if (bcsnapshotcostcovery != null) 
            // {
            //     if(bcsnapshotcostcovery.get(
            //         'totalMargin'
            //     ) != null)
            //     {
            //         totalMargin = totalMargin +( (Decimal) bcsnapshotcostcovery.get(
            //         'totalMargin'
            //         ));
            //     }
                
            // } 

            // String bcmastersnapshotcostrecoveryquery =
            //     'SELECT SUM(Margin_On_Reagent_Sale__c) totalMargin FROM Business_Case_Sales_Snapshot__c ' +
            //     whereMasterBCSClause +
            //     ' ';
            // System.debug(
            //     '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->bcmastersnapshotcostrecoveryquery: ' +
            //     bcmastersnapshotcostrecoveryquery
            // );

            // AggregateResult bcmastersnapshotcostcovery = Database.query(
            //     bcmastersnapshotcostrecoveryquery
            // );

            // System.debug('>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->bcmastersnapshotcostcovery Query returned snapshots: ' + bcmastersnapshotcostcovery);

            // if (bcmastersnapshotcostcovery != null) 
            // {
            //     if(bcmastersnapshotcostcovery.get('totalMargin') != null)
            //     {
            //         totalMargin = totalMargin +( (Decimal) bcmastersnapshotcostcovery.get(
            //             'totalMargin'
            //         ));
            //     }
                
            // } 
            // if(totalMargin > 0)
            // {
            //     fstats.financialOverviewTotalMargin = totalMargin;
            // }
            // else{
            //     fstats.financialOverviewTotalMargin = 0.00;
            // }
             System.debug(
                    '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->fstats.financialOverviewTotalMargin : ' +
                    fstats.financialOverviewTotalMargin
                );
            if (
                fstats.financialOverviewTotalInvestment > 0 
                // &&
                // fstats.financialOverviewTotalSales > 0
            ) 
            {
                System.debug(
                    '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->fstats.costRecovery if: ' +
                    (fstats.financialOverviewTotalMargin /
                    fstats.financialOverviewTotalInvestment) * 100
                );
                if(fstats.financialOverviewTotalMargin > 0)
                {
                    fstats.costRecovery = formatPercent(
                        (fstats.financialOverviewTotalMargin /
                        fstats.financialOverviewTotalInvestment) * 100
                    );
                }
                else{
                    fstats.costRecovery = formatPercent(0.00);
                }
                // fstats.costRecovery = formatPercent(
                //         (fstats.financialOverviewTotalSales /
                //         fstats.financialOverviewTotalInvestment) * 100
                //     );
                
            } else {
                // System.debug(
                //     '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->fstats.costRecovery: 0'
                // );
                fstats.costRecovery = formatPercent(0.00);
            }
            System.debug(
                '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->fstats: ' +
                fstats
            );
            return fstats;
        } catch (Exception e) {
            System.debug(
                '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->Exception: ' +
                e.getMessage()
            );
            return null;
        }
    }

    // //Get Total Investment of all Business Cases
    // @AuraEnabled(cacheable=true)
    // public static FinancialOverviewPerformanceStats getTotalFinancialPerformanceStats()
    // {
    //   try
    //   {
    //     FinancialOverviewPerformanceStats fstats = new FinancialOverviewPerformanceStats();
    //     AggregateResult totalInvestmentAmount = [Select SUM(Total_Unit_Cost__c) totalInvestment from Business_Case__c where Status__c != 'Closed'];
    //     if(totalInvestmentAmount != null )
    //     {
    //       fstats.financialOverviewTotalInvestment = (Decimal)totalInvestmentAmount.get('totalInvestment');
    //     }
    //     else
    //     {
    //       fstats.financialOverviewTotalInvestment = 0.00;
    //     }

    //     //Total_Reagent_Sales_Till_Date__c
    //     List<Business_Case_Sales_Snapshot__c> bcsnapshot = [SELECT Id,Total_Reagent_Sales_Till_Date__c,Total_Reagent_Sales__c,Business_Case__c FROM Business_Case_Sales_Snapshot__c order by CreatedDate desc ];
    //     if(bcsnapshot != null)
    //     {
    //       Map<Id,Business_Case_Sales_Snapshot__c> latestchildbyParent = new Map<Id,Business_Case_Sales_Snapshot__c>();

    //       for(Business_Case_Sales_Snapshot__c snapshot: bcsnapshot)
    //       {
    //         if(!latestchildbyParent.containsKey(snapshot.Business_Case__c))
    //         {
    //           latestchildbyParent.put(snapshot.Business_Case__c,snapshot);
    //         }
    //       }

    //       Decimal totalSales = 0.00;

    //       for(Business_Case_Sales_Snapshot__c snapshot: latestchildbyParent.values())
    //       {
    //         totalSales += (snapshot.Total_Reagent_Sales__c != null ? snapshot.Total_Reagent_Sales__c : 0);
    //       }

    //       if(totalSales > 0 )
    //       {
    //         fstats.financialOverviewTotalSales = totalSales;
    //       }
    //       else
    //       {
    //         fstats.financialOverviewTotalSales = 0.00;
    //       }

    //     }
    //     else
    //     {
    //       fstats.financialOverviewTotalSales = 0.00;
    //     }

    //     if(fstats.financialOverviewTotalInvestment > 0 && fstats.financialOverviewTotalSales > 0)
    //     {
    //        System.debug('>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->fstats.costRecovery if: '+(
    //           fstats.financialOverviewTotalSales / fstats.financialOverviewTotalInvestment
    //         ) * 100);
    //       fstats.costRecovery = formatPercent(
    //         (
    //           fstats.financialOverviewTotalSales / fstats.financialOverviewTotalInvestment
    //         ) * 100
    //       );

    //     }
    //     else
    //     {
    //      System.debug('>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->fstats.costRecovery: 0');
    //       fstats.costRecovery = formatPercent(0.00) ;
    //     }
    //     System.debug('>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->fstats: '+fstats);
    //     return fstats;
    //   }
    //   catch(Exception e)
    //   {
    //     System.debug('>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->Exception: '+e.getMessage());
    //     return null;
    //   }
    // }

    /**
     * Get summary metrics for dashboard cards
     */
    @AuraEnabled(cacheable=true)
    public static SummaryMetrics getSummaryMetrics() {
        try {
            SummaryMetrics metrics = new SummaryMetrics();

            // Get latest snapshots for each Business Case (most recent month)
            Map<String, Business_Case_Sales_Snapshot__c> latestSnapshots = new Map<String, Business_Case_Sales_Snapshot__c>();

            List<Business_Case_Sales_Snapshot__c> allSnapshots = [
                SELECT
                    Customer_Code__c,
                    Snapshot_Month__c,
                    Total_Reagent_Sales__c,
                    Target_Sales__c,
                    Machine_Count__c,
                    Total_Reagent_Sales_Till_Date__c,
                    Payback_Remaining__c,
                    Margin_On_Reagent_Sale__c
                FROM Business_Case_Sales_Snapshot__c
                WHERE Processing_Status__c = 'Completed'
                ORDER BY Customer_Code__c, Snapshot_Month__c DESC
            ];

            // Get the latest snapshot for each customer
            for (Business_Case_Sales_Snapshot__c snapshot : allSnapshots) {
                String key = snapshot.Customer_Code__c;
                if (!latestSnapshots.containsKey(key)) {
                    latestSnapshots.put(key, snapshot);
                }
            }

            // Calculate summary metrics from latest snapshots
            Decimal totalInvestment = 0;
            Decimal totalSales = 0;
            Decimal totalSalesTillDate = 0;
            Decimal totalCommitment = 0;
            Decimal totalAvgSales = 0;
            Integer totalMachines = 0;
            Integer totalSnapshots = allSnapshots.size();

            for (
                Business_Case_Sales_Snapshot__c snapshot : latestSnapshots.values()
            ) {
                // Investment calculation (simplified - based on payback remaining + sales till date)
                Decimal investment =
                    (snapshot.Payback_Remaining__c != null
                        ? snapshot.Payback_Remaining__c
                        : 0) +
                    (snapshot.Total_Reagent_Sales_Till_Date__c != null
                        ? snapshot.Total_Reagent_Sales_Till_Date__c
                        : 0);
                totalInvestment += investment;

                totalSales += (snapshot.Total_Reagent_Sales__c != null
                    ? snapshot.Total_Reagent_Sales__c
                    : 0);
                totalSalesTillDate += (snapshot.Total_Reagent_Sales_Till_Date__c !=
                    null
                    ? snapshot.Total_Reagent_Sales_Till_Date__c
                    : 0);
                totalCommitment += (snapshot.Target_Sales__c != null
                    ? snapshot.Target_Sales__c
                    : 0);
                totalAvgSales += (snapshot.Total_Reagent_Sales__c != null
                    ? snapshot.Total_Reagent_Sales__c
                    : 0);
                totalMachines += (snapshot.Machine_Count__c != null
                    ? snapshot.Machine_Count__c.intValue()
                    : 0);
            }

            metrics.totalInvestment = totalInvestment;
            metrics.totalSales = totalSalesTillDate; // Use total sales till date for lifetime value
            metrics.totalMachines = totalMachines;
            metrics.totalSnapshots = totalSnapshots;

            // Calculate percentages
            metrics.costRecoveryPercent = totalInvestment > 0
                ? (totalSalesTillDate / totalInvestment) * 100
                : 0;
            metrics.commitmentAchievementPercent = totalCommitment > 0
                ? (totalAvgSales / totalCommitment) * 100
                : 0;

            return metrics;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Error calculating summary metrics: ' + e.getMessage()
            );
        }
    }

    // ===== UTILITY METHODS =====

    public static String formatCurrency(Decimal amount) {
        if (amount == null)
            return '$0';
        return '$' + String.valueOf(amount.setScale(0).format());
    }

    public static String formatPercent(Decimal percent) {
        if (percent == null)
            return '0%';
        return percent.setScale(1) + '%';
    }

    public static String formatMonthLabel(Date monthDate) {
        if (monthDate == null)
            return '';
        DateTime dt = DateTime.newInstance(
            monthDate.year(),
            monthDate.month(),
            monthDate.day()
        );
        return dt.format('MMM yyyy');
    }

    public static Decimal calculateAchievementPercent(
        Decimal actual,
        Decimal target
    ) {
        if (target == null || target == 0)
            return 0;
        if (actual == null)
            return 0;
        return (actual / target) * 100;
    }

    public static Decimal calculateInvestment(
        Business_Case_Sales_Snapshot__c snapshot
    ) {
        // Use the actual investment from Business Case
        Decimal investment = snapshot.Business_Case__r.Unit_Cost__c != null
            ? snapshot.Business_Case__r.Unit_Cost__c
            : 0;
        System.debug(
            '🔍 Investment for BC ' +
                snapshot.Business_Case_Name__c +
                ': ' +
                investment
        );
        return investment;
    }

    public static String getStatusForNonInvoicedMachine(String machineStatus) {
        // Map machine status to performance status for machines without invoice data
        if (machineStatus == 'Ordered') {
            return 'Pending Installation';
        } else if (machineStatus == 'Installed') {
            return 'Pending Activation';
        } else if (machineStatus == 'Rejected') {
            return 'Rejected';
        } else if (machineStatus == 'Inactive') {
            return 'Recovered Asset';
        } else {
            return 'No Sales'; // Default for other statuses
        }
    }

    //Get Machines Count Status wise
    @AuraEnabled(cacheable=true)
    public static List<MachineStatusCount> getMachineCountStatuswise(
        String DateFrom,
        String DateTo,
        String Region,
        String Supplier,
        String BusinessCaseStatus,
        String MachineStatus,
        String CommitmentStatus,
        String RiskStatus,
        String SearchCustomer,
        String BusinessCaseName
    ) {
        try {
            System.debug(
                '>>>>BusinessCaseDashboardController-->getMachineCountStatuswise'
            );

            String whereBCClause = ' WHERE RecordType.Name = \'Individual Business Case\'';
            //String whereMasterBCClause = ' WHERE RecordType.Name = \'Master Business Case\'';

            if (!String.isBlank(Region) && Region != 'All Regions') {
                if (String.isBlank(whereBCClause)) {
                    whereBCClause = ' WHERE Region__c = \'' + Region + '\'';
                } else {
                    whereBCClause += ' AND Region__c = \'' + Region + '\'';
                }
            }
            if (
                !String.isBlank(SearchCustomer) &&
                SearchCustomer != 'All Customers'
            ) {
                String scustomer = '';
                if (SearchCustomer.contains(' - ')) {
                    scustomer = SearchCustomer.split(' - ')[0];
                    scustomer = scustomer.trim();
                }
                if (String.isBlank(whereBCClause)) {
                    whereBCClause =
                        ' WHERE Customer_Number__c = \'' +
                        SearchCustomer +
                        '\'';
                } else {
                    whereBCClause +=
                        ' AND Customer_Number__c = \'' +
                        SearchCustomer +
                        '\'';
                }
            }
            if (
                !String.isBlank(BusinessCaseStatus) &&
                BusinessCaseStatus != 'All Business Case Statuses'
            ) {
                String sbusinesscasestatus = '';
                System.debug(
                    '>>>>BusinessCaseDashboardController-->getTotalFinancialPerformanceStats-->BusinessCaseStatus: ' +
                    BusinessCaseStatus
                );
                sbusinesscasestatus = BusinessCaseStatus.trim();

                if (String.isBlank(whereBCClause)) {
                    whereBCClause =
                        ' WHERE Status__c  = \'' +
                        sbusinesscasestatus +
                        '\' ';
                } else {
                    whereBCClause +=
                        ' AND Status__c  = \'' +
                        sbusinesscasestatus +
                        '\'';
                }
            } else {
                if (String.isBlank(whereBCClause)) {
                    whereBCClause = ' WHERE (Status__c  LIKE \'%Active%\' OR Status__c LIKE \'%Revised%\' OR Status__c LIKE \'%New%\') ';
                } else {
                    whereBCClause += ' AND (Status__c  LIKE \'%Active%\' OR Status__c LIKE \'%Revised%\' OR Status__c LIKE \'%New%\')';
                }
            }

            if (
                !String.isBlank(MachineStatus) &&
                MachineStatus != 'All Machine Statuses'
            ) {
                String smachinestatus = '';
                smachinestatus = MachineStatus.trim();

                if (String.isBlank(whereBCClause)) {
                    whereBCClause =
                        ' WHERE Machine_Installation__r.Status__c  = \'' +
                        smachinestatus +
                        '\'';
                } else {
                    whereBCClause +=
                        ' AND Machine_Installation__r.Status__c  = \'' +
                        smachinestatus +
                        '\'';
                }
            }
            if (
                !String.isBlank(BusinessCaseName) &&
                BusinessCaseName != 'All Business Cases'
            ) {
                String sbcname = '';
                sbcname = BusinessCaseName.trim();

                if (String.isBlank(whereBCClause)) {
                    whereBCClause = ' WHERE Name  = \'' + sbcname + '\'';
                } else {
                    whereBCClause += ' AND Name  = \'' + sbcname + '\'';
                }
            }

            System.debug(
                '>>>>BusinessCaseDashboardController-->getMachineCountStatuswise-->whereBCCClause: ' +
                whereBCClause
            );

            String bccquery =
                'Select Id,Name,Machine_Installation__c,Customer_Number__c,Region__c,Status__c,Machine_Installation__r.Status__c,Master_Business_Case__c,Master_Business_Case__r.Name from Business_Case__c ' +
                whereBCClause;

            System.debug(
                '>>>>BusinessCaseDashboardController-->getMachineCountStatuswise-->bccquery: ' +
                bccquery
            );

            List<Business_Case__c> businessCasesList = Database.query(bccquery);

            System.debug(
                '>>>>BusinessCaseDashboardController-->getMachineCountStatuswise-->businessCasesList: ' +
                businessCasesList.size()
            );

            // Extract Machine_Installation__c IDs
            List<Id> machineIds = new List<Id>();
            for (Business_Case__c bc : businessCasesList) {
                if (bc.Machine_Installation__c != null) {
                    machineIds.add(bc.Machine_Installation__c);
                }
            }

            // Convert to comma-separated string for dynamic query
            String machineIdsString =
                '(' +
                '\'' +
                String.join(machineIds, '\',\'') +
                '\'' +
                ')';

            System.debug(
                '>>>>BusinessCaseDashboardController-->getMachineCountStatuswise-->Machine IDs: ' +
                machineIdsString
            );

            List<MachineStatusCount> machinestatuscount = new List<MachineStatusCount>();
            List<Machine_Installation__c> listofmachines = new List<Machine_Installation__c>();
            Map<String, Integer> statusCountMap = new Map<String, Integer>();
            List<MachineStatusCount> listofmachinestatuscount = new List<MachineStatusCount>();

            //listofmachines = [Select Id,Name,Status__c,Material_Number__c from Machine_Installation__c where Status__c != 'Invoiced/Sold'];
            String machinequery =
                'Select Id,Name,Status__c,Material_Number__c from Machine_Installation__c where Status__c != \'Invoiced/Sold\' and Id in ' +
                machineIdsString +
                '';

            System.debug(
                '>>>>BusinessCaseDashboardController-->getMachineCountStatuswise-->machinequery: ' +
                machinequery
            );

            listofmachines = Database.query(machinequery);

            System.debug(
                '>>>>BusinessCaseDashboardController-->getMachineCountStatuswise-->listofmachines size: ' +
                listofmachines.size()
            );

            List<String> listofstatuses = getPicklistValues(
                'Machine_Installation__c',
                'Status__c'
            );

            System.debug(
                '>>>>BusinessCaseDashboardController-->getMachineCountStatuswise-->listofstatuses size: ' +
                listofstatuses.size()
            );

            if (listofstatuses.size() > 0) {
                if (listofmachines.size() > 0) {
                    for (Machine_Installation__c m : listofmachines) {
                        String status = m.Status__c;
                        if (statusCountMap.containsKey(status)) {
                            statusCountMap.put(
                                status,
                                statusCountMap.get(status) + 1
                            );
                        } else {
                            statusCountMap.put(status, 1);
                        }
                    }
                    for (String status : listofstatuses) {
                        MachineStatusCount msc = new MachineStatusCount();
                        msc.status = status;
                        // if no machines for this status, default to 0
                        msc.count = statusCountMap.containsKey(status)
                            ? statusCountMap.get(status)
                            : 0;
                        listofmachinestatuscount.add(msc);
                    }
                } else {
                    for (String status : listofstatuses) {
                        MachineStatusCount msc = new MachineStatusCount();
                        msc.status = status;
                        // if no machines for this status, default to 0
                        msc.count = statusCountMap.containsKey(status)
                            ? statusCountMap.get(status)
                            : 0;
                        listofmachinestatuscount.add(msc);
                    }
                }
            } else {
                MachineStatusCount msc = new MachineStatusCount();
                msc.status = 'Initial Assessment';
                msc.count = 0;
                listofmachinestatuscount.add(msc);
            }
            // System.debug(
            //     '>>>>BusinessCaseDashboardController-->getMachineCountStatuswise-->listofmachinestatuscount size: ' +
            //     listofmachinestatuscount.size()
            // );
            System.debug(
                '>>>>BusinessCaseDashboardController-->getMachineCountStatuswise-->listofmachinestatuscount : ' +
                listofmachinestatuscount
            );
            return listofmachinestatuscount;
        } catch (Exception e) {
            System.debug(
                '>>>>BusinessCaseDashboardController-->getMachineCountStatuswise-->Exception: ' +
                e.getMessage()
            );
            return null;
        }
    }

    //Get Machines Count Status wise
    @AuraEnabled(cacheable=true)
    public static MachineStatusCountwiseResp getMachineCountStatuswiseUpdated(
        String DateFrom,
        String DateTo,
        String Region,
        String Supplier,
        String BusinessCaseStatus,
        String MachineStatus,
        String CommitmentStatus,
        String RiskStatus,
        String SearchCustomer,
        String BusinessCaseName
    ) {
        try 
        {
            List<MachineStatusListResp> listofmachinesobj = new List<MachineStatusListResp>();
            System.debug(
                '>>>>BusinessCaseDashboardController-->getMachineCountStatuswiseUpdated'
            );

            String whereBCClause = ' WHERE RecordType.Name = \'Individual Business Case\'';
            //String whereMasterBCClause = ' WHERE RecordType.Name = \'Master Business Case\'';

            if (!String.isBlank(Region) && Region != 'All Regions') {
                if (String.isBlank(whereBCClause)) {
                    whereBCClause = ' WHERE Region__c = \'' + Region + '\'';
                } else {
                    whereBCClause += ' AND Region__c = \'' + Region + '\'';
                }
            }
            if (
                !String.isBlank(SearchCustomer) &&
                SearchCustomer != 'All Customers'
            ) {
                String scustomer = '';
                if (SearchCustomer.contains(' - ')) {
                    scustomer = SearchCustomer.split(' - ')[0];
                    scustomer = scustomer.trim();
                }
                if (String.isBlank(whereBCClause)) {
                    whereBCClause =
                        ' WHERE Customer_Number__c = \'' +
                        SearchCustomer +
                        '\'';
                } else {
                    whereBCClause +=
                        ' AND Customer_Number__c = \'' +
                        SearchCustomer +
                        '\'';
                }
            }
            if (
                !String.isBlank(BusinessCaseStatus) &&
                BusinessCaseStatus != 'All Business Case Statuses'
            ) {
                String sbusinesscasestatus = '';
                System.debug(
                    '>>>>BusinessCaseDashboardController-->getMachineCountStatuswiseUpdated-->BusinessCaseStatus: ' +
                    BusinessCaseStatus
                );
                sbusinesscasestatus = BusinessCaseStatus.trim();

                if (String.isBlank(whereBCClause)) {
                    whereBCClause =
                        ' WHERE Status__c  = \'' +
                        sbusinesscasestatus +
                        '\' ';
                } else {
                    whereBCClause +=
                        ' AND Status__c  = \'' +
                        sbusinesscasestatus +
                        '\'';
                }
            } else {
                if (String.isBlank(whereBCClause)) {
                    whereBCClause = ' WHERE (Status__c  LIKE \'%Active%\' OR Status__c LIKE \'%Revised%\' OR Status__c LIKE \'%New%\') ';
                } else {
                    whereBCClause += ' AND (Status__c  LIKE \'%Active%\' OR Status__c LIKE \'%Revised%\' OR Status__c LIKE \'%New%\')';
                }
            }

            if (
                !String.isBlank(MachineStatus) &&
                MachineStatus != 'All Machine Statuses'
            ) {
                String smachinestatus = '';
                smachinestatus = MachineStatus.trim();

                if (String.isBlank(whereBCClause)) {
                    whereBCClause =
                        ' WHERE Machine_Installation__r.Status__c  = \'' +
                        smachinestatus +
                        '\'';
                } else {
                    whereBCClause +=
                        ' AND Machine_Installation__r.Status__c  = \'' +
                        smachinestatus +
                        '\'';
                }
            }
            if (
                !String.isBlank(BusinessCaseName) &&
                BusinessCaseName != 'All Business Cases'
            ) {
                String sbcname = '';
                sbcname = BusinessCaseName.trim();

                if (String.isBlank(whereBCClause)) {
                    whereBCClause = ' WHERE Name  = \'' + sbcname + '\'';
                } else {
                    whereBCClause += ' AND Name  = \'' + sbcname + '\'';
                }
            }

            System.debug(
                '>>>>BusinessCaseDashboardController-->getMachineCountStatuswiseUpdated-->whereBCCClause: ' +
                whereBCClause
            );

            String bccquery =
                'Select Id,Name,Machine_Installation__c,Customer_Number__c,Region__c,Status__c,Machine_Installation__r.Status__c,Master_Business_Case__c,Master_Business_Case__r.Name from Business_Case__c ' +
                whereBCClause;

            System.debug(
                '>>>>BusinessCaseDashboardController-->getMachineCountStatuswiseUpdated-->bccquery: ' +
                bccquery
            );

            List<Business_Case__c> businessCasesList = Database.query(bccquery);

            System.debug(
                '>>>>BusinessCaseDashboardController-->getMachineCountStatuswise-->businessCasesList: ' +
                businessCasesList.size()
            );

            // Extract Machine_Installation__c IDs
            List<Id> machineIds = new List<Id>();
            for (Business_Case__c bc : businessCasesList) {
                if (bc.Machine_Installation__c != null) 
                {
                    machineIds.add(bc.Machine_Installation__c);
                }
                MachineStatusListResp respobj = new MachineStatusListResp();
                respobj.id = bc.Id;
                respobj.customerNumber = bc.Customer_Number__c;
                respobj.machineInstallationStatus = bc.Machine_Installation__r.Status__c;
                respobj.masterBusinessCase = bc.Master_Business_Case__r.Name;
                respobj.name = bc.Name;
                respobj.region = bc.Region__c;
                respobj.status = bc.Status__c;
                listofmachinesobj.add(respobj);
            }

            // Convert to comma-separated string for dynamic query
            String machineIdsString =
                '(' +
                '\'' +
                String.join(machineIds, '\',\'') +
                '\'' +
                ')';

            System.debug(
                '>>>>BusinessCaseDashboardController-->getMachineCountStatuswiseUpdated-->Machine IDs: ' +
                machineIdsString
            );

            List<MachineStatusCount> machinestatuscount = new List<MachineStatusCount>();
            List<Machine_Installation__c> listofmachines = new List<Machine_Installation__c>();
            Map<String, Integer> statusCountMap = new Map<String, Integer>();
            List<MachineStatusCount> listofmachinestatuscount = new List<MachineStatusCount>();

            //listofmachines = [Select Id,Name,Status__c,Material_Number__c from Machine_Installation__c where Status__c != 'Invoiced/Sold'];
            String machinequery =
                'Select Id,Name,Status__c,Material_Number__c from Machine_Installation__c where Status__c != \'Invoiced/Sold\' and Id in ' +
                machineIdsString +
                '';

            System.debug(
                '>>>>BusinessCaseDashboardController-->getMachineCountStatuswiseUpdated-->machinequery: ' +
                machinequery
            );

            listofmachines = Database.query(machinequery);

            System.debug(
                '>>>>BusinessCaseDashboardController-->getMachineCountStatuswiseUpdated-->listofmachines size: ' +
                listofmachines.size()
            );

            List<String> listofstatuses = getPicklistValues(
                'Machine_Installation__c',
                'Status__c'
            );

            System.debug(
                '>>>>BusinessCaseDashboardController-->getMachineCountStatuswiseUpdated-->listofstatuses size: ' +
                listofstatuses.size()
            );

            if (listofstatuses.size() > 0) {
                if (listofmachines.size() > 0) {
                    for (Machine_Installation__c m : listofmachines) {
                        String status = m.Status__c;
                        if (statusCountMap.containsKey(status)) {
                            statusCountMap.put(
                                status,
                                statusCountMap.get(status) + 1
                            );
                        } else {
                            statusCountMap.put(status, 1);
                        }
                    }
                    for (String status : listofstatuses) {
                        MachineStatusCount msc = new MachineStatusCount();
                        msc.status = status;
                        // if no machines for this status, default to 0
                        msc.count = statusCountMap.containsKey(status)
                            ? statusCountMap.get(status)
                            : 0;
                        listofmachinestatuscount.add(msc);
                    }
                } else {
                    for (String status : listofstatuses) {
                        MachineStatusCount msc = new MachineStatusCount();
                        msc.status = status;
                        // if no machines for this status, default to 0
                        msc.count = statusCountMap.containsKey(status)
                            ? statusCountMap.get(status)
                            : 0;
                        listofmachinestatuscount.add(msc);
                    }
                }
            } else {
                MachineStatusCount msc = new MachineStatusCount();
                msc.status = 'Initial Assessment';
                msc.count = 0;
                listofmachinestatuscount.add(msc);
            }
            // System.debug(
            //     '>>>>BusinessCaseDashboardController-->getMachineCountStatuswise-->listofmachinestatuscount size: ' +
            //     listofmachinestatuscount.size()
            // );
            System.debug(
                '>>>>BusinessCaseDashboardController-->getMachineCountStatuswiseUpdated-->listofmachinestatuscount : ' +
                listofmachinestatuscount
            );

            MachineStatusCountwiseResp responseObj = new MachineStatusCountwiseResp();
            responseObj.machineStatusCount = listofmachinestatuscount;
            responseObj.machineStatusListResp = listofmachinesobj;

             System.debug(
                '>>>>BusinessCaseDashboardController-->getMachineCountStatuswiseUpdated-->responseObj : ' +
                responseObj
            );

            return responseObj;
        } catch (Exception e) {
            System.debug(
                '>>>>BusinessCaseDashboardController-->getMachineCountStatuswiseUpdated-->Exception: ' +
                e.getMessage()
            );
            return null;
        }
    }
    /**
     * Get machine status counts for dashboard tiles
     * Using snapshot data to maintain consistency with snapshot-only architecture
     */
    @AuraEnabled(cacheable=true)
    public static List<MachineStatusCount> getMachineStatusCounts() {
        try {
            // Get latest snapshots and their machine status data
            Map<String, String> machineStatusMap = new Map<String, String>();

            List<Business_Case_Sales_Snapshot__c> snapshots = [
                SELECT Business_Case__c, Machine_Status__c, Snapshot_Month__c
                FROM Business_Case_Sales_Snapshot__c
                WHERE
                    Processing_Status__c = 'Completed'
                    AND Machine_Status__c != NULL
                    AND Business_Case__c != NULL
                ORDER BY Business_Case__c, Snapshot_Month__c DESC
            ];

            // Get the latest machine status for each business case
            for (Business_Case_Sales_Snapshot__c snapshot : snapshots) {
                if (!machineStatusMap.containsKey(snapshot.Business_Case__c)) {
                    machineStatusMap.put(
                        snapshot.Business_Case__c,
                        snapshot.Machine_Status__c
                    );
                }
            }

            // Count occurrences of each status
            Map<String, Integer> statusCountMap = new Map<String, Integer>();
            for (String status : machineStatusMap.values()) {
                if (statusCountMap.containsKey(status)) {
                    statusCountMap.put(status, statusCountMap.get(status) + 1);
                } else {
                    statusCountMap.put(status, 1);
                }
            }

            // Convert to result list
            List<MachineStatusCount> results = new List<MachineStatusCount>();
            List<String> statusKeys = new List<String>(statusCountMap.keySet());
            statusKeys.sort();

            for (String status : statusKeys) {
                MachineStatusCount statusCount = new MachineStatusCount();
                statusCount.status = status;
                statusCount.count = statusCountMap.get(status);
                results.add(statusCount);
            }

            return results;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Error retrieving machine status counts: ' + e.getMessage()
            );
        }
    }

    /**
     * Get enhanced filter options including Business Case and Machine status
     * Machine Status and Business Case Status come directly from picklist field definitions
     * Other filter options come from existing snapshot data
     */
    @AuraEnabled(cacheable=true)
    public static EnhancedFilterOptions getEnhancedFilterOptions() {
        try {
            // Get existing snapshot data for months, customers, regions, suppliers
            List<Business_Case_Sales_Snapshot__c> snapshots = [
                SELECT
                    Snapshot_Month__c,
                    Customer_Code__c,
                    Customer_Name__c,
                    Region__c,
                    Vendor__c,
                    Business_Case__r.Name
                FROM Business_Case_Sales_Snapshot__c
                WHERE Processing_Status__c = 'Completed'
                ORDER BY Snapshot_Month__c DESC
                //LIMIT 2000
            ];

            List<Business_Case__c> listofbusinesscases = [
                SELECT Id, Name
                FROM Business_Case__c
            ];

            List<Business_Case__c> listofcustomers = [
                SELECT
                    Id,
                    Name,
                    Customer_Number__c,
                    Customer_Name__c,
                    Machine_Installation__r.SAP_Account_No_Bill_To__c,
                    Customer_Numbera__c
                FROM Business_Case__c
                WHERE
                    Master_Business_Case__c = NULL
                    AND RecordType.Name = 'Individual Business Case'
            ];

            List<Business_Case__c> listofmastercustomers = [
                SELECT
                    Id,
                    Name,
                    Customer_Number__c,
                    Customer_Name__c,
                    Machine_Installation__r.SAP_Account_No_Bill_To__c,
                    Customer_Numbera__c,
                    Customer_Namea__c
                FROM Business_Case__c
                WHERE RecordType.Name = 'Master Business Case'
            ];

            List<String> monthNames = new List<String>{
                'Jan',
                'Feb',
                'Mar',
                'Apr',
                'May',
                'Jun',
                'Jul',
                'Aug',
                'Sep',
                'Oct',
                'Nov',
                'Dec'
            };
            // Collect unique values from snapshot data
            Set<String> monthSet = new Set<String>();
            Map<String, String> customerMap = new Map<String, String>();
            Set<String> regionSet = new Set<String>();
            Set<String> supplierSet = new Set<String>();
            Set<String> businessCaseSet = new Set<String>();

            AggregateResult[] groupedResults = [
                SELECT
                    CALENDAR_YEAR(Invoice_Date__c) year,
                    CALENDAR_MONTH(Invoice_Date__c) month
                FROM Invoice__c
                WHERE Invoice_Date__c != NULL
                GROUP BY
                    CALENDAR_YEAR(Invoice_Date__c),
                    CALENDAR_MONTH(Invoice_Date__c)
                ORDER BY
                    CALENDAR_YEAR(Invoice_Date__c),
                    CALENDAR_MONTH(Invoice_Date__c)
            ];

            for (AggregateResult ar : groupedResults) {
                Integer yearVal = (Integer) ar.get('year');
                Integer monthVal = (Integer) ar.get('month');

                String monthName = monthNames[monthVal - 1];
                monthSet.add(monthName + ' ' + yearVal);
            }

            if (listofbusinesscases.size() > 0) {
                for (Business_Case__c bc : listofbusinesscases) {
                    if (!businessCaseSet.contains(bc.Name)) {
                        businessCaseSet.add(bc.Name);
                    }
                }
            }

            if (listofcustomers.size() > 0) {
                for (Business_Case__c bc : listofcustomers) {
                    if (
                        String.isNotBlank(bc.Customer_Number__c) &&
                        String.isNotBlank(bc.Customer_Number__c)
                    ) {
                        if (!customerMap.containsKey(bc.Customer_Number__c)) {
                            customerMap.put(
                                bc.Customer_Number__c,
                                bc.Customer_Name__c
                            );
                        }
                    }
                }
            }
            if (listofmastercustomers.size() > 0) {
                for (Business_Case__c bc : listofmastercustomers) {
                    if (
                        String.isNotBlank(bc.Customer_Numbera__c) &&
                        String.isNotBlank(bc.Customer_Numbera__c)
                    ) {
                        if (!customerMap.containsKey(bc.Customer_Numbera__c)) {
                            customerMap.put(
                                bc.Customer_Numbera__c,
                                bc.Customer_Namea__c
                            );
                        }
                    }
                }
            }

            for (Business_Case_Sales_Snapshot__c snapshot : snapshots) {
                // Collect months (formatted as strings like original method)
                if (snapshot.Snapshot_Month__c != null) {
                    String monthVal = snapshot.Snapshot_Month__c.format();
                    if (!monthSet.contains(monthVal)) {
                        monthSet.add(monthVal);
                    }
                }

                // Collect customers (avoid duplicates by using map)
                // if (
                //   String.isNotBlank(snapshot.Customer_Code__c) &&
                //   String.isNotBlank(snapshot.Customer_Name__c)
                // )
                // {
                //   if(!customerMap.containsKey(snapshot.Customer_Code__c))
                //   {

                //     customerMap.put(snapshot.Customer_Code__c, snapshot.Customer_Name__c);
                //   }

                // }

                // Collect regions
                if (String.isNotBlank(snapshot.Region__c)) {
                    if (!regionSet.contains(snapshot.Region__c)) {
                        regionSet.add(snapshot.Region__c);
                    }
                }

                // // Collect Business Cases
                // if (String.isNotBlank(snapshot.Business_Case__r.Name))
                // {
                //   if(!businessCaseSet.contains(snapshot.Business_Case__r.Name))
                //   {
                //     businessCaseSet.add(snapshot.Business_Case__r.Name);
                //   }

                // }

                // Collect suppliers/vendors
                if (String.isNotBlank(snapshot.Vendor__c)) {
                    if (!supplierSet.contains(snapshot.Vendor__c)) {
                        supplierSet.add(snapshot.Vendor__c);
                    }
                }
            }

            // Get Machine Status values directly from MD_Asset__c.Status__c picklist
            List<String> machineStatusList = new List<String>();
            try {
                Schema.DescribeFieldResult fieldResult = MD_Asset__c.Status__c.getDescribe();
                List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
                for (Schema.PicklistEntry entry : picklistValues) {
                    if (entry.isActive()) {
                        if (!entry.getValue().contains('Closed')) {
                            machineStatusList.add(entry.getValue());
                        }
                    }
                }
                machineStatusList.sort();
                // System.debug(
                //     'Machine Status picklist values: ' + machineStatusList
                // );
            } catch (Exception e) {
                // System.debug(
                //     'Error getting Machine Status picklist: ' + e.getMessage()
                // );
                // Fallback to known values if picklist access fails
                machineStatusList = new List<String>{
                    'Active',
                    'Ordered',
                    'Installed',
                    'Invoiced',
                    'Inactive',
                    'Rejected'
                };
            }

            // Get Business Case Status values directly from Business_Case__c.Status__c picklist
            List<String> businessCaseStatusList = new List<String>();
            try {
                Schema.DescribeFieldResult fieldResult = Business_Case__c.Status__c.getDescribe();
                List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
                for (Schema.PicklistEntry entry : picklistValues) {
                    if (entry.isActive()) {
                        if (!entry.getValue().contains('Closed')) {
                            businessCaseStatusList.add(entry.getValue());
                        }
                    }
                }
                businessCaseStatusList.sort();
                // System.debug(
                //     'Business Case Status picklist values: ' +
                //     businessCaseStatusList
                // );
            } catch (Exception e) {
                System.debug(
                    'Error getting Business Case Status picklist: ' +
                    e.getMessage()
                );
                // Fallback to known values if picklist access fails
                businessCaseStatusList = new List<String>{
                    'Active',
                    'Revised'
                };
            }

            // Get Commitment Status values directly from Business_Case_Sales_Snapshot__c.Performance_Status__c picklist
            List<String> commitmentStatusList = new List<String>();
            try {
                Schema.DescribeFieldResult fieldResult = Business_Case_Sales_Snapshot__c.Performance_Status__c.getDescribe();
                List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
                for (Schema.PicklistEntry entry : picklistValues) {
                    if (entry.isActive()) {
                        commitmentStatusList.add(entry.getValue());
                    }
                }
                commitmentStatusList.sort();
                // System.debug(
                //     'Machine Status picklist values: ' + commitmentStatusList
                // );
            } catch (Exception e) {
                System.debug(
                    'Error getting Machine Status picklist: ' + e.getMessage()
                );
                // Fallback to known values if picklist access fails
                commitmentStatusList = new List<String>{
                    'Behind',
                    'At Risk',
                    'On Track',
                    'No Target Set'
                };
            }

            // Convert snapshot data sets to sorted lists
            List<String> monthList = new List<String>(monthSet);
            monthList.sort();
            // Reverse to get most recent first (like original method)
            monthList = reverseList(monthList);

            List<String> regionList = new List<String>(regionSet);
            regionList.sort();

            List<String> businessCaseList = new List<String>(businessCaseSet);
            businessCaseList.sort();

            List<String> supplierList = new List<String>(supplierSet);
            supplierList.sort();

            // Create customer options list
            List<CustomerOption> customerOptions = new List<CustomerOption>();
            for (String customerCode : customerMap.keySet()) {
                CustomerOption option = new CustomerOption();
                option.customerCode = customerCode;
                option.customerName = customerMap.get(customerCode);
                customerOptions.add(option);
            }

            // Sort customers by code
            customerOptions.sort();

            EnhancedFilterOptions options = new EnhancedFilterOptions();
            options.months = monthList;
            options.customers = customerOptions;
            options.regions = regionList;
            options.suppliers = supplierList;
            options.businessCaseStatuses = businessCaseStatusList;
            options.machineStatuses = machineStatusList;
            options.performanceStatuses = commitmentStatusList;
            options.businessCases = businessCaseList;

            System.debug(
                'Final filter options - customers: ' +
                    options.customers.size() +
                    ' values'
            );
            System.debug(
                'Final filter options - Machine Statuses: ' +
                    options.machineStatuses.size() +
                    ' values'
            );
            System.debug(
                'Final filter options - Business Case Statuses: ' +
                    options.businessCaseStatuses.size() +
                    ' values'
            );

            return options;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Error retrieving enhanced filter options: ' + e.getMessage()
            );
        }
    }

    public static List<String> getPicklistValues(
        String objectApiName,
        String fieldApiName
    ) {
        try {
            // Get SObjectType dynamically
            Schema.SObjectType sObjectType = Schema.getGlobalDescribe()
                .get(objectApiName);

            if (sObjectType == null) {
                throw new AuraHandledException(
                    'Object ' + objectApiName + ' not found.'
                );
            }

            // Get field describe map dynamically
            Map<String, Schema.SObjectField> fieldsMap = sObjectType.getDescribe()
                .fields.getMap();

            Schema.SObjectField field = fieldsMap.get(fieldApiName);

            if (field == null) {
                throw new AuraHandledException(
                    'Field ' +
                        fieldApiName +
                        ' not found on object ' +
                        objectApiName
                );
            }

            // Get picklist values
            Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
            List<Schema.PicklistEntry> picklistEntries = fieldDescribe.getPicklistValues();

            // Extract the string values
            List<String> values = new List<String>();
            for (Schema.PicklistEntry entry : picklistEntries) {
                values.add(entry.getValue());
            }

            return values;
        } catch (Exception e) {
            return null;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<SnapshotWrapper> GetSnapshotDataUpdated(
        String DateFrom,
        String DateTo,
        String Region,
        String Supplier,
        String BusinessCaseStatus,
        String MachineStatus,
        String CommitmentStatus,
        String RiskStatus,
        String SearchCustomer,
        String BusinessCaseName
    ) {
        try {
            String whereBCClause = '';
            String whereBCSClause = '';
            String whereMasterClause = '';
            if (String.isBlank(wheremasterClause)) {
                wheremasterClause = ' WHERE Is_Master__c = true';
            } else {
                wheremasterClause += ' AND Is_Master__c = true';
            }

            // Date From Filter - Filter snapshots from a specific date onwards
            if (!String.isBlank(DateFrom)) {
                Date parsedDateFrom = Date.valueOf(DateFrom);
                String formattedDateFrom =
                    parsedDateFrom.year() +
                    '-' +
                    String.valueOf(parsedDateFrom.month()).leftPad(2, '0') +
                    '-' +
                    String.valueOf(parsedDateFrom.day()).leftPad(2, '0');

                if (String.isBlank(whereBCSClause)) {
                    whereBCSClause =
                        ' WHERE Snapshot_Month__c >= ' + formattedDateFrom;
                } else {
                    whereBCSClause +=
                        ' AND Snapshot_Month__c >= ' + formattedDateFrom;
                }

                System.debug(
                    'Date From filter applied: Snapshot_Month__c >= ' +
                    formattedDateFrom
                );
            }

            // Date To Filter - Filter snapshots up to a specific date
            if (!String.isBlank(DateTo)) {
                Date parsedDateTo = Date.valueOf(DateTo);
                String formattedDateTo =
                    parsedDateTo.year() +
                    '-' +
                    String.valueOf(parsedDateTo.month()).leftPad(2, '0') +
                    '-' +
                    String.valueOf(parsedDateTo.day()).leftPad(2, '0');

                if (String.isBlank(whereBCSClause)) {
                    whereBCSClause =
                        ' AND Snapshot_Month__c <= ' + formattedDateTo;
                } else {
                    whereBCSClause +=
                        ' AND Snapshot_Month__c <= ' + formattedDateTo;
                }

                System.debug(
                    'Date To filter applied: Snapshot_Month__c <= ' +
                    formattedDateTo
                );
            }

            if (!String.isBlank(Region) && Region != 'All Regions') {
                if (String.isBlank(whereBCClause)) {
                    whereBCClause = ' WHERE Region__c = \'' + Region + '\'';
                } else {
                    whereBCClause += ' AND Region__c = \'' + Region + '\'';
                }
            }
            if (
                !String.isBlank(SearchCustomer) &&
                SearchCustomer != 'All Customers'
            ) {
                String scustomer = '';
                if (SearchCustomer.contains(' - ')) {
                    scustomer = SearchCustomer.split(' - ')[0];
                    scustomer = scustomer.trim();
                }
                if (String.isBlank(whereBCClause)) {
                    whereBCClause =
                        ' WHERE Customer_Number__c = \'' +
                        SearchCustomer +
                        '\'';
                } else {
                    whereBCClause +=
                        ' AND Customer_Number__c = \'' +
                        SearchCustomer +
                        '\'';
                }

                if (String.isBlank(wheremasterClause)) {
                    wheremasterClause =
                        ' WHERE Customer_Numbera__c = \'' +
                        SearchCustomer +
                        '\'';
                } else {
                    wheremasterClause +=
                        ' AND Customer_Numbera__c = \'' +
                        SearchCustomer +
                        '\'';
                }
            }
            if (
                !String.isBlank(BusinessCaseStatus) &&
                BusinessCaseStatus != 'All Business Case Statuses'
            ) {
                String sbusinesscasestatus = '';
                // System.debug(
                //     '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->BusinessCaseStatus: ' +
                //     BusinessCaseStatus
                // );
                sbusinesscasestatus = BusinessCaseStatus.trim();

                if (String.isBlank(whereBCClause)) {
                    whereBCClause =
                        ' WHERE Status__c  = \'' +
                        sbusinesscasestatus +
                        '\' ';
                } else {
                    whereBCClause +=
                        ' AND Status__c  = \'' +
                        sbusinesscasestatus +
                        '\'';
                }
                if (String.isBlank(wheremasterClause)) {
                    wheremasterClause =
                        ' WHERE Status__c  = \'' +
                        sbusinesscasestatus +
                        '\' ';
                } else {
                    wheremasterClause +=
                        ' AND Status__c  = \'' +
                        sbusinesscasestatus +
                        '\'';
                }
            } else {
                if (String.isBlank(whereBCClause)) {
                    whereBCClause = ' WHERE (Status__c  LIKE \'%Active%\' OR Status__c LIKE \'%Revised%\' OR Status__c LIKE \'%New%\' ) ';
                } else {
                    whereBCClause += ' AND (Status__c  LIKE \'%Active%\' OR Status__c LIKE \'%Revised%\' OR Status__c LIKE \'%New%\')';
                }
                if (String.isBlank(wheremasterClause)) {
                    wheremasterClause = ' WHERE (Status__c  LIKE \'%Active%\' OR Status__c LIKE \'%Revised%\' OR Status__c LIKE \'%New%\' )';
                } else {
                    wheremasterClause += ' AND (Status__c  LIKE \'%Active%\' OR Status__c LIKE \'%Revised%\' OR Status__c LIKE \'%New%\')';
                }
            }

            if (
                !String.isBlank(CommitmentStatus) &&
                CommitmentStatus != 'All Commitment Statuses'
            ) {
                String scommitmenttatus = '';
                scommitmenttatus = CommitmentStatus.trim();

                whereBCSClause +=
                    ' AND Performance_Status__c  = \'' +
                    scommitmenttatus +
                    '\'';
            }

            if (!String.isBlank(Supplier) && Supplier != 'All Suppliers') {
                String ssupplier = '';
                if (Supplier.contains(' - ')) {
                    ssupplier = Supplier.split(' - ')[0];
                    ssupplier = ssupplier.trim();
                }

                whereBCSClause += ' AND Vendor__c  = \'' + Supplier + '\'';
            }

            if (
                !String.isBlank(BusinessCaseName) &&
                BusinessCaseName != 'All Business Cases'
            ) {
                String sbcname = '';
                sbcname = BusinessCaseName.trim();

                if (String.isBlank(whereBCClause)) {
                    whereBCClause = ' WHERE Name  = \'' + sbcname + '\'';
                } else {
                    whereBCClause += ' AND Name  = \'' + sbcname + '\'';
                }

                if (String.isBlank(wheremasterClause)) {
                    wheremasterClause =
                        ' WHERE Name = \'' +
                        SearchCustomer +
                        '\'';
                } else {
                    wheremasterClause +=
                        ' AND Name = \'' +
                        SearchCustomer +
                        '\'';
                }
            }

            if (String.isBlank(whereBCClause)) {
                whereBCClause = ' WHERE  Is_Master__c = false and Master_Business_Case__c = null';
            } else {
                whereBCClause += ' AND  Is_Master__c = false and Master_Business_Case__c = null';
            }

            // Note: whereBCSClause should NOT filter by Is_Master__c because it's used for both
            // regular business case snapshots AND master business case snapshots
            // The Business_Case__c queries above already handle the Master filtering

            if (
                !String.isBlank(MachineStatus) &&
                MachineStatus != 'All Machine Statuses'
            ) {
                String smachinestatus = '';
                smachinestatus = MachineStatus.trim();

                if (String.isBlank(whereBCClause)) {
                    whereBCClause =
                        ' WHERE Machine_Installation__r.Status__c  = \'' +
                        smachinestatus +
                        '\'';
                } else {
                    whereBCClause +=
                        ' AND Machine_Installation__r.Status__c  = \'' +
                        smachinestatus +
                        '\'';
                }
            }

            String bcquery = 'SELECT Id,Name,Status__c,Customer_Number__c,Customer_Name__c,Machine_Installation__r.SAP_Account_No_Ship_To__c,Machine_Installation__r.SAP_Account_No_Bill_To__c';
            bcquery += ',Machine_Installation__r.Diagnostic_Machine__r.Vendor__c,Machine_Installation__r.Diagnostic_Machine__r.Technology__c,Region__c,';
            bcquery += 'Machine_Installation__r.Material_Number__c,Machine_Installation__r.Material_Description__c,Machine_Installation__r.Status__c,';
            bcquery += 'Bill_To_Address_Line_1__c,Bill_To_Address_Line_2__c,Bill_To_City__c,Ship_To_Address_Line_1__c,Ship_To_Address_Line_2__c,Ship_To_City__c,Ship_To_Postal_Code__c,Ship_To_Province__c,Ship_To_Customer_Name__c,Unit_Cost__c,Total_Unit_Cost__c';
            bcquery +=
                ',Ship_To_Customer_Number__c,Monthly_Reagent_Commitment__c,Agreement_Date__c,RecordType.Name,Quantity__c  FROM Business_Case__c ' +
                whereBCClause;

            System.debug(
                '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->whereBCClause: ' +
                whereBCClause
            );
            System.debug(
                '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->bcquery: ' +
                bcquery
            );

            List<Id> activeBusinessCases = new List<Id>();
            List<Business_Case__c> activeBusinessCasesObj = new List<Business_Case__c>();
            for (Business_Case__c bc : Database.query(bcquery)) {
                activeBusinessCases.add(bc.Id);
                activeBusinessCasesObj.add(bc);
            }

            
            // System.debug(
            //     '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->activeBusinessCases: ' +
            //     activeBusinessCases.size()
            // );

            String bcmasterquery = 'SELECT Id,Name,Quantity__c,Status__c,Customer_Number__c,Customer_Name__c,Machine_Installation__r.SAP_Account_No_Ship_To__c,Machine_Installation__r.SAP_Account_No_Bill_To__c';
            bcmasterquery += ',Machine_Installation__r.Diagnostic_Machine__r.Vendor__c,Machine_Installation__r.Diagnostic_Machine__r.Technology__c,Region__c,';
            bcmasterquery += 'Machine_Installation__r.Material_Number__c,Machine_Installation__r.Material_Description__c,Machine_Installation__r.Status__c,';
            bcmasterquery += 'Bill_To_Address_Line_1__c,Bill_To_Address_Line_2__c,Bill_To_City__c,Ship_To_Address_Line_1__c,Ship_To_Address_Line_2__c,Ship_To_City__c,Ship_To_Postal_Code__c,Ship_To_Province__c,Ship_To_Customer_Name__c,Unit_Cost__c,Total_Unit_Cost__c';
            bcmasterquery += ',Ship_To_Customer_Number__c,Monthly_Reagent_Commitment__c,Agreement_Date__c,Customer_Numbera__c,Customer_Namea__c,Sum_of_Monthly_Reagent_Commitment__c,Material_Number__c,Material_Descriptionsa__c,Sum_of_Unit_Cost__c,RecordType.Name   ';
            bcmasterquery += ',Vendor__c,Technologyaa__c ';
            // bcmasterquery += ' ,Bill_To_Address_Line_1__c,Bill_To_Address_Line_2__c,Bill_To_City__c,Ship_To_Address_Line_1__c,Ship_To_Address_Line_2__c,Ship_To_City__c,Ship_To_Postal_Code__c,Ship_To_Province__c,Ship_To_Customer_Name__c';
            bcmasterquery += ',(SELECT  Id,Name,Status__c,Account__c,Account__r.Province__c,Account__r.City__c,Account__r.AddressLine_1__c,Account__r.Addess_Line_2__c,Account__r.Postal_Code__c,Account__r.Country_Code__c,Customer_Number__c,';
            bcmasterquery += ' Customer_Name__c,Supplier_Name__c,Technology__c,Region__c,SAP_Material_Number__c,Machine_Type__c,Quantity__c,Monthly_Reagent_Commitment__c,Unit_Cost__c,Margin_Percent__c,Agreement_Date__c,Asset_Number__c,';
            bcmasterquery += ' Asset_Number__r.Status__c,Machine_Installation__r.Ship_To_Account__c,Machine_Installation__r.Ship_To_Account__r.SAP_Customer_Number__c,Machine_Installation__r.Ship_To_Account__r.Name,Machine_Installation__r.Ship_To_Account__r.Province__c,';
            bcmasterquery += ' Machine_Installation__r.Ship_To_Account__r.City__c,Machine_Installation__r.Ship_To_Account__r.AddressLine_1__c,Machine_Installation__r.Ship_To_Account__r.Addess_Line_2__c,Machine_Installation__r.Ship_To_Account__r.Postal_Code__c,';
            bcmasterquery += ' Machine_Installation__r.Ship_To_Account__r.Country_Code__c,Machine_Installation__r.Diagnostic_Machine__r.Vendor__c,Machine_Installation__r.Diagnostic_Machine__r.Technology__c,Ship_To_Customer_Number__c,';
            bcmasterquery += ' Ship_To_Customer_Name__c,Machine_Installation__r.SAP_Account_No_Bill_To__c,Machine_Installation__r.bill_to_account__r.Name,Machine_Installation__r.Material_Number__c,Machine_Installation__r.Status__c,Machine_Installation__r.bill_to_account__r.Province__c,Machine_Installation__r.bill_to_account__r.City__c,';
            bcmasterquery += ' Machine_Installation__r.bill_to_account__r.AddressLine_1__c,Machine_Installation__r.bill_to_account__r.Postal_Code__c,Machine_Installation__r.bill_to_account__r.Country_Code__c,  ';
            bcmasterquery += ' Bill_To_Address_Line_1__c,Bill_To_Address_Line_2__c,Bill_To_City__c,Ship_To_Address_Line_1__c,Ship_To_Address_Line_2__c,Ship_To_City__c,Ship_To_Postal_Code__c,Ship_To_Province__c';
            bcmasterquery += ' FROM Business_Cases__r WHERE RecordType.Name = \'Individual Business Case\' and (Status__c like \'%Active%\' or Status__c like \'%Revised%\' or Status__c like \'%New%\') LIMIT 1 )';
            
            bcmasterquery += ' FROM Business_Case__c ' + whereMasterClause;

            System.debug(
                '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->whereMasterClause: ' +
                whereMasterClause
            );
            System.debug(
                '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->bcmasterquery: ' +
                bcmasterquery
            );

            for (Business_Case__c bc : Database.query(bcmasterquery)) {
                activeBusinessCases.add(bc.Id);
                activeBusinessCasesObj.add(bc);
            }

            // System.debug(
            //     '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->activebusinesscases: ' +
            //     activeBusinessCases.size()
            // );

            Map<Id,Decimal> marginByBusinessCase = new Map<Id,Decimal>();

            for (AggregateResult ar : [
                SELECT Business_Case__c, SUM(Margin_On_Reagent_Sale__c) totalMargin
                FROM Business_Case_Sales_Snapshot__c
                WHERE Business_Case__c IN :activeBusinessCases
                GROUP BY Business_Case__c
            ]) {
                marginByBusinessCase.put(
                    (Id) ar.get('Business_Case__c'),
                    (Decimal) ar.get('totalMargin')
                );
            }

            System.debug('>>>>BusinessCaseDashboard-->GetSnapshotDataUpdated-->marginByBusinessCase: '+marginByBusinessCase);

            Map<Id, DateTime> parentToLatestChild = new Map<Id, DateTime>();

            for (AggregateResult ar : [
                SELECT
                    Business_Case__c parentId,
                    MAX(LastModifiedDate) latestDate
                FROM Business_Case_Sales_Snapshot__c
                WHERE Business_Case__c IN :activeBusinessCases
                GROUP BY Business_Case__c
            ]) {
                parentToLatestChild.put(
                    (Id) ar.get('parentId'),
                    (DateTime) ar.get('latestDate')
                );
            }

           

            // System.debug(
            //     '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->parent child keySet: ' +
            //     parentToLatestChild.keySet()
            // );
            System.debug(
                '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->whereBCSClause: ' +
                whereBCSClause
            );

            List<String> idList = new List<String>();
            for (Id value : parentToLatestChild.keySet()) {
                idList.add(String.valueOf(value));
            }

            String idListStr =
                '(' +
                '\'' +
                String.join(idList, '\',\'') +
                '\'' +
                ')';

            String bscquery = 'Select Id, Business_Case__c,Business_Case_Name__c,Business_Case_Status__c,Machine_Status__c,';
            bscquery += ' Customer_Code__c,Customer_Name__c,Vendor__c,Technology__c,Region__c,Material_Number__c,Material_Description__c,Customer_Province__c,';
            bscquery += ' Customer_City__c,Customer_AddressLine1__c,Customer_AddressLine2__c,Customer_Postal_Code__c,Customer_Country__c,Ship_To_Customer_Number__c,';
            bscquery += ' Ship_To_Customer_Name__c,Ship_To_Province__c,Ship_To_City__c,Ship_To_AddressLine1__c,Ship_To_Address_Line_2__c,';
            bscquery += ' Ship_To_Postal_Code__c,Ship_To_Country__c,Snapshot_Month__c,Total_Reagent_Sales__c,Target_Sales__c,';
            bscquery += ' Machine_Count__c,Per_Machine_Sales__c,Source_Invoice_Count__c,YTD_Sales__c,Total_Reagent_Sales_Till_Date__c,';
            bscquery += ' Contract_Months_Elapsed__c,Avg_Reagent_Sales_Per_Month__c,Performance_Status__c,Deficit_Cost_Covered__c,Margin_Percent_Snapshot__c,';
            bscquery += ' Margin_On_Reagent_Sale__c,Payback_Remaining__c,Data_Quality_Score__c,Processing_Status__c,Snapshot_Created_Date__c,';
            bscquery += ' Monthly_Commitments__c,Business_Case__r.Unit_Cost__c,LastModifiedDate,Avg_YTD_Sales_Per_Month__c,Margin_till_Date__c,Business_Case__r.Sum_of_Unit_Cost__c   ';
            bscquery += '  FROM Business_Case_Sales_Snapshot__c ';
            bscquery +=
                ' WHERE Business_Case__c IN ' +
                idListStr +
                '  ' +
                whereBCSClause +
                ' and Processing_Status__c = \'Completed\' ';
            bscquery += ' ORDER BY Snapshot_Month__c DESC, Snapshot_Created_Date__c DESC ';

            System.debug(
                '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->bscquery: ' +
                bscquery
            );

            // List<Business_Case_Sales_Snapshot__c> latestChildren = [
            //    Select Id,
            //                       Business_Case__c,
            //                       Business_Case_Name__c,
            //                       Business_Case_Status__c,
            //                       Machine_Status__c,
            //                       Customer_Code__c,
            //                       Customer_Name__c,
            //                       Vendor__c,
            //                       Technology__c,
            //                       Region__c,
            //                       Material_Number__c,
            //                       Material_Description__c,
            //                       Customer_Province__c,
            //                       Customer_City__c,
            //                       Customer_AddressLine1__c,
            //                       Customer_AddressLine2__c,
            //                       Customer_Postal_Code__c,
            //                       Customer_Country__c,
            //                       Ship_To_Customer_Number__c,
            //                       Ship_To_Customer_Name__c,
            //                       Ship_To_Province__c,
            //                       Ship_To_City__c,
            //                       Ship_To_AddressLine1__c,
            //                       Ship_To_Address_Line_2__c,
            //                       Ship_To_Postal_Code__c,
            //                       Ship_To_Country__c,
            //                       Snapshot_Month__c,
            //                       Total_Reagent_Sales__c,
            //                       Target_Sales__c,
            //                       Machine_Count__c,
            //                       Per_Machine_Sales__c,
            //                       Source_Invoice_Count__c,
            //                       YTD_Sales__c,
            //                       Total_Reagent_Sales_Till_Date__c,
            //                       Contract_Months_Elapsed__c,
            //                       Avg_Reagent_Sales_Per_Month__c,
            //                       Performance_Status__c,
            //                       Deficit_Cost_Covered__c,
            //                       Margin_Percent_Snapshot__c,
            //                       Margin_On_Reagent_Sale__c,
            //                       Payback_Remaining__c,
            //                       Data_Quality_Score__c,
            //                       Processing_Status__c,
            //                       Snapshot_Created_Date__c,
            //                       Monthly_Commitments__c,
            //                       Business_Case__r.Total_Unit_Cost__c
            //                   FROM Business_Case_Sales_Snapshot__c
            //     WHERE Business_Case__c IN :parentToLatestChild.keySet() and Processing_Status__c = 'Completed'
            //     ORDER BY Snapshot_Month__c DESC, Snapshot_Created_Date__c DESC
            // ];

            List<Business_Case_Sales_Snapshot__c> latestChildren = new List<Business_Case_Sales_Snapshot__c>();

            try {
                latestChildren = Database.query(bscquery);
                System.debug(
                    '🔍 GetSnapshotDataUpdated - Query returned ' +
                        latestChildren.size() +
                        ' snapshots'
                );
                System.debug(
                    '🔍 GetSnapshotDataUpdated - whereBCSClause: ' +
                    whereBCSClause
                );
                System.debug(
                    '🔍 GetSnapshotDataUpdated - bscquery: ' +
                    bscquery
                );

                // Debug: Check for customer 3020001748 snapshots
                Integer customer3020001748Count = 0;
                for (Business_Case_Sales_Snapshot__c snap : latestChildren) {
                    if (snap.Customer_Code__c == '3020001748') {
                        customer3020001748Count++;
                        System.debug(
                            '📊 Customer 3020001748 snapshot found: BC=' +
                                snap.Business_Case__c +
                                ', Month=' +
                                snap.Snapshot_Month__c +
                                ', Sales=' +
                                snap.Total_Reagent_Sales_Till_Date__c
                        );
                    }
                }
                System.debug(
                    '🔍 Total snapshots for customer 3020001748: ' +
                    customer3020001748Count
                );

                // If no snapshots found with date filter, check what dates exist for this customer
                if (customer3020001748Count == 0 && DateTo != null) {
                    System.debug(
                        '🔍 Checking ALL snapshot dates for customer 3020001748 (without date filter)...'
                    );
                    List<Business_Case_Sales_Snapshot__c> allCustomerSnaps = [
                        SELECT
                            Id,
                            Snapshot_Month__c,
                            Business_Case__c,
                            Total_Reagent_Sales_Till_Date__c
                        FROM Business_Case_Sales_Snapshot__c
                        WHERE
                            Customer_Code__c = '3020001748'
                            AND Processing_Status__c = 'Completed'
                        ORDER BY Snapshot_Month__c ASC
                        LIMIT 10
                    ];
                    System.debug(
                        '🔍 Found ' +
                            allCustomerSnaps.size() +
                            ' total snapshots for customer 3020001748:'
                    );
                    for (
                        Business_Case_Sales_Snapshot__c snap : allCustomerSnaps
                    ) {
                        System.debug(
                            '  - Month: ' +
                                snap.Snapshot_Month__c +
                                ', BC: ' +
                                snap.Business_Case__c +
                                ', Sales: ' +
                                snap.Total_Reagent_Sales_Till_Date__c
                        );
                    }
                }
            } catch (Exception exc) {
                System.debug(
                    '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->Exception: ' +
                    exc.getMessage()
                );
            }

            // System.debug(
            //     '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->latestchildren size: ' +
            //     latestChildren.size()
            // );

            Map<Id, Business_Case_Sales_Snapshot__c> parentToChildMap = new Map<Id, Business_Case_Sales_Snapshot__c>();

            for (Business_Case_Sales_Snapshot__c c : latestChildren) {
                Business_Case_Sales_Snapshot__c existing = parentToChildMap.get(
                    c.Business_Case__c
                );
                // System.debug(
                //     '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->c: ' +
                //     c
                // );
                // System.debug(
                //     '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->existing: ' +
                //     existing
                // );
                // If none stored yet OR this one is newer, keep this one
                if (existing == null) {
                    // System.debug(
                    //     '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->existing is null: '
                    // );
                    parentToChildMap.put(c.Business_Case__c, c);
                } else {
                    if (c.LastModifiedDate > existing.LastModifiedDate) {
                        System.debug(
                            '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->existing is empty: '
                        );
                        parentToChildMap.put(c.Business_Case__c, c);
                    }
                }
            }

            // System.debug(
            //     '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->Parent to child map size: ' +
            //     parentToChildMap.size()
            // );
            // System.debug(
            //     '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->Parent to child map : ' +
            //     parentToChildMap
            // );

            AggregateResult investmentresult = [Select sum(Sum_of_Unit_Cost__c) totalsumcost,sum(Unit_Cost__c) totalcost from Business_Case__c where Id in :activeBusinessCases ];
            System.debug('>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->investmentresult: '+investmentresult);

            if(investmentresult != null)
            {
                System.debug('>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->totalsumcost: '+(Decimal)investmentresult.get('totalsumcost'));
                System.debug('>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->totalcost: '+(Decimal)investmentresult.get('totalcost'));
            }
            Decimal totalInvestment = 0;
            List<Business_Case_Sales_Snapshot__c> finalChildren = parentToChildMap.values();
                Set<Id> wrapperCases = new Set<Id>();
                Map<Id,Map<Date,Decimal>> salesbyMonth = new Map<Id,Map<Date,Decimal>>();
                 //Fetching last six months
                List<Date> lastSixMonths = new List<Date>();
                Datetime currentDate = Datetime.now().addMonths(-1);
                for (Integer i = 0; i < 6; i++) {
                    Date monthStart = Date.newInstance(currentDate.year(), currentDate.month(), 1).addMonths(-i);
                    lastSixMonths.add(monthStart);
                }
            if (finalChildren.size() > 0) {
                // System.debug(
                //     '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->final children size: ' +
                //     finalChildren.size()
                // );
                // System.debug(
                //     '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->final children : ' +
                //     finalChildren
                // );
                List<SnapshotWrapper> wrappers = new List<SnapshotWrapper>();
                // Process ALL snapshots to create wrapper objects for risk management
                Date today = Date.today();
                Date firstOfThisMonth = Date.newInstance(
                    today.year(),
                    today.month(),
                    1
                );
                Date lastMonth = firstOfThisMonth.addMonths(-1);
                // Date lastMonth = firstOfThisMonth;
                Date m0 = Date.newInstance(
                    lastMonth.year(),
                    lastMonth.month(),
                    1
                ); // last month
                Date m1 = m0.addMonths(-1); // last month - 1
                Date m2 = m1.addMonths(-1);
                Date m3 = m2.addMonths(-1);
                Date m4 = m3.addMonths(-1);

                String riskStatusQuery =
                    'Select Snapshot_Month__c,Business_Case__c,Monthly_Commitments__c,Total_Reagent_Sales__c from Business_Case_Sales_Snapshot__c WHERE Business_Case__c IN ' +
                    idListStr +
                    '  ' +
                    whereBCSClause +
                    ' and Processing_Status__c = \'Completed\' ';
                // System.debug(
                //     '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->riskStatusQuery: ' +
                //     riskStatusQuery
                // );
                Map<Id, List<Business_Case_Sales_Snapshot__c>> snapsByBc = new Map<Id, List<Business_Case_Sales_Snapshot__c>>();
                for (
                    Business_Case_Sales_Snapshot__c bsclastsix : Database.query(
                        riskStatusQuery
                    )
                ) {
                    List<Business_Case_Sales_Snapshot__c> isexist = snapsByBc.get(
                        bsclastsix.Business_Case__c
                    );
                    if (isexist == null) {
                        snapsByBc.put(
                            bsclastsix.Business_Case__c,
                            new List<Business_Case_Sales_Snapshot__c>()
                        );
                    }
                    snapsByBc.get(bsclastsix.Business_Case__c).add(bsclastsix);
                }

                Map<Id, Set<Date>> monthsPresentByBc = new Map<Id, Set<Date>>();
                for (Id bcId : snapsByBc.keySet()) {
                    Set<Date> months = new Set<Date>();
                    for (
                        Business_Case_Sales_Snapshot__c s : snapsByBc.get(bcId)
                    ) {
                        if (s.Snapshot_Month__c != null) 
                        {
                            System.debug('>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->s.Snapshot_Month__c: '+s.Snapshot_Month__c);
                            if( s.Total_Reagent_Sales__c >= s.Monthly_Commitments__c)
                            {
                                Date d = s.Snapshot_Month__c;
                                months.add(
                                    Date.newInstance(d.year(), d.month(), 1)
                                ); // normalize to first-of-month
                                System.debug('>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->smonths: '+months);
                            }
                            
                        }
                    }
                    monthsPresentByBc.put(bcId, months);
                }

               
                System.debug('>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->monthsPresentByBc: '+monthsPresentByBc);
                System.debug('>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->lastsixMonths: '+lastSixMonths);

            

                for (Business_Case__c bcase : activeBusinessCasesObj) 
                {
                    System.debug('>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->bcase: '+bcase);
                    SnapshotWrapper wrapper = new SnapshotWrapper();

                    wrapperCases.add(bcase.Id);

                    wrapper.businessCaseId = bcase.Id;
                    wrapper.businessCaseName = bcase.Name;
                    wrapper.businessCaseStatus = bcase.Status__c;
                  
                    if (bcase.RecordType.Name == 'Master Business Case') 
                    {
                        wrapper.customerCode = bcase.Customer_Numbera__c;
                        wrapper.customerName = bcase.Customer_Namea__c;
                        wrapper.vendor = bcase.Vendor__c;
                        wrapper.technology = bcase.Technologyaa__c;
                        wrapper.region = bcase.Business_Cases__r[0].Region__c;
                        wrapper.materialNumber = bcase.Material_Number__c;
                        wrapper.materialDescription = bcase.Material_Descriptionsa__c;
                        wrapper.machineStatus = bcase.Business_Cases__r[0]
                            .Machine_Installation__r.Status__c;
                        wrapper.customerAddressLine1 = bcase.Business_Cases__r[0]
                            .Bill_To_Address_Line_1__c;
                        wrapper.customerAddressLine2 = bcase.Business_Cases__r[0]
                            .Bill_To_Address_Line_2__c;
                        wrapper.customerCity = bcase.Business_Cases__r[0]
                            .Bill_To_City__c;

                        wrapper.shipToCustomerNumber = bcase.Business_Cases__r[0]
                            .Ship_To_Customer_Number__c;
                        wrapper.shipToCustomerName = bcase.Business_Cases__r[0]
                            .Ship_To_Customer_Name__c;
                        wrapper.shipToProvince = bcase.Business_Cases__r[0]
                            .Ship_To_Province__c;
                        wrapper.shipToCity = bcase.Business_Cases__r[0]
                            .Ship_To_City__c;
                        wrapper.shipToAddressLine1 = bcase.Business_Cases__r[0]
                            .Ship_To_Address_Line_1__c;
                        wrapper.shipToAddressLine2 = bcase.Business_Cases__r[0]
                            .Ship_To_Address_Line_2__c;
                        wrapper.shipToPostalCode = bcase.Business_Cases__r[0]
                            .Ship_To_Postal_Code__c;
                        wrapper.monthCommitment = bcase.Sum_of_Monthly_Reagent_Commitment__c;
                        wrapper.investment = (bcase.Sum_of_Unit_Cost__c == null ? 0 : bcase.Sum_of_Unit_Cost__c);
                        totalInvestment += (bcase.Sum_of_Unit_Cost__c == null ? 0 : bcase.Sum_of_Unit_Cost__c);
                    } else {
                        wrapper.customerCode = bcase.Customer_Number__c;
                        wrapper.customerName = bcase.Customer_Name__c;
                        wrapper.vendor = bcase.Machine_Installation__r.Diagnostic_Machine__r.Vendor__c;
                        wrapper.technology = bcase.Machine_Installation__r.Diagnostic_Machine__r.Technology__c;
                        wrapper.region = bcase.Region__c;
                        wrapper.materialNumber = bcase.Machine_Installation__r.Material_Number__c;
                        wrapper.materialDescription = bcase.Machine_Installation__r.Material_Description__c;
                        wrapper.machineStatus = bcase.Machine_Installation__r.Status__c;
                        wrapper.customerAddressLine1 = bcase.Bill_To_Address_Line_1__c;
                        wrapper.customerAddressLine2 = bcase.Bill_To_Address_Line_2__c;
                        wrapper.customerCity = bcase.Bill_To_City__c;

                        wrapper.shipToCustomerNumber = bcase.Ship_To_Customer_Number__c;
                        wrapper.shipToCustomerName = bcase.Ship_To_Customer_Name__c;
                        wrapper.shipToProvince = bcase.Ship_To_Province__c;
                        wrapper.shipToCity = bcase.Ship_To_City__c;
                        wrapper.shipToAddressLine1 = bcase.Ship_To_Address_Line_1__c;
                        wrapper.shipToAddressLine2 = bcase.Ship_To_Address_Line_2__c;
                        wrapper.shipToPostalCode = bcase.Ship_To_Postal_Code__c;
                        wrapper.monthCommitment = bcase.Monthly_Reagent_Commitment__c;
                        wrapper.investment = (bcase.Unit_Cost__c == null ? 0 : bcase.Unit_Cost__c);
                        totalInvestment += (bcase.Unit_Cost__c == null ? 0 : bcase.Unit_Cost__c);
                    }

                    // wrapper.shipToCountry = case.Ship_To_Country__c;

                    Business_Case_Sales_Snapshot__c snapshot = parentToChildMap.get(
                        bcase.Id
                    );
                    System.debug('>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->snapshot: '+snapshot);
                    if (snapshot != null) 
                    {
                        wrapper.id = snapshot.Id;
                        wrapper.totalReagentSales = snapshot.Total_Reagent_Sales__c;
                        wrapper.targetSales = snapshot.Target_Sales__c;
                        wrapper.ytdSales = snapshot.YTD_Sales__c;
                        wrapper.totalReagentSalesTillDate = snapshot.Total_Reagent_Sales_Till_Date__c;
                        wrapper.marginOnReagentSale = snapshot.Margin_On_Reagent_Sale__c;
                        wrapper.paybackRemaining = snapshot.Payback_Remaining__c;
                        wrapper.machineCount = snapshot.Machine_Count__c;
                        wrapper.perMachineSales = snapshot.Per_Machine_Sales__c;
                        wrapper.contractMonthsElapsed = snapshot.Contract_Months_Elapsed__c;
                        wrapper.avgReagentSalesPerMonth = snapshot.Avg_Reagent_Sales_Per_Month__c;
                        // wrapper.performanceStatus = snapshot.Performance_Status__c;
                        wrapper.deficitCostCovered = snapshot.Deficit_Cost_Covered__c;
                        wrapper.marginPercentSnapshot = snapshot.Margin_Percent_Snapshot__c;
                        wrapper.dataQualityScore = snapshot.Data_Quality_Score__c;
                        wrapper.snapshotMonth = snapshot.Snapshot_Month__c
                            ?.format();
                        wrapper.formattedMonth = formatMonthLabel(
                            snapshot.Snapshot_Month__c
                        );
                        wrapper.avgYtdSales = snapshot.Avg_YTD_Sales_Per_Month__c;
                        wrapper.riskStatus = deriveRiskStatusFromLatestMonthsBulk(
                            bcase.Id,
                            //snapshot.Snapshot_Month__c,
                            null,
                            bcase,
                            monthsPresentByBc
                        );
                        wrapper.marginTillDate = snapshot.Margin_till_Date__c;
                        //wrapper.investment = calculateInvestment(snapshot);

                        // Formatted fields for display
                        wrapper.formattedSales = formatCurrency(
                            wrapper.totalReagentSales
                        );
                        wrapper.formattedTarget = formatCurrency(
                            wrapper.targetSales
                        );
                        wrapper.formattedAchievement = formatPercent(
                            calculateAchievementPercent(
                                wrapper.totalReagentSales,
                                wrapper.targetSales
                            )
                        );
                        if (bcase.RecordType.Name == 'Master Business Case') {
                            if (
                                bcase.Sum_of_Monthly_Reagent_Commitment__c !=
                                null
                            ) {
                                if (
                                    bcase.Sum_of_Monthly_Reagent_Commitment__c >
                                    0
                                ) 
                                {
                                    if(snapshot.Avg_Reagent_Sales_Per_Month__c >= bcase.Sum_of_Monthly_Reagent_Commitment__c)
                                    {
                                        wrapper.performanceStatus = 'On Track';
                                    }
                                    else
                                    {
                                        wrapper.performanceStatus = 'Behind';
                                    }
                                    //wrapper.performanceStatus = 'Behind';
                                } else {
                                    wrapper.performanceStatus = 'No Target Set';
                                }
                            } else {
                                wrapper.performanceStatus = 'No Target Set';
                            }
                        } else {
                            if (bcase.Monthly_Reagent_Commitment__c != null) {
                                if (bcase.Monthly_Reagent_Commitment__c > 0) 
                                {
                                    if(snapshot.Avg_Reagent_Sales_Per_Month__c >=  bcase.Monthly_Reagent_Commitment__c )
                                    {
                                        wrapper.performanceStatus = 'On Track';
                                    }
                                    else
                                    {
                                        wrapper.performanceStatus = 'Behind';
                                    }
                                    // wrapper.performanceStatus = 'Behind';
                                } else {
                                    wrapper.performanceStatus = 'No Target Set';
                                }
                            } else {
                                wrapper.performanceStatus = 'No Target Set';
                            }
                        }
                    } 
                    else 
                    {
                        if(bcase.Quantity__c != null && String.isNotBlank(bcase.Quantity__c) && String.isNotEmpty(bcase.Quantity__c))
                        {
                            wrapper.machineCount = Decimal.valueOf(bcase.Quantity__c) ;
                        }
                        wrapper.riskStatus = deriveRiskStatusFromLatestMonthsBulk(
                            bcase.Id,
                            null,
                            bcase,
                            monthsPresentByBc
                        );
                        if (bcase.RecordType.Name == 'Master Business Case') {
                            if (
                                bcase.Sum_of_Monthly_Reagent_Commitment__c !=
                                null
                            ) {
                                if (
                                    bcase.Sum_of_Monthly_Reagent_Commitment__c >
                                    0
                                ) {
                                    wrapper.performanceStatus = 'Behind';
                                } else {
                                    wrapper.performanceStatus = 'No Target Set';
                                }
                            } else {
                                wrapper.performanceStatus = 'No Target Set';
                            }
                        } else {
                            if (bcase.Monthly_Reagent_Commitment__c != null) {
                                if (bcase.Monthly_Reagent_Commitment__c > 0) {
                                    wrapper.performanceStatus = 'Behind';
                                } else {
                                    wrapper.performanceStatus = 'No Target Set';
                                }
                            } else {
                                wrapper.performanceStatus = 'No Target Set';
                            }
                        }
                    }

                    Map<Date, Decimal> monthMap = new Map<Date, Decimal>();
                    for (Date m : lastSixMonths) {
                        monthMap.put(m, 0);
                    }
                    salesByMonth.put(bcase.Id, monthMap);
                    
                    wrappers.add(wrapper);
                }

                

                for(Business_Case_Sales_Snapshot__c snap : [
                    SELECT Id, Business_Case__c, Snapshot_Month__c, Total_Reagent_Sales__c
                    FROM Business_Case_Sales_Snapshot__c
                    WHERE Business_Case__c IN :wrapperCases
                    AND Snapshot_Month__c IN :lastSixMonths
                ])
                {
                    if(!salesbyMonth.containsKey(snap.Business_Case__c))
                    {
                        salesbyMonth.put(snap.Business_Case__c, new Map<Date,Decimal>());

                    }
                    salesbyMonth.get(snap.Business_Case__c).put(snap.Snapshot_Month__c, snap.Total_Reagent_Sales__c);
                }

                for(SnapshotWrapper wr : wrappers)
                {
                    Map<String, Decimal> mSales = new Map<String, Decimal>();

                    for (Date m : lastSixMonths) 
                    {
                        Datetime newm = Datetime.newInstance(m, Time.newInstance(0, 0, 0, 0));
                        String label = newm.format('MMM yyyy').replace(' ', '_'); 
                        Decimal value = salesbyMonth.containsKey(wr.businessCaseId)
                            ? salesbyMonth.get(wr.businessCaseId).get(m)
                            : 0;
                        mSales.put(label, value);
                    }

                    wr.monthlySales = mSales;
                    System.debug('>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->wr.monthlySales: '+wr.monthlySales);
                }
                //old code
                // for (Business_Case_Sales_Snapshot__c snapshot : finalChildren)
                // {
                //   SnapshotWrapper wrapper = new SnapshotWrapper();

                //   // Core Business Case information from snapshot
                //   wrapper.businessCaseId = snapshot.Business_Case__c;
                //   wrapper.businessCaseName = snapshot.Business_Case_Name__c;
                //   wrapper.businessCaseStatus = snapshot.Business_Case_Status__c;
                //   wrapper.customerCode = snapshot.Customer_Code__c;
                //   wrapper.customerName = snapshot.Customer_Name__c;
                //   wrapper.vendor = snapshot.Vendor__c;
                //   wrapper.technology = snapshot.Technology__c;
                //   wrapper.region = snapshot.Region__c;
                //   wrapper.materialNumber = snapshot.Material_Number__c;
                //   wrapper.materialDescription = snapshot.Material_Description__c;
                //   wrapper.machineStatus = snapshot.Machine_Status__c;

                //   // Customer Address Information from snapshot
                //   wrapper.customerProvince = snapshot.Customer_Province__c;
                //   wrapper.customerCity = snapshot.Customer_City__c;
                //   wrapper.customerAddressLine1 = snapshot.Customer_AddressLine1__c;
                //   wrapper.customerAddressLine2 = snapshot.Customer_AddressLine2__c;
                //   wrapper.customerPostalCode = snapshot.Customer_Postal_Code__c;
                //   wrapper.customerCountry = snapshot.Customer_Country__c;

                //   // Ship To Account Information from snapshot
                //   wrapper.shipToCustomerNumber = snapshot.Ship_To_Customer_Number__c;
                //   wrapper.shipToCustomerName = snapshot.Ship_To_Customer_Name__c;
                //   wrapper.shipToProvince = snapshot.Ship_To_Province__c;
                //   wrapper.shipToCity = snapshot.Ship_To_City__c;
                //   wrapper.shipToAddressLine1 = snapshot.Ship_To_AddressLine1__c;
                //   wrapper.shipToAddressLine2 = snapshot.Ship_To_Address_Line_2__c;
                //   wrapper.shipToPostalCode = snapshot.Ship_To_Postal_Code__c;
                //   wrapper.shipToCountry = snapshot.Ship_To_Country__c;

                //   // Sales metrics from snapshot - all data comes from single source
                //   wrapper.id = snapshot.Id;
                //   wrapper.totalReagentSales = snapshot.Total_Reagent_Sales__c;
                //   wrapper.targetSales = snapshot.Target_Sales__c;
                //   wrapper.ytdSales = snapshot.YTD_Sales__c;
                //   wrapper.totalReagentSalesTillDate = snapshot.Total_Reagent_Sales_Till_Date__c;
                //   wrapper.marginOnReagentSale = snapshot.Margin_On_Reagent_Sale__c;
                //   wrapper.paybackRemaining = snapshot.Payback_Remaining__c;
                //   wrapper.machineCount = snapshot.Machine_Count__c;
                //   wrapper.perMachineSales = snapshot.Per_Machine_Sales__c;
                //   wrapper.contractMonthsElapsed = snapshot.Contract_Months_Elapsed__c;
                //   wrapper.avgReagentSalesPerMonth = snapshot.Avg_Reagent_Sales_Per_Month__c;
                //   wrapper.performanceStatus = snapshot.Performance_Status__c;
                //   wrapper.deficitCostCovered = snapshot.Deficit_Cost_Covered__c;
                //   wrapper.marginPercentSnapshot = snapshot.Margin_Percent_Snapshot__c;
                //   wrapper.dataQualityScore = snapshot.Data_Quality_Score__c;
                //   wrapper.snapshotMonth = snapshot.Snapshot_Month__c?.format();
                //   wrapper.formattedMonth = formatMonthLabel(snapshot.Snapshot_Month__c);
                //   //wrapper.investment = calculateInvestment(snapshot);
                //   wrapper.investment = snapshot.Business_Case__r.Total_Unit_Cost__c;

                //   // Formatted fields for display
                //   wrapper.formattedSales = formatCurrency(wrapper.totalReagentSales);
                //   wrapper.formattedTarget = formatCurrency(wrapper.targetSales);
                //   wrapper.formattedAchievement = formatPercent(
                //     calculateAchievementPercent(
                //       wrapper.totalReagentSales,
                //       wrapper.targetSales
                //     )
                //   );

                //   wrappers.add(wrapper);
                // }
                // System.debug(
                //     '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->wrappers size: ' +
                //     wrappers.size()
                // );
                
                System.debug(
                    '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->totalInvestment: ' +
                    totalInvestment
                );
                System.debug(
                    '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->wrappers: ' +
                    wrappers
                );
                //Unit_Cost__c  * if(isblank( Quantity__c ),0,value(Quantity__c))
                return wrappers;
            } 
            else 
            {
                // System.debug(
                //     '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->final children is null: '
                // );
                List<SnapshotWrapper> wrappers = new List<SnapshotWrapper>();
                // Process ALL snapshots to create wrapper objects for risk management

                Map<Id, Set<Date>> monthsPresentByBc = new Map<Id, Set<Date>>();

                for (Business_Case__c bcase : activeBusinessCasesObj) 
                {
                    System.debug('>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->bcase: '+bcase);
                    SnapshotWrapper wrapper = new SnapshotWrapper();
                    wrapper.businessCaseId = bcase.Id;
                    wrapper.businessCaseName = bcase.Name;
                    wrapper.businessCaseStatus = bcase.Status__c;
                    //   wrapper.marginTillDate = marginByBusinessCase.containsKey(bcase.Id)
                    //                         ? marginByBusinessCase.get(bcase.Id)
                    //                         : 0;
                    if (bcase.RecordType.Name == 'Master Business Case') {
                        wrapper.customerCode = bcase.Customer_Numbera__c;
                        wrapper.customerName = bcase.Customer_Namea__c;
                        wrapper.vendor = bcase.Vendor__c;
                        wrapper.technology = bcase.Technologyaa__c;
                        wrapper.region = bcase.Business_Cases__r[0].Region__c;
                        wrapper.materialNumber = bcase.Material_Number__c;
                        wrapper.materialDescription = bcase.Material_Descriptionsa__c;
                        wrapper.machineStatus = bcase.Business_Cases__r[0]
                            .Machine_Installation__r.Status__c;
                        wrapper.customerAddressLine1 = bcase.Business_Cases__r[0]
                            .Bill_To_Address_Line_1__c;
                        wrapper.customerAddressLine2 = bcase.Business_Cases__r[0]
                            .Bill_To_Address_Line_2__c;
                        wrapper.customerCity = bcase.Business_Cases__r[0]
                            .Bill_To_City__c;

                        wrapper.shipToCustomerNumber = bcase.Business_Cases__r[0]
                            .Ship_To_Customer_Number__c;
                        wrapper.shipToCustomerName = bcase.Business_Cases__r[0]
                            .Ship_To_Customer_Name__c;
                        wrapper.shipToProvince = bcase.Business_Cases__r[0]
                            .Ship_To_Province__c;
                        wrapper.shipToCity = bcase.Business_Cases__r[0]
                            .Ship_To_City__c;
                        wrapper.shipToAddressLine1 = bcase.Business_Cases__r[0]
                            .Ship_To_Address_Line_1__c;
                        wrapper.shipToAddressLine2 = bcase.Business_Cases__r[0]
                            .Ship_To_Address_Line_2__c;
                        wrapper.shipToPostalCode = bcase.Business_Cases__r[0]
                            .Ship_To_Postal_Code__c;
                        wrapper.monthCommitment = bcase.Sum_of_Monthly_Reagent_Commitment__c;
                        wrapper.investment = (bcase.Sum_of_Unit_Cost__c == null ? 0 : bcase.Sum_of_Unit_Cost__c);
                        totalInvestment += (bcase.Sum_of_Unit_Cost__c == null ? 0 : bcase.Sum_of_Unit_Cost__c);
                        if(bcase.Quantity__c != null && String.isNotBlank(bcase.Quantity__c) && String.isNotEmpty(bcase.Quantity__c))
                        {
                            wrapper.machineCount = Decimal.valueOf(bcase.Quantity__c) ;
                        }
                    } else {
                        wrapper.customerCode = bcase.Customer_Number__c;
                        wrapper.customerName = bcase.Customer_Name__c;
                        wrapper.vendor = bcase.Machine_Installation__r.Diagnostic_Machine__r.Vendor__c;
                        wrapper.technology = bcase.Machine_Installation__r.Diagnostic_Machine__r.Technology__c;
                        wrapper.region = bcase.Region__c;
                        wrapper.materialNumber = bcase.Machine_Installation__r.Material_Number__c;
                        wrapper.materialDescription = bcase.Machine_Installation__r.Material_Description__c;
                        wrapper.machineStatus = bcase.Machine_Installation__r.Status__c;
                        wrapper.customerAddressLine1 = bcase.Bill_To_Address_Line_1__c;
                        wrapper.customerAddressLine2 = bcase.Bill_To_Address_Line_2__c;
                        wrapper.customerCity = bcase.Bill_To_City__c;

                        wrapper.shipToCustomerNumber = bcase.Ship_To_Customer_Number__c;
                        wrapper.shipToCustomerName = bcase.Ship_To_Customer_Name__c;
                        wrapper.shipToProvince = bcase.Ship_To_Province__c;
                        wrapper.shipToCity = bcase.Ship_To_City__c;
                        wrapper.shipToAddressLine1 = bcase.Ship_To_Address_Line_1__c;
                        wrapper.shipToAddressLine2 = bcase.Ship_To_Address_Line_2__c;
                        wrapper.shipToPostalCode = bcase.Ship_To_Postal_Code__c;
                        wrapper.monthCommitment = bcase.Monthly_Reagent_Commitment__c;
                        wrapper.investment = (bcase.Unit_Cost__c == null ? 0 : bcase.Unit_Cost__c);
                        totalInvestment += (bcase.Unit_Cost__c == null ? 0 : bcase.Unit_Cost__c);
                        if(bcase.Quantity__c != null && String.isNotBlank(bcase.Quantity__c) && String.isNotEmpty(bcase.Quantity__c))
                        {
                            wrapper.machineCount = Decimal.valueOf(bcase.Quantity__c) ;
                        }
                        
                    }
                    // wrapper.shipToCountry = case.Ship_To_Country__c;

                    wrapper.riskStatus = deriveRiskStatusFromLatestMonthsBulk(
                        bcase.Id,
                        null,
                        bcase,
                        monthsPresentByBc
                    );
                    if (bcase.RecordType.Name == 'Master Business Case') {
                        if (
                            bcase.Sum_of_Monthly_Reagent_Commitment__c != null
                        ) {
                            if (
                                bcase.Sum_of_Monthly_Reagent_Commitment__c > 0
                            ) {
                                wrapper.performanceStatus = 'Behind';
                            } else {
                                wrapper.performanceStatus = 'No Target Set';
                            }
                        } else {
                            wrapper.performanceStatus = 'No Target Set';
                        }
                    } else {
                        if (bcase.Monthly_Reagent_Commitment__c != null) {
                            if (bcase.Monthly_Reagent_Commitment__c > 0) {
                                wrapper.performanceStatus = 'Behind';
                            } else {
                                wrapper.performanceStatus = 'No Target Set';
                            }
                        } else {
                            wrapper.performanceStatus = 'No Target Set';
                        }
                    }
                    
                    Map<Date, Decimal> monthMap = new Map<Date, Decimal>();
                    for (Date m : lastSixMonths) {
                        monthMap.put(m, 0);
                    }
                    salesByMonth.put(bcase.Id, monthMap);

                    wrappers.add(wrapper);
                }

                for(Business_Case_Sales_Snapshot__c snap : [
                    SELECT Id, Business_Case__c, Snapshot_Month__c, Total_Reagent_Sales__c
                    FROM Business_Case_Sales_Snapshot__c
                    WHERE Business_Case__c IN :wrapperCases
                    AND Snapshot_Month__c IN :lastSixMonths
                ])
                {
                    if(!salesbyMonth.containsKey(snap.Business_Case__c))
                    {
                        salesbyMonth.put(snap.Business_Case__c, new Map<Date,Decimal>());

                    }
                    salesbyMonth.get(snap.Business_Case__c).put(snap.Snapshot_Month__c, snap.Total_Reagent_Sales__c);
                }

                for(SnapshotWrapper wr : wrappers)
                {
                    Map<String, Decimal> mSales = new Map<String, Decimal>();

                    for (Date m : lastSixMonths) 
                    {
                        Datetime newm = Datetime.newInstance(m, Time.newInstance(0, 0, 0, 0));
                        String label = newm.format('MMM yyyy').replace(' ', '_'); 
                        Decimal value = salesbyMonth.containsKey(wr.businessCaseId)
                            ? salesbyMonth.get(wr.businessCaseId).get(m)
                            : 0;
                        mSales.put(label, value);
                    }

                    wr.monthlySales = mSales;
                    System.debug('>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->wr.monthlySales: '+wr.monthlySales);
                }

                // System.debug(
                //     '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->wrappers size: ' +
                //     wrappers.size()
                // );
                // totalInvestment += bcase.Unit_Cost__c;
                // System.debug(
                //     '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->wrappers: ' +
                //     wrappers
                // );
                System.debug(
                    '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->totalInvestment: ' +
                    totalInvestment
                );
                //Unit_Cost__c  * if(isblank( Quantity__c ),0,value(Quantity__c))
                return wrappers;
            }

            //return null;
        } catch (Exception e) 
        {
            System.debug('>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->Exception: '+e.getMessage()+' | StackTrace: '+e.getStackTraceString()+' | '+e);
            return null;
        }
    }

    public static String deriveRiskStatusFromLatestMonthsBulk(
        Id businessCaseId,
        Date snapshotMonthIfKnown,
        Business_Case__c bc,
        Map<Id, Set<Date>> monthsPresentByBc
    ) {
        System.debug('>>>>BusinessCaseDashboardController-->deriveRiskStatusFromLatestMonthsBulk-->businessCaseId: '+businessCaseId);
        // Build month anchors: reference lastMonth as previous calendar month from today
        Date today = Date.today();
        Date firstOfThisMonth = Date.newInstance(
            today.year(),
            today.month(),
            1
        );
        Date lastMonth = firstOfThisMonth.addMonths(-1);
        Date m0 = Date.newInstance(lastMonth.year(), lastMonth.month(), 1); // last month
        Date m1 = m0.addMonths(-1);
        Date m2 = m1.addMonths(-1);
        Date m3 = m2.addMonths(-1);
        Date m4 = m3.addMonths(-1);

        //Business_Case__c bc = bcById != null ? bcById.get(businessCaseId) : null;
        Set<Date> monthsPresent;
        if (monthsPresentByBc == null) {
            monthsPresent = new Set<Date>(); // no entry for this BC
        } else {
            monthsPresent = monthsPresentByBc.get(businessCaseId);
            if (monthsPresent == null) {
                monthsPresent = new Set<Date>(); // no entry for this BC
            }
        }

        // If we know the selected latest snapshot month and it is >= last month, classify quickly
        if (snapshotMonthIfKnown != null) {
            Date norm = Date.newInstance(
                snapshotMonthIfKnown.year(),
                snapshotMonthIfKnown.month(),
                1
            );
            System.debug('>>>>BusinessCaseDashboardController-->deriveRiskStatusFromLatestMonthsBulk-->norm: '+norm);
           
            if (norm == m0)
                return 'Healthy';
            if (norm == m1)
                return 'Warning';
            if (norm == m2 || norm == m3)
                return 'High Risk';
            return 'Critical';
        }

        // No explicit latest snapshot provided; evaluate from the set we fetched
        if (monthsPresent.isEmpty()) {
            // Agreement date nuance: if Agreement_Date__c falls in previous month, treat as Warning
            if (bc != null && bc.Agreement_Date__c != null) {
                Date agree = bc.Agreement_Date__c;
                Date agreeNorm = Date.newInstance(
                    agree.year(),
                    agree.month(),
                    1
                );
                System.debug('>>>>BusinessCaseDashboardController-->deriveRiskStatusFromLatestMonthsBulk-->agreeNorm: '+agreeNorm);
                if (agreeNorm == m0) {
                    return 'Warning';
                }
            }
            System.debug('>>>>BusinessCaseDashboardController-->deriveRiskStatusFromLatestMonthsBulk-->monthsPresent empty');
            return 'Critical';
        }

        // Count gap from last month going backwards until a month has data
        Integer missing = 0;
        List<Date> anchors = new List<Date>{ m0, m1, m2, m3, m4 };
        for (Date d : anchors) {
            if (!monthsPresent.contains(d)) {
                missing++;
            } else {
                break;
            }
        }
        System.debug('>>>>BusinessCaseDashboardController-->deriveRiskStatusFromLatestMonthsBulk-->missing:'+missing);
        if (missing == 0)
            return 'Healthy';
        if (missing == 1)
            return 'Warning';
        if (missing == 2 || missing == 3)
            return 'High Risk';
        return 'Critical';
    }

     @AuraEnabled(cacheable=true)
    public static List<DetailedSnapshotWrapper> GetDetailedSnapshotDataUpdated(
        String DateFrom,
        String DateTo,
        String Region,
        String Supplier,
        String BusinessCaseStatus,
        String MachineStatus,
        String CommitmentStatus,
        String RiskStatus,
        String SearchCustomer,
        String BusinessCaseName
    ) 
    {
        try 
        {
            String whereBCClause = '';
            String whereBCSClause = '';
            String whereMasterClause = '';
            if (String.isBlank(wheremasterClause)) {
                wheremasterClause = ' WHERE Is_Master__c = true';
            } else {
                wheremasterClause += ' AND Is_Master__c = true';
            }

            // Date From Filter - Filter snapshots from a specific date onwards
            if (!String.isBlank(DateFrom)) {
                Date parsedDateFrom = Date.valueOf(DateFrom);
                String formattedDateFrom =
                    parsedDateFrom.year() +
                    '-' +
                    String.valueOf(parsedDateFrom.month()).leftPad(2, '0') +
                    '-' +
                    String.valueOf(parsedDateFrom.day()).leftPad(2, '0');

                if (String.isBlank(whereBCSClause)) {
                    whereBCSClause =
                        ' WHERE Snapshot_Month__c >= ' + formattedDateFrom;
                } else {
                    whereBCSClause +=
                        ' AND Snapshot_Month__c >= ' + formattedDateFrom;
                }

                System.debug(
                    'Date From filter applied: Snapshot_Month__c >= ' +
                    formattedDateFrom
                );
            }

            // Date To Filter - Filter snapshots up to a specific date
            if (!String.isBlank(DateTo)) {
                Date parsedDateTo = Date.valueOf(DateTo);
                String formattedDateTo =
                    parsedDateTo.year() +
                    '-' +
                    String.valueOf(parsedDateTo.month()).leftPad(2, '0') +
                    '-' +
                    String.valueOf(parsedDateTo.day()).leftPad(2, '0');

                if (String.isBlank(whereBCSClause)) {
                    whereBCSClause =
                        ' AND Snapshot_Month__c <= ' + formattedDateTo;
                } else {
                    whereBCSClause +=
                        ' AND Snapshot_Month__c <= ' + formattedDateTo;
                }

                System.debug(
                    'Date To filter applied: Snapshot_Month__c <= ' +
                    formattedDateTo
                );
            }

            if (!String.isBlank(Region) && Region != 'All Regions') {
                if (String.isBlank(whereBCClause)) {
                    whereBCClause = ' WHERE Region__c = \'' + Region + '\'';
                } else {
                    whereBCClause += ' AND Region__c = \'' + Region + '\'';
                }
            }
            if (
                !String.isBlank(SearchCustomer) &&
                SearchCustomer != 'All Customers'
            ) {
                String scustomer = '';
                if (SearchCustomer.contains(' - ')) {
                    scustomer = SearchCustomer.split(' - ')[0];
                    scustomer = scustomer.trim();
                }
                if (String.isBlank(whereBCClause)) {
                    whereBCClause =
                        ' WHERE Customer_Number__c = \'' +
                        SearchCustomer +
                        '\'';
                } else {
                    whereBCClause +=
                        ' AND Customer_Number__c = \'' +
                        SearchCustomer +
                        '\'';
                }

                if (String.isBlank(wheremasterClause)) {
                    wheremasterClause =
                        ' WHERE Customer_Numbera__c = \'' +
                        SearchCustomer +
                        '\'';
                } else {
                    wheremasterClause +=
                        ' AND Customer_Numbera__c = \'' +
                        SearchCustomer +
                        '\'';
                }
            }
            if (
                !String.isBlank(BusinessCaseStatus) &&
                BusinessCaseStatus != 'All Business Case Statuses'
            ) {
                String sbusinesscasestatus = '';
                // System.debug(
                //     '>>>>BusinessCaseDashboardController-->GetDetailedSnapshotDataUpdated-->BusinessCaseStatus: ' +
                //     BusinessCaseStatus
                // );
                sbusinesscasestatus = BusinessCaseStatus.trim();

                if (String.isBlank(whereBCClause)) {
                    whereBCClause =
                        ' WHERE Status__c  = \'' +
                        sbusinesscasestatus +
                        '\' ';
                } else {
                    whereBCClause +=
                        ' AND Status__c  = \'' +
                        sbusinesscasestatus +
                        '\'';
                }
                if (String.isBlank(wheremasterClause)) {
                    wheremasterClause =
                        ' WHERE Status__c  = \'' +
                        sbusinesscasestatus +
                        '\' ';
                } else {
                    wheremasterClause +=
                        ' AND Status__c  = \'' +
                        sbusinesscasestatus +
                        '\'';
                }
            } else {
                if (String.isBlank(whereBCClause)) {
                    whereBCClause = ' WHERE (Status__c  LIKE \'%Active%\' OR Status__c LIKE \'%Revised%\' OR Status__c LIKE \'%New%\' ) ';
                } else {
                    whereBCClause += ' AND (Status__c  LIKE \'%Active%\' OR Status__c LIKE \'%Revised%\' OR Status__c LIKE \'%New%\')';
                }
                if (String.isBlank(wheremasterClause)) {
                    wheremasterClause = ' WHERE (Status__c  LIKE \'%Active%\' OR Status__c LIKE \'%Revised%\' OR Status__c LIKE \'%New%\' )';
                } else {
                    wheremasterClause += ' AND (Status__c  LIKE \'%Active%\' OR Status__c LIKE \'%Revised%\' OR Status__c LIKE \'%New%\')';
                }
            }

            if (
                !String.isBlank(CommitmentStatus) &&
                CommitmentStatus != 'All Commitment Statuses'
            ) {
                String scommitmenttatus = '';
                scommitmenttatus = CommitmentStatus.trim();

                whereBCSClause +=
                    ' AND Performance_Status__c  = \'' +
                    scommitmenttatus +
                    '\'';
            }

            if (!String.isBlank(Supplier) && Supplier != 'All Suppliers') {
                String ssupplier = '';
                if (Supplier.contains(' - ')) {
                    ssupplier = Supplier.split(' - ')[0];
                    ssupplier = ssupplier.trim();
                }

                whereBCSClause += ' AND Vendor__c  = \'' + Supplier + '\'';
            }

            if (
                !String.isBlank(BusinessCaseName) &&
                BusinessCaseName != 'All Business Cases'
            ) {
                String sbcname = '';
                sbcname = BusinessCaseName.trim();

                if (String.isBlank(whereBCClause)) {
                    whereBCClause = ' WHERE Name  = \'' + sbcname + '\'';
                } else {
                    whereBCClause += ' AND Name  = \'' + sbcname + '\'';
                }

                if (String.isBlank(wheremasterClause)) {
                    wheremasterClause =
                        ' WHERE Name = \'' +
                        SearchCustomer +
                        '\'';
                } else {
                    wheremasterClause +=
                        ' AND Name = \'' +
                        SearchCustomer +
                        '\'';
                }
            }

            if (String.isBlank(whereBCClause)) {
                whereBCClause = ' WHERE  Is_Master__c = false and Master_Business_Case__c = null';
            } else {
                whereBCClause += ' AND  Is_Master__c = false and Master_Business_Case__c = null';
            }

            // Note: whereBCSClause should NOT filter by Is_Master__c because it's used for both
            // regular business case snapshots AND master business case snapshots
            // The Business_Case__c queries above already handle the Master filtering

            if (
                !String.isBlank(MachineStatus) &&
                MachineStatus != 'All Machine Statuses'
            ) {
                String smachinestatus = '';
                smachinestatus = MachineStatus.trim();

                if (String.isBlank(whereBCClause)) {
                    whereBCClause =
                        ' WHERE Machine_Installation__r.Status__c  = \'' +
                        smachinestatus +
                        '\'';
                } else {
                    whereBCClause +=
                        ' AND Machine_Installation__r.Status__c  = \'' +
                        smachinestatus +
                        '\'';
                }
            }

            String bcquery = 'SELECT Id,Name,Status__c,Customer_Number__c,Customer_Name__c,Machine_Installation__r.SAP_Account_No_Ship_To__c,Machine_Installation__r.SAP_Account_No_Bill_To__c';
            bcquery += ',Machine_Installation__r.Diagnostic_Machine__r.Vendor__c,Machine_Installation__r.Diagnostic_Machine__r.Technology__c,Region__c,';
            bcquery += 'Machine_Installation__r.Material_Number__c,Machine_Installation__r.Material_Description__c,Machine_Installation__r.Status__c,';
            bcquery += 'Bill_To_Address_Line_1__c,Bill_To_Address_Line_2__c,Bill_To_City__c,Ship_To_Address_Line_1__c,Ship_To_Address_Line_2__c,Ship_To_City__c,Ship_To_Postal_Code__c,Ship_To_Province__c,Ship_To_Customer_Name__c,Unit_Cost__c,Total_Unit_Cost__c';
            bcquery +=
                ',Ship_To_Customer_Number__c,Monthly_Reagent_Commitment__c,Agreement_Date__c,RecordType.Name  FROM Business_Case__c ' +
                whereBCClause;

            // System.debug(
            //     '>>>>BusinessCaseDashboardController-->GetDetailedSnapshotDataUpdated-->whereBCClause: ' +
            //     whereBCClause
            // );
            // System.debug(
            //     '>>>>BusinessCaseDashboardController-->GetDetailedSnapshotDataUpdated-->bcquery: ' +
            //     bcquery
            // );

            List<Id> activeBusinessCases = new List<Id>();
            List<Business_Case__c> activeBusinessCasesObj = new List<Business_Case__c>();
            for (Business_Case__c bc : Database.query(bcquery)) {
                activeBusinessCases.add(bc.Id);
                activeBusinessCasesObj.add(bc);
            }

            // System.debug(
            //     '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->activeBusinessCases: ' +
            //     activeBusinessCases.size()
            // );

            String bcmasterquery = 'SELECT Id,Name,Status__c,Customer_Number__c,Customer_Name__c,Machine_Installation__r.SAP_Account_No_Ship_To__c,Machine_Installation__r.SAP_Account_No_Bill_To__c';
            bcmasterquery += ',Machine_Installation__r.Diagnostic_Machine__r.Vendor__c,Machine_Installation__r.Diagnostic_Machine__r.Technology__c,Region__c,';
            bcmasterquery += 'Machine_Installation__r.Material_Number__c,Machine_Installation__r.Material_Description__c,Machine_Installation__r.Status__c,';
            bcmasterquery += 'Bill_To_Address_Line_1__c,Bill_To_Address_Line_2__c,Bill_To_City__c,Ship_To_Address_Line_1__c,Ship_To_Address_Line_2__c,Ship_To_City__c,Ship_To_Postal_Code__c,Ship_To_Province__c,Ship_To_Customer_Name__c,Unit_Cost__c,Total_Unit_Cost__c';
            bcmasterquery += ',Ship_To_Customer_Number__c,Monthly_Reagent_Commitment__c,Agreement_Date__c,Customer_Numbera__c,Customer_Namea__c,Sum_of_Monthly_Reagent_Commitment__c,Material_Number__c,Material_Descriptionsa__c,Sum_of_Unit_Cost__c,RecordType.Name   ';
            // bcmasterquery += ' ,Bill_To_Address_Line_1__c,Bill_To_Address_Line_2__c,Bill_To_City__c,Ship_To_Address_Line_1__c,Ship_To_Address_Line_2__c,Ship_To_City__c,Ship_To_Postal_Code__c,Ship_To_Province__c,Ship_To_Customer_Name__c';
            bcmasterquery += ',(SELECT  Id,Name,Status__c,Account__c,Account__r.Province__c,Account__r.City__c,Account__r.AddressLine_1__c,Account__r.Addess_Line_2__c,Account__r.Postal_Code__c,Account__r.Country_Code__c,Customer_Number__c,';
            bcmasterquery += ' Customer_Name__c,Supplier_Name__c,Technology__c,Region__c,SAP_Material_Number__c,Machine_Type__c,Quantity__c,Monthly_Reagent_Commitment__c,Unit_Cost__c,Margin_Percent__c,Agreement_Date__c,Asset_Number__c,';
            bcmasterquery += ' Asset_Number__r.Status__c,Machine_Installation__r.Ship_To_Account__c,Machine_Installation__r.Ship_To_Account__r.SAP_Customer_Number__c,Machine_Installation__r.Ship_To_Account__r.Name,Machine_Installation__r.Ship_To_Account__r.Province__c,';
            bcmasterquery += ' Machine_Installation__r.Ship_To_Account__r.City__c,Machine_Installation__r.Ship_To_Account__r.AddressLine_1__c,Machine_Installation__r.Ship_To_Account__r.Addess_Line_2__c,Machine_Installation__r.Ship_To_Account__r.Postal_Code__c,';
            bcmasterquery += ' Machine_Installation__r.Ship_To_Account__r.Country_Code__c,Machine_Installation__r.Diagnostic_Machine__r.Vendor__c,Machine_Installation__r.Diagnostic_Machine__r.Technology__c,Ship_To_Customer_Number__c,';
            bcmasterquery += ' Ship_To_Customer_Name__c,Machine_Installation__r.SAP_Account_No_Bill_To__c,Machine_Installation__r.bill_to_account__r.Name,Machine_Installation__r.Material_Number__c,Machine_Installation__r.Status__c,Machine_Installation__r.bill_to_account__r.Province__c,Machine_Installation__r.bill_to_account__r.City__c,';
            bcmasterquery += ' Machine_Installation__r.bill_to_account__r.AddressLine_1__c,Machine_Installation__r.bill_to_account__r.Postal_Code__c,Machine_Installation__r.bill_to_account__r.Country_Code__c,  ';
            bcmasterquery += ' Bill_To_Address_Line_1__c,Bill_To_Address_Line_2__c,Bill_To_City__c,Ship_To_Address_Line_1__c,Ship_To_Address_Line_2__c,Ship_To_City__c,Ship_To_Postal_Code__c,Ship_To_Province__c';
            bcmasterquery += ' FROM Business_Cases__r WHERE RecordType.Name = \'Individual Business Case\' and (Status__c like \'%Active%\' or Status__c like \'%Revised%\' or Status__c like \'%New%\') LIMIT 1 )';
            bcmasterquery += ' FROM Business_Case__c ' + whereMasterClause;

            // System.debug(
            //     '>>>>BusinessCaseDashboardController-->GetDetailedSnapshotDataUpdated-->whereMasterClause: ' +
            //     whereMasterClause
            // );
            // System.debug(
            //     '>>>>BusinessCaseDashboardController-->GetDetailedSnapshotDataUpdated-->bcmasterquery: ' +
            //     bcmasterquery
            // );

            for (Business_Case__c bc : Database.query(bcmasterquery)) {
                activeBusinessCases.add(bc.Id);
                activeBusinessCasesObj.add(bc);
            }

            // System.debug(
            //     '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->activebusinesscases: ' +
            //     activeBusinessCases.size()
            // );

            Map<Id, DateTime> parentToLatestChild = new Map<Id, DateTime>();

            for (AggregateResult ar : [
                SELECT
                    Business_Case__c parentId,
                    MAX(LastModifiedDate) latestDate
                FROM Business_Case_Sales_Snapshot__c
                WHERE Business_Case__c IN :activeBusinessCases
                GROUP BY Business_Case__c
            ]) {
                parentToLatestChild.put(
                    (Id) ar.get('parentId'),
                    (DateTime) ar.get('latestDate')
                );
            }

            // System.debug(
            //     '>>>>BusinessCaseDashboardController-->GetDetailedSnapshotDataUpdated-->parent child keySet: ' +
            //     parentToLatestChild.keySet()
            // );
            // System.debug(
            //     '>>>>BusinessCaseDashboardController-->GetDetailedSnapshotDataUpdated-->whereBCSClause: ' +
            //     whereBCSClause
            // );

            List<String> idList = new List<String>();
            for (Id value : activeBusinessCases) {
                idList.add(String.valueOf(value));
            }

            String idListStr =
                '(' +
                '\'' +
                String.join(idList, '\',\'') +
                '\'' +
                ')';

            String bscquery = 'Select Id, Business_Case__c,Business_Case_Name__c,Business_Case_Status__c,Machine_Status__c,';
            bscquery += ' Customer_Code__c,Customer_Name__c,Vendor__c,Technology__c,Region__c,Material_Number__c,Material_Description__c,Customer_Province__c,';
            bscquery += ' Customer_City__c,Customer_AddressLine1__c,Customer_AddressLine2__c,Customer_Postal_Code__c,Customer_Country__c,Ship_To_Customer_Number__c,';
            bscquery += ' Ship_To_Customer_Name__c,Ship_To_Province__c,Ship_To_City__c,Ship_To_AddressLine1__c,Ship_To_Address_Line_2__c,';
            bscquery += ' Ship_To_Postal_Code__c,Ship_To_Country__c,Snapshot_Month__c,Total_Reagent_Sales__c,Target_Sales__c,';
            bscquery += ' Machine_Count__c,Per_Machine_Sales__c,Source_Invoice_Count__c,YTD_Sales__c,Total_Reagent_Sales_Till_Date__c,';
            bscquery += ' Contract_Months_Elapsed__c,Avg_Reagent_Sales_Per_Month__c,Performance_Status__c,Deficit_Cost_Covered__c,Margin_Percent_Snapshot__c,';
            bscquery += ' Margin_On_Reagent_Sale__c,Payback_Remaining__c,Data_Quality_Score__c,Processing_Status__c,Snapshot_Created_Date__c,';
            bscquery += ' Monthly_Commitments__c,Business_Case__r.Unit_Cost__c,LastModifiedDate,Avg_YTD_Sales_Per_Month__c   ';
            bscquery += '  FROM Business_Case_Sales_Snapshot__c ';
            bscquery +=
                ' WHERE Business_Case__c IN ' +
                idListStr +
                '  ' +
                whereBCSClause +
                ' and Processing_Status__c = \'Completed\' ';
            bscquery += ' ORDER BY Snapshot_Month__c DESC, Snapshot_Created_Date__c DESC ';

            // System.debug(
            //     '>>>>BusinessCaseDashboardController-->GetDetailedSnapshotDataUpdated-->bscquery: ' +
            //     bscquery
            // );

            List<Business_Case_Sales_Snapshot__c> finalChildren = new List<Business_Case_Sales_Snapshot__c>();

            finalChildren = Database.query(bscquery);
            System.debug(
                '🔍 GetDetailedSnapshotDataUpdated - Query returned ' +
                    finalChildren.size() +
                    ' snapshots'
            );
            System.debug(
                '🔍 GetDetailedSnapshotDataUpdated - whereBCSClause: ' +
                whereBCSClause
            );

            

            // System.debug(
            //     '>>>>BusinessCaseDashboardController-->GetDetailedSnapshotDataUpdated-->latestchildren size: ' +
            //     latestChildren.size()
            // );

            Map<Id,Business_Case__c> activeBusinessCasesMap = new Map<Id,Business_Case__c>(activeBusinessCasesObj);

            if (finalChildren.size() > 0) {
                // System.debug(
                //     '>>>>BusinessCaseDashboardController-->GetDetailedSnapshotDataUpdated-->final children size: ' +
                //     finalChildren.size()
                // );
                // System.debug(
                //     '>>>>BusinessCaseDashboardController-->GetDetailedSnapshotDataUpdated-->final children : ' +
                //     finalChildren
                // );
                
                List<DetailedSnapshotWrapper> wrappers = new List<DetailedSnapshotWrapper>();
                // Process ALL snapshots to create wrapper objects for risk management
                Date today = Date.today();
                Date firstOfThisMonth = Date.newInstance(
                    today.year(),
                    today.month(),
                    1
                );
                Date lastMonth = firstOfThisMonth.addMonths(-1);
                // Date lastMonth = firstOfThisMonth;
                Date m0 = Date.newInstance(
                    lastMonth.year(),
                    lastMonth.month(),
                    1
                ); // last month
                Date m1 = m0.addMonths(-1); // last month - 1
                Date m2 = m1.addMonths(-1);
                Date m3 = m2.addMonths(-1);
                Date m4 = m3.addMonths(-1);

                for (Business_Case_Sales_Snapshot__c snapshot : finalChildren) {
                    DetailedSnapshotWrapper wrapper = new DetailedSnapshotWrapper();
                    Business_Case__c bcase = activeBusinessCasesMap.get(snapshot.Business_Case__c);
                    wrapper.businessCaseId = bcase.Id;
                    wrapper.businessCaseName = bcase.Name;
                    // wrapper.businessCaseStatus = bcase.Status__c;
                    if (bcase.RecordType.Name == 'Master Business Case') {
                        wrapper.customerCode = bcase.Customer_Numbera__c;
                        wrapper.customerName = bcase.Customer_Namea__c;
                        wrapper.supplier = bcase.Business_Cases__r[0]
                            .Machine_Installation__r.Diagnostic_Machine__r.Vendor__c;
                        wrapper.technology = bcase.Business_Cases__r[0]
                            .Machine_Installation__r.Diagnostic_Machine__r.Technology__c;
                        wrapper.region = bcase.Business_Cases__r[0].Region__c;
                        wrapper.materialNumber = bcase.Material_Number__c;
                        wrapper.materialDescription = bcase.Material_Descriptionsa__c;
                        wrapper.monthlyCommitment = bcase.Sum_of_Monthly_Reagent_Commitment__c;
                        
                    } else {
                        wrapper.customerCode = bcase.Customer_Number__c;
                        wrapper.customerName = bcase.Customer_Name__c;
                        wrapper.supplier = bcase.Machine_Installation__r.Diagnostic_Machine__r.Vendor__c;
                        wrapper.technology = bcase.Machine_Installation__r.Diagnostic_Machine__r.Technology__c;
                        wrapper.region = bcase.Region__c;
                        wrapper.materialNumber = bcase.Machine_Installation__r.Material_Number__c;
                        wrapper.materialDescription = bcase.Machine_Installation__r.Material_Description__c;
                        wrapper.monthlyCommitment = bcase.Monthly_Reagent_Commitment__c;
                       
                    }

                    wrapper.month = formatMonthLabel(snapshot.Snapshot_Month__c) ;
                    wrapper.totalReagentSales = snapshot.Total_Reagent_Sales__c;
                    wrapper.ytdSales = snapshot.YTD_Sales__c;
                    wrapper.avgYtdSales = snapshot.Avg_YTD_Sales_Per_Month__c;
                    wrapper.marginOnSales = snapshot.Margin_On_Reagent_Sale__c;
                    

                    wrappers.add(wrapper);
                }

                System.debug(
                    '>>>>BusinessCaseDashboardController-->GetDetailedSnapshotDataUpdated-->wrappers size: ' +
                    wrappers.size()
                );
                System.debug(
                    '>>>>BusinessCaseDashboardController-->GetDetailedSnapshotDataUpdated-->wrappers: ' +
                    wrappers
                );
                return wrappers;
            } else {
                // System.debug(
                //     '>>>>BusinessCaseDashboardController-->GetSnapshotDataUpdated-->final children is null: '
                // );
                List<DetailedSnapshotWrapper> wrappers = new List<DetailedSnapshotWrapper>();
                // Process ALL snapshots to create wrapper objects for risk management

                Map<Id, Set<Date>> monthsPresentByBc = new Map<Id, Set<Date>>();

                for (Business_Case_Sales_Snapshot__c snapshot : finalChildren) {
                    DetailedSnapshotWrapper wrapper = new DetailedSnapshotWrapper();
                    Business_Case__c bcase = activeBusinessCasesMap.get(snapshot.Business_Case__c);
                    wrapper.businessCaseId = bcase.Id;
                    wrapper.businessCaseName = bcase.Name;
                    // wrapper.businessCaseStatus = bcase.Status__c;
                    if (bcase.RecordType.Name == 'Master Business Case') {
                        wrapper.customerCode = bcase.Customer_Numbera__c;
                        wrapper.customerName = bcase.Customer_Namea__c;
                        wrapper.supplier = bcase.Business_Cases__r[0]
                            .Machine_Installation__r.Diagnostic_Machine__r.Vendor__c;
                        wrapper.technology = bcase.Business_Cases__r[0]
                            .Machine_Installation__r.Diagnostic_Machine__r.Technology__c;
                        wrapper.region = bcase.Business_Cases__r[0].Region__c;
                        wrapper.materialNumber = bcase.Material_Number__c;
                        wrapper.materialDescription = bcase.Material_Descriptionsa__c;
                        
                        wrapper.monthlyCommitment = bcase.Sum_of_Monthly_Reagent_Commitment__c;
                        
                    } else {
                        wrapper.customerCode = bcase.Customer_Number__c;
                        wrapper.customerName = bcase.Customer_Name__c;
                        wrapper.supplier = bcase.Machine_Installation__r.Diagnostic_Machine__r.Vendor__c;
                        wrapper.technology = bcase.Machine_Installation__r.Diagnostic_Machine__r.Technology__c;
                        wrapper.region = bcase.Region__c;
                        wrapper.materialNumber = bcase.Machine_Installation__r.Material_Number__c;
                        wrapper.materialDescription = bcase.Machine_Installation__r.Material_Description__c;
                        
                        wrapper.monthlyCommitment = bcase.Monthly_Reagent_Commitment__c;
                        
                    }
                    // wrapper.shipToCountry = case.Ship_To_Country__c;

                    wrappers.add(wrapper);
                }

                System.debug(
                    '>>>>BusinessCaseDashboardController-->GetDetailedSnapshotDataUpdated-->wrappers size: ' +
                    wrappers.size()
                );
                System.debug(
                    '>>>>BusinessCaseDashboardController-->GetDetailedSnapshotDataUpdated-->wrappers: ' +
                    wrappers
                );
                //Unit_Cost__c  * if(isblank( Quantity__c ),0,value(Quantity__c))
                return wrappers;
            }

            //return null;
        } catch (Exception e) 
        {
            return null;
        }
    }

    // ===== WRAPPER CLASSES =====

    public class DetailedSnapshotWrapper
    {
        @AuraEnabled
        public String customerName{get;set;    }
        @AuraEnabled
        public String customerCode{get;set;    }
        @AuraEnabled
        public String businessCaseId{get;set;    }
        @AuraEnabled
        public String businessCaseName{get;set;    }
        @AuraEnabled
        public String region{get;set;    }
        @AuraEnabled
        public String supplier{get;set;    }
        @AuraEnabled
        public String technology{get;set;    }
        @AuraEnabled
        public String month{get;set;    }
        @AuraEnabled
        public Decimal totalReagentSales{get;set;    }
        @AuraEnabled
        public Decimal monthlyCommitment{get;set;    }
        @AuraEnabled
        public Decimal ytdSales{get;set;    }
        @AuraEnabled
        public Decimal avgYtdSales{get;set;    }
        @AuraEnabled
        public String materialNumber{get;set;    }
        @AuraEnabled
        public String materialDescription{get;set;    }
        @AuraEnabled
        public Decimal marginOnSales{get;set;}
        
    }

    public class SnapshotWrapper {
        @AuraEnabled
        public String id { get; set; }
        @AuraEnabled
        public String riskStatus { get; set; }
        @AuraEnabled
        public String businessCaseId { get; set; }
        @AuraEnabled
        public String businessCaseName { get; set; }
        @AuraEnabled
        public String customerCode { get; set; }
        @AuraEnabled
        public String customerName { get; set; }
        @AuraEnabled
        public String vendor { get; set; }
        @AuraEnabled
        public String technology { get; set; }
        @AuraEnabled
        public String region { get; set; }
        @AuraEnabled
        public String materialNumber { get; set; }
        @AuraEnabled
        public String materialDescription { get; set; }
        @AuraEnabled
        public String machineStatus { get; set; }
        @AuraEnabled
        public String businessCaseStatus { get; set; }

        // Customer Address Information
        @AuraEnabled
        public String customerProvince { get; set; }
        @AuraEnabled
        public String customerCity { get; set; }
        @AuraEnabled
        public String customerAddressLine1 { get; set; }
        @AuraEnabled
        public String customerAddressLine2 { get; set; }
        @AuraEnabled
        public String customerPostalCode { get; set; }
        @AuraEnabled
        public String customerCountry { get; set; }

        // Ship To Account Information
        @AuraEnabled
        public String shipToCustomerNumber { get; set; }
        @AuraEnabled
        public String shipToCustomerName { get; set; }
        @AuraEnabled
        public String shipToProvince { get; set; }
        @AuraEnabled
        public String shipToCity { get; set; }
        @AuraEnabled
        public String shipToAddressLine1 { get; set; }
        @AuraEnabled
        public String shipToAddressLine2 { get; set; }
        @AuraEnabled
        public String shipToPostalCode { get; set; }
        @AuraEnabled
        public String shipToCountry { get; set; }

        // Financial Metrics
        @AuraEnabled
        public Decimal totalReagentSales { get; set; }
        @AuraEnabled
        public Decimal targetSales { get; set; }
        @AuraEnabled
        public Decimal ytdSales { get; set; }
        @AuraEnabled
        public Decimal avgYtdSales{get;set;}
        @AuraEnabled
        public Decimal totalReagentSalesTillDate { get; set; }
        @AuraEnabled
        public Decimal marginOnReagentSale { get; set; }
        @AuraEnabled
        public Decimal paybackRemaining { get; set; }
        @AuraEnabled
        public Decimal investment { get; set; }
        @AuraEnabled
        public Decimal monthCommitment { get; set; }
        // Performance Metrics
        @AuraEnabled
        public Decimal machineCount { get; set; }
        @AuraEnabled
        public Decimal perMachineSales { get; set; }
        @AuraEnabled
        public Decimal contractMonthsElapsed { get; set; }
        @AuraEnabled
        public Decimal avgReagentSalesPerMonth { get; set; }
        @AuraEnabled
        public String performanceStatus { get; set; }
        @AuraEnabled
        public Decimal deficitCostCovered { get; set; }
        @AuraEnabled
        public Decimal marginPercentSnapshot { get; set; }
        @AuraEnabled
        public Decimal dataQualityScore { get; set; }

        // Formatted fields for display
        @AuraEnabled
        public String snapshotMonth { get; set; }
        @AuraEnabled
        public String formattedMonth { get; set; }
        @AuraEnabled
        public String formattedSales { get; set; }
        @AuraEnabled
        public String formattedTarget { get; set; }
        @AuraEnabled
        public String formattedAchievement { get; set; }
          @AuraEnabled
        //Month By Sales
        public Map<String, Decimal> monthlySales{get;set;}
        @AuraEnabled
        public Decimal marginTillDate{get;set;}
    }

    public class FilterOptions {
        @AuraEnabled
        public List<String> months { get; set; }
        @AuraEnabled
        public List<CustomerOption> customers { get; set; }
        @AuraEnabled
        public List<String> regions { get; set; }
        @AuraEnabled
        public List<String> suppliers { get; set; }
    }

    public class CustomerOption implements Comparable {
        @AuraEnabled
        public String customerCode { get; set; }
        @AuraEnabled
        public String customerName { get; set; }

        public Integer compareTo(Object compareTo) {
            CustomerOption compareToCustomer = (CustomerOption) compareTo;
            if (customerCode == compareToCustomer.customerCode)
                return 0;
            if (customerCode > compareToCustomer.customerCode)
                return 1;
            return -1;
        }
    }

    public class MachineStatusCount {
        @AuraEnabled
        public String status { get; set; }
        @AuraEnabled
        public Integer count { get; set; }
    }

    public class MachineStatusListResp
    {   
        @AuraEnabled
        public string id{get;set;   }
        @AuraEnabled
        public string name{get;set;   }
        @AuraEnabled
        public string customerNumber{get;set;   }
        @AuraEnabled
        public string region{get;set;   }
        @AuraEnabled
        public string status{get;set;   }
        @AuraEnabled
        public string machineInstallationStatus{get;set;   }
        @AuraEnabled
        public string masterBusinessCase{get;set;   }
       
    }

    public class MachineStatusCountwiseResp
    {
        @AuraEnabled
        public List<MachineStatusListResp> machineStatusListResp{get;set;   }
        @AuraEnabled
        public List<MachineStatusCount> machineStatusCount{get;set;   }
    }

    public class EnhancedFilterOptions {
        @AuraEnabled
        public List<String> months { get; set; }
        @AuraEnabled
        public List<CustomerOption> customers { get; set; }
        @AuraEnabled
        public List<String> regions { get; set; }
        @AuraEnabled
        public List<String> suppliers { get; set; }
        @AuraEnabled
        public List<String> businessCaseStatuses { get; set; }
        @AuraEnabled
        public List<String> machineStatuses { get; set; }
        @AuraEnabled
        public List<String> performanceStatuses { get; set; }
        @AuraEnabled
        public List<String> businessCases { get; set; }
    }

    public class SummaryMetrics {
        @AuraEnabled
        public Decimal totalInvestment { get; set; }
        @AuraEnabled
        public Decimal totalSales { get; set; }
        @AuraEnabled
        public Integer totalMachines { get; set; }
        @AuraEnabled
        public Integer totalSnapshots { get; set; }
        @AuraEnabled
        public Decimal costRecoveryPercent { get; set; }
        @AuraEnabled
        public Decimal commitmentAchievementPercent { get; set; }
    }

    public class FinancialOverviewPerformanceStats {
        @AuraEnabled
        public Decimal financialOverviewTotalInvestment { get; set; }
        @AuraEnabled
        public Decimal financialOverviewTotalSales { get; set; }
        @AuraEnabled
        public Decimal financialOverviewTotalMargin { get; set; }
        @AuraEnabled
        public String costRecovery { get; set; }
        @AuraEnabled
        public Integer machineCount { get; set; }
    }

    public class RegionalCommitmentPerformanceStats {
        @AuraEnabled
        public String Region { get; set; }
        @AuraEnabled
        public Integer MachinesCount { get; set; }
        @AuraEnabled
        public String MonthlyCommitment { get; set; }
        @AuraEnabled
        public String MonthlySales { get; set; }
        @AuraEnabled
        public String AchievementPercentage { get; set; }
    }
}