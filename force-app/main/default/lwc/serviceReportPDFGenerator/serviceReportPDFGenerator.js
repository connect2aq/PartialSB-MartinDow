import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';

import generateAndSavePDF from '@salesforce/apex/ServiceReportPDFController.generateAndSavePDF';
import getRelatedFiles from '@salesforce/apex/ServiceReportPDFController.getRelatedFiles';
import getFileDownloadUrl from '@salesforce/apex/ServiceReportPDFController.getFileDownloadUrl';
import deleteFile from '@salesforce/apex/ServiceReportPDFController.deleteFile';

export default class ServiceReportPDFGenerator extends NavigationMixin(LightningElement) {
    @api recordId;
    
    @track isLoading = false;
    @track showModal = false;
    @track files = [];
    @track showFiles = false;
    
    wiredFilesResult;
    
    // Wire method to get related files
    @wire(getRelatedFiles, { recordId: '$recordId' })
    wiredFiles(result) {
        this.wiredFilesResult = result;
        if (result.data) {
            this.files = result.data;
            this.showFiles = this.files.length > 0;
        } else if (result.error) {
            console.error('Error loading files:', result.error);
        }
    }
    
    // Check if running on mobile
    get isMobile() {
        return this.isInSalesforceApp() || this.isMobileDevice();
    }
    
    isInSalesforceApp() {
        return (typeof window !== 'undefined' && 
                (window.location.href.indexOf('.lightning.force.com') > -1 ||
                 window.location.href.indexOf('/one/one.app') > -1 ||
                 window.location.href.indexOf('file-force.com') > -1));
    }
    
    isMobileDevice() {
        return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
    }
    
    // Get button label based on platform
    get buttonLabel() {
        return this.isMobile ? 'Generate & Save PDF' : 'Generate PDF';
    }
    
    // Get button icon
    get buttonIcon() {
        return this.isMobile ? 'utility:download' : 'utility:preview';
    }
    
    // Handle PDF generation
    handleGeneratePDF() {
        if (this.isMobile) {
            this.generateAndSavePDFMobile();
        } else {
            this.showPDFModal();
        }
    }
    
    // Mobile: Direct PDF generation and save
    generateAndSavePDFMobile() {
        this.isLoading = true;
        
        generateAndSavePDF({ caseId: this.recordId })
            .then(result => {
                this.showToast('Success', 'PDF generated and saved successfully!', 'success');
                
                // Refresh the files list
                this.refreshFilesList();
                
                // Show files section
                this.showFiles = true;
                
            })
            .catch(error => {
                console.error('Error generating PDF:', error);
                this.showToast('Error', this.getErrorMessage(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    // Desktop: Show modal with PDF preview
    showPDFModal() {
        this.showModal = true;
    }
    
    // Close modal
    closeModal() {
        this.showModal = false;
    }
    
    // Handle save PDF from modal
    handleSavePDF() {
        this.isLoading = true;
        
        generateAndSavePDF({ caseId: this.recordId })
            .then(result => {
                this.showToast('Success', 'PDF saved to Notes & Attachments!', 'success');
                this.closeModal();
                this.refreshFilesList();
                this.showFiles = true;
            })
            .catch(error => {
                console.error('Error saving PDF:', error);
                this.showToast('Error', this.getErrorMessage(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    // Refresh files list
    refreshFilesList() {
        return refreshApex(this.wiredFilesResult);
    }
    
    // Handle file preview/download
    handleFileAction(event) {
        const documentId = event.target.dataset.id;
        const action = event.target.dataset.action;
        
        if (action === 'preview') {
            this.previewFile(documentId);
        } else if (action === 'download') {
            this.downloadFile(documentId);
        } else if (action === 'delete') {
            this.deleteFileRecord(documentId);
        }
    }
    
    // Preview file
    previewFile(documentId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'filePreview'
            },
            state: {
                selectedRecordId: documentId
            }
        });
    }
    
    // Download file
    downloadFile(documentId) {
        getFileDownloadUrl({ contentDocumentId: documentId })
            .then(downloadUrl => {
                // Create temporary link and trigger download
                const link = document.createElement('a');
                link.href = downloadUrl;
                link.download = '';
                document.body.appendChild(link);
                link.click();
                document.body.removeChild(link);
            })
            .catch(error => {
                console.error('Error getting download URL:', error);
                this.showToast('Error', 'Failed to download file', 'error');
            });
    }
    
    // Delete file
    deleteFileRecord(documentId) {
        if (confirm('Are you sure you want to delete this file?')) {
            deleteFile({ contentDocumentId: documentId })
                .then(() => {
                    this.showToast('Success', 'File deleted successfully', 'success');
                    this.refreshFilesList();
                })
                .catch(error => {
                    console.error('Error deleting file:', error);
                    this.showToast('Error', 'Failed to delete file', 'error');
                });
        }
    }
    
    // Toggle files visibility
    toggleFiles() {
        this.showFiles = !this.showFiles;
    }
    
    // Get PDF URL for modal preview
    get pdfUrl() {
        return `/apex/MD_ServiceReportPDF?id=${this.recordId}`;
    }
    
    // Show toast message
    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }
    
    // Get error message from exception
    getErrorMessage(error) {
        if (error.body && error.body.message) {
            return error.body.message;
        } else if (error.message) {
            return error.message;
        }
        return 'An unknown error occurred';
    }
    
    // Get formatted date
    getFormattedDate(dateTime) {
        if (!dateTime) return '';
        const date = new Date(dateTime);
        return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
    }
}