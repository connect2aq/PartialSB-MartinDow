import { api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import savePdfAsFile from '@salesforce/apex/CasePdfController.savePdfAsFile';
import { CloseActionScreenEvent } from 'lightning/actions';
import LightningModal from 'lightning/modal'

export default class CasePdfPreviewModal extends LightningModal {
    //static renderMode = "light";
    @api recordId;

    get pdfUrl() {
        return `/apex/FieldServiceReportPDF?id=${this.recordId}`; // 
    }

    closeModal(){
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    attachPdf(){
        savePdfAsFile({recordId: this.recordId})
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