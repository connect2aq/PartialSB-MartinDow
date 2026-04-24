public with sharing class MDProductSearchController {
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getMaterialGroupOptions() {
        Map<String, Set<String>> groupMap = new Map<String, Set<String>>();
        groupMap.put('Material_Group_1__c', new Set<String>());
        groupMap.put('Material_Group_2__c', new Set<String>());
        groupMap.put('Material_Group_3__c', new Set<String>());
        groupMap.put('Material_Group_4__c', new Set<String>());
        groupMap.put('Material_Group_5__c', new Set<String>());

        for (MD_Product2__c prod : [
            SELECT
                Material_Group_1__c,
                Material_Group_2__c,
                Material_Group_3__c,
                Material_Group_4__c,
                Material_Group_5__c
            FROM MD_Product2__c
            WHERE IsActive__c = TRUE
        ]) {
            if (String.isNotBlank(prod.Material_Group_1__c))
                groupMap.get('Material_Group_1__c')
                    .add(prod.Material_Group_1__c);
            if (String.isNotBlank(prod.Material_Group_2__c))
                groupMap.get('Material_Group_2__c')
                    .add(prod.Material_Group_2__c);
            if (String.isNotBlank(prod.Material_Group_3__c))
                groupMap.get('Material_Group_3__c')
                    .add(prod.Material_Group_3__c);
            if (String.isNotBlank(prod.Material_Group_4__c))
                groupMap.get('Material_Group_4__c')
                    .add(prod.Material_Group_4__c);
            if (String.isNotBlank(prod.Material_Group_5__c))
                groupMap.get('Material_Group_5__c')
                    .add(prod.Material_Group_5__c);
        }

        Map<String, List<String>> result = new Map<String, List<String>>();
        for (String key : groupMap.keySet()) {
            result.put(key, new List<String>(groupMap.get(key)));
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<MD_Product2__c> searchMaterials(
        String searchText,
        String group1,
        String group2,
        String group3,
        String group4,
        String group5,
        String industryStandard
    ) {
        String likeSearch = '%' + searchText + '%';
        String baseQuery = 'SELECT Id, Material_Number__c, Price__c, Description__c, Old_Material_Number__c, Division__c, Industry_Standard_Description__c, Sub_Group__c, Material_Group_1__c, Material_Group_2__c, Material_Group_3__c, Material_Group_4__c, Material_Group_5__c, Size_Dimensions__c, Commodity_Code__c, IsActive__c FROM MD_Product2__c WHERE (Material_Number__c LIKE :likeSearch OR Description__c LIKE :likeSearch OR Old_Material_Number__c LIKE :likeSearch)';
        if (String.isNotBlank(group1))
            baseQuery += ' AND Material_Group_1__c = :group1';
        if (String.isNotBlank(group2))
            baseQuery += ' AND Material_Group_2__c = :group2';
        if (String.isNotBlank(group3))
            baseQuery += ' AND Material_Group_3__c = :group3';
        if (String.isNotBlank(group4))
            baseQuery += ' AND Material_Group_4__c = :group4';
        if (String.isNotBlank(group5))
            baseQuery += ' AND Material_Group_5__c = :group5';
        if (String.isNotBlank(industryStandard))
            baseQuery += ' AND Industry_Standard_Description__c LIKE :industryStandard';
        baseQuery += ' LIMIT 200';

        System.debug('Executing query: ' + baseQuery);
        return Database.query(baseQuery);
    }
}