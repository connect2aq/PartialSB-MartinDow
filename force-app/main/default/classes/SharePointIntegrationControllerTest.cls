@isTest
public class SharePointIntegrationControllerTest {
  @isTest
  static void testUpdateAccountStatus() {
    Account acc = new Account(Name = 'Test Account');
    insert acc;
    Test.startTest();
    SharePointIntegrationController.updateAccountStatus(acc.Id, 'Active');
    Test.stopTest();
    Account updated = [
      SELECT Account_Status__c
      FROM Account
      WHERE Id = :acc.Id
    ];
    System.assertEquals('Active', updated.Account_Status__c);
  }

  @isTest
  static void testGetAccountContacts() {
    Account acc = new Account(Name = 'Test Account');
    insert acc;
    Contact con = new Contact(
      FirstName = 'Test',
      LastName = 'Contact',
      Email = 'test@example.com',
      AccountId = acc.Id
    );
    insert con;
    Test.startTest();
    List<Contact> contacts = SharePointIntegrationController.getAccountContacts(
      acc.Id
    );
    Test.stopTest();
    System.assertEquals(1, contacts.size());
    System.assertEquals('test@example.com', contacts[0].Email);
  }

  @isTest
  static void testGetAccountSalesAreas() {
    Account acc = new Account(Name = 'Test Account');
    insert acc;
    MD_Sales_Area__c sa = new MD_Sales_Area__c(
      Parent_Account__c = acc.Id,
      Sales_Org__c = '3000'
    );
    insert sa;
    Test.startTest();
    List<MD_Sales_Area__c> salesAreas = SharePointIntegrationController.getAccountSalesAreas(
      acc.Id
    );
    Test.stopTest();
    System.assertEquals(1, salesAreas.size());
    System.assertEquals('3000', salesAreas[0].Sales_Org__c);
  }

  @isTest
  static void testGetAccountTaxNumbers() {
    Account acc = new Account(Name = 'Test Account');
    insert acc;
    MD_Tax_Number__c tax = new MD_Tax_Number__c(
      Account__c = acc.Id,
      Tax_Category_Code__c = 'PK01 - Pakistan: CNIC',
      Category_Value__c = '888888'
    );
    insert tax;
    Test.startTest();
    List<MD_Tax_Number__c> taxes = SharePointIntegrationController.getAccountTaxNumbers(
      acc.Id
    );
    Test.stopTest();
    System.assertEquals(1, taxes.size());
    // System.assertEquals('PK01', taxes[0].Tax_Category_Code__c);
  }

  @isTest
  static void testGetAccountCreditProfiles() {
    Account acc = new Account(Name = 'Test Account');
    insert acc;
    Credit_Profile__c cp = new Credit_Profile__c(
      Account__c = acc.Id,
      Credit_Segment__c = 'ZMSPL2 MDSPL Segment - Diagnostics',
      Credit_Limit__c = 10000
    );
    insert cp;
    Test.startTest();
    List<Credit_Profile__c> cps = SharePointIntegrationController.getAccountCreditProfiles(
      acc.Id
    );
    Test.stopTest();
    System.assertEquals(1, cps.size());
    // System.assertEquals('SEG1', cps[0].Credit_Segment__c);
  }

  @isTest
  static void testGetAccountForSAPValidation() {
    Account acc = new Account(
      Name = 'Test Account',
      City__c = 'Karachi',
      Province__c = 'Sindh',
      Postal_Code__c = '75500',
      AddressLine_1__c = 'Line1',
      Country_Code__c = 'PK',
      Company_Code__c = '3000'
      // Reconciliation_Account__c = '1033',
      // Payment_Terms_FI_Role__c = 'C001',
      // Business_Vertical__c = null
    );
    insert acc;
    Test.startTest();
    Account result = SharePointIntegrationController.getAccountForSAPValidation(
      acc.Id
    );
    Test.stopTest();
    System.assertEquals('Karachi', result.City__c);
    System.assertEquals('3000', result.Company_Code__c);
  }

  @isTest
  static void testUpdateAccountStatus_catch() {
    try {
      Test.startTest();
      SharePointIntegrationController.updateAccountStatus(
        '001000000000000ZZZ',
        'Active'
      );
      Test.stopTest();
      System.assert(false, 'Exception should have been thrown');
    } catch (Exception e) {
      System.debug('Exception message: ' + e.getMessage());
      System.assert(true);
    }
  }

  // @isTest
  // static void testGetAccountContacts_catch() {
  //   try {
  //     Test.startTest();
  //     SharePointIntegrationController.getAccountContacts('invalidId');
  //     Test.stopTest();
  //     System.assert(false, 'Exception should have been thrown');
  //   } catch (Exception e) {
  //     System.assert(true);
  //   }
  // }
  // @isTest
  // static void testGetAccountContacts_catch() {
  //   try {
  //     Test.startTest();
  //     SharePointIntegrationController.getAccountContacts('001000000000000ZZZ');
  //     Test.stopTest();
  //     System.assert(false, 'Exception should have been thrown');
  //   } catch (AuraHandledException e) {
  //     System.assert(e.getMessage().contains('Failed to get contacts'));
  //   }
  // }

  // @isTest
  // static void testGetAccountSalesAreas_catch() {
  //   try {
  //     Test.startTest();
  //     SharePointIntegrationController.getAccountSalesAreas(
  //       '001000000000000ZZZ'
  //     );
  //     Test.stopTest();
  //     System.assert(false, 'Exception should have been thrown');
  //   } catch (AuraHandledException e) {
  //     System.assert(e.getMessage().contains('Failed to get sales areas'));
  //   }
  // }

  // @isTest
  // static void testGetAccountTaxNumbers_catch() {
  //   try {
  //     Test.startTest();
  //     SharePointIntegrationController.getAccountTaxNumbers(
  //       '001000000000000ZZZ'
  //     );
  //     Test.stopTest();
  //     System.assert(false, 'Exception should have been thrown');
  //   } catch (AuraHandledException e) {
  //     System.assert(e.getMessage().contains('Failed to get tax numbers'));
  //   }
  // }

  // @isTest
  // static void testGetAccountCreditProfiles_catch() {
  //   try {
  //     Test.startTest();
  //     SharePointIntegrationController.getAccountCreditProfiles(
  //       '001000000000000ZZZ'
  //     );
  //     Test.stopTest();
  //     System.assert(false, 'Exception should have been thrown');
  //   } catch (AuraHandledException e) {
  //     System.assert(e.getMessage().contains('Failed to get credit profiles'));
  //   }
  // }

  // @isTest
  // static void testGetAccountForSAPValidation_catch() {
  //   try {
  //     Test.startTest();
  //     SharePointIntegrationController.getAccountForSAPValidation(
  //       '001000000000000ZZZ'
  //     );
  //     Test.stopTest();
  //     System.assert(false, 'Exception should have been thrown');
  //   } catch (AuraHandledException e) {
  //     System.assert(e.getMessage().contains('Failed to get account'));
  //   }
  // }
}