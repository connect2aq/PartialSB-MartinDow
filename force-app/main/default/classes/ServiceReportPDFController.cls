public with sharing class ServiceReportPDFController {
    
    @AuraEnabled
    public static String generateAndSavePDF(Id caseId) {
        try {
            // Get case record for file naming
            MD_Case__c caseRecord = [SELECT Name FROM MD_Case__c WHERE Id = :caseId LIMIT 1];
            
            // Generate PDF using your VF page
            PageReference pdfPage = Page.FieldServiceReportPDF; // Your VF page name
            pdfPage.getParameters().put('id', caseId);
            
            Blob pdfBlob;
            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('Test PDF Content for Service Report');
            } else {
                pdfBlob = pdfPage.getContentAsPDF();
            }
            
            // Create ContentVersion for Notes & Attachments
            String fileName = 'Service_Report_' + (caseRecord.Name != null ? caseRecord.Name.replace('/', '_') : 'Unknown') + '_' + 
                             System.now().format('dd_MM_yyyy_HH_mm') + '.pdf';
            
            ContentVersion cv = new ContentVersion();
            cv.Title = 'Service Report - ' + (caseRecord.Name != null ? caseRecord.Name : 'Unknown');
            cv.PathOnClient = fileName;
            cv.VersionData = pdfBlob;
            cv.FirstPublishLocationId = caseId;
            cv.IsMajorVersion = true;
            insert cv;
            
            return cv.Id;
            
        } catch (Exception e) {
            System.debug('Error in generateAndSavePDF: ' + e.getMessage());
            throw new AuraHandledException('PDF generation failed: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<ContentDocumentWrapper> getRelatedFiles(Id recordId) {
        try {
            List<ContentDocumentWrapper> fileWrappers = new List<ContentDocumentWrapper>();
            
            // Get ContentDocumentLinks for the record
            List<ContentDocumentLink> cdLinks = [
                SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileType, 
                       ContentDocument.ContentSize, ContentDocument.CreatedDate,
                       ContentDocument.LastModifiedDate, ContentDocument.Owner.Name
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :recordId 
                AND ContentDocument.FileType = 'PDF'
                ORDER BY ContentDocument.LastModifiedDate DESC
                LIMIT 50
            ];
            
            for (ContentDocumentLink cdLink : cdLinks) {
                ContentDocumentWrapper wrapper = new ContentDocumentWrapper();
                wrapper.documentId = cdLink.ContentDocumentId;
                wrapper.title = cdLink.ContentDocument.Title;
                wrapper.fileType = cdLink.ContentDocument.FileType;
                wrapper.contentSize = cdLink.ContentDocument.ContentSize;
                wrapper.createdDate = cdLink.ContentDocument.CreatedDate;
                wrapper.lastModifiedDate = cdLink.ContentDocument.LastModifiedDate;
                wrapper.ownerName = cdLink.ContentDocument.Owner.Name;
                wrapper.sizeFormatted = formatFileSize(cdLink.ContentDocument.ContentSize);
                
                fileWrappers.add(wrapper);
            }
            
            return fileWrappers;
            
        } catch (Exception e) {
            System.debug('Error in getRelatedFiles: ' + e.getMessage());
            throw new AuraHandledException('Failed to retrieve files: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String getFileDownloadUrl(Id contentDocumentId) {
        try {
            // Get ContentVersion Id
            ContentVersion cv = [
                SELECT Id FROM ContentVersion 
                WHERE ContentDocumentId = :contentDocumentId 
                AND IsLatest = true 
                LIMIT 1
            ];
            
            // Return download URL
            return '/sfc/servlet.shepherd/version/download/' + cv.Id;
            
        } catch (Exception e) {
            System.debug('Error in getFileDownloadUrl: ' + e.getMessage());
            throw new AuraHandledException('Failed to get download URL: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void deleteFile(Id contentDocumentId) {
        try {
            ContentDocument cd = new ContentDocument(Id = contentDocumentId);
            delete cd;
            
        } catch (Exception e) {
            System.debug('Error in deleteFile: ' + e.getMessage());
            throw new AuraHandledException('Failed to delete file: ' + e.getMessage());
        }
    }
    
    // Helper method to format file size
    private static String formatFileSize(Integer sizeInBytes) {
        if (sizeInBytes == null) return '0 B';
        
        if (sizeInBytes < 1024) {
            return sizeInBytes + ' B';
        } else if (sizeInBytes < 1024 * 1024) {
            return String.valueOf(Math.round(sizeInBytes / 1024.0)) + ' KB';
        } else if (sizeInBytes < 1024 * 1024 * 1024) {
            return String.valueOf(Math.round(sizeInBytes / (1024.0 * 1024.0))) + ' MB';
        } else {
            return String.valueOf(Math.round(sizeInBytes / (1024.0 * 1024.0 * 1024.0))) + ' GB';
        }
    }
    
    // Wrapper class for ContentDocument data
    public class ContentDocumentWrapper {
        @AuraEnabled public Id documentId { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String fileType { get; set; }
        @AuraEnabled public Integer contentSize { get; set; }
        @AuraEnabled public DateTime createdDate { get; set; }
        @AuraEnabled public DateTime lastModifiedDate { get; set; }
        @AuraEnabled public String ownerName { get; set; }
        @AuraEnabled public String sizeFormatted { get; set; }
    }
}