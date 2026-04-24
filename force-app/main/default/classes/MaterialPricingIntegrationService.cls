public with sharing class MaterialPricingIntegrationService {

    // --- Response and row wrappers (lightweight) ---

    // Used only for typed convenience when data is an array
    public class PriceItem {
        public String materialNo;
        public Decimal amount;
    }

    // --- Public entrypoint for Anonymous Window ---
    // English comment: Validates date and runs the whole sync in one go.
    public static void syncByDate(String requestedDate) {
        // English comment: Basic format guard: must be exactly 8 digits (YYYYMMDD).
        if (String.isBlank(requestedDate) || requestedDate.length() != 8 || !requestedDate.isNumeric()) {
            System.debug('Invalid requestedDate. Expected YYYYMMDD like 20251104.');
            return;
        }

        HttpResponse res;
        String endpoint;
        String bodyForLog = null; // GET call, so no request body

        try {
            // --- Retrieve token and base URL using the same flow as CustomerDemandIntegrationService ---
            TokenRequest.AuthTokenResult tokenResult = TokenRequest.getAuthToken();
            if (tokenResult == null || !tokenResult.success || String.isBlank(tokenResult.token) || String.isBlank(tokenResult.baseEndpointUrl)) {
                System.debug('Auth failed or base endpoint missing.');
                return;
            }

            // English comment: Build endpoint as per spec: baseEndpointUrl + 'SAP/GetMaterialPricingInfo/{RequestedDate}'
            endpoint = tokenResult.baseEndpointUrl;
            if (!endpoint.endsWith('/')) endpoint += '/';
            endpoint += 'SAP/GetMaterialPricingInfo/' + requestedDate;

            System.debug('Resolved Pricing Endpoint: ' + endpoint);

            // --- Prepare and execute GET callout ---
            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint(endpoint);
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + tokenResult.token);
            req.setTimeout(60000);

            Http http = new Http();
            res = http.send(req);

            // English comment: Log the API call using the same util style as your other class.
            ApiLogUtil.get().add('GetMaterialPricingInfo', endpoint, 'GET', bodyForLog, res.getStatusCode(), res.getBody());

            System.debug('=================== MATERIAL PRICING RESPONSE START ===================');
            System.debug('Status Code: ' + res.getStatusCode());
            System.debug('Status: ' + res.getStatus());
            System.debug('Body: ' + res.getBody());
            System.debug('=================== MATERIAL PRICING RESPONSE END =====================');

            if (res.getStatusCode() != 200) {
                // English comment: Non-200 means we stop gracefully (no updates).
                System.debug('Non-200 response received. Aborting updates.');
                return;
            }

            // --- Parse JSON robustly (handles "data": "No Data" as well as array) ---
            Object raw = JSON.deserializeUntyped(res.getBody());
            if (!(raw instanceof Map<String, Object>)) {
                System.debug('Unexpected response shape.');
                return;
            }
            Map<String, Object> root = (Map<String, Object>) raw;
            Boolean apiSuccess = (root.containsKey('success') && root.get('success') instanceof Boolean)
                ? (Boolean) root.get('success') : false;

            // English comment: If API signals failure, stop.
            if (!apiSuccess) {
                System.debug('API success=false. Message: ' + (String) root.get('message'));
                return;
            }

            Object dataNode = root.get('data');

            // English comment: Case 1 — "No Data" (string)
            if (dataNode == null) {
                System.debug('data is null. Nothing to update.');
                return;
            }
            if (dataNode instanceof String) {
                String ds = (String) dataNode;
                if (ds.equalsIgnoreCase('No Data')) {
                    System.debug('API returned "No Data". Nothing to update.');
                    return;
                }
                // English comment: If it's some other string, we still exit gracefully.
                System.debug('Unexpected string in data: ' + ds);
                return;
            }

            // English comment: Case 2 — Array of objects [{materialNo, amount}, ...]
            if (!(dataNode instanceof List<Object>)) {
                System.debug('Unexpected data type. Expected array.');
                return;
            }

            List<Object> rows = (List<Object>) dataNode;
            if (rows.isEmpty()) {
                System.debug('Empty data array. Nothing to update.');
                return;
            }

            // English comment: Collect material numbers and amounts.
            Map<String, Decimal> matToAmount = new Map<String, Decimal>();
            for (Object o : rows) {
                if (!(o instanceof Map<String, Object>)) continue;
                Map<String, Object> row = (Map<String, Object>) o;

                String materialNo = (row.containsKey('materialNo') && row.get('materialNo') != null)
                    ? String.valueOf(row.get('materialNo')) : null;

                Decimal amount;
                Object amt = row.get('amount');
                if (amt == null) continue;
                if (amt instanceof Decimal) {
                    amount = (Decimal) amt;
                } else if (amt instanceof Integer) {
                    amount = Decimal.valueOf((Integer) amt);
                } else if (amt instanceof Long) {
                    amount = Decimal.valueOf((Long) amt);
                } else if (amt instanceof Double) {
                    amount = Decimal.valueOf((Double) amt);
                } else {
                    try {
                        amount = Decimal.valueOf(String.valueOf(amt));
                    } catch (Exception e) {
                        continue;
                    }
                }

                if (String.isNotBlank(materialNo)) {
                    matToAmount.put(materialNo, amount);
                }
            }

            if (matToAmount.isEmpty()) {
                System.debug('No valid rows to process after parsing.');
                return;
            }

            // English comment: Query matching products using external-id field Material_Number__c (unique).
            List<MD_Product2__c> products = [
                SELECT Id, Material_Number__c, Price__c
                FROM MD_Product2__c
                WHERE Material_Number__c IN :matToAmount.keySet()
            ];

            if (products.isEmpty()) {
                System.debug('No matching MD_Product2__c found for provided materialNo(s).');
                return;
            }

            // English comment: Prepare updates (partial success tolerant).
            List<MD_Product2__c> toUpdate = new List<MD_Product2__c>();
            for (MD_Product2__c p : products) {
                if (matToAmount.containsKey(p.Material_Number__c)) {
                    p.Price__c = matToAmount.get(p.Material_Number__c);
                    toUpdate.add(p);
                }
            }

            if (!toUpdate.isEmpty()) {
                Database.SaveResult[] sr = Database.update(toUpdate, /* allOrNone */ false);
                // English comment: Optional debug per-row errors (kept light).
                for (Integer i = 0; i < sr.size(); i++) {
                    if (!sr[i].isSuccess()) {
                        for (Database.Error e : sr[i].getErrors()) {
                            System.debug('Update error on ' + toUpdate[i].Material_Number__c + ': ' + e.getMessage());
                        }
                    }
                }
                System.debug('Update attempted for ' + toUpdate.size() + ' record(s).');
            } else {
                System.debug('Nothing to update after mapping.');
            }

        } catch (Exception ex) {
            System.debug('Exception in syncByDate: ' + ex.getMessage());
            System.debug(ex.getStackTraceString());
        } finally {
            // English comment: Ensure logs are flushed like in your other service.
            ApiLogUtil.get().flushSync();
        }
    }
}