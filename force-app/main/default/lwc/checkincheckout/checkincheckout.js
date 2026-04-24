import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import updateEventLocation from '@salesforce/apex/EventLocationUpdateController.updateEventLocation';
import updateEventRemarks from '@salesforce/apex/EventLocationUpdateController.updateEventRemarks';
import getEventDescription from '@salesforce/apex/EventLocationUpdateController.getEventDescription';
import markEventNotCompleted from '@salesforce/apex/EventLocationUpdateController.markEventNotCompleted';
import getEventStatusSimple from '@salesforce/apex/EventLocationUpdateController.getEventStatusSimple';
// NEW: fetch current remarks to prefill
import getEventRemarks from '@salesforce/apex/EventLocationUpdateController.getEventRemarks';

import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import EVENT_OBJECT from '@salesforce/schema/Event';
import INCOMPLETE_REASON_FIELD from '@salesforce/schema/Event.Incomplete_Visit_Reason__c';

import { getRecordNotifyChange } from 'lightning/uiRecordApi';

// --- Static fallback so the dropdown always opens ---
const STATIC_REASON_OPTIONS = [
    { label: 'Customer Unavailable', value: 'Customer Unavailable' },
    { label: 'Meeting Rescheduled', value: 'Meeting Rescheduled' },
    { label: 'Emergency / Urgent Issue', value: 'Emergency / Urgent Issue' },
    { label: 'Travel / Logistics Issue', value: 'Travel / Logistics Issue' },
    { label: 'Manager Cancelled', value: 'Manager Cancelled' },
    { label: 'Other', value: 'Other' }
];

export default class CheckInComponent extends LightningElement {
    _recordId; // Event record Id

    @track latitude;
    @track longitude;
    @track locationCaptured = false;

    @track showCheckInDescription = false;
    @track showModal = false; // Checkout remarks modal
    @track remarksText = '';
    @track eventDescription = '';

    // Not Completed modal state
    @track showNotCompletedModal = false;
    @track selectedReason = '';
    @track notCompletedDescription = '';
    @track reasonOptions = STATIC_REASON_OPTIONS; // default options available immediately
    @track savingNotCompleted = false;

    // Button state tracking
    @track isCheckedIn = false;
    @track isCheckedOut = false;
    @track isNotCompleted = false;
    @track stateLoaded = false; // Track if state is loaded

    // Dynamic picklist (Reason)
    recordTypeId;

