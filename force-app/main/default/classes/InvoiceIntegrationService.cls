public with sharing class InvoiceIntegrationService {
    /**
     * Fetches invoices from SAP by date range and processes them in Salesforce.
     * @param dateFrom Start date (inclusive)
     * @param dateTo End date (inclusive)
     */
    @future(callout=true)
    public static void fetchAndProcessInvoicesFromSAP(
        Date dateFrom,
        Date dateTo
    ) {
        try {
            // 1. Get SAP token and endpoint
            TokenRequest.AuthTokenResult tokenResult;
            if (Test.isRunningTest()) {
                // Provide dummy token and endpoint for test context
                tokenResult = new TokenRequest.AuthTokenResult();
                tokenResult.token = 'testToken';
                tokenResult.baseEndpointUrl = 'https://test.endpoint/';
            } else {
                tokenResult = TokenRequest.getAuthToken();
            }
            String accessToken = (tokenResult != null) ? tokenResult.token : null;
            String baseEndpointUrl = (tokenResult != null)
                ? tokenResult.baseEndpointUrl
                : null;
    
            if (String.isBlank(accessToken) || String.isBlank(baseEndpointUrl)) {
                throw new AuraHandledException(
                    'Failed to get SAP access token or endpoint URL'
                );
            }
    
            // Format dates as yyyyMMdd
            String fromStr =
                String.valueOf(dateFrom.year()) +
                (dateFrom.month() < 10 ? '0' : '') +
                dateFrom.month() +
                (dateFrom.day() < 10 ? '0' : '') +
                dateFrom.day();
            String toStr =
                String.valueOf(dateTo.year()) +
                (dateTo.month() < 10 ? '0' : '') +
                dateTo.month() +
                (dateTo.day() < 10 ? '0' : '') +
                dateTo.day();
    
            String endpoint =
                baseEndpointUrl +
                'SAP/GetSalesReport?fromDate=' +
                fromStr +
                '&toDate=' +
                toStr;
    
            // 3. Make GET call
            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint(endpoint);
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setTimeout(60000);
    
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            ApiLogUtil.get().add('GetSalesReport', endpoint, 'GET', null, res.getStatusCode(), res.getBody());
    
            if (res.getStatusCode() != 200) {
                throw new AuraHandledException(
                    'Failed to fetch invoices from SAP. Status: ' + res.getStatus()
                );
            }
    
            // 4. Parse response (assume JSON array of InvoiceWrapper)
            // Pre-process JSON to handle invalid dates like '0000-00-00'
            String cleanJson = res.getBody().replace('"0000-00-00"', 'null');
            InvoiceProcessingService.InvoiceWrapper invoiceWrapper = (InvoiceProcessingService.InvoiceWrapper) JSON.deserialize(
                cleanJson,
                InvoiceProcessingService.InvoiceWrapper.class
            );
    
            // 5. Process invoices in Salesforce
            InvoiceProcessingService.processInvoices(invoiceWrapper);
        } finally {
            ApiLogUtil.get().flushSync();
        }
    }
}