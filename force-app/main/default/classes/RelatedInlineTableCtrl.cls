public with sharing class RelatedInlineTableCtrl {
    public class RowError {
        @AuraEnabled public String id;
        @AuraEnabled public String message;
        @AuraEnabled public List<String> fieldNames;
    }
    public class SaveResponse {
        @AuraEnabled public Boolean hasErrors;
        @AuraEnabled public Integer successCount;
        @AuraEnabled public Integer errorCount;
        @AuraEnabled public List<RowError> rowErrors;
    }

    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getRecords(String objectApiName,
                                                       List<String> fieldApiNames,
                                                       String whereClause,
                                                       Integer limitSize) {
        if (String.isBlank(objectApiName)) {
            throw new AuraHandledException('objectApiName is required.');
        }
        if (fieldApiNames == null || fieldApiNames.isEmpty()) {
            throw new AuraHandledException('At least one field name is required.');
        }

        Set<String> fields = new Set<String>();
        for (String f : fieldApiNames) {
            if (!String.isBlank(f)) fields.add(f.trim());
        }
        fields.add('Id');

        for (String f : fields) {
            if (f.contains('.')) {
                throw new AuraHandledException('Relationship fields (e.g., Account.Name) are not supported in this template.');
            }
        }

        String fieldList = String.join(new List<String>(fields), ',');
        String soql = 'SELECT ' + fieldList + ' FROM ' + objectApiName;
        if (!String.isBlank(whereClause)) {
            soql += ' WHERE ' + whereClause;
        }
        Integer lim = (limitSize == null || limitSize <= 0) ? 200 : limitSize;
        soql += ' LIMIT :lim';

        List<SObject> sobjs = Database.query(soql);

        List<Map<String, Object>> out = new List<Map<String, Object>>();
        for (SObject s : sobjs) {
            Map<String, Object> row = new Map<String, Object>();
            for (String f : fields) {
                row.put(f, s.get(f));
            }
            out.add(row);
        }
        return out;
    }

    @AuraEnabled
    public static SaveResponse saveRecords(String objectApiName,
                                           List<Map<String, Object>> draftValues) {
        SaveResponse resp = new SaveResponse();
        resp.hasErrors = false;
        resp.successCount = 0;
        resp.errorCount = 0;
        resp.rowErrors = new List<RowError>();

        if (String.isBlank(objectApiName)) {
            throw new AuraHandledException('objectApiName is required.');
        }
        if (draftValues == null || draftValues.isEmpty()) {
            return resp;
        }

        Schema.SObjectType sType = Schema.getGlobalDescribe().get(objectApiName);
        if (sType == null) {
            throw new AuraHandledException('Invalid objectApiName: ' + objectApiName);
        }
        Schema.DescribeSObjectResult d = sType.getDescribe();
        Map<String, Schema.SObjectField> fmap = d.fields.getMap();

        List<SObject> updates = new List<SObject>();
        for (Map<String, Object> row : draftValues) {
            if (!row.containsKey('Id') || row.get('Id') == null) continue;

            SObject rec = sType.newSObject((Id) row.get('Id'));

            for (String key : row.keySet()) {
                if (key == 'Id') continue;
                if (fmap.containsKey(key)) {
                    Schema.DescribeFieldResult fd = fmap.get(key).getDescribe();
                    if (fd.isUpdateable()) {
                        rec.put(key, row.get(key));
                    }
                }
            }
            updates.add(rec);
        }

        if (updates.isEmpty()) return resp;

        Database.SaveResult[] results = Database.update(updates, false);

        Integer success = 0, errors = 0;
        for (Integer i = 0; i < results.size(); i++) {
            Database.SaveResult sr = results[i];
            if (sr.isSuccess()) {
                success++;
            } else {
                errors++;
                RowError re = new RowError();
                re.id = (String) updates[i].get('Id');
                re.fieldNames = new List<String>();
                if (sr.getErrors() != null && sr.getErrors().size() > 0) {
                    Database.Error e = sr.getErrors()[0];
                    re.message = e.getMessage();
                    if (e.getFields() != null) {
                        for (String fn : e.getFields()) {
                            re.fieldNames.add(fn);
                        }
                    }
                } else {
                    re.message = 'Unknown error.';
                }
                resp.rowErrors.add(re);
            }
        }

        resp.successCount = success;
        resp.errorCount = errors;
        resp.hasErrors = (errors > 0);
        return resp;
    }
}