import { api } from 'lwc';
import LightningModal from 'lightning/modal';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import savePdfAsFile from '@salesforce/apex/MdQuotePdfController.savePdfAsFile';

export default class MdQuotePdfController extends LightningModal {
    // Use a private backing field and a setter to react only when recordId exists
    _recordId;
    isAttaching = false;
    quoteName = 'Quote: (loading...)';

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        // Only compute substring if recordId is present to avoid runtime errors
        this.quoteName = value ? 'Quote: ' + String(value).slice(0, 8) : 'Quote: (loading...)';
    }

    // Build the VF URL only when recordId is ready
    get pdfUrl() {
        return this._recordId ? `/apex/NewquotepdfVF?id=${this._recordId}` : 'about:blank';
    }

    closeModal() {
        // Close modal and also close the quick action shell defensively
        try { this.close('cancelled'); } catch (e) { /* no-op */ }
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    attachPdf() {
        if (!this._recordId) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Missing recordId',
                message: 'Record Id is required to attach PDF.',
                variant: 'error'
            }));
            return;
        }

        this.isAttaching = true;
        savePdfAsFile({ recordId: this._recordId })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'PDF attached to Files successfully.',
                    variant: 'success'
                }));
                this.closeModal();
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: (error && error.body && error.body.message) ? error.body.message : 'Error attaching PDF',
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.isAttaching = false;
            });
    }
}