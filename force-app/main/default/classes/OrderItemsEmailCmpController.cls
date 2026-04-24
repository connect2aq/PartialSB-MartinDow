global with sharing class OrderItemsEmailCmpController {
    // This property will receive the value via assignTo from the component attribute
    public Id orderRecordId { get; set; }

    private List<MD_OrderItem__c> items;

    // Lazy-load items based on the assigned orderRecordId
    global List<MD_OrderItem__c> getItems() {
        if (items == null && orderRecordId != null) {
            items = [
                SELECT Material_Number__c,
                       Material_Description__c,
                       Quantity__c,
                       Market_Price__c,
                       GST_Per_Unit__c,
                       Storage_Location__c
                FROM MD_OrderItem__c
                WHERE OrderId__c = :orderRecordId
                ORDER BY Material_Number__c
            ];
        }
        return items;
    }
}