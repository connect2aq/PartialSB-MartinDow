// fileUploadComponent.js
import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getRelatedFiles from '@salesforce/apex/FileUploadController.getRelatedFiles';
import createNotesAttachment from '@salesforce/apex/FileUploadController.createNotesAttachment';
import { NavigationMixin } from 'lightning/navigation';

export default class FileUploadComponent extends NavigationMixin(LightningElement) {
    @api recordId; // Service Request Record ID
    @track uploadedFiles = [];
    @track isLoading = false;
    
    // File upload configuration
    acceptedFormats = ['.pdf', '.png', '.jpg', '.jpeg', '.gif'];
    multiple = true;
    
    // Wire to get existing files
    wiredFilesResult;
    
    @wire(getRelatedFiles, { recordId: '$recordId' })
    wiredFiles(result) {
        this.wiredFilesResult = result;
        if (result.data) {
            this.uploadedFiles = result.data;
        } else if (result.error) {
            console.error('Error fetching files:', result.error);
        }
    }

    // Handle file upload success - Dual save to Files + Notes & Attachments
    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        this.isLoading = false;
        
        // Call Apex method to create duplicate in Notes & Attachments
        this.createNotesAttachments(uploadedFiles);
        
        // Show success message
        const evt = new ShowToastEvent({
            title: 'Success!',
            message: `${uploadedFiles.length} file(s) uploaded successfully to Files and Notes & Attachments`,
            variant: 'success',
        });
        this.dispatchEvent(evt);
        
        // Refresh the files list
        return refreshApex(this.wiredFilesResult);
    }

    // Create duplicate entries in Notes & Attachments
    async createNotesAttachments(uploadedFiles) {
        try {
            for (const file of uploadedFiles) {
                await createNotesAttachment({
                    recordId: this.recordId,
                    contentVersionId: file.contentVersionId,
                    fileName: file.name
                });
            }
            console.log('Files successfully duplicated to Notes & Attachments');
        } catch (error) {
            console.error('Error creating Notes & Attachments:', error);
            // Don't show error to user as Files upload was successful
        }
    }

    // Handle upload start
    handleUploadStart() {
        this.isLoading = true;
    }

    // Handle file preview
    handleFilePreview(event) {
        const fileId = event.target.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'filePreview'
            },
            state: {
                selectedRecordId: fileId
            }
        });
    }

    // Handle file download
    handleFileDownload(event) {
        const fileId = event.target.dataset.id;
        const downloadUrl = `/sfc/servlet.shepherd/document/download/${fileId}`;
        window.open(downloadUrl, '_blank');
    }



    // Format file size
    formatFileSize(bytes) {
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }

    // Get file type icon
    getFileIcon(fileType) {
        if (fileType.includes('pdf')) return 'doctype:pdf';
        if (fileType.includes('image')) return 'doctype:image';
        return 'doctype:unknown';
    }
}