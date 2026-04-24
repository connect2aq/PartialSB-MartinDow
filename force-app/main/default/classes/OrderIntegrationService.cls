public class OrderIntegrationService {
    
    // API response wrapper class
    public class APIResponse {
        public Boolean success;
        public String message;
        public String data;
    }

    // NEW: @future method for trigger-based integration
    @future(callout=true)
    public static void processOrdersForIntegration(List<Id> orderIds) {
        for (Id orderId : orderIds) {
            try {
                System.debug('Processing order integration for Order: ' + orderId);
                createOrderInSystem(orderId);
                System.debug('Order integration completed for Order: ' + orderId);
            } catch (Exception ex) {
                System.debug('Error processing order integration for Order: ' + orderId + '. Error: ' + ex.getMessage());
            }
        }
    }

    // Get authentication token from the TokenRequest class
    public static String getAuthToken() {
        TokenRequest.AuthTokenResult tokenResult = TokenRequest.getAuthToken();
        return (tokenResult != null && tokenResult.success) ? tokenResult.token : null;
    }
    
    public static OrderRequest buildOrderRequest(Id orderId) {
        // Fetch the main Order
        MD_Order__c order = [
            SELECT
                Id,
                CreatedDate,
                External_Order_ID__c,
                Order_Type__c,
                Sales_Org__c,
                Distribution_Channel__c,
                Division__c,
                Delivering_Plant__c,
                Purchase_Order_Number__c,
                Sales_Office__c,
                Customer_Reference_Date__c,
                Customer_Code_Bill_To__c,
                Customer_Code_Ship_To__c
            FROM MD_Order__c
            WHERE Id = :orderId
            LIMIT 1
        ];

        // Check if Order_Type__c is valid (only 2 allowed values)
        if (order.Order_Type__c != 'YSMP - FOC Order' && order.Order_Type__c != 'YKB - Demo Release Order') {
            System.debug('Invalid Order Type. Current Type: ' + order.Order_Type__c);
            System.debug('Allowed types: YSMP - FOC Order, YKB - Demo Release Order');
            return null; // Don't proceed if order type doesn't match
        }

        // Create request object
        OrderRequest req = new OrderRequest();

        // Map Order fields
        req.vbeln = ''; // Empty string as specified
        req.docType = extractCode(order.Order_Type__c);
        req.Bstdk = order.CreatedDate != null ? order.CreatedDate.format('yyyy-MM-dd') : '';
        req.salesOrg = extractCode(order.Sales_Org__c);
        req.distrChan = extractCode(order.Distribution_Channel__c);
        req.division = extractCode(order.Division__c);
        req.plant = extractCode(order.Delivering_Plant__c);
        req.purchNo = order.Purchase_Order_Number__c != null ? order.Purchase_Order_Number__c : '';
        req.salesOff = extractCode(order.Sales_Office__c);
        req.custRef = order.Customer_Reference_Date__c != null ? String.valueOf(order.Customer_Reference_Date__c) : '';
        req.partnNumb = extractCode(order.Customer_Code_Bill_To__c);
        req.partnNum2 = extractCode(order.Customer_Code_Ship_To__c);
        req.bname = String.valueOf(order.Id); // Record ID

        // Fetch Order Items
        List<MD_OrderItem__c> orderItems = [
            SELECT
                Material_Number__c,
                Quantity__c,
                Storage_Location__c
            FROM MD_OrderItem__c
            WHERE OrderId__c = :order.Id
            ORDER BY CreatedDate ASC
        ];

        // Initialize order items list
        req.n_SORD = new List<OrderRequest.N_SORD>();

        // Process order items with incremental item numbers
Integer itemNumber = 10;
for (MD_OrderItem__c item : orderItems) {
    OrderRequest.N_SORD orderItem = new OrderRequest.N_SORD();
    // FIXED: pad itemNumber to 6 digits
    orderItem.itmNumber = String.valueOf(itemNumber).leftPad(6, '0');
    orderItem.material = extractCode(item.Material_Number__c);
    orderItem.reqQty = item.Quantity__c != null ? String.valueOf(item.Quantity__c) : '';
    orderItem.storeLoc = extractCode(item.Storage_Location__c);
    orderItem.Vbeln = '';
    
    req.n_SORD.add(orderItem);
    itemNumber += 10;
}

        return req;
    }
    
    // MODIFIED: Removed @AuraEnabled, now called from trigger
    public static void createOrderInSystem(Id orderId) {
        try {
            // Step 1: Build Order request
            OrderRequest orderRequest = buildOrderRequest(orderId);
            
            // Do NOT treat invalid type as failure (keep existing behavior)
            if (orderRequest == null) {
                System.debug('Order request is null. Order type validation failed or other issue.');
                return;
            }
            
            // Step 2: Get authentication token and base URL from TokenRequest
            TokenRequest.AuthTokenResult tokenResult = TokenRequest.getAuthToken();
            String accessToken = (tokenResult != null && tokenResult.success) ? tokenResult.token : null;
            String baseEndpointUrl = (tokenResult != null) ? tokenResult.baseEndpointUrl : null;
            
            if (String.isBlank(accessToken) || String.isBlank(baseEndpointUrl)) {
                System.debug('Failed to get authentication token or base URL');
                // Mark failure with a clear message
                markOrderFailed(orderId, 'Authentication token or Base Endpoint URL is missing. Please verify TokenRequest configuration.');
                return;
            }

            // Step 3: Get the order type to determine endpoint
            MD_Order__c order = [SELECT Order_Type__c FROM MD_Order__c WHERE Id = :orderId LIMIT 1];
            String endpoint = '';
            
            if (order.Order_Type__c == 'YSMP - FOC Order') {
                endpoint = baseEndpointUrl + 'SAP/PostFocIssuance';
                // endpoint = 'https://webhook.site/d2395677-a57d-4557-a931-8c8296a4752e';
            } else if (order.Order_Type__c == 'YKB - Demo Release Order') {
                endpoint = baseEndpointUrl + 'SAP/PostDemo';
                // endpoint = 'https://webhook.site/d2395677-a57d-4557-a931-8c8296a4752e';
            }
            
            System.debug('Using endpoint for Order Type [' + order.Order_Type__c + ']: ' + endpoint);

            // Step 4: Convert to JSON and make API call
            String payload = JSON.serializePretty(orderRequest);
            System.debug('=================== ORDER REQUEST JSON START ===================');
            System.debug(payload);
            System.debug('=================== ORDER REQUEST JSON END ===================');

            HttpRequest req = new HttpRequest();
            req.setMethod('POST');
            req.setEndpoint(endpoint);
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setBody(payload);
            req.setTimeout(60000); // 60 seconds timeout

            Http http = new Http();
            HttpResponse res = http.send(req);
            
            ApiLogUtil.get().add(endpoint.replace(baseEndpointUrl + 'SAP/', ''), endpoint, 'POST', payload, res.getStatusCode(), res.getBody());

            System.debug('=================== API RESPONSE START ===================');
            System.debug('API Response Status: ' + res.getStatusCode());
            System.debug('API Response Body: ' + res.getBody());
            System.debug('=================== API RESPONSE END ===================');

            if (res.getStatusCode() == 200) {
                // Parse the response
                APIResponse apiResponse = (APIResponse) JSON.deserialize(res.getBody(), APIResponse.class);
                
                if (apiResponse != null && apiResponse.success && String.isNotBlank(apiResponse.data)) {
                    // Success path: update Order with External Order ID and Submitted status
                    MD_Order__c orderToUpdate = [SELECT Id FROM MD_Order__c WHERE Id = :orderId LIMIT 1];
                    orderToUpdate.External_Order_ID__c = apiResponse.data;
                    orderToUpdate.Status__c = 'Submitted';
                    update orderToUpdate;
                    
                    System.debug('Order updated successfully with External Order ID: ' + apiResponse.data);
                } else {
                    // Failure even with HTTP 200: capture meaningful message (prefer APIResponse.message)
                    String failureMsg = (apiResponse != null && String.isNotBlank(apiResponse.message))
                        ? 'API responded with failure. Message: ' + apiResponse.message
                        : 'API responded with failure. Raw Body: ' + res.getBody();
                    markOrderFailed(orderId, failureMsg);
                }
            } else {
                // Non-200 HTTP status: mark as failed and save full body
                String httpFailure = 'HTTP ' + String.valueOf(res.getStatusCode()) + ' - ' + res.getStatus() + '\n' + res.getBody();
                markOrderFailed(orderId, httpFailure);
            }

        } catch (Exception ex) {
            // Exception: mark as failed and capture message + stack trace
            String exMsg = 'Exception during Order integration: ' + ex.getMessage() + '\n' + ex.getStackTraceString();
            markOrderFailed(orderId, exMsg);
            System.debug('Error during Order integration: ' + ex.getMessage());
            System.debug('Stack trace: ' + ex.getStackTraceString());
        } finally {
            ApiLogUtil.get().flushSync();
        }
    }

    // Utility: Extract code before dash from picklist value
    public static String extractCode(String value) {
        if (String.isBlank(value)) return '';
        List<String> parts = value.split('-');
        return parts.isEmpty() ? '' : parts[0].trim();
    }

    // NEW: Centralized failure handler to set Status__c = 'Failed' and save the full error message
    private static void markOrderFailed(Id orderId, String errorMessage) {
        try {
            MD_Order__c toUpdate = new MD_Order__c(
                Id = orderId,
                Status__c = 'Failed',
                Error_Message__c = errorMessage
            );
            update toUpdate;
            System.debug('Order marked as Failed and error message saved to Error_Message__c.');
        } catch (Exception updEx) {
            System.debug('Failed to update order status/error field: ' + updEx.getMessage());
        }
    }
}