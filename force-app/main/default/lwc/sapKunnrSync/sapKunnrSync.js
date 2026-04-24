import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import runAndFetchBundleByKunnr from '@salesforce/apex/SAPKunnrSyncService.runAndFetchBundleByKunnr';

export default class SapKunnrSync extends LightningElement {
    // KUNNR stored as string for precision
    kunnr = '';
    @track busy = false;

    // UI state for messages and results
    @track bundle;
    @track noDataMessage = '';
    @track errorMessage = '';

    // Returns count of sales areas
    get salesAreaCount() {
        // Return number of sales area records
        return this.bundle && this.bundle.salesAreas ? this.bundle.salesAreas.length : 0;
    }
    // Returns count of tax numbers
    get taxCount() {
        // Return number of tax number records
        return this.bundle && this.bundle.taxNumbers ? this.bundle.taxNumbers.length : 0;
    }
    // Returns count of credit profiles
    get creditCount() {
        // Return number of credit profile records
        return this.bundle && this.bundle.creditProfiles ? this.bundle.creditProfiles.length : 0;
    }

    // Disable submit until valid KUNNR format is present
    get disableSubmit() {
        // Must be exactly 10 digits and start with '3'
        return !/^[3][0-9]{9}$/.test(this.kunnr);
    }

    // Handle input changes
handleChange(event) {
    // Keep only digits, trim to 10
    let val = (event.target.value || '').toString().replace(/\D+/g, '');
    if (val.length > 10) val = val.slice(0, 10);
    this.kunnr = val;

    // reset UI messages
    this.noDataMessage = '';
    this.errorMessage = '';
    this.bundle = undefined;
}

    // Trigger Apex
    async handleSync() {
        if (this.disableSubmit) {
            this.showToast('Invalid KUNNR', 'Please enter exactly 10 digits starting with 3.', 'error');
            return;
        }
        this.busy = true;
        this.noDataMessage = '';
        this.errorMessage = '';
        this.bundle = undefined;

        try {
            const result = await runAndFetchBundleByKunnr({ kunnr: this.kunnr.toString() });
            if (!result || !result.status) {
                this.errorMessage = 'Unexpected empty response.';
                this.showToast('Error', this.errorMessage, 'error');
                return;
            }

            if (result.status === 'SUCCESS') {
                this.bundle = result.bundle;
                this.showToast('Success', 'Account and related records synced successfully.', 'success');
            } else if (result.status === 'NO_DATA') {
                this.noDataMessage = result.message || 'No Data Available';
                this.showToast('Info', this.noDataMessage, 'info');
            } else {
                this.errorMessage = result.message || 'An error occurred.';
                this.showToast('Error', this.errorMessage, 'error');
            }
        } catch (e) {
            this.errorMessage = e && e.body && e.body.message ? e.body.message : (e && e.message ? e.message : 'Call failed.');
            this.showToast('Error', this.errorMessage, 'error');
        } finally {
            this.busy = false;
        }
    }

    // Helper to show toast notifications
    showToast(title, message, variant) {
        // Show a toast message
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}