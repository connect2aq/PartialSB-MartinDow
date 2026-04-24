public with sharing class MDOpportunityLineItemController {
  @AuraEnabled
  public static String saveSelectedProducts(
    Id varRecId,
    List<Object> selectedProducts,
    String objName
  ) {
    System.debug('varRecId: ' + varRecId);
    System.debug('objName: ' + objName);
    if (String.isBlank(objName)) {
      return 'Error: Parent record (rec) is null. Please ensure the record is loaded before saving.';
    }
    if (objName == 'MD_Opportunity__c') {
      return saveOpportunityLineItems(varRecId, selectedProducts);
    } else if (objName == 'MD_Quote__c') {
      return saveQuoteLineItems(varRecId, selectedProducts);
    } else if (objName == 'MD_Order__c') {
      return saveOrderLineItems(varRecId, selectedProducts);
    } else if (objName == 'Customer_Demand__c') {
      return saveCustomerDemandLineItems(varRecId, selectedProducts);
    } else {
      return 'Error: Unsupported parent object type: ' + objName;
    }
  }

  private static String saveOpportunityLineItems(
    Id opportunityId,
    List<Object> selectedProducts
  ) {
    List<SObject> itemsToInsert = new List<SObject>();
    for (Object obj : selectedProducts) {
      Map<Object, Object> prod = (Map<Object, Object>) obj;
      String materialId = (String) prod.get('materialId');
      String materialNumber = (String) prod.get('materialNumber');
      String quantityStr = (String) prod.get('quantity');
      String priceStr = (String) prod.get('price');
      String quantityError = validateQuantity(quantityStr, materialNumber);
      if (quantityError != null) {
        return quantityError;
      }
      Integer quantity = parseQuantity(quantityStr);
      String priceError = validatePrice(priceStr, materialNumber);
      if (priceError != null) {
        return priceError;
      }
      Decimal price = parsePrice(priceStr);
      MD_OpportunityLineItem__c lineItem = new MD_OpportunityLineItem__c();
      lineItem.Name = materialNumber;
      lineItem.Product__c = materialId;
      lineItem.Opportunity__c = opportunityId;
      lineItem.Quantity__c = quantity;
      lineItem.Unit_Price__c = price;
      itemsToInsert.add(lineItem);
    }
    if (!itemsToInsert.isEmpty()) {
      insert itemsToInsert;
      return 'Selected products have been saved successfully.';
    }
    return 'No products to save.';
  }

  private static String saveQuoteLineItems(
    Id quoteId,
    List<Object> selectedProducts
  ) {
    List<SObject> itemsToInsert = new List<SObject>();
    for (Object obj : selectedProducts) {
      Map<Object, Object> prod = (Map<Object, Object>) obj;
      String materialId = (String) prod.get('materialId');
      String materialNumber = (String) prod.get('materialNumber');
      String quantityStr = (String) prod.get('quantity');
      String priceStr = (String) prod.get('price');
      String quantityError = validateQuantity(quantityStr, materialNumber);
      if (quantityError != null) {
        return quantityError;
      }
      Integer quantity = parseQuantity(quantityStr);
      String priceError = validatePrice(priceStr, materialNumber);
      if (priceError != null) {
        return priceError;
      }
      Decimal price = parsePrice(priceStr);
      MD_Quote_Line_Item__c lineItem = new MD_Quote_Line_Item__c();
      lineItem.Name = materialNumber;
      lineItem.Product2Id__c = materialId;
      lineItem.QuoteId__c = quoteId;
      lineItem.Quantity__c = quantity;
      lineItem.UnitPrice__c = price;
      itemsToInsert.add(lineItem);
    }
    if (!itemsToInsert.isEmpty()) {
      insert itemsToInsert;
      return 'Selected products have been saved successfully.';
    }
    return 'No products to save.';
  }

  private static String saveOrderLineItems(
    Id orderId,
    List<Object> selectedProducts
  ) {
    List<SObject> itemsToInsert = new List<SObject>();
    for (Object obj : selectedProducts) {
      Map<Object, Object> prod = (Map<Object, Object>) obj;
      String materialId = (String) prod.get('materialId');
      String materialNumber = (String) prod.get('materialNumber');
      String quantityStr = (String) prod.get('quantity');
      String priceStr = (String) prod.get('price');
      String quantityError = validateQuantity(quantityStr, materialNumber);
      if (quantityError != null) {
        return quantityError;
      }
      Integer quantity = parseQuantity(quantityStr);
      String priceError = validatePrice(priceStr, materialNumber);
      if (priceError != null) {
        return priceError;
      }
      Decimal price = parsePrice(priceStr);
      MD_OrderItem__c lineItem = new MD_OrderItem__c();
      lineItem.Product2Id__c = materialId;
      lineItem.OrderId__c = orderId;
      lineItem.Quantity__c = quantity;
      lineItem.Price__c = price;
      itemsToInsert.add(lineItem);
    }
    if (!itemsToInsert.isEmpty()) {
      insert itemsToInsert;
      return 'Selected products have been saved successfully.';
    }
    return 'No products to save.';
  }

  private static String saveCustomerDemandLineItems(
    Id demandId,
    List<Object> selectedProducts
  ) {
    List<SObject> itemsToInsert = new List<SObject>();
    for (Object obj : selectedProducts) {
      Map<Object, Object> prod = (Map<Object, Object>) obj;
      String materialId = (String) prod.get('materialId');
      String materialNumber = (String) prod.get('materialNumber');
      String quantityStr = (String) prod.get('quantity');
      String priceStr = (String) prod.get('price');
      String quantityError = validateQuantity(quantityStr, materialNumber);
      if (quantityError != null) {
        return quantityError;
      }
      Integer quantity = parseQuantity(quantityStr);
      String priceError = validatePrice(priceStr, materialNumber);
      if (priceError != null) {
        return priceError;
      }
      Decimal price = parsePrice(priceStr);

      Customer_Demand_Line_item__c lineItem = new Customer_Demand_Line_item__c();
      // lineItem.Name = materialNumber;
      lineItem.Material_Master__c = materialId;
      lineItem.Customer_Demand__c = demandId;
      lineItem.Quantity__c = quantity;
      lineItem.Amount__c = price;
      itemsToInsert.add(lineItem);
    }
    if (!itemsToInsert.isEmpty()) {
      insert itemsToInsert;
      return 'Selected products have been saved successfully.';
    }
    return 'No products to save.';
  }
  // Validate and parse quantity
  private static String validateQuantity(
    String quantityStr,
    String materialNumber
  ) {
    if (quantityStr != null && quantityStr != '') {
      if (!Pattern.matches('^-?\\d+$', quantityStr)) {
        return 'Error: Invalid quantity value for product ' +
          materialNumber +
          ': ' +
          quantityStr;
      }
    }
    return null;
  }

  private static Integer parseQuantity(String quantityStr) {
    if (quantityStr != null && quantityStr != '') {
      return Integer.valueOf(quantityStr);
    }
    return 0;
  }

  // Validate and parse price
  private static String validatePrice(String priceStr, String materialNumber) {
    if (priceStr != null && priceStr != '') {
      if (!Pattern.matches('^-?\\d+(\\.\\d+)?$', priceStr)) {
        return 'Error: Invalid price value for product ' +
          materialNumber +
          ': ' +
          priceStr;
      }
    }
    return null;
  }

  private static Decimal parsePrice(String priceStr) {
    if (priceStr != null && priceStr != '') {
      return Decimal.valueOf(priceStr);
    }
    return 0;
  }
}