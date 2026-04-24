public class CustomerDemandRequest {
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
    public String QT_VALID_F;
    public String QT_VALID_T;
    public List<N_QUOT> N_QUOT;
    
    public CustomerDemandRequest() { }
    
    public class N_QUOT {
        public String itmNumber;
        public String material;
        public String reqQty;
        public String storeLoc;
        public String Cond_Type;
        public String Cond_Value;
        public String Charg;
        public String PartnNumb3;
        public String Vbeln;
    }
}