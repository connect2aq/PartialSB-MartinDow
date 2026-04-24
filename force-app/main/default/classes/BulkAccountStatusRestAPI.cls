@RestResource(urlMapping='/BulkAccountStatus')
global class BulkAccountStatusRestAPI {
    // Response wrapper for bulk operation
    global class BulkResponse {
        public Integer statusCode;
        public String message;
        public BulkResponse(Integer code, String msg) {
            this.statusCode = code;
            this.message = msg;
        }
    }

    @HttpPost
    global static void doPost() {
        try {
            String body = RestContext.request.requestBody?.toString();
            List<Object> dataList = (List<Object>) JSON.deserializeUntyped(body);

            // Validate top‑level payload
            if (dataList == null || dataList.isEmpty()) {
                sendResponse(new BulkResponse(400, 'Request body must be a non-empty JSON array.'));
                return;
            }

            List<Id> ids = new List<Id>();
            Map<Id, String> statusMap = new Map<Id, String>();

            for (Object obj : dataList) {
                Map<String, Object> rec = (Map<String, Object>) obj;
                String accountId = (String) rec.get('Id');
                String accountStatus = (String) rec.get('Account_Status__c');

                // Validation without throwing Exception
                if (String.isBlank(accountId) || !isValidSalesforceId(accountId)) {
                    sendResponse(new BulkResponse(400, 'Invalid Account ID: ' + accountId));
                    return;
                }
                if (String.isBlank(accountStatus) || !isValidAccountStatus(accountStatus)) {
                    sendResponse(new BulkResponse(400, 'Invalid Account Status: ' + accountStatus));
                    return;
                }

                ids.add((Id) accountId);
                statusMap.put((Id) accountId, accountStatus);
            }

            // Query and update
            List<Account> accountsToUpdate = [
                SELECT Id
                FROM Account
                WHERE Id IN :ids
            ];

            if (accountsToUpdate.isEmpty()) {
                sendResponse(new BulkResponse(404, 'No accounts found for provided IDs.'));
                return;
            }

            for (Account acc : accountsToUpdate) {
                acc.Account_Status__c = statusMap.get(acc.Id);
            }
            update accountsToUpdate;

            sendResponse(new BulkResponse(200, 'Accounts status updated successfully.'));

        } catch (DmlException dmlEx) {
            sendResponse(new BulkResponse(500, 'Database Error: ' + dmlEx.getMessage()));
        } catch (Exception ex) {
            sendResponse(new BulkResponse(500, 'System Error: ' + ex.getMessage()));
        }
    }

    // Helper to send JSON response and set status code
    private static void sendResponse(BulkResponse resp) {
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(resp));
        RestContext.response.statusCode = resp.statusCode;
    }

    // Helper: Validate Salesforce ID format
    private static Boolean isValidSalesforceId(String recordId) {
        if (String.isBlank(recordId)) return false;
        Integer len = recordId.length();
        if (len != 15 && len != 18) return false;
        for (Integer i = 0; i < len; i++) {
            if (!recordId.substring(i, i+1).isAlphanumeric()) {
                return false;
            }
        }
        return true;
    }

    // Helper: Validate allowed picklist values
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