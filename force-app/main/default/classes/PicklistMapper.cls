public with sharing class PicklistMapper {
    // Cache: fieldApi -> (code -> combine from Picklist_Table__c)
    private static Map<String, Map<String, String>> codeToCombine = new Map<String, Map<String, String>>();

    // Global allowed values from describe (fieldApi -> Set(allowed))
    private static Map<String, Set<String>> allowedValues = new Map<String, Set<String>>();

    // Tax category fields (we'll use a tailored preference order, not "code-only")
    private static final Set<String> TAX_FIELDS = new Set<String>{
        'Output_Tax_Category_MWST_Code__c',
        'Output_Tax_Category_ZMWS_Code__c',
        'Output_Tax_Category_ZMST_Code__c',
        'Output_Tax_Category_ZPK2_Code__c'
    };

    // Map field API -> SObjectField token (for global describe)
    private static final Map<String, Schema.SObjectField> FIELD_TOKEN = new Map<String, Schema.SObjectField>{
        // Account fields
        'Country_Code__c' => Account.Country_Code__c,
        'Company_Code__c' => Account.Company_Code__c,
        'Reconciliation_Account__c' => Account.Reconciliation_Account__c,
        'Payment_Terms_FI_Role__c' => Account.Payment_Terms_FI_Role__c,

        // MD_Sales_Area__c fields
        'Sales_Org__c' => MD_Sales_Area__c.Sales_Org__c,
        'Distribution_Channel__c' => MD_Sales_Area__c.Distribution_Channel__c,
        'Division__c' => MD_Sales_Area__c.Division__c,
        'Sales_District__c' => MD_Sales_Area__c.Sales_District__c,
        'Delivering_Plant__c' => MD_Sales_Area__c.Delivering_Plant__c,
        'Customer_Group__c' => MD_Sales_Area__c.Customer_Group__c,
        'Sales_Office__c' => MD_Sales_Area__c.Sales_Office__c,
        'Currency__c' => MD_Sales_Area__c.Currency__c,
        'Sales_Group__c' => MD_Sales_Area__c.Sales_Group__c,
        'Price_Group__c' => MD_Sales_Area__c.Price_Group__c,
        'Pricing_Procedure_Indicator__c' => MD_Sales_Area__c.Pricing_Procedure_Indicator__c,
        'Incoterms__c' => MD_Sales_Area__c.Incoterms__c,
        'Payment_Terms__c' => MD_Sales_Area__c.Payment_Terms__c,
        'Customer_Account_Assignment_Group__c' => MD_Sales_Area__c.Customer_Account_Assignment_Group__c,
        'Output_Tax_Category_MWST_Code__c' => MD_Sales_Area__c.Output_Tax_Category_MWST_Code__c,
        'Output_Tax_Category_ZMWS_Code__c' => MD_Sales_Area__c.Output_Tax_Category_ZMWS_Code__c,
        'Output_Tax_Category_ZMST_Code__c' => MD_Sales_Area__c.Output_Tax_Category_ZMST_Code__c,
        'Output_Tax_Category_ZPK2_Code__c' => MD_Sales_Area__c.Output_Tax_Category_ZPK2_Code__c,

        // MD_Tax_Number__c
        'Tax_Category_Code__c' => MD_Tax_Number__c.Tax_Category_Code__c
    };

    // Preload Picklist_Table__c mappings and global allowed values (ONE bulk query)
    public static void preload(Map<String, Set<String>> needs) {
        if (needs == null || needs.isEmpty()) return;

        Set<String> fields = new Set<String>();
        Set<String> codes = new Set<String>();
        for (String f : needs.keySet()) {
            if (String.isBlank(f)) continue;
            fields.add(f);
            Set<String> cs = needs.get(f);
            if (cs != null) for (String c : cs) if (!String.isBlank(c)) codes.add(c);
        }

        if (!fields.isEmpty() && !codes.isEmpty()) {
            for (Picklist_Table__c rec : [
                SELECT Salesforce_Field_API__c, Code__c, Combine__c
                FROM Picklist_Table__c
                WHERE Salesforce_Field_API__c IN :fields
                  AND Code__c IN :codes
            ]) {
                String f = rec.Salesforce_Field_API__c;
                String c = rec.Code__c;
                String v = rec.Combine__c;
                if (v != null) {
                    try { v = v.unescapeHtml4(); } catch (Exception e) { v = v.replace('&amp;', '&'); }
                    v = normalizeSpaces(v);
                }
                if (!codeToCombine.containsKey(f)) codeToCombine.put(f, new Map<String, String>());
                codeToCombine.get(f).put(c, v);
            }
        }

        // Cache global allowed values for all these fields
        ensureDescribeCached(fields);
    }

    // Main mapping function (record-type agnostic)
    public static String mapOrCode(String fieldApi, String code) {
        if (String.isBlank(code)) return null;

        // Combine (from Picklist_Table__c), HTML-unescaped + normalized
        String combine = null;
        Map<String, String> byCode = codeToCombine.get(fieldApi);
        if (byCode != null) combine = byCode.get(code);
        if (combine != null) combine = normalizeSpaces(combine);

        // Load allowed values (global)
        ensureDescribeCached(new Set<String>{ fieldApi });
        Set<String> allowed = allowedValues.get(fieldApi);

        // If there is an allowed set (restricted picklist)
        if (allowed != null && !allowed.isEmpty()) {
            // For tax fields, use the robust preference order to avoid invalids
            if (TAX_FIELDS.contains(fieldApi)) {
                // 1) Code exactly allowed?
                if (allowed.contains(code)) return code;
                // 2) Combine exactly allowed?
                if (!String.isBlank(combine) && allowed.contains(combine)) return combine;
                // 3) Any allowed value that starts with the code? (e.g., "1 - Standard")
                for (String av : allowed) {
                    if (av != null && av.startsWith(code)) return av;
                }
                // 4) Normalized equality
                String normCombine = normalizeSpaces(combine);
                for (String av : allowed) {
                    if (equalsNormalized(av, normCombine)) return av;
                }
                // 5) Fallbacks
                return !String.isBlank(combine) ? combine : code;
            }

            // Non-tax fields: prefer code if allowed, else combine if allowed, else prefix, else normalized, else safe fallback
            if (allowed.contains(code)) return code;
            if (!String.isBlank(combine) && allowed.contains(combine)) return combine;
            for (String av : allowed) {
                if (av != null && av.startsWith(code)) return av;
            }
            String normCombine = normalizeSpaces(combine);
            for (String av : allowed) {
                if (equalsNormalized(av, normCombine)) return av;
            }
            return !String.isBlank(combine) ? combine : code;
        }

        // Unrestricted field: prefer combine then code
        return !String.isBlank(combine) ? combine : code;
    }

    // ---------- internals ----------
    private static void ensureDescribeCached(Set<String> fieldApis) {
        if (fieldApis == null || fieldApis.isEmpty()) return;
        for (String f : fieldApis) {
            if (allowedValues.containsKey(f)) continue;
            Schema.SObjectField token = FIELD_TOKEN.get(f);
            Set<String> vals = new Set<String>();
            if (token != null) {
                Schema.DescribeFieldResult dfr = token.getDescribe();
                for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
                    String v = normalizeSpaces(pe.getValue());
                    vals.add(v);
                }
            }
            allowedValues.put(f, vals);
        }
    }

    private static String normalizeSpaces(String s) {
        if (s == null) return null;
        String t = s.trim();
        while (t.contains('  ')) t = t.replace('  ', ' ');
        return t;
    }

    private static Boolean equalsNormalized(String a, String b) {
        if (a == null || b == null) return false;
        String aa = normalizeSpaces(a).toLowerCase();
        String bb = normalizeSpaces(b).toLowerCase();
        // handle minor label variants
        aa = aa.replace('foods & beverages', 'food & beverages');
        bb = bb.replace('foods & beverages', 'food & beverages');
        return aa == bb;
    }
}