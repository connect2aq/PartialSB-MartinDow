public with sharing class SAPAccountSyncService {
    private static final Safe SAFE = new Safe();
    private static final KeyUtil KEY = new KeyUtil();
    private static final RecordTypeUtil RTU = new RecordTypeUtil();
    private static Map<String, Id> rtCache = new Map<String, Id>(); // record type cache

    public class ResultSummary {
        public Integer total = 0;
        public Integer successCount = 0;
        public Integer failureCount = 0;
        public List<String> failures = new List<String>();
    }
    
    @future(callout=true)
    public static void enqueueSyncByDate(String yyyymmdd) {
        SAPAccountSyncService.syncByDate(yyyymmdd);
    }

    // Example: SAPAccountSyncService.ResultSummary r = SAPAccountSyncService.syncByDate('20250903');
    public static SAPAccountSyncService.ResultSummary syncByDate(String yyyymmdd) {
        ResultSummary summary = new ResultSummary();
        
        try {

            if (String.isBlank(yyyymmdd) || yyyymmdd.length() != 8 || !yyyymmdd.isNumeric()) {
                summary.failureCount++;
                summary.failures.add('Invalid date format. Expected YYYYMMDD, e.g., 20250903');
                return summary;
            }
    
            TokenRequest.AuthTokenResult tokenResult = TokenRequest.getAuthToken();
            if (tokenResult == null || tokenResult.success != true || String.isBlank(tokenResult.token) || String.isBlank(tokenResult.baseEndpointUrl)) {
                summary.failureCount++;
                summary.failures.add('Auth failed: token/base URL missing. Error=' + (tokenResult != null ? tokenResult.errorMessage : 'null'));
                return summary;
            }
    
            String endpoint = UrlJoiner.join(tokenResult.baseEndpointUrl, 'SAP/GetAccountDetails')
                             + '?requestdate=' + EncodingUtil.urlEncode(yyyymmdd, 'UTF-8');
    
            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint(endpoint);
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + tokenResult.token);
            req.setTimeout(120000);
    
            Http http = new Http();
            HttpResponse res;
            try {
                res = http.send(req);
            } catch (Exception ex) {
                summary.failureCount++;
                summary.failures.add('HTTP send failed: ' + ex.getMessage());
                return summary;
            }
            
            ApiLogUtil.get().add('GetAccountDetails', endpoint, 'GET', null, res.getStatusCode(), res.getBody());
    
            System.debug('GET Status = ' + (res != null ? res.getStatusCode() : -1));
            System.debug('GET Body   = ' + (res != null ? res.getBody() : 'null'));
    
            if (res == null || res.getStatusCode() != 200) {
                summary.failureCount++;
                summary.failures.add('GET failed. Status=' + (res != null ? res.getStatus() : 'null') + ', Body=' + (res != null ? res.getBody() : 'null'));
                return summary;
            }
    
            Map<String, Object> top = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            if (SAFE.valBool(top, 'success') != true) {
                summary.failureCount++;
                summary.failures.add('API success=false. Message=' + SAFE.valStr(top, 'message'));
                return summary;
            }
    
            Object rawData = top != null ? top.get('data') : null;
            List<Object> data = SAFE.toList(rawData);
    
            if (data == null || data.isEmpty()) {
                return summary;
            }
            summary.total = data.size();
    
            Set<String> allKunnrs = new Set<String>();
            for (Object o : data) {
                Map<String, Object> row = (Map<String, Object>) o;
                String kunnr = SAFE.valStrCI(row, 'kunnr');
                if (!String.isBlank(kunnr)) allKunnrs.add(kunnr);
            }
    
            Map<String, Account> existingByKunnr = new Map<String, Account>();
            if (!allKunnrs.isEmpty()) {
                for (Account a : [
                    SELECT Id, Name, SAP_Customer_Number__c, RecordTypeId, Phone, Cell__c, Email__c,
                           Account_Name2__c, City__c, Province__c, Postal_Code__c, AddressLine_1__c, Addess_Line_2__c,
                           Country_Code__c, Company_Code__c, Reconciliation_Account__c, Payment_Terms_FI_Role__c,
                           Business_Vertical__c
                    FROM Account
                    WHERE SAP_Customer_Number__c IN :allKunnrs
                ]) {
                    if (!String.isBlank(a.SAP_Customer_Number__c)) {
                        existingByKunnr.put(a.SAP_Customer_Number__c, a);
                    }
                }
            }
    
            Map<String, Set<String>> needs = new Map<String, Set<String>>();
            for (Object o : data) {
                Map<String, Object> row = (Map<String, Object>) o;
    
                addNeed(needs, 'Country_Code__c', SAFE.valStrCI(row, 'country'));
                addNeed(needs, 'Company_Code__c', SAFE.valStrCI(row, 'bukrs'));
                addNeed(needs, 'Reconciliation_Account__c', SAFE.valStrCI(row, 'akont'));
    
                List<Object> saArr = SAFE.valList(row, 'cusT_SD');
                if (saArr != null) {
                    for (Object so : saArr) {
                        Map<String, Object> sa = (Map<String, Object>) so;
                        addNeed(needs, 'Sales_Org__c', SAFE.valStrCI(sa, 'vkorg'));
                        addNeed(needs, 'Distribution_Channel__c', SAFE.valStrCI(sa, 'vtweg'));
                        addNeed(needs, 'Division__c', SAFE.valStrCI(sa, 'spart'));
                        addNeed(needs, 'Sales_District__c', SAFE.valStrCI(sa, 'bzirk'));
                        addNeed(needs, 'Delivering_Plant__c', SAFE.valStrCI(sa, 'vwerk'));
                        addNeed(needs, 'Customer_Group__c', SAFE.valStrCI(sa, 'kdgrp'));
                        addNeed(needs, 'Sales_Office__c', SAFE.valStrCI(sa, 'vkbur'));
                        addNeed(needs, 'Currency__c', SAFE.valStrCI(sa, 'waers'));
                        addNeed(needs, 'Sales_Group__c', SAFE.valStrCI(sa, 'vkgrp'));
                        addNeed(needs, 'Price_Group__c', SAFE.valStrCI(sa, 'konda'));
                        addNeed(needs, 'Pricing_Procedure_Indicator__c', SAFE.valStrCI(sa, 'kalks'));
                        addNeed(needs, 'Incoterms__c', SAFE.valStrCI(sa, 'inco1'));
                        addNeed(needs, 'Payment_Terms__c', SAFE.valStrCI(sa, 'ztermsd'));
                        addNeed(needs, 'Customer_Account_Assignment_Group__c', SAFE.valStrCI(sa, 'ktgrd'));
                        addNeed(needs, 'Payment_Terms_FI_Role__c', SAFE.valStrCI(sa, 'zterm'));
                    }
                }
    
                List<Object> taxNums = SAFE.valList(row, 'n_CUSTMER2');
                if (taxNums != null) {
                    for (Object tobj : taxNums) {
                        Map<String, Object> t = (Map<String, Object>) tobj;
                        addNeed(needs, 'Tax_Category_Code__c', SAFE.valStrCI(t, 'taxtype'));
                    }
                }
            }
            PicklistMapper.preload(needs);
    
            Id accRtId = RTU.accountRtIdByDevName('Functional_Account');
    
            Map<String, Account> accToUpsert = new Map<String, Account>();
            List<Map<String, Object>> normalizedRows = new List<Map<String, Object>>();
    
            for (Object o : data) {
                Map<String, Object> row = (Map<String, Object>) o;
                normalizedRows.add(row);
    
                String kunnr = SAFE.valStrCI(row, 'kunnr');
                if (String.isBlank(kunnr)) {
                    summary.failureCount++;
                    summary.failures.add('Missing kunnr; skipping row.');
                    continue;
                }
    
                Account acc = accToUpsert.get(kunnr);
                if (acc == null) {
                    acc = existingByKunnr.get(kunnr);
                    if (acc == null) {
                        acc = new Account();
                        acc.SAP_Customer_Number__c = kunnr;
                    }
                }
    
                String v;
                v = SAFE.valStrCI(row, 'name1'); if (!String.isBlank(v)) acc.Name = v;
                v = SAFE.valStrCI(row, 'name2'); if (!String.isBlank(v)) acc.Account_Name2__c = v;
                v = SAFE.valStrCI(row, 'searchterm1'); if (!String.isBlank(v)) acc.Business_Vertical__c = v;
                v = SAFE.valStrCI(row, 'city'); if (!String.isBlank(v)) acc.City__c = v;
                v = SAFE.valStrCI(row, 'district'); if (!String.isBlank(v)) acc.Province__c = v;
                v = SAFE.valStrCI(row, 'postlcod1'); if (!String.isBlank(v)) acc.Postal_Code__c = v;
                v = SAFE.valStrCI(row, 'strsuppl3'); if (!String.isBlank(v)) acc.AddressLine_1__c = v;
                v = SAFE.valStrCI(row, 'location'); if (!String.isBlank(v)) acc.Addess_Line_2__c = v;
    
                v = SAFE.valStrCI(row, 'country'); if (!String.isBlank(v)) acc.Country_Code__c = PicklistMapper.mapOrCode('Country_Code__c', v);
                v = SAFE.valStrCI(row, 'bukrs'); if (!String.isBlank(v)) acc.Company_Code__c = PicklistMapper.mapOrCode('Company_Code__c', v);
                v = SAFE.valStrCI(row, 'akont'); if (!String.isBlank(v)) acc.Reconciliation_Account__c = PicklistMapper.mapOrCode('Reconciliation_Account__c', v);
    
                List<Object> nCustmer = SAFE.valList(row, 'n_CUSTMER');
                if ((acc.Email__c == null || acc.Email__c == '') && nCustmer != null && !nCustmer.isEmpty()) {
                    String email = SAFE.valStrCI((Map<String, Object>) nCustmer[0], 'eMail');
                    if (!String.isBlank(email)) acc.Email__c = email;
                }
                List<Object> nCustmer3 = SAFE.valList(row, 'n_CUSTMER3');
                if ((acc.Phone == null || acc.Phone == '') && nCustmer3 != null && !nCustmer3.isEmpty()) {
                    String tel = SAFE.valStrCI((Map<String, Object>) nCustmer3[0], 'telephone');
                    if (!String.isBlank(tel)) acc.Phone = tel;
                }
                List<Object> nCustmer4 = SAFE.valList(row, 'n_CUSTMER4');
                if ((acc.Cell__c == null || acc.Cell__c == '') && nCustmer4 != null && !nCustmer4.isEmpty()) {
                    String mobile = SAFE.valStrCI((Map<String, Object>) nCustmer4[0], 'mobile');
                    if (!String.isBlank(mobile)) acc.Cell__c = mobile;
                }
    
                List<Object> salesAreasArr = SAFE.valList(row, 'cusT_SD');
                if (salesAreasArr != null && !salesAreasArr.isEmpty()) {
                    Map<String, Object> sa0 = (Map<String, Object>) salesAreasArr[0];
                    String ztermAcc = SAFE.valStrCI(sa0, 'zterm');
                    if (!String.isBlank(ztermAcc)) {
                        acc.Payment_Terms_FI_Role__c = PicklistMapper.mapOrCode('Payment_Terms_FI_Role__c', ztermAcc);
                    }
                }
    
                if (accRtId != null) acc.RecordTypeId = accRtId;
    
                accToUpsert.put(kunnr, acc);
            }
    
            List<Account> upsertAccounts = new List<Account>(accToUpsert.values());
            if (!upsertAccounts.isEmpty()) {
                try {
                    upsert upsertAccounts Account.SAP_Customer_Number__c;
                } catch (Exception ex) {
                    summary.failureCount += upsertAccounts.size();
                    summary.failures.add('Account upsert failed: ' + ex.getMessage());
                    return summary;
                }
            }
    
            Map<String, Account> finalByKunnr = new Map<String, Account>();
            if (!allKunnrs.isEmpty()) {
                for (Account a : [
                    SELECT Id, SAP_Customer_Number__c
                    FROM Account
                    WHERE SAP_Customer_Number__c IN :allKunnrs
                ]) {
                    if (!String.isBlank(a.SAP_Customer_Number__c)) {
                        finalByKunnr.put(a.SAP_Customer_Number__c, a);
                    }
                }
            }
    
            Map<String, MD_Sales_Area__c> saByKey = new Map<String, MD_Sales_Area__c>();
            Map<String, MD_Tax_Number__c> taxByKey = new Map<String, MD_Tax_Number__c>();
            Map<String, Credit_Profile__c> cpByKey = new Map<String, Credit_Profile__c>();
    
            Set<Id> accIds = new Set<Id>();
            for (String k : finalByKunnr.keySet()) accIds.add(finalByKunnr.get(k).Id);
    
            if (!accIds.isEmpty()) {
                for (MD_Sales_Area__c sa : [
                    SELECT Id, Parent_Account__c,
                           Sales_Org__c, Distribution_Channel__c, Division__c, Sales_District__c, Delivering_Plant__c,
                           Customer_Group__c, Sales_Office__c, Currency__c, Sales_Group__c, Price_Group__c,
                           Pricing_Procedure_Indicator__c, Incoterms__c, Incoterms_Description__c, Payment_Terms__c,
                           Customer_Account_Assignment_Group__c,
                           Output_Tax_Category_MWST_Code__c, Output_Tax_Category_ZMWS_Code__c,
                           Output_Tax_Category_ZMST_Code__c, Output_Tax_Category_ZPK2_Code__c
                    FROM MD_Sales_Area__c
                    WHERE Parent_Account__c IN :accIds
                ]) {
                    String key = KEY.saKey(sa.Parent_Account__c, sa.Sales_Org__c, sa.Distribution_Channel__c, sa.Division__c);
                    saByKey.put(key, sa);
                }
                for (MD_Tax_Number__c tn : [
                    SELECT Id, Account__c, Tax_Category_Code__c
                    FROM MD_Tax_Number__c
                    WHERE Account__c IN :accIds
                ]) {
                    String key = KEY.taxKey(tn.Account__c, tn.Tax_Category_Code__c);
                    taxByKey.put(key, tn);
                }
                for (Credit_Profile__c cp : [
                    SELECT Id, Account__c, Credit_Segment__c
                    FROM Credit_Profile__c
                    WHERE Account__c IN :accIds
                ]) {
                    String key = KEY.cpKey(cp.Account__c, cp.Credit_Segment__c);
                    cpByKey.put(key, cp);
                }
            }
    
            Map<String, MD_Sales_Area__c> saPhase1Map = new Map<String, MD_Sales_Area__c>();
            List<TaxUpdate> taxPhase2 = new List<TaxUpdate>();
    
            for (Object o : data) {
                Map<String, Object> row = (Map<String, Object>) o;
                String kunnr = SAFE.valStrCI(row, 'kunnr');
                if (String.isBlank(kunnr)) continue;
                Account acc = finalByKunnr.get(kunnr);
                if (acc == null) {
                    summary.failureCount++;
                    summary.failures.add('Account missing post-upsert for kunnr=' + kunnr);
                    continue;
                }
    
                List<Object> saArr = SAFE.valList(row, 'cusT_SD');
                if (saArr != null && !saArr.isEmpty()) {
                    for (Object so : saArr) {
                        Map<String, Object> sa = (Map<String, Object>) so;
    
                        String vkorgMapped = PicklistMapper.mapOrCode('Sales_Org__c', SAFE.valStrCI(sa, 'vkorg'));
                        String vtwegMapped = PicklistMapper.mapOrCode('Distribution_Channel__c', SAFE.valStrCI(sa, 'vtweg'));
                        String spartMapped = PicklistMapper.mapOrCode('Division__c', SAFE.valStrCI(sa, 'spart'));
    
                        String key = KEY.saKey(acc.Id, vkorgMapped, vtwegMapped, spartMapped);
    
                        MD_Sales_Area__c target = saByKey.get(key);
                        if (target == null) {
                            target = new MD_Sales_Area__c();
                            target.Parent_Account__c = acc.Id;
                            target.Sales_Org__c = vkorgMapped;
                            target.Distribution_Channel__c = vtwegMapped;
                            target.Division__c = spartMapped;
                        }
    
                        target.Sales_District__c = PicklistMapper.mapOrCode('Sales_District__c', SAFE.valStrCI(sa, 'bzirk'));
                        target.Delivering_Plant__c = PicklistMapper.mapOrCode('Delivering_Plant__c', SAFE.valStrCI(sa, 'vwerk'));
                        target.Customer_Group__c = PicklistMapper.mapOrCode('Customer_Group__c', SAFE.valStrCI(sa, 'kdgrp'));
                        target.Sales_Office__c = PicklistMapper.mapOrCode('Sales_Office__c', SAFE.valStrCI(sa, 'vkbur'));
                        target.Currency__c = PicklistMapper.mapOrCode('Currency__c', SAFE.valStrCI(sa, 'waers'));
                        target.Sales_Group__c = PicklistMapper.mapOrCode('Sales_Group__c', SAFE.valStrCI(sa, 'vkgrp'));
                        target.Price_Group__c = PicklistMapper.mapOrCode('Price_Group__c', SAFE.valStrCI(sa, 'konda'));
                        target.Pricing_Procedure_Indicator__c = PicklistMapper.mapOrCode('Pricing_Procedure_Indicator__c', SAFE.valStrCI(sa, 'kalks'));
                        target.Incoterms__c = PicklistMapper.mapOrCode('Incoterms__c', SAFE.valStrCI(sa, 'inco1'));
                        target.Incoterms_Description__c = SAFE.valStrCI(sa, 'inco2');
                        target.Payment_Terms__c = PicklistMapper.mapOrCode('Payment_Terms__c', SAFE.valStrCI(sa, 'ztermsd'));
                        target.Customer_Account_Assignment_Group__c = PicklistMapper.mapOrCode('Customer_Account_Assignment_Group__c', SAFE.valStrCI(sa, 'ktgrd'));
    
                        saByKey.put(key, target);
                        saPhase1Map.put(key, target);
    
                        List<Object> taxCats = SAFE.valList(row, 'n_CUSTMER1');
                        if (taxCats != null) {
                            for (Object tobj : taxCats) {
                                Map<String, Object> t = (Map<String, Object>) tobj;
                                String tatyp = SAFE.valStrCI(t, 'tatyp');
                                String taxkd = SAFE.valStrCI(t, 'taxkd');
                                if (String.isBlank(tatyp) || String.isBlank(taxkd)) continue;
    
                                if (tatyp.equalsIgnoreCase('MWST') || tatyp.equalsIgnoreCase('ZMWS')
                                    || tatyp.equalsIgnoreCase('ZMST') || tatyp.equalsIgnoreCase('ZPK2')) {
                                    TaxUpdate tu = new TaxUpdate();
                                    tu.accId = acc.Id;
                                    tu.vkorg = vkorgMapped;
                                    tu.vtweg = vtwegMapped;
                                    tu.spart = spartMapped;
                                    tu.tatyp = tatyp.toUpperCase();
                                    tu.code = taxkd;
                                    taxPhase2.add(tu);
                                }
                            }
                        }
                    }
                }
    
                List<Object> taxNums = SAFE.valList(row, 'n_CUSTMER2');
                if (taxNums != null) {
                    for (Object tobj : taxNums) {
                        Map<String, Object> t = (Map<String, Object>) tobj;
                        String ttypeRaw = SAFE.valStrCI(t, 'taxtype');
                        if (String.isBlank(ttypeRaw)) continue;
    
                        String ttypeMapped = PicklistMapper.mapOrCode('Tax_Category_Code__c', ttypeRaw);
                        String keyTN = KEY.taxKey(acc.Id, ttypeMapped);
    
                        MD_Tax_Number__c targetTN = taxByKey.get(keyTN);
                        if (targetTN == null) {
                            targetTN = new MD_Tax_Number__c();
                            targetTN.Account__c = acc.Id;
                            targetTN.Tax_Category_Code__c = ttypeMapped;
                        }
                        targetTN.Category_Value__c = SAFE.valStrCI(t, 'taxnumber');
    
                        taxByKey.put(keyTN, targetTN);
                    }
                }
    
                List<Object> cps = SAFE.valList(row, 'n_CUSTMER6');
                if (cps != null) {
                    for (Object co : cps) {
                        Map<String, Object> c = (Map<String, Object>) co;
                        String seg = SAFE.valStrCI(c, 'creditSegment');
                        if (String.isBlank(seg)) continue;
    
                        String keyCP = KEY.cpKey(acc.Id, seg);
                        Credit_Profile__c targetCP = cpByKey.get(keyCP);
                        if (targetCP == null) {
                            targetCP = new Credit_Profile__c();
                            targetCP.Account__c = acc.Id;
                            targetCP.Credit_Segment__c = seg;
                        }
                        targetCP.Credit_Limit__c = SAFE.toDecimal(SAFE.valStrCI(c, 'creditLimit'));
                        targetCP.Outstanding_Amount__c = SAFE.toDecimal(SAFE.valStrCI(c, 'outstandingAmount'));
    
                        cpByKey.put(keyCP, targetCP);
                    }
                }
    
                summary.successCount++;
            }
    
            try {
                if (!saPhase1Map.isEmpty()) upsert new List<MD_Sales_Area__c>(saPhase1Map.values());
                if (!taxByKey.isEmpty()) upsert new List<MD_Tax_Number__c>(taxByKey.values());
                if (!cpByKey.isEmpty()) upsert new List<Credit_Profile__c>(cpByKey.values());
            } catch (Exception ex) {
                summary.failureCount++;
                summary.failures.add('Related upserts (phase-1) failed: ' + ex.getMessage());
            }
    
            Map<String, MD_Sales_Area__c> saIndex = new Map<String, MD_Sales_Area__c>();
            if (!accIds.isEmpty()) {
                for (MD_Sales_Area__c sa : [
                    SELECT Id, Parent_Account__c,
                           Sales_Org__c, Distribution_Channel__c, Division__c,
                           Output_Tax_Category_MWST_Code__c, Output_Tax_Category_ZMWS_Code__c,
                           Output_Tax_Category_ZMST_Code__c, Output_Tax_Category_ZPK2_Code__c
                    FROM MD_Sales_Area__c
                    WHERE Parent_Account__c IN :accIds
                ]) {
                    String key = KEY.saKey(sa.Parent_Account__c, sa.Sales_Org__c, sa.Distribution_Channel__c, sa.Division__c);
                    saIndex.put(key, sa);
                }
            }
    
            Map<Id, MD_Sales_Area__c> taxUpdateMap = new Map<Id, MD_Sales_Area__c>();
    
            for (TaxUpdate tu : taxPhase2) {
                String key = KEY.saKey(tu.accId, tu.vkorg, tu.vtweg, tu.spart);
                MD_Sales_Area__c sa = saIndex.get(key);
                if (sa == null || sa.Id == null) continue;
    
                if (!taxUpdateMap.containsKey(sa.Id)) {
                    taxUpdateMap.put(sa.Id, new MD_Sales_Area__c(Id = sa.Id));
                }
                MD_Sales_Area__c upd = taxUpdateMap.get(sa.Id);
    
                if (tu.tatyp == 'MWST') {
                    String v = PicklistMapper.mapOrCode('Output_Tax_Category_MWST_Code__c', tu.code);
                    if (v != null) upd.Output_Tax_Category_MWST_Code__c = v;
                } else if (tu.tatyp == 'ZMWS') {
                    String v = PicklistMapper.mapOrCode('Output_Tax_Category_ZMWS_Code__c', tu.code);
                    if (v != null) upd.Output_Tax_Category_ZMWS_Code__c = v;
                } else if (tu.tatyp == 'ZMST') {
                    String v = PicklistMapper.mapOrCode('Output_Tax_Category_ZMST_Code__c', tu.code);
                    if (v != null) upd.Output_Tax_Category_ZMST_Code__c = v;
                } else if (tu.tatyp == 'ZPK2') {
                    String v = PicklistMapper.mapOrCode('Output_Tax_Category_ZPK2_Code__c', tu.code);
                    if (v != null) upd.Output_Tax_Category_ZPK2_Code__c = v;
                }
            }
    
            if (!taxUpdateMap.isEmpty()) {
                List<MD_Sales_Area__c> updates = new List<MD_Sales_Area__c>(taxUpdateMap.values());
                Database.SaveResult[] sr = Database.update(updates, false);
                for (Integer i = 0; i < sr.size(); i++) {
                    if (!sr[i].isSuccess()) {
                        Database.Error e = sr[i].getErrors().isEmpty() ? null : sr[i].getErrors()[0];
                        String em = e == null ? 'Unknown error' : e.getMessage();
                        summary.failureCount++;
                        summary.failures.add('Tax update failed for SA Id=' + updates[i].Id + ' -> ' + em);
                    }
                }
            }
    
            return summary;
        } finally {
            ApiLogUtil.get().flushSync();
        }
    }

    private class TaxUpdate {
        Id accId; String vkorg; String vtweg; String spart; String tatyp; String code;
    }

    private static void addNeed(Map<String, Set<String>> needs, String fieldApi, String code) {
        if (String.isBlank(fieldApi) || String.isBlank(code)) return;
        Set<String> setCodes = needs.get(fieldApi);
        if (setCodes == null) {
            setCodes = new Set<String>();
            needs.put(fieldApi, setCodes);
        }
        setCodes.add(code);
    }

    private class Safe {
        String valStrCI(Map<String, Object> m, String key) {
            if (m == null || String.isBlank(key)) return null;
            if (m.containsKey(key)) {
                Object v = m.get(key);
                return v == null ? null : String.valueOf(v);
            }
            for (String k : m.keySet()) {
                if (k != null && k.equalsIgnoreCase(key)) {
                    Object v = m.get(k);
                    return v == null ? null : String.valueOf(v);
                }
            }
            return null;
        }
        String valStr(Map<String, Object> m, String key) {
            Object o = m != null ? m.get(key) : null;
            return o == null ? null : String.valueOf(o);
        }
        Boolean valBool(Map<String, Object> m, String key) {
            Object o = m != null ? m.get(key) : null;
            return (o instanceof Boolean) ? (Boolean) o : (o != null && 'true'.equalsIgnoreCase(String.valueOf(o)));
        }
        List<Object> valList(Map<String, Object> m, String key) {
            Object o = m != null ? m.get(key) : null;
            return toList(o);
        }
        List<Object> toList(Object o) {
            if (o == null) return null;
            if (o instanceof List<Object>) return (List<Object>) o;
            if (o instanceof Map<String, Object>) {
                List<Object> one = new List<Object>(); one.add(o); return one;
            }
            return null;
        }
        Decimal toDecimal(String s) {
            try { if (String.isBlank(s)) return null; return Decimal.valueOf(s); }
            catch (Exception e) { return null; }
        }
    }

    private class KeyUtil {
        String saKey(Id accId, String vkorg, String vtweg, String spart) {
            return String.valueOf(accId) + '|' + String.valueOf(vkorg) + '|' + String.valueOf(vtweg) + '|' + String.valueOf(spart);
        }
        String taxKey(Id accId, String taxtype) { return String.valueOf(accId) + '|' + String.valueOf(taxtype); }
        String cpKey(Id accId, String segment) { return String.valueOf(accId) + '|' + String.valueOf(segment); }
    }

    private class RecordTypeUtil {
        Id accountRtIdByDevName(String devName) {
            if (String.isBlank(devName)) return null;
            if (rtCache.containsKey(devName)) return rtCache.get(devName);
            Map<String, Schema.RecordTypeInfo> byDev = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
            Schema.RecordTypeInfo rti = byDev != null ? byDev.get(devName) : null;
            Id idd = rti != null ? rti.getRecordTypeId() : null;
            if (idd != null) rtCache.put(devName, idd);
            return idd;
        }
    }
}