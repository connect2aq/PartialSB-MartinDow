@isTest
public class MDProductSearchControllerTest {
  @testSetup
  static void setup() {
    // Insert test products with various group values
    for (Integer i = 1; i <= 3; i++) {
      MD_Product2__c prod = new MD_Product2__c(
        Description__c = 'Test Product ' + i,
        IsActive__c = true,
        Material_Number__c = 'MAT' + i,
        Material_Group_1__c = 'G1_' + i,
        Material_Group_2__c = 'G2_' + i,
        Material_Group_3__c = 'G3_' + i,
        Material_Group_4__c = 'G4_' + i,
        Material_Group_5__c = 'G5_' + i
      );
      insert prod;
    }
  }

  @isTest
  static void testGetMaterialGroupOptions() {
    Map<String, List<String>> result = MDProductSearchController.getMaterialGroupOptions();
    System.assert(result != null);
    // System.assert(result.containsKey('Material_Group_1__c'));
    // System.assert(result.get('Material_Group_1__c').size() > 0);
  }

  @isTest
  static void testSearchMaterials_Basic() {
    List<MD_Product2__c> results = MDProductSearchController.searchMaterials(
      'MAT',
      null,
      null,
      null,
      null,
      null,
      null
    );
    System.assert(results.size() > 0);
  }

  @isTest
  static void testSearchMaterials_WithGroups() {
    List<MD_Product2__c> results = MDProductSearchController.searchMaterials(
      'MAT',
      'G1_1',
      'G2_1',
      'G3_1',
      'G4_1',
      'G5_1',
      null
    );
    System.assert(results.size() > 0);
  }

  @isTest
  static void testSearchMaterials_IndustryStandard() {
    List<MD_Product2__c> results = MDProductSearchController.searchMaterials(
      'MAT',
      null,
      null,
      null,
      null,
      null,
      '%Desc%'
    );
    // System.assert(true);
  }
}