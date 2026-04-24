import { api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import LightningModal from 'lightning/modal';
import savePdfAsFile from '@salesforce/apex/QuotePdfController.savePdfAsFile';
import sendQuotePdfEmail from '@salesforce/apex/QuotePdfController.sendQuotePdfEmail';

export default class QuotePdfViewer extends LightningModal {
    @api recordId;
    @track isProcessing = false;

    get pdfUrl() {
        // Yahan apne Visualforce page ka naam dalein
        return `/apex/quotePDF?id=${this.recordId}`;
    }

    closeModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    attachPdf() {
        this.isProcessing = true;
        
        savePdfAsFile({ recordId: this.recordId })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'PDF successfully attached to Notes & Attachments.',
                        variant: 'success'
                    })
                );
                this.isProcessing = false;
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body ? error.body.message : 'Error attaching PDF',
                        variant: 'error'
                    })
                );
                this.isProcessing = false;
            });
    }

    sendEmail() {
        this.isProcessing = true;
        
        sendQuotePdfEmail({ recordId: this.recordId })
            .then((result) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Email sent successfully to contact person.',
                        variant: 'success'
                    })
                );
                this.isProcessing = false;
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body ? error.body.message : 'Error sending email',
                        variant: 'error'
                    })
                );
                this.isProcessing = false;
            });
    }
}