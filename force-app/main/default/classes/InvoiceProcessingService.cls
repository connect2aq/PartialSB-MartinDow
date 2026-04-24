public with sharing class InvoiceProcessingService {
    public class InvoiceData {
        // Header fields
        public String InvoiceNumber;
        public String CustomerNumber;
        public String CustomerName;
        public String CustomerCity;
        public String CustomerGroup;
        public String SalesDistrict;
        public String Division;
        public String SalesGroup;
        public String SalesOffice;
        public String SalesOrganization;
        public Date InvoiceDateTime;
        public String ReferenceDocumentNumber;
        public Date CustomerReferenceDate;
        public String QuotationNumber;

        // Line-level fields
        public String LineItemPosition;
        public String MaterialNumber;
        public String MaterialDescription;
        public String AlternativeMaterialID;
        public String Quantity;
        public Decimal NetPrice;
        public Decimal GrossAmount;
        public Decimal SpecialPrice;
        public String BatchNumber;
        public String SupplierBatchNumber;
        public String MaterialGroupCategory1;
        public String MaterialGroupCategory2;
        public String MaterialGroupCategory3;
        public String MaterialGroupCategory4;
        public String MaterialGroupCategory5;
        public String DescriptionCategory1;
        public String DescriptionCategory2;
        public String DescriptionCategory3;
        public String DescriptionCategory4;
        public String DescriptionCategory5;
        public String MaterialGroupCode;
        public String MaterialGroupName;
        public String MaterialType;
        public String ProductSubgroup;
        public String AccountAssignmentGroup;
    }

    public class InvoiceWrapper {
        public List<InvoiceData> data;
    }

    public static void processInvoices(InvoiceWrapper wrapper) {
        if (wrapper == null || wrapper.data == null || wrapper.data.isEmpty())
            return;

        // --- Collect all Customer Numbers for bulk Account query ---
        Set<String> customerNumbers = new Set<String>();
        for (InvoiceData inv : wrapper.data) {
            if (String.isNotBlank(inv.CustomerNumber)) {
                customerNumbers.add(inv.CustomerNumber);
            }
        }

        Map<String, Id> customerToAccountId = new Map<String, Id>();
        if (!customerNumbers.isEmpty()) {
            for (Account acc : [
                SELECT Id, SAP_Customer_Number__c
                FROM Account
                WHERE SAP_Customer_Number__c IN :customerNumbers
            ]) {
                customerToAccountId.put(acc.SAP_Customer_Number__c, acc.Id);
            }
        }

        // Use a map to deduplicate invoices by Invoice_Number__c
        Map<String, Invoice__c> invoiceNumberToInvoice = new Map<String, Invoice__c>();
        List<Invoice_Line_Item__c> lineItemsToUpsert = new List<Invoice_Line_Item__c>();

        // --- Build Invoice + Line Items ---
        for (InvoiceData inv : wrapper.data) {
            Id accountId = customerToAccountId.get(inv.CustomerNumber);

            // Header
            if (!invoiceNumberToInvoice.containsKey(inv.InvoiceNumber)) {
                Invoice__c invoice = new Invoice__c();
                invoice.Invoice_Number__c = inv.InvoiceNumber;
                invoice.Invoice_Customer_Code__c = inv.CustomerNumber;
                invoice.Invoice_Customer_Name__c = inv.CustomerName;
                invoice.Invoice_City__c = inv.CustomerCity;
                invoice.Customer_Group__c = inv.CustomerGroup;
                invoice.Invoice_District__c = inv.SalesDistrict;
                invoice.Invoice_Division__c = inv.Division;
                invoice.Invoice_Sales_Group__c = inv.SalesGroup;
                invoice.Invoice_Sales_Office__c = inv.SalesOffice;
                invoice.Invoice_Sales_Org__c = inv.SalesOrganization;
                invoice.Invoice_Date__c = inv.InvoiceDateTime;
                invoice.Functional_Account__c = accountId;
                invoice.SO_Customer_Ref__c = inv.ReferenceDocumentNumber;
                invoice.SO_Customer_Ref_Date__c = inv.CustomerReferenceDate;
                invoice.Quotation_Number__c = inv.QuotationNumber;
                invoiceNumberToInvoice.put(inv.InvoiceNumber, invoice);
            }

            // Line
            Invoice_Line_Item__c lineItem = new Invoice_Line_Item__c();
            // Do not set Name (auto number)
            lineItem.Invoice__c = null; // will link after invoice upsert
            lineItem.Invoice_Customer_Code__c = inv.CustomerNumber;
            lineItem.Invoice_Material_No__c = inv.MaterialNumber;
            lineItem.Invoice_Material_Description__c = inv.MaterialDescription;
            lineItem.Invoice_Old_Material__c = inv.AlternativeMaterialID;
            lineItem.Invoice_Quantity__c = (inv.Quantity == null
                ? 0
                : Integer.valueOf(inv.Quantity));
            lineItem.Invoice_Net_Price__c = inv.NetPrice;
            lineItem.Invoice_Value__c = inv.GrossAmount;
            lineItem.Invoice_MRP_Price__c = inv.SpecialPrice;
            lineItem.Invoice_Batch_No__c = inv.BatchNumber;
            lineItem.Supplier_Batch_No__c = inv.SupplierBatchNumber;
            lineItem.Mat_Grp_1__c = inv.MaterialGroupCategory1;
            lineItem.Mat_Grp_2__c = inv.MaterialGroupCategory2;
            lineItem.Mat_Grp_3__c = inv.MaterialGroupCategory3;
            lineItem.Mat_Grp_4__c = inv.MaterialGroupCategory4;
            lineItem.Mat_Grp_5__c = inv.MaterialGroupCategory5;
            lineItem.Mat_Grp_Desc_1__c = inv.DescriptionCategory1;
            lineItem.Mat_Grp_Desc_2__c = inv.DescriptionCategory2;
            lineItem.Mat_Grp_Desc_3__c = inv.DescriptionCategory3;
            lineItem.Mat_Grp_Desc_4__c = inv.DescriptionCategory4;
            lineItem.Mat_Grp_Desc_5__c = inv.DescriptionCategory5;
            lineItem.Material_Group__c = inv.MaterialGroupCode;
            lineItem.Material_Group_Desc__c = inv.MaterialGroupName;
            lineItem.Material_Type__c = inv.MaterialType;
            lineItem.Invoice_SubGroup__c = inv.ProductSubgroup;
            lineItem.AG_OG__c = inv.AccountAssignmentGroup;
            // Set Invoice_Number__c for linking
            lineItem.Invoice_Number__c = inv.InvoiceNumber;

            // Set External_Id__c for upsert (InvoiceNumber-LineItemPosition)
            lineItem.External_Id__c =
                inv.InvoiceNumber +
                '-' +
                inv.LineItemPosition;

            // Vendor/Technology/DGroup only when MatGrp5 == '51'
            if (inv.MaterialGroupCategory5 == '51') {
                lineItem.Vendor__c = getVendor(inv.AccountAssignmentGroup);
                lineItem.Technology__c = getTechnology(
                    inv.AccountAssignmentGroup
                );
                lineItem.DGroup__c = getDGroup(inv.AccountAssignmentGroup);
            }

            lineItemsToUpsert.add(lineItem);
        }

        List<Invoice__c> invoicesToUpsert = new List<Invoice__c>(
            invoiceNumberToInvoice.values()
        );

        // --- Upsert Invoices ---
        upsert invoicesToUpsert Invoice_Number__c;

        // Debug: Show inserted/updated invoices
        System.debug('Invoices upserted: ' + invoicesToUpsert);

        // --- Map InvoiceNumber -> Id after upsert ---
        // Build set of all invoice numbers referenced by line items
        Set<String> allInvoiceNumbers = new Set<String>();
        for (Invoice_Line_Item__c li : lineItemsToUpsert) {
            if (String.isNotBlank(li.Invoice_Number__c)) {
                allInvoiceNumbers.add(li.Invoice_Number__c);
            }
        }
        Map<String, Id> invoiceNumberToId = new Map<String, Id>();
        for (Invoice__c inv : [
            SELECT Id, Invoice_Number__c
            FROM Invoice__c
            WHERE Invoice_Number__c IN :allInvoiceNumbers
        ]) {
            invoiceNumberToId.put(inv.Invoice_Number__c, inv.Id);
        }

        // --- Link Line Items to parent Invoice ---
        List<Invoice_Line_Item__c> lineItemsWithParent = new List<Invoice_Line_Item__c>();
        for (Invoice_Line_Item__c li : lineItemsToUpsert) {
            if (invoiceNumberToId.containsKey(li.Invoice_Number__c)) {
                li.Invoice__c = invoiceNumberToId.get(li.Invoice_Number__c);
                lineItemsWithParent.add(li);
            } else {
                System.debug(
                    'Skipping line item with missing parent Invoice: ' + li
                );
            }
        }

        // --- Upsert only line items with parent Invoice set ---
        upsert lineItemsWithParent External_Id__c;
    }

    // --- Helper Methods ---
    private static String getVendor(String code) {
        if (code == null)
            return null;
        String prefix = code.split('-').size() > 0 ? code.split('-')[0] : '';
        Map<String, String> vendorMap = new Map<String, String>{
            'E' => 'VitalScientific',
            'S' => 'VitalScientific',
            'D' => 'VitalScientific',
            'B' => 'Boule',
            'LOC' => 'VitalScientific',
            'U' => 'VitalScientific',
            'DM' => 'VitalScientific',
            'A' => 'Boule',
            'F' => 'VitalScientific',
            'LT' => '',
            'YHLO' => 'YHLO',
            'ER' => 'Erba',
            'NV' => 'Nova',
            'OR' => 'OCD',
            'STA' => 'Stago',
            'AV' => 'AlphaVenus',
            'DYM' => 'Dymind',
            'HW' => 'Headway',
            'ZYB' => 'ZYBIO'
        };
        return vendorMap.containsKey(prefix) ? vendorMap.get(prefix) : null;
    }

    private static String getTechnology(String code) {
        if (code == null)
            return null;
        List<String> parts = code.split('-');
        if (parts.size() < 2)
            return null;
        String tech = parts[1];
        if (tech == 'CC')
            return 'Clinical Chemistry';
        if (tech == 'HM')
            return 'Hematology';
        if (tech == 'ELT')
            return 'Electrolyte';
        if (tech == 'ELCT')
            return 'ELCT - Analyzer';
        if (tech == 'IMA')
            return 'Immunoassay';
        if (tech == 'COAG')
            return 'Coagulation';
        if (tech == 'URIN')
            return 'Urinalysis';
        if (tech == 'ABG')
            return 'Arterial Blood Gas';
        if (tech == 'POC')
            return 'Point of Care';
        if (tech == 'POCT')
            return 'POCT - Point of Care Test';
        if (tech == 'XRAY')
            return 'XRay';
        if (tech == 'PCR')
            return '';
        if (tech == 'UBT')
            return 'Urea Breath Test';
        return null;
    }

    // private static String getDGroup(String code) {
    //   if (code == null)
    //     return null;
    //   List<String> parts = code.split('-');
    //   if (parts.size() < 3)
    //     return 'Reagent';
    //   String prodType = parts[2];
    //   if (prodType == 'INS' || prodType == 'INS-M')
    //     return 'Instrument';
    //   return 'Reagent';
    // }

    private static String getDGroup(String code) {
        if (code == null)
            return null;
        List<String> parts = code.split('-');
        if (parts.size() < 3)
            return 'Reagent';
        String prodType = parts[2] != null ? parts[2].toUpperCase() : '';
        // Treat any prodType that starts with 'INS' (INS, INST, INS-M, INSXYZ...) as Instrument
        if (prodType.startsWith('INS'))
            return 'Instrument';
        return 'Reagent';
    }
}