    @api get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        value = value || '';
        if (value === this.recordId) return;
        this._recordId = value;
        this.getEventStatusSimple();
    }

    // Get default record type for Event
    @wire(getObjectInfo, { objectApiName: EVENT_OBJECT })
    wiredObj({ data }) {
        if (data) {
            this.recordTypeId = data.defaultRecordTypeId;
        }
    }

    // Try to load picklist values; if it fails, we keep static list
    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: INCOMPLETE_REASON_FIELD })
    wiredReasonValues({ data }) {
        if (data && data.values?.length) {
            this.reasonOptions = data.values.map(v => ({ label: v.label, value: v.value }));
        }
    }

    async getEventStatusSimple() {
        try {
            const data = await getEventStatusSimple({ eventId: this.recordId });
            if (data) {
                this.isCheckedIn = data.hasCheckIn || false;
                this.isCheckedOut = data.hasCheckOut || false;
                this.isNotCompleted = data.isNotCompleted || false;

                // Show description if already checked in
                if (this.isCheckedIn && !this.isCheckedOut && !this.isNotCompleted) {
                    this.loadEventDescription();
                    this.showCheckInDescription = true;
                }
            }
        } catch (ex) {
            // eslint-disable-next-line no-console
            console.error('Error loading event status:', ex.message);
        } finally {
            this.stateLoaded = true; // Still mark as loaded to enable buttons
        }
    }

    // ======= Button State Getters =======
    get isCheckInDisabled() {
        if (!this.stateLoaded) return true;
        return this.isCheckedIn || this.isCheckedOut || this.isNotCompleted;
    }

    get isCheckOutDisabled() {
        if (!this.stateLoaded) return true;
        return !this.isCheckedIn || this.isCheckedOut || this.isNotCompleted;
    }

    get isNotCompletedDisabled() {
        if (!this.stateLoaded) return true;
        return this.isCheckedOut || this.isNotCompleted;
    }

    // ======= Check-In / Check-Out =======
    handleCheckIn() {
        // Get location and show description as you already had
        this.getLocation(true);
        this.loadEventDescription();
        this.showCheckInDescription = true;
    }

    async handleCheckOut() {
        // 1) Capture location (existing behavior)
        this.getLocation(false);

        // 2) Prefill remarks from server BEFORE opening modal
        //    If it errors, we just continue with empty string
        try {
            const current = await getEventRemarks({ eventId: this.recordId });
            // Safely set to empty string if null/undefined
            this.remarksText = current || '';
        } catch (e) {
            this.remarksText = '';
        }

        // 3) Open modal (now textarea shows the current remarks)
        this.showModal = true;
    }

    // Get device location and update record via Apex
    getLocation(isCheckIn) {
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    this.latitude = position.coords.latitude;
                    this.longitude = position.coords.longitude;
                    this.locationCaptured = true;
                    this.updateLocation(this.latitude, this.longitude, isCheckIn);
                },
                (error) => {
                    this.locationCaptured = false;
                    let errorMessage = 'Unable to access device location.';
                    if (error.code === error.PERMISSION_DENIED) {
                        errorMessage = 'Permission to access location was denied.';
                    } else if (error.code === error.POSITION_UNAVAILABLE) {
                        errorMessage = 'Location information is unavailable.';
                    } else if (error.code === error.TIMEOUT) {
                        errorMessage = 'The request to get user location timed out.';
                    } else if (error.code === error.UNKNOWN_ERROR) {
                        errorMessage = 'An unknown error occurred while accessing location.';
                    }
                    this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: errorMessage, variant: 'error' }));
                }
            );
        } else {
            this.locationCaptured = false;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Geolocation is not supported by this browser.',
                variant: 'error'
            }));
        }
    }

    updateLocation(latitude, longitude, isCheckIn) {
        if (!this.locationCaptured) return;

        updateEventLocation({ eventId: this.recordId, lat: latitude, lon: longitude, isCheckIn })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: isCheckIn ? 'Check-in location saved successfully.' : 'Check-out location saved successfully.',
                    variant: 'success'
                }));
                if (isCheckIn) {
                    this.isCheckedIn = true;
                } else {
                    this.isCheckedOut = true;
                }
            })
            .catch((error) => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: error?.body?.message || 'Failed to update location.',
                    variant: 'error'
                }));
            });
    }

    // ======= Checkout Remarks =======
    handleRemarksChange(event) {
        this.remarksText = event.target.value;
    }

    handleSaveRemarks() {
        if (this.remarksText.length > 255) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Remarks cannot exceed 255 characters.',
                variant: 'error'
            }));
            return;
        }

        updateEventRemarks({ eventId: this.recordId, remarks: this.remarksText })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Remarks saved successfully.',
                    variant: 'success'
                }));
                this.closeModal();
            })
            .catch((error) => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: error?.body?.message || 'Failed to save remarks.',
                    variant: 'error'
                }));
            });
    }

    handleCancelRemarks() {
        this.closeModal();
    }

    closeModal() {
        this.showModal = false;
        this.remarksText = '';
    }

    // ======= Not Completed flow =======
    openNotCompletedModal() {
        if (!this.reasonOptions || this.reasonOptions.length === 0) {
            this.reasonOptions = STATIC_REASON_OPTIONS;
        }
        this.showNotCompletedModal = true;
    }

    closeNotCompletedModal() {
        this.showNotCompletedModal = false;
        this.selectedReason = '';
        this.notCompletedDescription = '';
    }

    handleReasonChange(event) {
        this.selectedReason = event.detail.value;
    }

    handleNcDescriptionChange(event) {
        this.notCompletedDescription = event.target.value;
    }

    get disableNcSave() {
        return !this.selectedReason || this.savingNotCompleted;
    }

    handleSaveNotCompleted() {
        if (!this.recordId) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'No recordId found.',
                variant: 'error'
            }));
            return;
        }

        this.savingNotCompleted = true;

        markEventNotCompleted({
            eventId: this.recordId,
            reason: this.selectedReason,
            descriptionText: this.notCompletedDescription || ''
        })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Marked as Not Completed.',
                    variant: 'success'
                }));
                this.isNotCompleted = true;

                // Refresh current state using the same imperative method
                this.getEventStatusSimple();

                try {
                    getRecordNotifyChange([{ recordId: this.recordId }]);
                } catch (e) { /* ignore */ }
                this.closeNotCompletedModal();
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: error?.body?.message || 'Failed to mark as Not Completed.',
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.savingNotCompleted = false;
            });
    }

    // ======= Description loader =======
    loadEventDescription() {
        getEventDescription({ eventId: this.recordId })
            .then(result => {
                this.eventDescription = result;
            })
            .catch(() => {
                this.eventDescription = 'Error loading description';
            });
    }

    // ======= Helpers =======
    get googleMapsLink() {
        if (this.latitude && this.longitude) {
            return `https://www.google.com/maps?q=${this.latitude},${this.longitude}`;
        }
        return '';
    }

    get remainingCharacters() {
        return 255 - this.remarksText.length;
    }
}