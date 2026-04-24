// FileUploadController.cls
public with sharing class FileUploadController {
    
    /**
     * Get all files related to a Service Request record
     * @param recordId The MD_Case__c record ID
     * @return List of file information
     */
    @AuraEnabled(cacheable=true)
    public static List<FileWrapper> getRelatedFiles(Id recordId) {
        List<FileWrapper> fileList = new List<FileWrapper>();
        
        try {
            // Query ContentDocumentLinks to get files associated with the record
            List<ContentDocumentLink> docLinks = [
                SELECT ContentDocumentId, LinkedEntityId
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :recordId
                ORDER BY SystemModstamp DESC
            ];
            
            if (!docLinks.isEmpty()) {
                Set<Id> contentDocIds = new Set<Id>();
                for (ContentDocumentLink link : docLinks) {
                    contentDocIds.add(link.ContentDocumentId);
                }
                
                // Query ContentDocument and latest ContentVersion
                List<ContentDocument> documents = [
                    SELECT Id, Title, FileType, FileExtension, ContentSize, CreatedDate,
                           (SELECT Id, Title, FileType, FileExtension, ContentSize, CreatedDate 
                            FROM ContentVersions 
                            WHERE IsLatest = true 
                            ORDER BY CreatedDate DESC 
                            LIMIT 1)
                    FROM ContentDocument 
                    WHERE Id IN :contentDocIds
                    ORDER BY CreatedDate DESC
                ];
                
                for (ContentDocument doc : documents) {
                    if (!doc.ContentVersions.isEmpty()) {
                        ContentVersion version = doc.ContentVersions[0];
                        FileWrapper wrapper = new FileWrapper();
                        wrapper.Id = doc.Id;
                        wrapper.Title = doc.Title;
                        wrapper.FileType = doc.FileType;
                        wrapper.FileExtension = doc.FileExtension;
                        wrapper.FileSize = formatFileSize(doc.ContentSize);
                        wrapper.CreatedDate = doc.CreatedDate.format('MMM dd, yyyy');
                        wrapper.FileIcon = getFileIcon(doc.FileType);
                        wrapper.DownloadUrl = '/sfc/servlet.shepherd/document/download/' + doc.Id;
                        fileList.add(wrapper);
                    }
                }
            }
            
        } catch (Exception e) {
            System.debug('Error fetching files: ' + e.getMessage());
            throw new AuraHandledException('Error fetching files: ' + e.getMessage());
        }
        
        return fileList;
    }
    
    /**
     * Create duplicate entry in Notes & Attachments for backward compatibility
     * @param recordId The MD_Case__c record ID
     * @param contentVersionId The ContentVersion ID of uploaded file
     * @param fileName The original file name
     * @return Success message
     */
    @AuraEnabled
    public static String createNotesAttachment(Id recordId, Id contentVersionId, String fileName) {
        try {
            // Get the ContentVersion data
            ContentVersion cv = [
                SELECT Id, Title, FileExtension, VersionData, ContentSize
                FROM ContentVersion 
                WHERE Id = :contentVersionId 
                LIMIT 1
            ];
            
            // Create Attachment record for Notes & Attachments section
            Attachment att = new Attachment();
            att.Name = cv.Title + (String.isNotBlank(cv.FileExtension) ? '.' + cv.FileExtension : '');
            att.Body = cv.VersionData;
            att.ParentId = recordId;
            att.ContentType = getContentType(cv.FileExtension);
            att.Description = 'Uploaded via Mobile - ' + System.now().format('MMM dd, yyyy HH:mm');
            
            insert att;
            
            System.debug('Attachment created successfully: ' + att.Id);
            return 'Attachment created successfully';
            
        } catch (Exception e) {
            System.debug('Error creating attachment: ' + e.getMessage());
            throw new AuraHandledException('Error creating attachment: ' + e.getMessage());
        }
    }
    
    /**
     * Helper method to get content type based on file extension
     */
    private static String getContentType(String fileExtension) {
        if (String.isBlank(fileExtension)) return 'application/octet-stream';
        
        String ext = fileExtension.toLowerCase();
        Map<String, String> contentTypes = new Map<String, String>{
            'pdf' => 'application/pdf',
            'jpg' => 'image/jpeg',
            'jpeg' => 'image/jpeg',
            'png' => 'image/png',
            'gif' => 'image/gif',
            'doc' => 'application/msword',
            'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'xls' => 'application/vnd.ms-excel',
            'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        };
        
        return contentTypes.containsKey(ext) ? contentTypes.get(ext) : 'application/octet-stream';
    }
    
    /**
     * Helper method to format file size
     */
    private static String formatFileSize(Long bytes) {
        if (bytes == null || bytes == 0) return '0 Bytes';
        
        String[] sizes = new String[]{'Bytes', 'KB', 'MB', 'GB'};
        Integer i = 0;
        Decimal size = bytes;
        
        while (size >= 1024 && i < sizes.size() - 1) {
            size = size / 1024;
            i++;
        }
        
        return size.setScale(2) + ' ' + sizes[i];
    }
    
    /**
     * Helper method to get file icon based on file type
     */
    private static String getFileIcon(String fileType) {
        if (String.isBlank(fileType)) return 'doctype:unknown';
        
        String lowerFileType = fileType.toLowerCase();
        
        if (lowerFileType.contains('pdf')) return 'doctype:pdf';
        if (lowerFileType.contains('image') || lowerFileType.contains('jpg') || 
            lowerFileType.contains('jpeg') || lowerFileType.contains('png') || 
            lowerFileType.contains('gif')) return 'doctype:image';
        if (lowerFileType.contains('word') || lowerFileType.contains('doc')) return 'doctype:word';
        if (lowerFileType.contains('excel') || lowerFileType.contains('xls')) return 'doctype:excel';
        if (lowerFileType.contains('powerpoint') || lowerFileType.contains('ppt')) return 'doctype:ppt';
        
        return 'doctype:unknown';
    }
    
    /**
     * Wrapper class for file information
     */
    public class FileWrapper {
        @AuraEnabled public Id Id { get; set; }
        @AuraEnabled public String Title { get; set; }
        @AuraEnabled public String FileType { get; set; }
        @AuraEnabled public String FileExtension { get; set; }
        @AuraEnabled public String FileSize { get; set; }
        @AuraEnabled public String CreatedDate { get; set; }
        @AuraEnabled public String FileIcon { get; set; }
        @AuraEnabled public String DownloadUrl { get; set; }
    }
}