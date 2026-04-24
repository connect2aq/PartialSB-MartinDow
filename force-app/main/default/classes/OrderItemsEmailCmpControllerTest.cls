@IsTest
private class OrderItemsEmailCmpControllerTest {

    // Generic helper: set a field only if it exists and is createable
    private static void setIfCreateable(SObject rec, String fieldApi, Object value) {
        Map<String, Schema.SObjectField> fmap =
            rec.getSObjectType().getDescribe().fields.getMap();
        if (fmap.containsKey(fieldApi)) {
            Schema.DescribeFieldResult fdesc = fmap.get(fieldApi).getDescribe();
            if (fdesc.isCreateable()) {
                rec.put(fieldApi, value);
            }
        }
    }

    // Create a parent MD_Order__c; set Name only if createable
    private static MD_Order__c createOrder() {
        MD_Order__c o = new MD_Order__c();
        setIfCreateable(o, 'Name', 'Test Order');
        insert o;
        return o;
    }

    // Build (not insert) a child MD_OrderItem__c safely
    private static MD_OrderItem__c buildOrderItem(
        Id orderId,
        String materialNumber,
        String materialDescription,
        Decimal qty,
        Decimal marketPrice,
        Decimal gstPerUnit,
        String storageLocation
    ) {
        MD_OrderItem__c item = new MD_OrderItem__c();
        item.OrderId__c = orderId;

        // Set optional fields only if createable in this org
        setIfCreateable(item, 'Name', 'Item ' + materialNumber);
        setIfCreateable(item, 'Material_Number__c', materialNumber);
        setIfCreateable(item, 'Material_Description__c', materialDescription);
        setIfCreateable(item, 'Quantity__c', qty);
        setIfCreateable(item, 'Market_Price__c', marketPrice);
        setIfCreateable(item, 'GST_Per_Unit__c', gstPerUnit);
        setIfCreateable(item, 'Storage_Location__c', storageLocation);

        return item;
    }

    @TestSetup
    static void setupData() {
        MD_Order__c order = createOrder();

        List<MD_OrderItem__c> batch = new List<MD_OrderItem__c>();
        // Two items (ORDER BY Material_Number__c will be exercised if present)
        batch.add(buildOrderItem(order.Id, 'M-200', 'Item B', 5, 200, 15, 'WH-1'));
        batch.add(buildOrderItem(order.Id, 'M-100', 'Item A', 2, 100, 10, 'WH-1'));
        insert batch;
    }

    @IsTest
    static void testGetItems_NoRecordId() {
        // Path: orderRecordId == null, items == null
        OrderItemsEmailCmpController ctrl = new OrderItemsEmailCmpController();
        Test.startTest();
        ctrl.getItems(); // execute for coverage, no asserts per requirement
        Test.stopTest();
    }

    @IsTest
    static void testGetItems_WithRecordId() {
        MD_Order__c order = [SELECT Id FROM MD_Order__c LIMIT 1];

        OrderItemsEmailCmpController ctrl = new OrderItemsEmailCmpController();
        ctrl.orderRecordId = order.Id;

        Test.startTest();
        // First call: performs SOQL and caches results
        List<MD_OrderItem__c> first = ctrl.getItems();
        // Second call: returns cached list (items != null branch)
        List<MD_OrderItem__c> second = ctrl.getItems();
        Test.stopTest();
    }
}