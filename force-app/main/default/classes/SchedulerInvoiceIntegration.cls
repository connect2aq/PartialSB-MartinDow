global class SchedulerInvoiceIntegration implements Schedulable {
    global void execute(SchedulableContext sc) {
        // Define date range: Yesterday to Today
        Date dateFrom = Date.today().addDays(-1); // Yesterday
        Date dateTo = Date.today(); // Today

        // Call the integration service method asynchronously (future method)
        InvoiceIntegrationService.fetchAndProcessInvoicesFromSAP(
            dateFrom,
            dateTo
        );
    }
}