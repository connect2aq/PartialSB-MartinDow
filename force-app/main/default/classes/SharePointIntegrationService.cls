public class SharePointIntegrationService {
    
    // SAP API response wrapper class
    public class SAPResponse {
        public Boolean success;
        public String message;
        public String data;
    }

    // Get authentication token from the TokenRequest class
    public static String getAuthToken() {
        TokenRequest.AuthTokenResult tokenResult = TokenRequest.getAuthToken();
        return (tokenResult != null && tokenResult.success) ? tokenResult.token : null;
    }
    
    public static SharePointAccountRequest buildSAPRequest(Id accountId) {
        // Fetch the main Account
        Account acc = [
            SELECT
                Id,
                SAP_Customer_Number__c,
                Share_Point_Number__c,
                Account_Status__c,
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
        SharePointAccountRequest req = new SharePointAccountRequest();

        // Map Account fields
        req.AccountID = String.valueOf(acc.Id);
        req.NAME1 = acc.Name;
        req.NAME2 = acc.Account_Name2__c;
        req.City = acc.City__c;
        req.District = acc.Province__c;
        req.PostlCod1 = acc.Postal_Code__c;
        req.StandardAddressLine1 = acc.AddressLine_1__c;
        req.StandardAddressLine2 = acc.Addess_Line_2__c;
        req.Country = acc.Country_Code__c;
        req.CompanyCode = acc.Company_Code__c;
        req.ReconciliationAccount = extractCode(acc.Reconciliation_Account__c);
        req.PaymentTerms = extractCode(acc.Payment_Terms_FI_Role__c);
        req.BusinessVertical = acc.Business_Vertical__c;

        // Initialize contact lists
        req.nCustomer  = new List<SharePointAccountRequest.nCustomer>();
        req.nCustomer3 = new List<SharePointAccountRequest.nCustomer3>();
        req.nCustomer4 = new List<SharePointAccountRequest.nCustomer4>();

        // Contacts -> only Primary_Contact__c = TRUE will be serialized
        // NOTE: Minimal change = added Primary_Contact__c in SELECT and filtered WHERE clause
        List<Contact> contacts = [
            SELECT Email, Phone, MobilePhone, Primary_Contact__c
            FROM Contact
            WHERE AccountId = :acc.Id
            AND Primary_Contact__c = TRUE
        ];

        // If multiple primaries exist, all primary contacts will be sent (business rule prefers exactly 1)
        for (Contact c : contacts) {
            if (String.isNotBlank(c.Email)) {
                SharePointAccountRequest.nCustomer emailWrapper = new SharePointAccountRequest.nCustomer();
                emailWrapper.accountID = String.valueOf(acc.Id);
                emailWrapper.eMail = c.Email;
                req.nCustomer.add(emailWrapper);
            }
            if (String.isNotBlank(c.Phone)) {
                SharePointAccountRequest.nCustomer3 phoneWrapper = new SharePointAccountRequest.nCustomer3();
                phoneWrapper.AccountID = String.valueOf(acc.Id);
                phoneWrapper.telephone = c.Phone;
                req.nCustomer3.add(phoneWrapper);
            }
            if (String.isNotBlank(c.MobilePhone)) {
                SharePointAccountRequest.nCustomer4 mobileWrapper = new SharePointAccountRequest.nCustomer4();
                mobileWrapper.accountID = String.valueOf(acc.Id);
                mobileWrapper.mobile = c.MobilePhone;
                req.nCustomer4.add(mobileWrapper);
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
            req.SalesOrg = extractCode(sa.Sales_Org__c);
            req.DistributionChannel = extractCode(sa.Distribution_Channel__c);
            req.Division = extractCode(sa.Division__c);
            req.CustomerGroup = extractCode(sa.Customer_Group__c);
            req.SalesDistrict = extractCode(sa.Sales_District__c);
            req.SalesOffice = extractCode(sa.Sales_Office__c);
            req.CurrencyX = extractCode(sa.Currency__c);
            req.SalesGroup = extractCode(sa.Sales_Group__c);
            req.PriceGroup = extractCode(sa.Price_Group__c);
            req.PricingProcedureIndicator = extractCode(sa.Pricing_Procedure_Indicator__c);
            req.DeliveringPlant = extractCode(sa.Delivering_Plant__c);
            req.Incoterms = extractCode(sa.Incoterms__c);
            req.Incoterms2 = sa.Incoterms_Description__c;
            req.SalesPaymentTerms = extractCode(sa.Payment_Terms__c);
            req.CustomerAccountAssignmentGroup = extractCode(sa.Customer_Account_Assignment_Group__c);
        }

        // Tax Categories (nCustomer1)
        req.nCustomer1 = new List<SharePointAccountRequest.nCustomer1>();
        for (MD_Sales_Area__c sa : salesAreas) {
            SharePointAccountRequest.nCustomer1 w1 = new SharePointAccountRequest.nCustomer1();
            w1.accountID = String.valueOf(acc.Id);
            w1.tatyp = 'MWST';
            w1.taxkd = extractCode(sa.Output_Tax_Category_MWST_Code__c);
            req.nCustomer1.add(w1);

            SharePointAccountRequest.nCustomer1 w2 = new SharePointAccountRequest.nCustomer1();
            w2.accountID = String.valueOf(acc.Id);
            w2.tatyp = 'ZMWS';
            w2.taxkd = extractCode(sa.Output_Tax_Category_ZMWS_Code__c);
            req.nCustomer1.add(w2);

            SharePointAccountRequest.nCustomer1 w3 = new SharePointAccountRequest.nCustomer1();
            w3.accountID = String.valueOf(acc.Id);
            w3.tatyp = 'ZMST';
            w3.taxkd = extractCode(sa.Output_Tax_Category_ZMST_Code__c);
            req.nCustomer1.add(w3);

            SharePointAccountRequest.nCustomer1 w4 = new SharePointAccountRequest.nCustomer1();
            w4.accountID = String.valueOf(acc.Id);
            w4.tatyp = 'ZPK2';
            w4.taxkd = extractCode(sa.Output_Tax_Category_ZPK2_Code__c);
            req.nCustomer1.add(w4);
        }

        // Tax Numbers (nCustomer2)
        req.nCustomer2 = new List<SharePointAccountRequest.nCustomer2>();
        List<MD_Tax_Number__c> taxNumbers = [
            SELECT Tax_Category_Code__c, Category_Value__c
            FROM MD_Tax_Number__c
            WHERE Account__c = :acc.Id
        ];
        for (MD_Tax_Number__c t : taxNumbers) {
            SharePointAccountRequest.nCustomer2 w = new SharePointAccountRequest.nCustomer2();
            w.AccountID = String.valueOf(acc.Id);
            w.taxtype = extractCode(t.Tax_Category_Code__c);
            w.taxnumber = t.Category_Value__c;
            req.nCustomer2.add(w);
        }

        // Credit Profile (nCustomer6)
        req.nCustomer6 = new List<SharePointAccountRequest.nCustomer6>();
        List<Credit_Profile__c> creditProfiles = [
            SELECT Credit_Segment__c, Credit_Limit__c
            FROM Credit_Profile__c
            WHERE Account__c = :acc.Id
        ];
        for (Credit_Profile__c cp : creditProfiles) {
            SharePointAccountRequest.nCustomer6 w = new SharePointAccountRequest.nCustomer6();
            w.accountID = String.valueOf(acc.Id);
            w.creditSegment = String.isNotBlank(cp.Credit_Segment__c) ? cp.Credit_Segment__c.substringBefore(' ') : null;
            w.creditLimit = (cp.Credit_Limit__c != null) ? String.valueOf(cp.Credit_Limit__c) : null;
            req.nCustomer6.add(w);
        }

        return req;
    }
    
    @AuraEnabled
    public static void createAccountInSAP(Id accountId) {
        try {
            // Step 1: Get authentication token and base URL from TokenRequest
            TokenRequest.AuthTokenResult tokenResult = TokenRequest.getAuthToken();
            String accessToken = (tokenResult != null && tokenResult.success) ? tokenResult.token : null;
            String baseEndpointUrl = (tokenResult != null) ? tokenResult.baseEndpointUrl : null;
            
            if (String.isBlank(accessToken) || String.isBlank(baseEndpointUrl)) {
                System.debug('Failed to get authentication token or base URL');
                // NEW: Save failure details to Share_Point_Error_Message__c (no status change)
                saveErrorMessage(accountId, 'Authentication token or Base Endpoint URL is missing. Please verify TokenRequest configuration.');
                return;
            }

            // Step 2: Build SAP request
            SharePointAccountRequest sapRequest = buildSAPRequest(accountId);

            // Step 3: Convert to JSON and make SAP API call
            String payload = JSON.serializePretty(sapRequest).replace('"CurrencyX"', '"Currency"');
            System.debug('=================== SAP REQUEST JSON START ===================');
            System.debug(payload);
            System.debug('=================== SAP REQUEST JSON END ===================');

            HttpRequest req = new HttpRequest();
            req.setMethod('POST');
            // req.setEndpoint('https://webhook.site/b524af63-4991-4e4c-883c-9e3bb9678be7');
            req.setEndpoint(baseEndpointUrl + 'Sharepoint/InsertCustomer');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setBody(payload);
            req.setTimeout(60000); // 60 seconds timeout

            Http http = new Http();
            HttpResponse res = http.send(req);
            
            ApiLogUtil.get().add('InsertCustomer', baseEndpointUrl + 'Sharepoint/InsertCustomer', 'POST', payload, res.getStatusCode(), res.getBody());

            System.debug('=================== SAP RESPONSE START ===================');
            System.debug('SAP Response Status: ' + res.getStatusCode());
            System.debug('SAP Response Body: ' + res.getBody());
            System.debug('=================== SAP RESPONSE END ===================');

            if (res.getStatusCode() == 200) {
                // Parse the response
                SAPResponse sapResponse = (SAPResponse) JSON.deserialize(res.getBody(), SAPResponse.class);
                
                if (sapResponse.success && String.isNotBlank(sapResponse.data)) {
                    // Success path unchanged
                    Account acc = [SELECT Id FROM Account WHERE Id = :accountId LIMIT 1];
                    acc.Share_Point_Number__c = sapResponse.data;
                    acc.Account_Status__c = 'Pending Approval';
                    update acc;
                    
                    System.debug('Account updated successfully with SAP Customer Number: ' + sapResponse.data);
                } else {
                    // NEW: Application-level failure (200 but success=false or empty data)
                    String failureMsg = (sapResponse != null && String.isNotBlank(sapResponse.message))
                        ? 'API responded with failure. Message: ' + sapResponse.message
                        : 'API responded with failure. Raw Body: ' + res.getBody();
                    saveErrorMessage(accountId, failureMsg);
                    System.debug('SAP API returned error: ' + (sapResponse != null ? sapResponse.message : 'null message'));
                }
            } else {
                // NEW: Non-200 HTTP response
                String httpFailure = 'HTTP ' + String.valueOf(res.getStatusCode()) + ' - ' + res.getStatus() + '\n' + res.getBody();
                saveErrorMessage(accountId, httpFailure);
                System.debug('SAP API call failed. Status: ' + res.getStatus() + ', Body: ' + res.getBody());
            }

        } catch (Exception ex) {
            // NEW: Exception path
            String exMsg = 'Error during SAP integration: ' + ex.getMessage() + '\n' + ex.getStackTraceString();
            saveErrorMessage(accountId, exMsg);
            System.debug('Error during SAP integration: ' + ex.getMessage());
            System.debug('Stack trace: ' + ex.getStackTraceString());
        } finally {
            ApiLogUtil.get().flushSync();
        }
    }

    // Overloaded method for backward compatibility
    public static void createAccountInSAP(SharePointAccountRequest sapRequest) {
        System.debug('Warning: Using deprecated method. Use createAccountInSAP(Id accountId) instead.');
    }

    // Utility: Extract code before dash from picklist value
    public static String extractCode(String value) {
        if (String.isBlank(value)) return null;
        List<String> parts = value.split('-');
        return parts.isEmpty() ? null : parts[0].trim();
    }

    // NEW: Centralized failure logger (Status fields untouched)
    private static void saveErrorMessage(Id accountId, String message) {
        try {
            Account upd = new Account(
                Id = accountId,
                Share_Point_Error_Message__c = message
            );
            update upd;
            System.debug('Saved Share_Point_Error_Message__c for Account: ' + accountId);
        } catch (Exception updEx) {
            System.debug('Failed to save Share_Point_Error_Message__c: ' + updEx.getMessage());
        }
    }
}