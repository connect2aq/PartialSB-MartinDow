public class SAPIntegrationService {
    
    // SAP API response wrapper class
    public class SAPResponse {
        public Boolean success;
        public String message;
        public String data;
    }

    // @future method for trigger-based integration
    @future(callout=true)
    public static void processAccountsForSAP(List<Id> accountIds) {
        for (Id accountId : accountIds) {
            try {
                System.debug('Processing SAP integration for Account: ' + accountId);
                createAccountInSAP(accountId);
                System.debug('SAP integration completed for Account: ' + accountId);
            } catch (Exception ex) {
                System.debug('Error processing SAP integration for Account: ' + accountId + '. Error: ' + ex.getMessage());
            }
        }
    }

    // Get authentication token from the TokenRequest class (helper kept for compatibility)
    public static String getAuthToken() {
        TokenRequest.AuthTokenResult tokenResult = TokenRequest.getAuthToken();
        return (tokenResult != null && tokenResult.success) ? tokenResult.token : null;
    }

    public static SAPAccountRequest buildSAPRequest(Id accountId) {
        // Fetch the main Account
        Account acc = [
            SELECT
                Id,
                SAP_Customer_Number__c,
                Name,
                Account_Name2__c,
                City__c,
                Province__c,
                Postal_Code__c,
                AddressLine_1__c,
                Addess_Line_2__c,
                Country_Code__c,
                Company_Code__c,
                Reconciliation_Account__c,
                Payment_Terms_FI_Role__c,
                Phone,
                Cell__c,
                Email__c,
                Business_Vertical__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        // Create request object
        SAPAccountRequest req = new SAPAccountRequest();

        // Map Account fields
        req.Kunnr = acc.SAP_Customer_Number__c != null ? acc.SAP_Customer_Number__c : '';
        req.Name1 = acc.Name;
        req.Name2 = acc.Account_Name2__c;
        req.Name4 = String.valueOf(acc.Id); // SFID reference
        req.City = acc.City__c;
        req.District = acc.Province__c;
        req.PostlCod1 = acc.Postal_Code__c;
        req.StrSuppl3 = acc.AddressLine_1__c;
        req.Location = acc.Addess_Line_2__c;
        req.Country = extractCode(acc.Country_Code__c);
        req.Bukrs = acc.Company_Code__c;
        req.Akont = extractCode(acc.Reconciliation_Account__c);
        req.Zterm = extractCode(acc.Payment_Terms_FI_Role__c);
        req.Vsbed = '01'; // Default shipping condition
        req.Searchterm1 = acc.Business_Vertical__c;
        req.Searchterm2 = 'DIAG';

        // Initialize contact lists
        req.N_CUSTMER  = new List<SAPAccountRequest.N_CUSTMER>();
        req.N_CUSTMER3 = new List<SAPAccountRequest.N_CUSTMER3>();
        req.N_CUSTMER4 = new List<SAPAccountRequest.N_CUSTMER4>();

        // Contacts -> ONLY Primary_Contact__c = TRUE should be sent
        // Minimal change: added Primary_Contact__c field and WHERE filter
        List<Contact> contacts = [
            SELECT Email, Phone, MobilePhone, Primary_Contact__c
            FROM Contact
            WHERE AccountId = :acc.Id
            AND Primary_Contact__c = TRUE
        ];

        // If multiple primaries exist, all primary contacts will be sent
        for (Contact c : contacts) {
            if (String.isNotBlank(c.Email)) {
                SAPAccountRequest.N_CUSTMER emailWrapper = new SAPAccountRequest.N_CUSTMER();
                emailWrapper.KUNNR = req.Kunnr;
                emailWrapper.EMail = c.Email;
                req.N_CUSTMER.add(emailWrapper);
            }
            if (String.isNotBlank(c.Phone)) {
                SAPAccountRequest.N_CUSTMER3 phoneWrapper = new SAPAccountRequest.N_CUSTMER3();
                phoneWrapper.Kunnr = req.Kunnr;
                phoneWrapper.Telephone = c.Phone;
                req.N_CUSTMER3.add(phoneWrapper);
            }
            if (String.isNotBlank(c.MobilePhone)) {
                SAPAccountRequest.N_CUSTMER4 mobileWrapper = new SAPAccountRequest.N_CUSTMER4();
                mobileWrapper.Kunnr = req.Kunnr;
                mobileWrapper.Mobile = c.MobilePhone;
                req.N_CUSTMER4.add(mobileWrapper);
            }
        }

        // Sales Areas
        List<MD_Sales_Area__c> salesAreas = [
            SELECT
                Sales_Org__c,
                Distribution_Channel__c,
                Division__c,
                Sales_District__c,
                Delivering_Plant__c,
                Customer_Group__c,
                Sales_Office__c,
                Sales_Group__c,
                Currency__c,
                Price_Group__c,
                Pricing_Procedure_Indicator__c,
                Incoterms__c,
                Incoterms_Description__c,
                Payment_Terms__c,
                Customer_Account_Assignment_Group__c,
                Output_Tax_Category_MWST_Code__c,
                Output_Tax_Category_ZMST_Code__c,
                Output_Tax_Category_ZMWS_Code__c,
                Output_Tax_Category_ZPK2_Code__c
            FROM MD_Sales_Area__c
            WHERE Parent_Account__c = :acc.Id
        ];

        if (!salesAreas.isEmpty()) {
            MD_Sales_Area__c sa = salesAreas[0];
            req.Vkorg   = extractCode(sa.Sales_Org__c);
            req.Vtweg   = extractCode(sa.Distribution_Channel__c);
            req.Spart   = extractCode(sa.Division__c);
            req.Kdgrp   = extractCode(sa.Customer_Group__c);
            req.Bzirk   = extractCode(sa.Sales_District__c);
            req.Vkbur   = extractCode(sa.Sales_Office__c);
            req.Waers   = extractCode(sa.Currency__c);
            req.Vkgrp   = extractCode(sa.Sales_Group__c);
            req.Konda   = extractCode(sa.Price_Group__c);
            req.Kalks   = extractCode(sa.Pricing_Procedure_Indicator__c);
            req.Vwerk   = extractCode(sa.Delivering_Plant__c);
            req.Inco1   = extractCode(sa.Incoterms__c);
            req.Inco2   = sa.Incoterms_Description__c;
            req.ZtermSd = extractCode(sa.Payment_Terms__c);
            req.Ktgrd   = extractCode(sa.Customer_Account_Assignment_Group__c);
        }

        // Tax Categories (N_CUSTMER1)
        req.N_CUSTMER1 = new List<SAPAccountRequest.N_CUSTMER1>();
        for (MD_Sales_Area__c sa : salesAreas) {
            SAPAccountRequest.N_CUSTMER1 w1 = new SAPAccountRequest.N_CUSTMER1();
            w1.Kunnr = req.Kunnr; w1.Tatyp = 'MWST'; w1.Taxkd = extractCode(sa.Output_Tax_Category_MWST_Code__c);
            req.N_CUSTMER1.add(w1);

            SAPAccountRequest.N_CUSTMER1 w2 = new SAPAccountRequest.N_CUSTMER1();
            w2.Kunnr = req.Kunnr; w2.Tatyp = 'ZMWS'; w2.Taxkd = extractCode(sa.Output_Tax_Category_ZMWS_Code__c);
            req.N_CUSTMER1.add(w2);

            SAPAccountRequest.N_CUSTMER1 w3 = new SAPAccountRequest.N_CUSTMER1();
            w3.Kunnr = req.Kunnr; w3.Tatyp = 'ZMST'; w3.Taxkd = extractCode(sa.Output_Tax_Category_ZMST_Code__c);
            req.N_CUSTMER1.add(w3);

            SAPAccountRequest.N_CUSTMER1 w4 = new SAPAccountRequest.N_CUSTMER1();
            w4.Kunnr = req.Kunnr; w4.Tatyp = 'ZPK2'; w4.Taxkd = extractCode(sa.Output_Tax_Category_ZPK2_Code__c);
            req.N_CUSTMER1.add(w4);
        }

        // Tax Numbers (N_CUSTMER2)
        req.N_CUSTMER2 = new List<SAPAccountRequest.N_CUSTMER2>();
        List<MD_Tax_Number__c> taxNumbers = [
            SELECT Tax_Category_Code__c, Category_Value__c
            FROM MD_Tax_Number__c
            WHERE Account__c = :acc.Id
        ];
        for (MD_Tax_Number__c t : taxNumbers) {
            SAPAccountRequest.N_CUSTMER2 wrapper = new SAPAccountRequest.N_CUSTMER2();
            wrapper.KUNNR = req.Kunnr;
            wrapper.Taxtype = extractCode(t.Tax_Category_Code__c);
            wrapper.Taxnumber = t.Category_Value__c;
            req.N_CUSTMER2.add(wrapper);
        }

        // Credit Profile (N_CUSTMER6)
        req.N_CUSTMER6 = new List<SAPAccountRequest.N_CUSTMER6>();
        List<Credit_Profile__c> creditProfiles = [
            SELECT Credit_Segment__c, Credit_Limit__c
            FROM Credit_Profile__c
            WHERE Account__c = :acc.Id
        ];
        for (Credit_Profile__c cp : creditProfiles) {
            SAPAccountRequest.N_CUSTMER6 wrapper = new SAPAccountRequest.N_CUSTMER6();
            wrapper.Kunnr = req.Kunnr;
            wrapper.creditSegment = String.isNotBlank(cp.Credit_Segment__c) ? cp.Credit_Segment__c.substringBefore(' ') : null;
            wrapper.CreditLimit = (cp.Credit_Limit__c != null) ? String.valueOf(cp.Credit_Limit__c) : null;
            req.N_CUSTMER6.add(wrapper);
        }

        return req;
    }
    
    // Called from trigger or anonymous window
    public static void createAccountInSAP(Id accountId) {
        try {
            // Step 1: Get authentication token and base URL from TokenRequest
            TokenRequest.AuthTokenResult tokenResult = TokenRequest.getAuthToken();
            String accessToken = (tokenResult != null && tokenResult.success) ? tokenResult.token : null;
            String baseEndpointUrl = (tokenResult != null) ? tokenResult.baseEndpointUrl : null;
            
            if (String.isBlank(accessToken) || String.isBlank(baseEndpointUrl)) {
                System.debug('Failed to get authentication token or base URL');
                // Failure: map error + Account_Status__c = 'Failed'
                markFailed(accountId, 'Authentication token or Base Endpoint URL is missing. Please verify TokenRequest configuration.');
                return;
            }

            // Step 2: Build SAP request
            SAPAccountRequest sapRequest = buildSAPRequest(accountId);
            
            // Step 3: Convert to JSON and make SAP API call
            String payload = JSON.serializePretty(sapRequest);
            System.debug('=================== SAP REQUEST JSON START ===================');
            System.debug(payload);
            System.debug('=================== SAP REQUEST JSON END ===================');

            HttpRequest req = new HttpRequest();
            req.setMethod('POST');
            req.setEndpoint(baseEndpointUrl + 'SAP/PostCustomer');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setBody(payload);
            req.setTimeout(60000); // 60 seconds timeout

            Http http = new Http();
            HttpResponse res = http.send(req);
            
            ApiLogUtil.get().add('PostCustomer', baseEndpointUrl + 'SAP/PostCustomer', 'POST', payload, res.getStatusCode(), res.getBody());

            System.debug('=================== SAP RESPONSE START ===================');
            System.debug('SAP Response Status: ' + res.getStatusCode());
            System.debug('SAP Response Body: ' + res.getBody());
            System.debug('=================== SAP RESPONSE END ===================');

            if (res.getStatusCode() == 200) {
                // Parse the response
                SAPResponse sapResponse = (SAPResponse) JSON.deserialize(res.getBody(), SAPResponse.class);
                
                if (sapResponse != null && sapResponse.success && String.isNotBlank(sapResponse.data)) {
                    // Success path: map SAP number + set Active
                    Account acc = new Account(
                        Id = accountId,
                        SAP_Customer_Number__c = sapResponse.data,
                        Account_Status__c = 'Active'
                    );
                    update acc;
                    
                    System.debug('Account updated successfully with SAP Customer Number: ' + sapResponse.data);
                } else {
                    // 200 but application-level failure → map error + mark failed
                    String failureMsg = (sapResponse != null && String.isNotBlank(sapResponse.message))
                        ? 'API responded with failure. Message: ' + sapResponse.message
                        : 'API responded with failure. Raw Body: ' + res.getBody();
                    markFailed(accountId, failureMsg);
                    System.debug('SAP API returned error: ' + (sapResponse != null ? sapResponse.message : 'null message'));
                }
            } else {
                // Non-200 HTTP response → map error + mark failed
                String httpFailure = 'HTTP ' + String.valueOf(res.getStatusCode()) + ' - ' + res.getStatus() + '\n' + res.getBody();
                markFailed(accountId, httpFailure);
                System.debug('SAP API call failed. Status: ' + res.getStatus() + ', Body: ' + res.getBody());
            }

        } catch (Exception ex) {
            // Exception path → map error + mark failed
            String exMsg = 'Error during SAP integration: ' + ex.getMessage() + '\n' + ex.getStackTraceString();
            markFailed(accountId, exMsg);
            System.debug('Error during SAP integration: ' + ex.getMessage());
            System.debug('Stack trace: ' + ex.getStackTraceString());
        } finally {
            ApiLogUtil.get().flushSync();
        }
    }

    // Overloaded method for backward compatibility (no-op)
    public static void createAccountInSAP(SAPAccountRequest sapRequest) {
        System.debug('Warning: Using deprecated method. Use createAccountInSAP(Id accountId) instead.');
    }

    // Utility: Extract code before dash from picklist value
    public static String extractCode(String value) {
        if (String.isBlank(value)) return null;
        List<String> parts = value.split('-');
        return parts.isEmpty() ? null : parts[0].trim();
    }

    // Centralized failure mapper: save full error text and set Account_Status__c = 'Failed'
    private static void markFailed(Id accountId, String message) {
        try {
            Account upd = new Account(
                Id = accountId,
                SAP_Error_Message__c = message,
                Account_Status__c = 'Failed'
            );
            update upd;
            System.debug('Saved SAP_Error_Message__c and set Account_Status__c=Failed for Account: ' + accountId);
        } catch (Exception updEx) {
            System.debug('Failed to save SAP error details: ' + updEx.getMessage());
        }
    }
}