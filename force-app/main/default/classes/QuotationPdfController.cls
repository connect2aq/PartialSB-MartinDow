public class QuotationPdfController {
    
    public string PaymentTerms { get; set; }
    
    public QuotationPdfController(ApexPages.StandardController std) {
        String quoteId = ApexPages.currentPage().getParameters().get('id');
        MD_Quote__c quote = [Select Account__c from MD_Quote__c where ID = :quoteId] ?? new MD_Quote__c();
        list<MD_Sales_Area__c> Areas = [Select Payment_Terms__c from MD_Sales_Area__c where Parent_Account__c =: quote.Account__c AND Payment_Terms__c != ''];
        if (Areas.size() > 0){
            this.PaymentTerms = Areas[0].Payment_Terms__c;
        }
    }
    
}