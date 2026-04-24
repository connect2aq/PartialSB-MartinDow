@isTest
public class InvoiceProcessingServiceTest {
  @isTest
  static void testProcessInvoices_basic() {
    // Create test Account
    Account acc = new Account(
      Name = 'Test Account',
      SAP_Customer_Number__c = 'CUST001'
    );
    insert acc;

    // Build test InvoiceData
    InvoiceProcessingService.InvoiceData inv = new InvoiceProcessingService.InvoiceData();
    inv.InvoiceNumber = 'INV001';
    inv.CustomerNumber = 'CUST001';
    inv.CustomerName = 'Test Customer';
    inv.CustomerCity = 'Test City';
    inv.CustomerGroup = 'G1';
    inv.SalesDistrict = 'D1';
    inv.Division = 'Div1';
    inv.SalesGroup = 'SG1';
    inv.SalesOffice = 'SO1';
    inv.SalesOrganization = 'ORG1';
    inv.InvoiceDateTime = Date.today();
    inv.ReferenceDocumentNumber = 'REF001';
    inv.CustomerReferenceDate = Date.today();
    inv.LineItemPosition = '1001';
    inv.MaterialNumber = 'MAT001';
    inv.MaterialDescription = 'Test Material';
    inv.AlternativeMaterialID = 'ALT001';
    inv.Quantity = '10';
    inv.NetPrice = 100.0;
    inv.GrossAmount = 110.0;
    inv.SpecialPrice = 90.0;
    inv.BatchNumber = 'BATCH1';
    inv.SupplierBatchNumber = 'SUPBATCH1';
    inv.MaterialGroupCategory1 = 'C1';
    inv.MaterialGroupCategory2 = 'C2';
    inv.MaterialGroupCategory3 = 'C3';
    inv.MaterialGroupCategory4 = 'C4';
    inv.MaterialGroupCategory5 = '51';
    inv.DescriptionCategory1 = 'Desc1';
    inv.DescriptionCategory2 = 'Desc2';
    inv.DescriptionCategory3 = 'Desc3';
    inv.DescriptionCategory4 = 'Desc4';
    inv.DescriptionCategory5 = 'Desc5';
    inv.MaterialGroupCode = 'MG1';
    inv.MaterialGroupName = 'MGName';
    inv.MaterialType = 'Type1';
    inv.ProductSubgroup = 'Sub1';
    inv.AccountAssignmentGroup = 'E-CC-INS';

    InvoiceProcessingService.InvoiceWrapper wrapper = new InvoiceProcessingService.InvoiceWrapper();
    wrapper.data = new List<InvoiceProcessingService.InvoiceData>{ inv };

    Test.startTest();
    InvoiceProcessingService.processInvoices(wrapper);
    Test.stopTest();

    // Assert Invoice__c created
    List<Invoice__c> invoices = [
      SELECT Id, Invoice_Number__c
      FROM Invoice__c
      WHERE Invoice_Number__c = 'INV001'
    ];
    System.assertEquals(1, invoices.size(), 'Invoice should be created');

    // Assert Invoice_Line_Item__c created and linked
    List<Invoice_Line_Item__c> items = [
      SELECT Id, Invoice__c, External_Id__c
      FROM Invoice_Line_Item__c
      WHERE External_Id__c = 'INV001-1001'
    ];
    System.assertEquals(1, items.size(), 'Line item should be created');
    System.assertEquals(
      invoices[0].Id,
      items[0].Invoice__c,
      'Line item should be linked to invoice'
    );
  }
}