@isTest
public class CustomEmailToCaseHandlerTest {
  @isTest
  static void testHandleInboundEmail_BinaryAttachment() {
    Account acc = new Account(Name = 'Attachment Account');
    insert acc;
    Contact con = new Contact(
      FirstName = 'Bin',
      LastName = 'User',
      Email = 'binuser@example.com',
      AccountId = acc.Id
    );
    insert con;

    Messaging.InboundEmail.BinaryAttachment binAtt = new Messaging.InboundEmail.BinaryAttachment();
    binAtt.body = Blob.valueOf('binary content');
    binAtt.filename = 'testfile.bin';
    binAtt.mimeTypeSubType = 'application/octet-stream';

    Messaging.InboundEmail email = new Messaging.InboundEmail();
    email.subject = 'Binary Attachment Subject';
    email.plainTextBody = 'Body with binary attachment.';
    email.fromAddress = 'binuser@example.com';
    email.binaryAttachments = new List<Messaging.InboundEmail.BinaryAttachment>{
      binAtt
    };
    email.textAttachments = new List<Messaging.InboundEmail.TextAttachment>();

    Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
    env.fromAddress = 'binuser@example.com';

    Test.startTest();
    CustomEmailToCaseHandler handler = new CustomEmailToCaseHandler();
    Messaging.InboundEmailResult result = handler.handleInboundEmail(
      email,
      env
    );
    Test.stopTest();

    System.assert(
      result.success,
      'Handler should succeed with binary attachment'
    );
    MD_Case__c[] cases = [
      SELECT Id
      FROM MD_Case__c
      WHERE Subject__c = 'Binary Attachment Subject'
    ];
    System.assertEquals(1, cases.size(), 'Case should be created');
    List<ContentDocumentLink> links = [
      SELECT Id
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :cases[0].Id
    ];
    System.assert(
      links.size() > 0,
      'ContentDocumentLink should be created for binary attachment'
    );
  }

  @isTest
  static void testHandleInboundEmail_TextAttachment() {
    Account acc = new Account(Name = 'Text Attachment Account');
    insert acc;
    Contact con = new Contact(
      FirstName = 'Text',
      LastName = 'User',
      Email = 'textuser@example.com',
      AccountId = acc.Id
    );
    insert con;

    Messaging.InboundEmail.TextAttachment textAtt = new Messaging.InboundEmail.TextAttachment();
    textAtt.body = 'text file content';
    textAtt.filename = 'testfile.txt';
    textAtt.mimeTypeSubType = 'text/plain';

    Messaging.InboundEmail email = new Messaging.InboundEmail();
    email.subject = 'Text Attachment Subject';
    email.plainTextBody = 'Body with text attachment.';
    email.fromAddress = 'textuser@example.com';
    email.binaryAttachments = new List<Messaging.InboundEmail.BinaryAttachment>();
    email.textAttachments = new List<Messaging.InboundEmail.TextAttachment>{
      textAtt
    };

    Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
    env.fromAddress = 'textuser@example.com';

    Test.startTest();
    CustomEmailToCaseHandler handler = new CustomEmailToCaseHandler();
    Messaging.InboundEmailResult result = handler.handleInboundEmail(
      email,
      env
    );
    Test.stopTest();

    System.assert(
      result.success,
      'Handler should succeed with text attachment'
    );
    MD_Case__c[] cases = [
      SELECT Id
      FROM MD_Case__c
      WHERE Subject__c = 'Text Attachment Subject'
    ];
    System.assertEquals(1, cases.size(), 'Case should be created');
    List<ContentDocumentLink> links = [
      SELECT Id
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :cases[0].Id
    ];
    System.assert(
      links.size() > 0,
      'ContentDocumentLink should be created for text attachment'
    );
  }
  @isTest
  static void testHandleInboundEmail_Basic() {
    // Create a Contact and Account for matching
    Account acc = new Account(Name = 'Test Account');
    insert acc;
    Contact con = new Contact(
      FirstName = 'Test',
      LastName = 'User',
      Email = 'testuser@example.com',
      AccountId = acc.Id
    );
    insert con;

    // Prepare inbound email
    Messaging.InboundEmail email = new Messaging.InboundEmail();
    email.subject = 'Test Email Subject';
    email.plainTextBody = 'Test email body.';
    email.fromAddress = 'testuser@example.com';
    email.binaryAttachments = new List<Messaging.InboundEmail.BinaryAttachment>();
    email.textAttachments = new List<Messaging.InboundEmail.TextAttachment>();

    Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
    env.fromAddress = 'testuser@example.com';

    Test.startTest();
    CustomEmailToCaseHandler handler = new CustomEmailToCaseHandler();
    Messaging.InboundEmailResult result = handler.handleInboundEmail(
      email,
      env
    );
    Test.stopTest();

    System.assert(result.success, 'Email handler should succeed');
    // Assert that a case was created
    MD_Case__c[] cases = [
      SELECT
        Id,
        Subject__c,
        ContactId__c,
        AccountId__c,
        Origin__c,
        SuppliedEmail__c
      FROM MD_Case__c
      WHERE Subject__c = 'Test Email Subject'
    ];
    System.assertEquals(1, cases.size(), 'One case should be created');
    System.assertEquals(con.Id, cases[0].ContactId__c);
    System.assertEquals(acc.Id, cases[0].AccountId__c);
    System.assertEquals('Email', cases[0].Origin__c);
    System.assertEquals('testuser@example.com', cases[0].SuppliedEmail__c);
  }

  @isTest
  static void testHandleInboundEmail_NoContact() {
    // Prepare inbound email with no matching contact
    Messaging.InboundEmail email = new Messaging.InboundEmail();
    email.subject = 'No Contact Subject';
    email.plainTextBody = 'No contact body.';
    email.fromAddress = 'nomatch@example.com';
    email.binaryAttachments = new List<Messaging.InboundEmail.BinaryAttachment>();
    email.textAttachments = new List<Messaging.InboundEmail.TextAttachment>();

    Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
    env.fromAddress = 'nomatch@example.com';

    Test.startTest();
    CustomEmailToCaseHandler handler = new CustomEmailToCaseHandler();
    Messaging.InboundEmailResult result = handler.handleInboundEmail(
      email,
      env
    );
    Test.stopTest();

    System.assert(result.success, 'Email handler should succeed');
    // Assert that a case was created without contact/account
    MD_Case__c[] cases = [
      SELECT Id, Subject__c, ContactId__c, AccountId__c
      FROM MD_Case__c
      WHERE Subject__c = 'No Contact Subject'
    ];
    System.assertEquals(1, cases.size(), 'One case should be created');
    System.assertEquals(null, cases[0].ContactId__c);
    System.assertEquals(null, cases[0].AccountId__c);
  }
}