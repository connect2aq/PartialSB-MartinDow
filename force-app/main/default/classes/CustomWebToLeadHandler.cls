@RestResource(urlMapping='/CustomWebToLead')
global without sharing class CustomWebToLeadHandler {

    global class LeadRequest {
        public String firstName;
        public String lastName;
        public String company;
        public String email;
        public String mobile;
        public Boolean webToLead;
        public String leadSource;
    }

    @HttpPost
    global static void createMDLead() {
        RestRequest req = RestContext.request;
        String requestBody = req.requestBody.toString();
        
        LeadRequest request = (LeadRequest) JSON.deserialize(requestBody, LeadRequest.class);

        System.debug('### Email: ' + request.email);
        System.debug('### First Name: ' + request.firstName);
        System.debug('### Last Name: ' + request.lastName);

        MD_Lead__c newLead = new MD_Lead__c(
            First_Name__c = request.firstName,
            Name = request.lastName,
            Company__c = request.company,
            Email__c = request.email,
            Mobile__c = request.mobile,
            Web_to_Lead__c = request.webToLead != null ? request.webToLead : true,
            Lead_Source__c = String.isNotBlank(request.leadSource) ? request.leadSource : 'Website'
        );

        insert newLead;
        
        System.debug('### Lead created successfully with Id: ' + newLead.Id);
    }
}