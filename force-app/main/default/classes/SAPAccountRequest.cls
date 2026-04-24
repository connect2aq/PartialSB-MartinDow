public class SAPAccountRequest {
    // public String AccountId;
    public String Kunnr;
    public String Name1;
    public String Name2;
    public String Name4;
    public String Searchterm1;
    public String Searchterm2;
    public String City;
    public String District;
    public String PostlCod1;
    public String StrSuppl3;
    public String Location;
    public String Country;
    public String Bukrs;
    public String Akont;
    public String Vkorg;
    public String Zterm;
    public String Vtweg;
    public String Spart;
    public String Bzirk;
    public String Vwerk;
    public String Kdgrp;
    public String Vkbur;
    public String Waers;
    public String Vkgrp;
    public String Konda;
    public String Kalks;
    public String Vsbed;
    public String Inco1;
    public String Inco2;
    public String ZtermSd;
    public String Ktgrd;
    public List<N_CUSTMER> N_CUSTMER;
    public List<N_CUSTMER1> N_CUSTMER1;
    public List<N_CUSTMER2> N_CUSTMER2;
    public List<N_CUSTMER3> N_CUSTMER3;
    public List<N_CUSTMER4> N_CUSTMER4;
    public List<N_CUSTMER6> N_CUSTMER6;
    
    public SAPAccountRequest() { }
    
    public class N_CUSTMER {
        // public String AccountId;
        public String KUNNR;
        public String EMail;
    }
    
    public class N_CUSTMER1 {
        // public String AccountId;
        public String Kunnr;
        public String Tatyp;
        public String Taxkd;
    }
    
    public class N_CUSTMER2 {
        // public String AccountId;
        public String KUNNR;
        public String Taxtype;
        public String Taxnumber;
    }
    
    public class N_CUSTMER3 {
        // public String AccountId;
        public String Kunnr;
        public String Telephone;
    }
    
    public class N_CUSTMER4 {
        // public String AccountId;
        public String Kunnr;
        public String Mobile;
    }
    
    public class N_CUSTMER6 {
        // public String AccountId;
        public String Kunnr;
        public String CreditSegment;
        // public String RiskClass;
        // public String CheckRule;
        // public String CreditGroup;
        public String CreditLimit;
    }
}