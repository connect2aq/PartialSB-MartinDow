@RestResource(urlMapping='/CustomWebToCase')
global without sharing class CustomWebToCaseHandler {

    global class CaseRequest {
        public String suppliedName;
        public String suppliedEmail;
        public String suppliedPhone;
        public String subject;
        public String resolutionDescription;
        public String city;
    }

    @HttpPost
    global static void createMDCase() {
        RestRequest req = RestContext.request;
        String requestBody = req.requestBody.toString();
        
        CaseRequest request = (CaseRequest) JSON.deserialize(requestBody, CaseRequest.class);

        System.debug('### suppliedEmail: ' + request.suppliedEmail);
            Id caseRtId = [
            SELECT Id
            FROM RecordType
            WHERE SobjectType = 'MD_Case__c'
            AND DeveloperName = 'Customer_Complaint'
            LIMIT 1
            ].Id;


        MD_Case__c newCase = new MD_Case__c(
            SuppliedName__c = request.suppliedName,
            SuppliedEmail__c = request.suppliedEmail,
            SuppliedPhone__c = request.suppliedPhone,
            Subject__c = request.subject,
            Resolution_Description__c = request.resolutionDescription,
            RecordTypeId = caseRtId,
            Status__c = 'New',
            //Service_Manager__c = '005BK000008W1AHYA0',
            Origin__c = 'Web',
            City1__c = request.city

        );

        if (String.isNotBlank(request.suppliedEmail)) {
            List<Contact> contacts = [SELECT Id, AccountId FROM Contact WHERE Email = :request.suppliedEmail LIMIT 1];
            System.debug('### Contacts found: ' + contacts.size());

            if (!contacts.isEmpty()) {
                Contact matchedContact = contacts[0];
                newCase.ContactId__c = matchedContact.Id;
                System.debug('### matchedContact.Id: ' + matchedContact.Id);

                if (matchedContact.AccountId != null) {
                    newCase.AccountId__c = matchedContact.AccountId;
                    System.debug('### matchedAccount.Id: ' + matchedContact.AccountId);
                } else {
                    System.debug('### Contact found but AccountId is null.');
                }
            } else {
                System.debug('### No contact found matching email.');
            }
        } else {
            System.debug('### Supplied email blank hai.');
        }

        insert newCase;
    }
}