public class SharePointAccountRequest {
    // public String AccountId;
    public String AccountID;
    public String NAME1;
    public String NAME2;
    // public String Name4;
    public String BusinessVertical;
    // public String Searchterm2;
    public String City;
    public String District;
    public String PostlCod1;
    public String StandardAddressLine1;
    public String StandardAddressLine2;
    public String Country;
    public String CompanyCode;
    public String ReconciliationAccount;
    public String SalesOrg;
    public String PaymentTerms;
    public String DistributionChannel;
    public String Division;
    public String SalesDistrict;
    public String DeliveringPlant;
    public String CustomerGroup;
    public String SalesOffice;
    public String CurrencyX;
    public String SalesGroup;
    public String PriceGroup;
    public String PricingProcedureIndicator;
    // public String Vsbed;
    public String Incoterms;
    public String Incoterms2;
    public String SalesPaymentTerms;
    public String CustomerAccountAssignmentGroup;
    public List<nCustomer> nCustomer;
    public List<nCustomer1> nCustomer1;
    public List<nCustomer2> nCustomer2;
    public List<nCustomer3> nCustomer3;
    public List<nCustomer4> nCustomer4;
    public List<nCustomer6> nCustomer6;
    
    public SharePointAccountRequest() { }
    
    public class nCustomer {
        // public String AccountId;
        public String accountID;
        public String eMail;
    }
    
    public class nCustomer1 {
        // public String AccountId;
        public String accountID;
        public String tatyp;
        public String taxkd;
    }
    
    public class nCustomer2 {
        // public String AccountId;
        public String AccountID;
        public String taxtype;
        public String taxnumber;
    }
    
    public class nCustomer3 {
        // public String AccountId;
        public String AccountID;
        public String telephone;
    }
    
    public class nCustomer4 {
        // public String AccountId;
        public String accountID;
        public String mobile;
    }
    
    public class nCustomer6 {
        // public String AccountId;
        public String accountID;
        public String creditSegment;
        // public String RiskClass;
        // public String CheckRule;
        // public String CreditGroup;
        public String creditLimit;
    }
}