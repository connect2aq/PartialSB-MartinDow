import { api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import savePdfAsFile from '@salesforce/apex/QuotePdfController.savePdfAsFile';
import { CloseActionScreenEvent } from 'lightning/actions';
import LightningModal from 'lightning/modal';

export default class QuotePdfPreviewModal extends LightningModal {
    @api recordId;

    get pdfUrl() {
        return `/apex/QuotationReportPDF?id=${this.recordId}`;
    }

    closeModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    attachPdf() {
        savePdfAsFile({ recordId: this.recordId })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'PDF attached successfully.',
                        variant: 'success'
                    })
                );
                this.closeModal();
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body.message,
                        variant: 'error'
                    })
                );
            });
    }
}