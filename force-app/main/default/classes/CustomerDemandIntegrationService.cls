public class CustomerDemandIntegrationService {

    // Wrapper for API response
    public class APIResponse {
        public Boolean success;
        public String message;
        public String data;
    }

    /**
     * Build the quotation request payload from Customer_Demand__c
     */
    public static CustomerDemandRequest buildQuotationRequest(Id demandId) {
        Customer_Demand__c rec = [
            SELECT Id,
                   External_Quote_ID__c,
                   Order_Type__c,
                   Sales_Org__c,
                   Distribution_Channel__c,
                   Division__c,
                   QT_Valid_From__c,
                   QT_Valid_To__c,
                   Plant__c,
                   Purchase_Order_No__c,
                   Sales_Office__c,
                   Date_of_Creation__c,
                   Customer_Code_Bill_To__c,
                   Customer_Code_Ship_To__c
            FROM Customer_Demand__c
            WHERE Id = :demandId
            LIMIT 1
        ];

        CustomerDemandRequest req = new CustomerDemandRequest();

        // Map exactly as specified
        req.Vbeln      = rec.External_Quote_ID__c == null ? '' : String.valueOf(rec.External_Quote_ID__c);
        req.DocType    = extractCode(rec.Order_Type__c);
        req.SalesOrg   = extractCode(rec.Sales_Org__c);
        req.DistrChan  = extractCode(rec.Distribution_Channel__c);
        req.Division   = extractCode(rec.Division__c);

        // Date fields are Date; format to yyyy-MM-dd
        req.QT_VALID_F = formatDate(rec.QT_Valid_From__c);
        req.QT_VALID_T = formatDate(rec.QT_Valid_To__c);

        req.Plant      = extractCode(rec.Plant__c);
        req.PurchNo    = rec.Purchase_Order_No__c == null ? '' : rec.Purchase_Order_No__c;
        req.SalesOff   = extractCode(rec.Sales_Office__c);
        req.Bstdk      = formatDate(rec.Date_of_Creation__c);
        req.Bname      = String.valueOf(rec.Id);

        req.PartnNumb  = extractCode(rec.Customer_Code_Bill_To__c);
        req.PartnNum2  = extractCode(rec.Customer_Code_Ship_To__c);

        // N_QUOT must always be an empty array (constructor already did this)
        return req;
    }

    /**
     * Future wrapper for trigger-based async callout (bulk-safe).
     */
    @future(callout=true)
    public static void processDemandsForIntegration(List<Id> demandIds) {
        Set<Id> ids = new Set<Id>(demandIds);
        if (ids.isEmpty()) return;

        for (Customer_Demand__c cd : [
            SELECT Id, External_Quote_ID__c
            FROM Customer_Demand__c
            WHERE Id IN :ids
        ]) {
            if (String.isBlank(cd.External_Quote_ID__c)) {
                try {
                    postQuotation(cd.Id);
                } catch (Exception ex) {
                    System.debug('Error processing demand ' + cd.Id + ': ' + ex.getMessage());
                    // On failure, save error + set Status = Failed
                    markFailed(cd.Id, 'Error processing demand: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
                }
            } else {
                System.debug('Skipping demand ' + cd.Id + ' as External_Quote_ID__c is already set.');
            }
        }
    }

    /**
     * Main synchronous method used by anonymous window and future wrapper.
     */
    public static void postQuotation(Id demandId) {
        try {
            // 1) Build request
            CustomerDemandRequest payload = buildQuotationRequest(demandId);

            // 2) Get token and base endpoint
            TokenRequest.AuthTokenResult tokenResult = TokenRequest.getAuthToken();
            String accessToken = (tokenResult != null && tokenResult.success) ? tokenResult.token : null;
            String baseEndpointUrl = (tokenResult != null) ? tokenResult.baseEndpointUrl : null;

            if (String.isBlank(accessToken) || String.isBlank(baseEndpointUrl)) {
                System.debug('Token or base endpoint URL not available. Aborting quotation call.');
                // Failure: save error + Status = Failed
                markFailed(demandId, 'Authentication token or Base Endpoint URL is missing. Please verify TokenRequest configuration.');
                return;
            }

            // 3) Build endpoint (kept as-is per your current code)
            String endpoint = '';
            // String endpoint = 'https://webhook.site/77a4e54e-055a-4b8d-aa9e-419fe89f6590';
            endpoint = baseEndpointUrl + 'SAP/postQuotation';
            System.debug('Resolved Quotation Endpoint: ' + endpoint);

            // 4) Serialize and log pretty JSON
            String body = JSON.serializePretty(payload);
            System.debug('=================== QUOTATION REQUEST JSON START ===================');
            System.debug(body);
            System.debug('=================== QUOTATION REQUEST JSON END =====================');

            // 5) Prepare and execute HTTP callout
            HttpRequest req = new HttpRequest();
            req.setMethod('POST');
            req.setEndpoint(endpoint);
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setTimeout(60000);
            req.setBody(body);

            Http http = new Http();
            HttpResponse res = http.send(req);
            
            ApiLogUtil.get().add('PostQuotation', endpoint, 'POST', body, res.getStatusCode(), res.getBody());

            System.debug('=================== API RESPONSE START ===================');
            System.debug('Status Code: ' + res.getStatusCode());
            System.debug('Status: ' + res.getStatus());
            System.debug('Body: ' + res.getBody());
            System.debug('=================== API RESPONSE END =====================');

            // 6) Handle response
            if (res.getStatusCode() == 200) {
                APIResponse apiRes = (APIResponse) JSON.deserialize(res.getBody(), APIResponse.class);
                if (apiRes != null && apiRes.success == true && String.isNotBlank(apiRes.data)) {
                    // Success: set External_Quote_ID__c and Status = 'Submit'
                    Customer_Demand__c upd = new Customer_Demand__c(
                        Id = demandId,
                        External_Quote_ID__c = apiRes.data,
                        Status__c = 'Submit'
                    );
                    update upd;
                    System.debug('External_Quote_ID__c updated to: ' + apiRes.data + ' | Status set to Submit');
                } else {
                    // 200 but application-level failure → error + Status = Failed
                    String failureMsg = (apiRes != null && String.isNotBlank(apiRes.message))
                        ? 'API responded with failure. Message: ' + apiRes.message
                        : 'API responded with failure. Raw Body: ' + res.getBody();
                    markFailed(demandId, failureMsg);
                    System.debug('API returned success=false or empty data.');
                }
            } else {
                // Non-200 HTTP response → error + Status = Failed
                String httpFailure = 'HTTP ' + String.valueOf(res.getStatusCode()) + ' - ' + res.getStatus() + '\n' + res.getBody();
                markFailed(demandId, httpFailure);
                System.debug('Callout failed: ' + res.getStatus() + ' | Body: ' + res.getBody());
            }
        } catch (Exception ex) {
            // Exception → error + Status = Failed
            String exMsg = 'Exception in postQuotation: ' + ex.getMessage() + '\n' + ex.getStackTraceString();
            markFailed(demandId, exMsg);
            System.debug('Error in postQuotation: ' + ex.getMessage());
            System.debug('Stack Trace: ' + ex.getStackTraceString());
        } finally {
            ApiLogUtil.get().flushSync();
        }
    }

    // ----------------- Helpers -----------------

    // Safe URL join: ensures exactly one slash between base and path.
    private static String joinUrl(String base, String path) {
        if (String.isBlank(base)) return path;
        if (String.isBlank(path)) return base;
        String b = base.endsWith('/') ? base.substring(0, base.length() - 1) : base;
        String p = path.startsWith('/') ? path.substring(1) : path;
        return b + '/' + p;
    }

    // Extract code from "CODE - Label" or return value if already a code
    public static String extractCode(String value) {
        if (String.isBlank(value)) return '';
        List<String> parts = value.split('-');
        if (parts.isEmpty()) return '';
        String first = parts[0].trim();
        return String.isBlank(first) ? '' : first;
    }

    // Format Date to yyyy-MM-dd; convert to Datetime then use formatGmt
    public static String formatDate(Date d) {
        if (d == null) return '';
        Datetime dt = Datetime.newInstance(d.year(), d.month(), d.day());
        return dt.formatGmt('yyyy-MM-dd');
    }

    // Overload for Datetime to yyyy-MM-dd (not used here, kept for safety)
    public static String formatDate(Datetime dt) {
        return dt == null ? '' : dt.formatGmt('yyyy-MM-dd');
    }

    // Existing helper retained for compatibility (still used elsewhere if needed)
    private static void saveErrorMessage(Id demandId, String message) {
        try {
            Customer_Demand__c upd = new Customer_Demand__c(
                Id = demandId,
                Error_Message__c = message
            );
            update upd;
            System.debug('Saved Error_Message__c on Customer_Demand__c: ' + demandId);
        } catch (Exception updEx) {
            System.debug('Failed to save Error_Message__c: ' + updEx.getMessage());
        }
    }

    // NEW: Mark failure with Status__c = 'Failed' and save error text in one DML
    private static void markFailed(Id demandId, String errorMessage) {
        try {
            Customer_Demand__c upd = new Customer_Demand__c(
                Id = demandId,
                Status__c = 'Failed',
                Error_Message__c = errorMessage
            );
            update upd;
            System.debug('Demand marked Failed and error saved. Id: ' + demandId);
        } catch (Exception e) {
            System.debug('Failed to mark as Failed: ' + e.getMessage());
        }
    }
}