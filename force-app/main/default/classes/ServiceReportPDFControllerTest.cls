@isTest
public class ServiceReportPDFControllerTest {
  @isTest
  static void testGenerateAndSavePDF() {
    MD_Case__c caseRec = new MD_Case__c(Subject__c = 'Test Case');
    insert caseRec;
    Test.startTest();
    String contentVersionId = ServiceReportPDFController.generateAndSavePDF(
      caseRec.Id
    );
    Test.stopTest();
    System.assertNotEquals(
      null,
      contentVersionId,
      'ContentVersion Id should be returned'
    );
    List<ContentVersion> cvs = [
      SELECT Id, FirstPublishLocationId
      FROM ContentVersion
      WHERE FirstPublishLocationId = :caseRec.Id
    ];
    System.assertEquals(1, cvs.size(), 'ContentVersion should be created');
  }

  @isTest
  static void testGetRelatedFiles() {
    MD_Case__c caseRec = new MD_Case__c(Subject__c = 'Test Case 2');
    insert caseRec;
    ContentVersion cv = new ContentVersion(
      Title = 'Service Report - Test',
      PathOnClient = 'Service_Report_Test.pdf',
      VersionData = Blob.valueOf('Test PDF'),
      FirstPublishLocationId = caseRec.Id,
      IsMajorVersion = true
    );
    insert cv;
    List<ServiceReportPDFController.ContentDocumentWrapper> files = ServiceReportPDFController.getRelatedFiles(
      caseRec.Id
    );
    System.assert(files.size() > 0, 'Should return at least one related file');
  }

  @isTest
  static void testGetFileDownloadUrl() {
    MD_Case__c caseRec = new MD_Case__c(Subject__c = 'Test Case 3');
    insert caseRec;
    ContentVersion cv = new ContentVersion(
      Title = 'Service Report - Test',
      PathOnClient = 'Service_Report_Test.pdf',
      VersionData = Blob.valueOf('Test PDF'),
      FirstPublishLocationId = caseRec.Id,
      IsMajorVersion = true
    );
    insert cv;
    Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id]
    .ContentDocumentId;
    String url = ServiceReportPDFController.getFileDownloadUrl(docId);
    System.assert(
      url.startsWith('/sfc/servlet.shepherd/version/download/'),
      'Should return a download URL'
    );
  }

  @isTest
  static void testDeleteFile() {
    MD_Case__c caseRec = new MD_Case__c(Subject__c = 'Test Case 4');
    insert caseRec;
    ContentVersion cv = new ContentVersion(
      Title = 'Service Report - Test',
      PathOnClient = 'Service_Report_Test.pdf',
      VersionData = Blob.valueOf('Test PDF'),
      FirstPublishLocationId = caseRec.Id,
      IsMajorVersion = true
    );
    insert cv;
    Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id]
    .ContentDocumentId;
    Test.startTest();
    ServiceReportPDFController.deleteFile(docId);
    Test.stopTest();
    List<ContentDocument> cds = [
      SELECT Id
      FROM ContentDocument
      WHERE Id = :docId
    ];
    System.assertEquals(0, cds.size(), 'ContentDocument should be deleted');
  }
}