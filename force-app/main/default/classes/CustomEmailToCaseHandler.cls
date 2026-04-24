global class CustomEmailToCaseHandler implements Messaging.InboundEmailHandler {

    global Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();

        System.debug('--- Email to Case Handler Triggered ---');

        try {
            // Step 1: Create Case
            MD_Case__c newCase = new MD_Case__c();
            newCase.Subject__c = String.isNotBlank(email.subject) ? email.subject : 'No Subject';
            newCase.Resolution_Description__c = email.plainTextBody != null ? email.plainTextBody : 'No description provided';
            //newCase.Service_Manager__c = '005BK000008W1AHYA0';
            newCase.Origin__c = 'Email';
            newCase.SuppliedEmail__c = email.fromAddress;
            newCase.RecordTypeId = Schema.SObjectType.MD_Case__c.getRecordTypeInfosByDeveloperName().get('Email_to_case').getRecordTypeId();
            System.debug('Creating Case with Subject: ' + newCase.Subject__c);

            // Step 2: Match Contact by Email
            if (!String.isBlank(envelope.fromAddress)) {
                System.debug('Looking for contact with email: ' + envelope.fromAddress);
                List<Contact> matchedContacts = [
                    SELECT Id, AccountId 
                    FROM Contact 
                    WHERE Email = :envelope.fromAddress 
                    LIMIT 1
                ];
                if (!matchedContacts.isEmpty()) {
                    Contact c = matchedContacts[0];
                    newCase.ContactId__c = c.Id;
                    newCase.AccountId__c = c.AccountId;
                    System.debug('Matched Contact Id: ' + c.Id + ' | AccountId: ' + c.AccountId);
                } else {
                    System.debug('No matching contact found for email: ' + envelope.fromAddress);
                }
            }

            // Step 3: Insert the Case
            insert newCase;
            System.debug('Inserted Case Id: ' + newCase.Id);

            // Step 4: Handle Binary Attachments
            if (email.binaryAttachments != null && !email.binaryAttachments.isEmpty()) {
                System.debug('Found binary attachments: ' + email.binaryAttachments.size());
                for (Messaging.InboundEmail.BinaryAttachment bAtt : email.binaryAttachments) {
                    insertFileToCase(bAtt.filename, bAtt.body, newCase.Id);
                }
            } else {
                System.debug('No binary attachments found');
            }

            // Step 5: Handle Text Attachments
            if (email.textAttachments != null && !email.textAttachments.isEmpty()) {
                System.debug('Found text attachments: ' + email.textAttachments.size());
                for (Messaging.InboundEmail.TextAttachment tAtt : email.textAttachments) {
                    Blob bodyBlob = Blob.valueOf(tAtt.body);
                    insertFileToCase(tAtt.filename, bodyBlob, newCase.Id);
                }
            } else {
                System.debug('No text attachments found');
            }

            result.success = true;
        } catch (Exception e) {
            result.success = false;
            System.debug('ERROR in Email-to-Case handler: ' + e.getMessage());
        }

        return result;
    }

    // Helper Method to Upload File & Link to Case
    private void insertFileToCase(String fileName, Blob fileBody, Id caseId) {
        try {
            System.debug('Uploading file: ' + fileName + ' for Case: ' + caseId);

            ContentVersion cv = new ContentVersion(
                Title = fileName,
                PathOnClient = '/' + fileName,
                VersionData = fileBody,
                IsMajorVersion = true
            );
            insert cv;
            System.debug('Inserted ContentVersion Id: ' + cv.Id);

            ContentVersion insertedCV = [
                SELECT ContentDocumentId 
                FROM ContentVersion 
                WHERE Id = :cv.Id 
                LIMIT 1
            ];
            System.debug('Fetched ContentDocumentId: ' + insertedCV.ContentDocumentId);

            ContentDocumentLink cdl = new ContentDocumentLink(
                ContentDocumentId = insertedCV.ContentDocumentId,
                LinkedEntityId = caseId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            );
            insert cdl;
            System.debug('Linked file to Case');
            
        } catch (Exception e) {
            System.debug('ERROR while uploading file: ' + fileName + ' | ' + e.getMessage());
        }
    }
}