public class OrderRequest {
    public String vbeln;
    public String docType;
    public String Bstdk;
    public String salesOrg;
    public String distrChan;
    public String division;
    public String plant;
    public String purchNo;
    public String salesOff;
    public String custRef;
    public String partnNumb;
    public String partnNum2;
    public String bname;
    public List<N_SORD> n_SORD;
    
    public OrderRequest() { }
    
    public class N_SORD {
        public String itmNumber;
        public String material;
        public String reqQty;
        public String storeLoc;
        public String Vbeln;
        // public String CondType;
        // public String CondValue;
        // public String Charg;
        // public String PartnNumb3;
    }
}