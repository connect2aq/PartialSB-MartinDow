@isTest
public class MDOpportunityLineItemControllerTest {
  @isTest
  static void testSaveSelectedProducts_Opportunity() {
    // Create related Opportunity and Product
    MD_Opportunity__c opp = new MD_Opportunity__c(
      Name = 'Test Opp',
      Close_Date__c = Date.today().addDays(10)
    );
    insert opp;
    MD_Product2__c prod = new MD_Product2__c(Description__c = 'Test Product');
    insert prod;
    // Prepare selectedProducts list
    List<Map<Object, Object>> selectedProducts = new List<Map<Object, Object>>{
      new Map<Object, Object>{
        'materialId' => prod.Id,
        'materialNumber' => 'P001',
        'quantity' => '2',
        'price' => '100.5'
      }
    };
    // Call controller
    String result = MDOpportunityLineItemController.saveSelectedProducts(
      opp.Id,
      selectedProducts,
      'MD_Opportunity__c'
    );
    System.assert(result.contains('successfully'));
  }

  @isTest
  static void testSaveSelectedProducts_Quote() {
    MD_Quote__c quote = new MD_Quote__c(Quote_Name__c = 'Test Quote');
    insert quote;
    MD_Product2__c prod = new MD_Product2__c(Description__c = 'Test Product');
    insert prod;
    List<Map<Object, Object>> selectedProducts = new List<Map<Object, Object>>{
      new Map<Object, Object>{
        'materialId' => prod.Id,
        'materialNumber' => 'P002',
        'quantity' => '3',
        'price' => '200.0'
      }
    };
    String result = MDOpportunityLineItemController.saveSelectedProducts(
      quote.Id,
      selectedProducts,
      'MD_Quote__c'
    );
    System.assert(result.contains('successfully'));
  }

  @isTest
  static void testSaveSelectedProducts_Order() {
    MD_Order__c order = new MD_Order__c(Status__c = 'Open');
    insert order;
    MD_Product2__c prod = new MD_Product2__c(Description__c = 'Test Product');
    insert prod;
    List<Map<Object, Object>> selectedProducts = new List<Map<Object, Object>>{
      new Map<Object, Object>{
        'materialId' => prod.Id,
        'materialNumber' => 'P003',
        'quantity' => '1',
        'price' => '50.0'
      }
    };
    String result = MDOpportunityLineItemController.saveSelectedProducts(
      order.Id,
      selectedProducts,
      'MD_Order__c'
    );
    System.assert(result.contains('successfully'));
  }

  @isTest
  static void testSaveSelectedProducts_CustomerDemand() {
    Account acc = new Account(Name = 'Test Account', SAP_Customer_Number__c = '3020000001');
    insert acc;
    Customer_Demand__c demand = new Customer_Demand__c(
      Purchase_Order_No__c = 'Test Demand',
      Bill_To_Party__c = acc.Id
    );
    insert demand;
    MD_Product2__c prod = new MD_Product2__c(Description__c = 'Test Product 4');
    insert prod;
    List<Map<Object, Object>> selectedProducts = new List<Map<Object, Object>>{
      new Map<Object, Object>{
        'materialId' => prod.Id,
        'materialNumber' => 'P004',
        'quantity' => '5',
        'price' => '75.0'
      }
    };
    String result = MDOpportunityLineItemController.saveSelectedProducts(
      demand.Id,
      selectedProducts,
      'Customer_Demand__c'
    );
    System.assert(result.contains('successfully'));
  }

  @isTest
  static void testSaveSelectedProducts_BlankObjName() {
    String result = MDOpportunityLineItemController.saveSelectedProducts(
      null,
      new List<Map<Object, Object>>(),
      ''
    );
    System.assert(result.contains('Error: Parent record'));
  }

  @isTest
  static void testSaveSelectedProducts_UnsupportedObj() {
    String result = MDOpportunityLineItemController.saveSelectedProducts(
      null,
      new List<Map<Object, Object>>(),
      'Unsupported__c'
    );
    System.assert(result.contains('Unsupported parent object type'));
  }

  @isTest
  static void testSaveSelectedProducts_InvalidQuantity() {
    MD_Opportunity__c opp = new MD_Opportunity__c(
      Name = 'Test Opp',
      Close_Date__c = Date.today().addDays(10)
    );
    insert opp;
    MD_Product2__c prod = new MD_Product2__c(Description__c = 'Test Product 5');
    insert prod;
    List<Map<Object, Object>> selectedProducts = new List<Map<Object, Object>>{
      new Map<Object, Object>{
        'materialId' => prod.Id,
        'materialNumber' => 'P005',
        'quantity' => 'abc',
        'price' => '100.0'
      }
    };
    String result = MDOpportunityLineItemController.saveSelectedProducts(
      opp.Id,
      selectedProducts,
      'MD_Opportunity__c'
    );
    System.assert(result.contains('Invalid quantity value'));
  }

  @isTest
  static void testSaveSelectedProducts_InvalidPrice() {
    MD_Opportunity__c opp = new MD_Opportunity__c(
      Name = 'Test Opp',
      Close_Date__c = Date.today().addDays(10)
    );
    insert opp;
    MD_Product2__c prod = new MD_Product2__c(Description__c = 'Test Product 6');
    insert prod;
    List<Map<Object, Object>> selectedProducts = new List<Map<Object, Object>>{
      new Map<Object, Object>{
        'materialId' => prod.Id,
        'materialNumber' => 'P006',
        'quantity' => '2',
        'price' => 'abc'
      }
    };
    String result = MDOpportunityLineItemController.saveSelectedProducts(
      opp.Id,
      selectedProducts,
      'MD_Opportunity__c'
    );
    System.assert(result.contains('Invalid price value'));
  }
}