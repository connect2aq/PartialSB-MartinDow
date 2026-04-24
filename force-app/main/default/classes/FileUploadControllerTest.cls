@isTest
public class FileUploadControllerTest {
  @isTest
  static void testGetRelatedFiles() {
    // Create a parent record (MD_Case__c or any sObject you use)
    Account acc = new Account(Name = 'File Parent');
    insert acc;
    // Create ContentVersion
    ContentVersion cv = new ContentVersion(
      Title = 'TestFile',
      PathOnClient = 'TestFile.txt',
      VersionData = Blob.valueOf('Test file content'),
      IsMajorVersion = true
    );
    insert cv;
    // Get ContentDocumentId
    Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id]
    .ContentDocumentId;
    // Link to parent
    ContentDocumentLink cdl = new ContentDocumentLink(
      ContentDocumentId = docId,
      LinkedEntityId = acc.Id,
      ShareType = 'V'
    );
    insert cdl;
    // Call method
    List<FileUploadController.FileWrapper> files = FileUploadController.getRelatedFiles(
      acc.Id
    );
    System.assert(files.size() > 0, 'Should return at least one file');
    System.assertEquals('TestFile', files[0].Title);
  }

  @isTest
  static void testCreateNotesAttachment() {
    Account acc = new Account(Name = 'File Parent 2');
    insert acc;
    ContentVersion cv = new ContentVersion(
      Title = 'TestFile2',
      PathOnClient = 'TestFile2.txt',
      VersionData = Blob.valueOf('Test file content 2'),
      IsMajorVersion = true
    );
    insert cv;
    String result = FileUploadController.createNotesAttachment(
      acc.Id,
      cv.Id,
      'TestFile2.txt'
    );
    System.assertEquals('Attachment created successfully', result);
    List<Attachment> atts = [
      SELECT Id, Name, ParentId
      FROM Attachment
      WHERE ParentId = :acc.Id
    ];
    System.assert(atts.size() > 0, 'Attachment should be created');
  }
}