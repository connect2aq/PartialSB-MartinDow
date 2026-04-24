@RestResource(urlMapping='/AccountStatus')
global class AccountStatusRestAPI {
    
    // Response wrapper class
    global class Response {
        public Integer statusCode;
        public String message;
        
        public Response(Integer code, String msg) {
            this.statusCode = code;
            this.message = msg;
        }
    }
    
    @HttpPost
    global static void doPost() {
        Response response = null;
        String requestBody = '';
        Long startTime = System.currentTimeMillis();
        
        try {
            String body = RestContext.request.requestBody?.toString();
            requestBody = body; // Store for logging
            
            // Parse JSON to Map for flexible handling
            Map<String, Object> requestData = (Map<String, Object>)JSON.deserializeUntyped(body);
            
            // Extract required fields
            String accountId = (String)requestData.get('Id');
            String accountStatus = (String)requestData.get('Account_Status__c');
            
            // Validation
            if(String.isBlank(accountId)) {
                response = new Response(400, 'Account ID is required and cannot be empty.');
            } else if(String.isBlank(accountStatus)) {
                response = new Response(400, 'Account Status is required and cannot be empty.');
            } else {
                // Validate Account ID format
                if(!isValidSalesforceId(accountId)) {
                    response = new Response(400, 'Invalid Account ID format.');
                } else {
                    // Check if Account exists
                    List<Account> existingAccounts = [SELECT Id, Account_Status__c FROM Account WHERE Id = :accountId LIMIT 1];
                    
                    if(existingAccounts.isEmpty()) {
                        response = new Response(404, 'Account not found with the provided ID.');
                    } else {
                        // Validate picklist value
                        if(!isValidAccountStatus(accountStatus)) {
                            response = new Response(400, 'Invalid Account Status value. Valid values are: Ready for SAP Push, SAP Synced, Draft, Active, Inactive.');
                        } else {
                            // Update the account
                            Account accountToUpdate = existingAccounts[0];
                            accountToUpdate.Account_Status__c = accountStatus;
                            
                            update accountToUpdate;
                            
                            response = new Response(200, 'Account status updated successfully.');
                        }
                    }
                }
            }
            
        } catch (DmlException dmlEx) {
            String message = 'Database Error: ' + dmlEx.getMessage();
            System.debug('DML Exception: ' + message);
            response = new Response(500, message);
            
        } catch (Exception ex) {
            String message = 'System Error: ' + 
                '\nMessage: ' + ex.getMessage() + 
                '\nLine Number: ' + ex.getLineNumber() + 
                '\nStack Trace: ' + ex.getStackTraceString() + 
                '\nException Type: ' + ex.getTypeName();
            
            System.debug('General Exception: ' + message);
            response = new Response(500, 'Internal server error occurred.');
        }
        
        // Log the API call
        Long endTime = System.currentTimeMillis();
        logAPICall(requestBody, response, startTime, endTime);
        
        // Set response headers and body
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(response));
        
        // Set appropriate HTTP status code
        if(response.statusCode == 200) {
            RestContext.response.statusCode = 200;
        } else if(response.statusCode == 400) {
            RestContext.response.statusCode = 400;
        } else if(response.statusCode == 404) {
            RestContext.response.statusCode = 404;
        } else {
            RestContext.response.statusCode = 500;
        }
    }
    
    // Method to log API calls
    private static void logAPICall(String requestBody, Response response, Long startTime, Long endTime) {
        try {
            API_Log__c apiLog = new API_Log__c();
            
            // Basic API Info
            apiLog.API_Name__c = 'Account Status Update API';
            apiLog.API_URL__c = 'https://app-efficiency-7703--devsb.sandbox.my.salesforce.com/services/apexrest/AccountStatus';
            apiLog.Request_Method__c = 'POST';
            
            // Request/Response Data
            apiLog.Request_Body__c = requestBody;
            apiLog.Response_Code__c = response.statusCode;
            apiLog.Response_Message__c = JSON.serialize(response);
            
            // Client Information
            apiLog.User_Agent__c = RestContext.request.headers.get('User-Agent');
            apiLog.Remote_Address__c = RestContext.request.remoteAddress;
            
            // Timing and Status
            apiLog.Processing_Time_MS__c = endTime - startTime;
            apiLog.Is_Success__c = (response.statusCode == 200);
            apiLog.Request_Timestamp__c = DateTime.now();
            
            // Error details if any
            if(response.statusCode != 200) {
                apiLog.Error_Details__c = response.message;
            }
            
            insert apiLog;
            
        } catch(Exception logEx) {
            // Don't fail the main API if logging fails
            System.debug('Failed to log API call: ' + logEx.getMessage());
        }
    }
    
    // Helper method to validate Salesforce ID format
    private static Boolean isValidSalesforceId(String recordId) {
        if(String.isBlank(recordId)) {
            return false;
        }
        
        // Salesforce ID should be 15 or 18 characters
        if(recordId.length() != 15 && recordId.length() != 18) {
            return false;
        }
        
        // Check if it contains only alphanumeric characters
        for(Integer i = 0; i < recordId.length(); i++) {
            String character = recordId.substring(i, i + 1);
            if(!character.isAlphanumeric()) {
                return false;
            }
        }
        
        return true;
    }
    
    // Helper method to validate Account Status picklist values
    private static Boolean isValidAccountStatus(String status) {
        Set<String> validStatuses = new Set<String>{
            'Ready for SAP Push',
            'SAP Synced',
            'Draft',
            'Active',
            'Inactive'
        };
        
        return validStatuses.contains(status);
    }
}