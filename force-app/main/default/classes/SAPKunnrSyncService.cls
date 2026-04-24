public with sharing class SAPKunnrSyncService {

    @TestVisible private static Boolean DEBUG = true;
    private static void dbg(String s) {
        if (DEBUG) System.debug(LoggingLevel.WARN, '[SAPKunnrSync] ' + s);
    }

    // Helpers
    private static final JSONUtil J = new JSONUtil();
    private static final PicklistMapperBridge PM = new PicklistMapperBridge();

    // Field describe caches
    private static final Map<String, SObjectField> SA_FIELDS =
        MD_Sales_Area__c.SObjectType.getDescribe().fields.getMap();
    private static final Map<String, SObjectField> ACC_FIELDS =
        Account.SObjectType.getDescribe().fields.getMap();

    // SAP query fallbacks
    private static final List<String> QUERY_KEYS = new List<String>{
        'accountNumber', 'AccountNumber', 'accountNo', 'AccountNo', 'kunnr', 'KUNNR'
    };

    // Aliases used by the smart mapper (inner class cannot have static fields)
    private static final Map<String, List<String>> PM_FIELD_ALIASES = new Map<String, List<String>>{
        // Sales Area
        'Plant__c' => new List<String>{ 'Delivering_Plant__c' },
        'Payment_Terms_SD__c' => new List<String>{ 'Payment_Terms__c', 'Payment_Terms_SD__c' },
        'Account_Assignment_Group__c' => new List<String>{ 'Customer_Account_Assignment_Group__c' },
        'Sales_Org__c' => new List<String>{ 'Sales_Org__c' },
        'Distribution_Channel__c' => new List<String>{ 'Distribution_Channel__c' },
        'Division__c' => new List<String>{ 'Division__c' },
        'Incoterms__c' => new List<String>{ 'Incoterms__c' },
        'Currency__c' => new List<String>{ 'Currency__c' },

        // Tax Number
        'Tax_Category_Code__c' => new List<String>{ 'Tax_Category_Code__c' },

        // Credit Profile
        'Credit_Segment__c' => new List<String>{ 'Credit_Segment__c' },

        // Account (optional convenience)
        'Country_Code__c' => new List<String>{ 'Country_Code__c' },
        'Company_Code__c' => new List<String>{ 'Company_Code__c' },
        'Reconciliation_Account__c' => new List<String>{ 'Reconciliation_Account__c' },
        'Business_Vertical__c' => new List<String>{ 'Business_Vertical__c' }
    };

    // =============== UI DTOs ===============
    public class AccountBundle {
        @AuraEnabled public Account account;
        @AuraEnabled public List<MD_Sales_Area__c> salesAreas;
        @AuraEnabled public List<MD_Tax_Number__c> taxNumbers;
        @AuraEnabled public List<Credit_Profile__c> creditProfiles;
    }

    public class KunnrUIResult {
        @AuraEnabled public String status;   // SUCCESS | NO_DATA | ERROR
        @AuraEnabled public String message;
        @AuraEnabled public AccountBundle bundle;
    }

    // =============== Public (LWC / Anonymous) ===============
    @AuraEnabled(cacheable=false)
    public static KunnrUIResult runAndFetchBundleByKunnr(String kunnr) {
        KunnrUIResult res = new KunnrUIResult();

        try {
            // Sanitize and validate
            if (kunnr != null) kunnr = kunnr.replaceAll('[^0-9]', '');
            if (!isValidKunnr(kunnr)) {
                res.status = 'ERROR';
                res.message = 'Invalid KUNNR. It must be 10 digits and start with 3.';
                return res;
            }

            // Auth
            TokenRequest.AuthTokenResult tok = TokenRequest.getAuthToken();
            if (tok == null || tok.success != true ||
                String.isBlank(tok.token) || String.isBlank(tok.baseEndpointUrl)) {
                res.status = 'ERROR';
                res.message = 'Authentication failed while fetching SAP token/base URL.';
                return res;
            }

            // Callouts with fallbacks
            HttpResponse r;
            try {
                r = callSapWithFallbacks(tok.baseEndpointUrl, tok.token, kunnr);
            } catch (Exception ex) {
                res.status = 'ERROR';
                res.message = 'HTTP callout failed: ' + ex.getMessage();
                return res;
            }

            if (r == null || r.getStatusCode() != 200) {
                res.status = 'ERROR';
                res.message = extractErrorMessage(r);
                return res;
            }

            // Parse top-level
            Map<String, Object> top = (Map<String, Object>) JSON.deserializeUntyped(r.getBody());
            Boolean ok = J.getBool(top, 'success');
            Object dataRaw = top != null ? top.get('data') : null;

            if (ok != true) {
                res.status = 'ERROR';
                res.message = J.getString(top, 'message');
                if (String.isBlank(res.message)) res.message = 'SAP responded with success=false.';
                return res;
            }

            // "No Data Available" handling
            if (dataRaw instanceof String) {
                res.status = 'NO_DATA';
                res.message = String.valueOf(dataRaw);
                return res;
            }

            List<Object> rows = J.asList(dataRaw);
            if (rows == null || rows.isEmpty()) {
                res.status = 'NO_DATA';
                res.message = 'No Data Available';
                return res;
            }

            List<Map<String, Object>> valid = new List<Map<String, Object>>();
            for (Object o : rows) {
                Map<String, Object> row = (Map<String, Object>) o;
                if (!String.isBlank(J.getString(row, 'kunnr'))) valid.add(row);
            }
            if (valid.isEmpty()) {
                res.status = 'NO_DATA';
                res.message = 'No Data Available';
                return res;
            }

            try {
                processPayload(valid);
            } catch (Exception ex) {
                res.status = 'ERROR';
                res.message = 'Processing failed: ' + ex.getMessage();
                return res;
            }

            try {
                res.bundle = fetchBundle(kunnr);
                res.status = 'SUCCESS';
                res.message = 'Success';
                return res;
            } catch (Exception ex) {
                res.status = 'ERROR';
                res.message = 'Post-processing fetch failed: ' + ex.getMessage();
                return res;
            }
        } finally {
            ApiLogUtil.get().flushSync();
        }
    }

    // =============== HTTP helpers ===============
    private static HttpResponse callSapWithFallbacks(String baseUrl, String bearer, String kunnr) {
        for (String key : QUERY_KEYS) {
            String endpoint = buildEndpointQuery(baseUrl, kunnr, key);
            dbg('Trying QUERY key=' + key + ' -> ' + endpoint);
            HttpResponse r = sendGet(endpoint, bearer);
            Integer sc = r != null ? r.getStatusCode() : -1;
            dbg('Status=' + sc + ' bodySnippet=' + (r != null ? r.getBody().left(160) : 'null'));
            if (sc == 200) return r;
            if (sc == 401 || sc == 403 || sc >= 500) return r;
        }
        String endpointPath = buildEndpointPath(baseUrl, kunnr);
        dbg('Trying PATH -> ' + endpointPath);
        return sendGet(endpointPath, bearer);
    }

    private static String buildEndpointQuery(String baseUrl, String kunnr, String keyParam) {
        String path = 'SAP/GetAccountDetailsByAccountNumber';
        String url  = UrlJoiner.join(baseUrl, path);
        String qp   = keyParam + '=' + EncodingUtil.urlEncode(kunnr, 'UTF-8');
        return url + (url.contains('?') ? '&' : '?') + qp;
    }

    private static String buildEndpointPath(String baseUrl, String kunnr) {
        String path = 'SAP/GetAccountDetailsByAccountNumber/' + EncodingUtil.urlEncode(kunnr, 'UTF-8');
        return UrlJoiner.join(baseUrl, path);
    }

    private static HttpResponse sendGet(String endpoint, String bearerToken) {
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(endpoint);
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + bearerToken);
        req.setTimeout(120000);
        HttpResponse res = new Http().send(req);

        ApiLogUtil.get().add('GetAccountDetailsByAccountNumber', endpoint, 'GET', null, res.getStatusCode(), res.getBody());

        return res;
    }

    private static String extractErrorMessage(HttpResponse r) {
        if (r == null) return 'HTTP response is null.';
        try {
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(r.getBody());
            String msg = J.getString(body, 'message');
            if (!String.isBlank(msg)) return msg;
        } catch (Exception ignore) { }
        String snip = '';
        try { snip = r.getBody() != null ? r.getBody().left(300) : ''; } catch (Exception e) {}
        return 'HTTP ' + r.getStatusCode() + ' - ' + r.getStatus() + (String.isBlank(snip) ? '' : (' | ' + snip));
    }

    // =============== Processing pipeline ===============
    private static void processPayload(List<Map<String, Object>> rows) {
        Set<String> kunnrs = new Set<String>();
        for (Map<String, Object> row : rows) {
            String k = J.getString(row, 'kunnr');
            if (!String.isBlank(k)) kunnrs.add(k);
        }
        if (kunnrs.isEmpty()) return;

        Map<String, Account> accByKunnr = new Map<String, Account>();
        for (Account a : [
            SELECT Id, Name, SAP_Customer_Number__c, Phone, Email__c, BillingCity, BillingPostalCode,
                   BillingCountry, BillingState, BillingStreet, RecordTypeId
            FROM Account
            WHERE SAP_Customer_Number__c IN :kunnrs
        ]) {
            accByKunnr.put(a.SAP_Customer_Number__c, a);
        }

        Id funcRt = getFunctionalAccountRtId();
        List<Account> accsToUpsert = new List<Account>();

        Map<String, List<Map<String, Object>>> rowsSalesArea = new Map<String, List<Map<String, Object>>>();
        Map<String, List<Map<String, Object>>> rowsTaxNums   = new Map<String, List<Map<String, Object>>>();
        Map<String, List<Map<String, Object>>> rowsCredits   = new Map<String, List<Map<String, Object>>>();
        Map<String, List<Map<String, Object>>> rowsTaxCats   = new Map<String, List<Map<String, Object>>>();

        // Contact data per KUNNR (email/phone/mobile/lastName)
        Map<String, Map<String, String>> contactDataByKunnr = new Map<String, Map<String, String>>();

        for (Map<String, Object> row : rows) {
            String kunnr = J.getString(row, 'kunnr');
            if (String.isBlank(kunnr)) continue;

            Account acc = accByKunnr.containsKey(kunnr) ? accByKunnr.get(kunnr) : new Account();
            acc.SAP_Customer_Number__c = kunnr;

            // Name composition
            String name1 = J.getString(row, 'name1');
            String name2 = J.getString(row, 'name2');
            String nm = String.isBlank(name2) ? name1 : (name1 + ' ' + name2);
            if (!String.isBlank(nm)) acc.Name = nm;

            // Prepare contact data holder for this KUNNR
            Map<String, String> contactData = contactDataByKunnr.containsKey(kunnr)
                ? contactDataByKunnr.get(kunnr)
                : new Map<String, String>();
            if (!String.isBlank(nm)) {
                contactData.put('lastName', nm);
            } else if (!String.isBlank(name1)) {
                contactData.put('lastName', name1);
            }

            // Standard billing fields
            acc.BillingCity        = J.getString(row, 'city');
            acc.BillingState       = J.getString(row, 'district');
            acc.BillingPostalCode  = J.getString(row, 'postlcod1');
            acc.BillingCountry     = J.getString(row, 'country');
            acc.BillingStreet      = J.joinNonBlank(' ', new List<String>{
                J.getString(row, 'strsuppl3'),
                J.getString(row, 'location')
            });

            // Custom address on Account
            maybeSet(acc, 'AddressLine_1__c', J.getString(row, 'strsuppl3'));
            maybeSet(acc, 'Addess_Line_2__c', J.getString(row, 'location'));
            maybeSet(acc, 'Province__c',       J.getString(row, 'district'));
            maybeSet(acc, 'City__c',           J.getString(row, 'city'));
            maybeSet(acc, 'Postal_Code__c',    J.getString(row, 'postlcod1'));

            // Account picklists via mapper (allowed-only)
            setPicklistWithMapping(acc, 'Country_Code__c',           'Account.Country_Code__c',           J.getString(row, 'country'));
            setPicklistWithMapping(acc, 'Company_Code__c',           'Account.Company_Code__c',           J.getString(row, 'bukrs'));
            setPicklistWithMapping(acc, 'Reconciliation_Account__c', 'Account.Reconciliation_Account__c', J.getString(row, 'akont'));
            setPicklistWithMapping(acc, 'Business_Vertical__c',      'Account.Business_Vertical__c',      J.getString(row, 'searchterm1'));

            // Contacts (Account-level + collect for Contact creation)
            List<Map<String, Object>> custEmail = J.asListMap(row.get('n_CUSTMER'));
            if (!custEmail.isEmpty()) {
                String email = J.getString(custEmail[0], 'eMail');
                if (!String.isBlank(email) && ACC_FIELDS.containsKey('Email__c')) {
                    acc.put('Email__c', email);
                }
                if (!String.isBlank(email)) {
                    contactData.put('email', email);
                }
            }

            List<Map<String, Object>> custTel = J.asListMap(row.get('n_CUSTMER3'));
            if (!custTel.isEmpty()) {
                String tel = J.getString(custTel[0], 'telephone');
                if (!String.isBlank(tel)) {
                    acc.Phone = tel;
                    contactData.put('phone', tel);
                }
            }

            List<Map<String, Object>> custMob = J.asListMap(row.get('n_CUSTMER4'));
            if (!custMob.isEmpty()) {
                String mob = J.getString(custMob[0], 'mobile');
                if (!String.isBlank(mob)) {
                    acc.Phone = mob;
                    contactData.put('mobile', mob);
                }
            }

            if (!contactData.isEmpty()) {
                contactDataByKunnr.put(kunnr, contactData);
            }

            if (funcRt != null) acc.RecordTypeId = funcRt;
            accsToUpsert.add(acc);

            // Child buckets
            List<Map<String, Object>> sa = J.asListMap(row.get('cusT_SD'));
            if (!sa.isEmpty()) rowsSalesArea.put(kunnr, sa);

            List<Map<String, Object>> t1 = J.asListMap(row.get('n_CUSTMER2'));
            if (!t1.isEmpty()) rowsTaxNums.put(kunnr, t1);

            List<Map<String, Object>> c6 = J.asListMap(row.get('n_CUSTMER6'));
            if (!c6.isEmpty()) rowsCredits.put(kunnr, c6);

            List<Map<String, Object>> c1 = J.asListMap(row.get('n_CUSTMER1'));
            if (!c1.isEmpty()) rowsTaxCats.put(kunnr, c1);
        }

        dbg('processPayload: kunnrs=' + kunnrs.size()
            + ', accsToUpsert=' + accsToUpsert.size()
            + ', contactDataByKunnr=' + contactDataByKunnr.size());

        // Upsert accounts by External Id
        Database.upsert(accsToUpsert, Account.SAP_Customer_Number__c);

        // Resolve Account Ids
        Map<String, Id> accIdByKunnr = new Map<String, Id>();
        for (Account a : [
            SELECT Id, SAP_Customer_Number__c
            FROM Account
            WHERE SAP_Customer_Number__c IN :kunnrs
        ]) {
            accIdByKunnr.put(a.SAP_Customer_Number__c, a.Id);
        }

        dbg('processPayload: accIdByKunnr size=' + accIdByKunnr.size());

        // Upsert children
        for (String k : accIdByKunnr.keySet()) {
            Id accId = accIdByKunnr.get(k);
            if (accId == null) continue;

            if (rowsSalesArea.containsKey(k)) upsertSalesAreas(accId, rowsSalesArea.get(k));
            if (rowsTaxNums.containsKey(k))   upsertTaxNumbers(accId, rowsTaxNums.get(k));
            if (rowsCredits.containsKey(k))   upsertCreditProfiles(accId, rowsCredits.get(k));
            if (rowsTaxCats.containsKey(k))   patchSalesAreaOutputTax(accId, rowsTaxCats.get(k));
        }

        // Upsert primary Contact per Account/KUNNR based on collected data
        upsertPrimaryContacts(accIdByKunnr, contactDataByKunnr);
    }

    // ---- Sales Areas (composite key: Org | DC | Division)
    private static void upsertSalesAreas(Id accountId, List<Map<String, Object>> rows) {
        if (accountId == null || rows == null || rows.isEmpty()) return;

        Map<String, MD_Sales_Area__c> existing = new Map<String, MD_Sales_Area__c>();
        for (MD_Sales_Area__c ex : [
            SELECT Id, Parent_Account__c, Sales_Org__c, Distribution_Channel__c, Division__c
            FROM MD_Sales_Area__c
            WHERE Parent_Account__c = :accountId
        ]) {
            String key = norm(ex.Sales_Org__c) + '|' + norm(ex.Distribution_Channel__c) + '|' + norm(ex.Division__c);
            existing.put(key, ex);
        }

        List<MD_Sales_Area__c> toSave = new List<MD_Sales_Area__c>();

        for (Map<String, Object> sa : rows) {
            MD_Sales_Area__c rec = new MD_Sales_Area__c();
            rec.Parent_Account__c = accountId;

            setPicklistWithMapping(rec, 'Sales_Org__c',                'MD_Sales_Area__c.Sales_Org__c',                J.getString(sa, 'vkorg'));
            setPicklistWithMapping(rec, 'Distribution_Channel__c',     'MD_Sales_Area__c.Distribution_Channel__c',     J.getString(sa, 'vtweg'));
            setPicklistWithMapping(rec, 'Division__c',                 'MD_Sales_Area__c.Division__c',                 J.getString(sa, 'spart'));
            maybeSet(rec, 'District__c', J.getString(sa, 'bzirk'));
            setPicklistWithMapping(rec, 'Plant__c',                    'MD_Sales_Area__c.Delivering_Plant__c',         J.getString(sa, 'vwerk'));
            setPicklistWithMapping(rec, 'Customer_Group__c',           'MD_Sales_Area__c.Customer_Group__c',           J.getString(sa, 'kdgrp'));
            setPicklistWithMapping(rec, 'Sales_Office__c',             'MD_Sales_Area__c.Sales_Office__c',             J.getString(sa, 'vkbur'));
            setPicklistWithMapping(rec, 'Currency__c',                 'MD_Sales_Area__c.Currency__c',                 J.getString(sa, 'waers'));
            setPicklistWithMapping(rec, 'Sales_Group__c',              'MD_Sales_Area__c.Sales_Group__c',              J.getString(sa, 'vkgrp'));
            setPicklistWithMapping(rec, 'Price_Group__c',              'MD_Sales_Area__c.Price_Group__c',              J.getString(sa, 'konda'));
            setPicklistWithMapping(rec, 'Pricing_Procedure__c',        'MD_Sales_Area__c.Pricing_Procedure_Indicator__c', J.getString(sa, 'kalks'));
            setPicklistWithMapping(rec, 'Shipping_Conditions__c',      'MD_Sales_Area__c.Shipping_Conditions__c',      J.getString(sa, 'vsbed'));
            setPicklistWithMapping(rec, 'Incoterms__c',                'MD_Sales_Area__c.Incoterms__c',                J.getString(sa, 'inco1'));
            maybeSet(rec, 'Incoterms_Location__c', J.getString(sa, 'inco2'));

            String terms = !String.isBlank(J.getString(sa, 'ztermsd'))
                ? J.getString(sa, 'ztermsd')
                : J.getString(sa, 'zterm');
            setPicklistWithMapping(rec, 'Payment_Terms_SD__c',         'MD_Sales_Area__c.Payment_Terms__c',            terms);
            setPicklistWithMapping(rec, 'Account_Assignment_Group__c', 'MD_Sales_Area__c.Customer_Account_Assignment_Group__c', J.getString(sa, 'ktgrd'));

            String key = norm((String) rec.get('Sales_Org__c')) + '|' +
                         norm((String) rec.get('Distribution_Channel__c')) + '|' +
                         norm((String) rec.get('Division__c'));
            if (existing.containsKey(key)) rec.Id = existing.get(key).Id;

            toSave.add(rec);
        }

        toSave = (List<MD_Sales_Area__c>) dedupeById((List<SObject>) toSave);

        List<MD_Sales_Area__c> ins = new List<MD_Sales_Area__c>();
        List<MD_Sales_Area__c> upd = new List<MD_Sales_Area__c>();
        for (MD_Sales_Area__c s : toSave) {
            if (s.Id == null) ins.add(s);
            else upd.add(s);
        }
        if (!ins.isEmpty()) insert ins;
        if (!upd.isEmpty()) update upd;
    }

    // ---- Tax Numbers (composite key: Tax Category Code | Category Value)
    private static void upsertTaxNumbers(Id accountId, List<Map<String, Object>> rows) {
        if (accountId == null || rows == null || rows.isEmpty()) return;

        Map<String, MD_Tax_Number__c> desired = new Map<String, MD_Tax_Number__c>();
        for (Map<String, Object> r : rows) {
            String taxNum  = J.getString(r, 'taxnumber');
            String typeRaw = J.getString(r, 'taxtype');
            if (String.isBlank(taxNum)) continue;

            String mappedCat = PM.mapToAllowed(new MD_Tax_Number__c(), 'Tax_Category_Code__c', typeRaw);
            String key = norm(mappedCat) + '|' + norm(taxNum);

            MD_Tax_Number__c tn = new MD_Tax_Number__c();
            tn.Account__c = accountId;
            tn.Tax_Category_Code__c = mappedCat;
            tn.Category_Value__c = taxNum;
            desired.put(key, tn);
        }
        if (desired.isEmpty()) return;

        Map<String, MD_Tax_Number__c> existing = new Map<String, MD_Tax_Number__c>();
        for (MD_Tax_Number__c ex : [
            SELECT Id, Account__c, Tax_Category_Code__c, Category_Value__c
            FROM MD_Tax_Number__c
            WHERE Account__c = :accountId
        ]) {
            String key = norm(ex.Tax_Category_Code__c) + '|' + norm(ex.Category_Value__c);
            existing.put(key, ex);
        }

        List<MD_Tax_Number__c> toSave = new List<MD_Tax_Number__c>();
        for (String key : desired.keySet()) {
            MD_Tax_Number__c target = desired.get(key);
            MD_Tax_Number__c ex = existing.get(key);
            if (ex != null) target.Id = ex.Id;
            toSave.add(target);
        }

        toSave = (List<MD_Tax_Number__c>) dedupeById((List<SObject>) toSave);

        List<MD_Tax_Number__c> ins = new List<MD_Tax_Number__c>();
        List<MD_Tax_Number__c> upd = new List<MD_Tax_Number__c>();
        for (MD_Tax_Number__c t : toSave) {
            if (t.Id == null) ins.add(t);
            else upd.add(t);
        }
        if (!ins.isEmpty()) insert ins;
        if (!upd.isEmpty()) update upd;
    }

    // ---- Credit Profiles (composite key: Credit Segment)
    private static void upsertCreditProfiles(Id accountId, List<Map<String, Object>> rows) {
        if (accountId == null || rows == null || rows.isEmpty()) return;

        Map<String, Credit_Profile__c> desired = new Map<String, Credit_Profile__c>();
        for (Map<String, Object> r : rows) {
            String segCode = J.getString(r, 'creditSegment');
            if (String.isBlank(segCode)) continue;

            String mappedSeg = PM.mapToAllowed(new Credit_Profile__c(), 'Credit_Segment__c', segCode);
            String key = norm(mappedSeg);

            Credit_Profile__c cp = new Credit_Profile__c();
            cp.Account__c = accountId;
            cp.Credit_Segment__c = mappedSeg;
            cp.Credit_Limit__c = J.getDecimal(r, 'creditLimit');
            cp.Outstanding_Amount__c = J.getDecimal(r, 'outstandingAmount');
            desired.put(key, cp);
        }
        if (desired.isEmpty()) return;

        Map<String, Credit_Profile__c> existing = new Map<String, Credit_Profile__c>();
        for (Credit_Profile__c ex : [
            SELECT Id, Account__c, Credit_Segment__c
            FROM Credit_Profile__c
            WHERE Account__c = :accountId
        ]) {
            existing.put(norm(ex.Credit_Segment__c), ex);
        }

        List<Credit_Profile__c> toSave = new List<Credit_Profile__c>();
        for (String key : desired.keySet()) {
            Credit_Profile__c target = desired.get(key);
            Credit_Profile__c ex = existing.get(key);
            if (ex != null) target.Id = ex.Id;
            toSave.add(target);
        }

        toSave = (List<Credit_Profile__c>) dedupeById((List<SObject>) toSave);

        List<Credit_Profile__c> ins = new List<Credit_Profile__c>();
        List<Credit_Profile__c> upd = new List<Credit_Profile__c>();
        for (Credit_Profile__c c : toSave) {
            if (c.Id == null) ins.add(c);
            else upd.add(c);
        }
        if (!ins.isEmpty()) insert ins;
        if (!upd.isEmpty()) update upd;
    }

    // ---- Primary Contact per Account/KUNNR
    private static void upsertPrimaryContacts(
        Map<String, Id> accIdByKunnr,
        Map<String, Map<String, String>> contactDataByKunnr
    ) {
        dbg('upsertPrimaryContacts: accIdByKunnr=' +
            (accIdByKunnr == null ? 0 : accIdByKunnr.size()) +
            ', contactDataByKunnr=' +
            (contactDataByKunnr == null ? 0 : contactDataByKunnr.size()));

        if (accIdByKunnr == null || accIdByKunnr.isEmpty()) return;
        if (contactDataByKunnr == null || contactDataByKunnr.isEmpty()) return;

        Map<Id, Map<String, String>> dataByAccId = new Map<Id, Map<String, String>>();
        Set<Id> accIds = new Set<Id>();

        // Prepare contact data per Account Id, only when at least one contact field exists
        for (String kunnr : contactDataByKunnr.keySet()) {
            Id accId = accIdByKunnr.get(kunnr);
            Map<String, String> data = contactDataByKunnr.get(kunnr);

            dbg('ContactData for KUNNR=' + kunnr + ' accId=' + accId + ' rawData=' + data);

            if (accId == null) continue;
            if (data == null) continue;

            String email  = data.containsKey('email')  ? data.get('email')  : null;
            String phone  = data.containsKey('phone')  ? data.get('phone')  : null;
            String mobile = data.containsKey('mobile') ? data.get('mobile') : null;

            Boolean hasAny = !String.isBlank(email) || !String.isBlank(phone) || !String.isBlank(mobile);
            if (!hasAny) {
                dbg('Skipping KUNNR=' + kunnr + ' for Contact (no email/phone/mobile)');
                continue; // Do not create a Contact if there is no email/phone/mobile
            }

            dataByAccId.put(accId, data);
            accIds.add(accId);
        }

        dbg('upsertPrimaryContacts: dataByAccId size=' + dataByAccId.size() + ', accIds size=' + accIds.size());

        if (accIds.isEmpty()) return;

        // Try to find existing Contact per Account whose LastName matches the expected name
        Map<Id, Contact> existingByAcc = new Map<Id, Contact>();
        List<Contact> contacts = [
            SELECT Id, AccountId, LastName, Email, Phone, MobilePhone
            FROM Contact
            WHERE AccountId IN :accIds
        ];

        for (Contact c : contacts) {
            Map<String, String> data = dataByAccId.get(c.AccountId);
            if (data == null) continue;

            String expectedLastName = data.get('lastName');
            if (String.isBlank(expectedLastName)) continue;

            if (norm(c.LastName) == norm(expectedLastName)) {
                existingByAcc.put(c.AccountId, c);
            }
        }

        List<Contact> toInsert = new List<Contact>();
        List<Contact> toUpdate = new List<Contact>();

        for (Id accId : dataByAccId.keySet()) {
            Map<String, String> data = dataByAccId.get(accId);
            if (data == null) continue;

            String lastName = data.get('lastName');
            if (String.isBlank(lastName)) {
                lastName = 'Customer';
            }

            Contact target;
            if (existingByAcc.containsKey(accId)) {
                // Re-use existing contact for this account
                target = existingByAcc.get(accId);
            } else {
                // Create a new contact for this account
                target = new Contact();
                target.AccountId = accId;
            }

            // Always keep LastName in sync with the account name from SAP
            target.LastName = lastName;

            String email = data.get('email');
            if (!String.isBlank(email)) {
                target.Email = email;
            }

            String phone = data.get('phone');
            if (!String.isBlank(phone)) {
                target.Phone = phone;
            }

            String mobile = data.get('mobile');
            if (!String.isBlank(mobile)) {
                target.MobilePhone = mobile;
            }

            if (target.Id == null) {
                toInsert.add(target);
            } else {
                toUpdate.add(target);
            }
        }

        dbg('upsertPrimaryContacts: toInsert=' + toInsert.size() + ', toUpdate=' + toUpdate.size());

        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    // ---- Patch Output Tax Categories on Sales Areas
    private static void patchSalesAreaOutputTax(Id accountId, List<Map<String, Object>> rowsTax) {
        if (accountId == null || rowsTax == null || rowsTax.isEmpty()) return;

        Map<String, String> tatypToField = new Map<String, String>{
            'MWST' => 'Output_Tax_Category_MWST_Code__c',
            'ZMST' => 'Output_Tax_Category_ZMST_Code__c',
            'ZMWS' => 'Output_Tax_Category_ZMWS_Code__c',
            'ZPK2' => 'Output_Tax_Category_ZPK2_Code__c'
        };

        List<MD_Sales_Area__c> areas = [
            SELECT Id, Parent_Account__c, Sales_Org__c, Distribution_Channel__c, Division__c,
                   Output_Tax_Category_MWST_Code__c, Output_Tax_Category_ZMST_Code__c,
                   Output_Tax_Category_ZMWS_Code__c, Output_Tax_Category_ZPK2_Code__c
            FROM MD_Sales_Area__c
            WHERE Parent_Account__c = :accountId
        ];
        if (areas.isEmpty()) return;

        List<MD_Sales_Area__c> toUpdate = new List<MD_Sales_Area__c>();

        for (Map<String, Object> t : rowsTax) {
            String tatyp = J.getString(t, 'tatyp');
            String taxkd = J.getString(t, 'taxkd');
            String fieldName = tatypToField.get(tatyp);
            if (String.isBlank(fieldName)) continue;

            for (MD_Sales_Area__c area : areas) {
                if (!SA_FIELDS.containsKey(fieldName)) continue;
                String mapped = PM.mapToAllowed(new MD_Sales_Area__c(), fieldName, taxkd);
                if (!String.isBlank(mapped) && picklistAllows(area.getSObjectType(), fieldName, mapped)) {
                    area.put(fieldName, mapped);
                    toUpdate.add(area);
                } else {
                    dbg('Skip unmapped sales-area tax for ' + fieldName + ' -> ' + taxkd);
                }
            }
        }

        if (!toUpdate.isEmpty()) {
            toUpdate = (List<MD_Sales_Area__c>) dedupeById((List<SObject>) toUpdate);
            update toUpdate;
        }
    }

    // =============== Bundle fetch for UI ===============
    private static AccountBundle fetchBundle(String kunnr) {
        Account acc = [
            SELECT Id, Name, SAP_Customer_Number__c
            FROM Account
            WHERE SAP_Customer_Number__c = :kunnr
            LIMIT 1
        ];
        AccountBundle b = new AccountBundle();
        b.account = acc;
        b.salesAreas = [
            SELECT Id, Sales_Org__c, Distribution_Channel__c, Division__c
            FROM MD_Sales_Area__c
            WHERE Parent_Account__c = :acc.Id
        ];
        b.taxNumbers = [
            SELECT Id, Tax_Category_Code__c, Category_Value__c
            FROM MD_Tax_Number__c
            WHERE Account__c = :acc.Id
        ];
        b.creditProfiles = [
            SELECT Id, Credit_Segment__c, Credit_Limit__c, Outstanding_Amount__c
            FROM Credit_Profile__c
            WHERE Account__c = :acc.Id
        ];
        return b;
    }

    // =============== Utilities ===============
    private static Boolean isValidKunnr(String kunnr) {
        if (String.isBlank(kunnr)) return false;
        return Pattern.compile('^3\\d{9}$').matcher(kunnr).matches();
    }

    private static Id getFunctionalAccountRtId() {
        try {
            return [
                SELECT Id
                FROM RecordType
                WHERE SobjectType = 'Account'
                  AND DeveloperName = 'Functional_Account'
                LIMIT 1
            ].Id;
        } catch (Exception e) {
            return null;
        }
    }

    private static String norm(String s) {
        if (String.isBlank(s)) return '';
        String t = s.trim().toLowerCase();
        t = t.replace('&amp;', '&');
        while (t.contains('  ')) t = t.replace('  ', ' ');
        return t;
    }

    private static Boolean picklistAllows(Schema.SObjectType sType, String fieldApi, String value) {
        Map<String, SObjectField> fmap = sType.getDescribe().fields.getMap();
        if (!fmap.containsKey(fieldApi)) return false;
        Schema.DescribeFieldResult d = fmap.get(fieldApi).getDescribe();
        if (d.getType() != Schema.DisplayType.Picklist &&
            d.getType() != Schema.DisplayType.MultiPicklist) {
            return true;
        }
        Set<String> allowed = new Set<String>();
        for (Schema.PicklistEntry pe : d.getPicklistValues()) {
            allowed.add(pe.getValue());
        }
        return allowed.contains(value);
    }

    private static void maybeSet(SObject sob, String fieldApiName, Object val) {
        if (sob == null || val == null) return;
        String s = String.valueOf(val);
        if (String.isBlank(s)) return;
        Map<String, SObjectField> fmap = sob.getSObjectType().getDescribe().fields.getMap();
        if (fmap.containsKey(fieldApiName)) sob.put(fieldApiName, val);
    }

    private static void setPicklistWithMapping(SObject sob, String fieldApiName, String /*unused*/ mapperFieldApi, String incomingCode) {
        if (sob == null || String.isBlank(fieldApiName) || String.isBlank(incomingCode)) return;
        String mapped = PM.mapToAllowed(sob, fieldApiName, incomingCode);
        if (String.isBlank(mapped)) {
            dbg('Mapping not found for ' + fieldApiName + ' <- ' + incomingCode + ' (skipped)');
        } else {
            sob.put(fieldApiName, mapped);
        }
    }

    private static List<SObject> dedupeById(List<SObject> records) {
        Map<Id, SObject> byId = new Map<Id, SObject>();
        List<SObject> inserts = new List<SObject>();
        for (SObject s : records) {
            if (s == null) continue;
            if (s.Id == null) inserts.add(s);
            else byId.put(s.Id, s);
        }
        List<SObject> outp = new List<SObject>();
        outp.addAll(inserts);
        outp.addAll(byId.values());
        return outp;
    }

    // =============== Small util classes ===============
    public class JSONUtil {
        public List<Object> asList(Object obj) {
            if (obj == null) return new List<Object>();
            if (obj instanceof List<Object>) return (List<Object>) obj;
            return new List<Object>();
        }
        public List<Map<String, Object>> asListMap(Object obj) {
            List<Map<String, Object>> out = new List<Map<String, Object>>();
            for (Object o : asList(obj)) {
                if (o instanceof Map<String, Object>) out.add((Map<String, Object>) o);
            }
            return out;
        }
        public String getString(Map<String, Object> m, String key) {
            if (m == null) return null;
            Object v = m.get(key);
            return v == null ? null : String.valueOf(v);
        }
        public Boolean getBool(Map<String, Object> m, String key) {
            if (m == null) return null;
            Object v = m.get(key);
            if (v == null) return null;
            if (v instanceof Boolean) return (Boolean) v;
            String s = String.valueOf(v);
            if (s == 'true') return true;
            if (s == 'false') return false;
            return null;
        }
        public Decimal getDecimal(Map<String, Object> m, String key) {
            String s = getString(m, key);
            if (String.isBlank(s)) return null;
            try {
                return Decimal.valueOf(s);
            } catch (Exception e) {
                return null;
            }
        }
        public String joinNonBlank(String sep, List<String> parts) {
            List<String> cleaned = new List<String>();
            for (String p : parts) if (!String.isBlank(p)) cleaned.add(p);
            return String.join(cleaned, sep);
        }
    }

    // =============== Smart Mapper Bridge (non-static inner class) ===============
    public class PicklistMapperBridge {
        public String mapToAllowed(SObject sob, String targetFieldApi, String incomingCode) {
            if (sob == null || String.isBlank(targetFieldApi) || String.isBlank(incomingCode)) return null;

            String objectApi = sob.getSObjectType().getDescribe().getName();

            // Build candidate mapper keys
            List<String> candidates = new List<String>();
            candidates.add(objectApi + '.' + targetFieldApi);
            candidates.add(targetFieldApi);

            List<String> aliases = PM_FIELD_ALIASES.containsKey(targetFieldApi)
                ? PM_FIELD_ALIASES.get(targetFieldApi)
                : new List<String>();
            for (String aliasField : aliases) {
                candidates.add(objectApi + '.' + aliasField);
                candidates.add(aliasField);
            }

            if (targetFieldApi.endsWith('_Code__c')) {
                String noCode = targetFieldApi.replace('_Code__c', '__c');
                candidates.add(objectApi + '.' + noCode);
                candidates.add(noCode);
            }

            // Try mapping, accept only allowed value for target field
            for (String key : candidates) {
                String mapped;
                try {
                    mapped = PicklistMapper.mapOrCode(key, incomingCode);
                } catch (Exception e) {
                    mapped = incomingCode;
                }
                if (String.isBlank(mapped)) continue;

                if (SAPKunnrSyncService.picklistAllows(sob.getSObjectType(), targetFieldApi, mapped)) {
                    return mapped;
                }
            }
            return null;
        }
    }
}