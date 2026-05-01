// comments in English only
import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getEventDescription from '@salesforce/apex/EventLocationUpdateController.getEventDescription';

// Apex
import getEventStatusSimple from '@salesforce/apex/EventLocationUpdateController.getEventStatusSimple';
import updateEventLocation from '@salesforce/apex/EventLocationUpdateController.updateEventLocation';
import updateEventRemarks from '@salesforce/apex/EventLocationUpdateController.updateEventRemarks';
import getEventRemarks from '@salesforce/apex/EventLocationUpdateController.getEventRemarks';
import markEventNotCompleted from '@salesforce/apex/EventLocationUpdateController.markEventNotCompleted';
import { NavigationMixin } from 'lightning/navigation';
export default class EventAttendance extends NavigationMixin(LightningElement) {
    // ============ inputs ============
    _recordId;

    @api
    get recordId() {
        return this._recordId;
    }
set recordId(value) {
    const normalized = value || '';
    if (normalized === this._recordId) return;
    this._recordId = normalized;

    // comments in English only
    // Force refresh LDS wire when recordId changes

    this.stateLoaded = false;
    this.isCheckedIn = false;
    this.isCheckedOut = false;
    this.isNotCompleted = false;
    this.getEventStatusSimple(true);
    this.loadEventDescription();
}

    // ============ ui state ============
    @track showRemarksModal = false;
    @track remarksText = '';
    @track isSaving = false;
    @track isPrefilling = false;
    @track showCheckInDescription = false;
    @track stateLoaded = false;
    @track eventDescriptionText = '';
    

    // server-driven flags
    @track isCheckedIn = false;
    @track isCheckedOut = false;
    @track isNotCompleted = false;

    // ========= helper: central refresh after any mutation =========
// comments in English only
// comments in English only

async loadEventDescription() {
    try {
        this.eventDescriptionText = await getEventDescription({ eventId: this.recordId }) || '';
    } catch (e) {
        this.eventDescriptionText = '';
        const msg = e?.body?.message || e?.message || 'Failed to load event description.';
        this.toast('Error', msg, 'error');
        // console.error('getEventDescription error:', JSON.stringify(e));
    }
}




refreshRecordUI(delayMs = 1500) {
    // Notify LDS-backed components first
    try {
        getRecordNotifyChange([{ recordId: this.recordId }]);
    } catch (e) {
        // no-op
    }

    // Soft reload the same record page after a delay
    try {
        // wait so the server commit finishes and fields are visible on reload
        setTimeout(() => {
            this[NavigationMixin.Navigate](
                {
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: this.recordId,
                        objectApiName: 'Event', // change if your object is custom e.g., 'Event__c'
                        actionName: 'view'
                    }
                },
                true // replace = true (don’t add a new history entry)
            );

            // OPTIONAL ultra-safe fallback: hard reload shortly after soft navigate.
            // Uncomment if your org still shows stale UI sometimes.
            // setTimeout(() => { window.location.reload(); }, 400);

        }, delayMs);
    } catch (e) {
        // no-op
    }
}



    // ========= server: status (cache-busted) =========
    async getEventStatusSimple(bust = false) {
        try {
            const params = bust
                ? { eventId: this.recordId, nonce: Date.now() }
                : { eventId: this.recordId, nonce: null };

            const data = await getEventStatusSimple(params);
            if (data) {
                this.isCheckedIn = !!data.hasCheckIn;
                this.isCheckedOut = !!data.hasCheckOut;
                this.isNotCompleted = !!data.isNotCompleted;

                if (this.isCheckedIn && !this.isCheckedOut && !this.isNotCompleted) {
                    this.showCheckInDescription = true;
                }
            }
        } catch (ex) {
            // eslint-disable-next-line no-console
            console.error('Error loading event status:', ex?.message);
        } finally {
            this.stateLoaded = true;
        }
    }

    // ========= button disabled (pure flags) =========
get isCheckInDisabled() {
    if (!this.recordId) return true;
    if (this.isSaving || this.isPrefilling) return true;
    if (!this.stateLoaded) return false;
    return this.isCheckedIn || this.isCheckedOut || this.isNotCompleted;
}

get isCheckOutDisabled() {
    if (!this.recordId) return true;
    if (this.isSaving || this.isPrefilling) return true;
    if (!this.stateLoaded) return true;
    return !this.isCheckedIn || this.isCheckedOut || this.isNotCompleted;
}

    get isNotCompletedDisabled() {
        if (!this.recordId) return true;
        if (!this.stateLoaded) return false;
        return this.isCheckedOut || this.isNotCompleted;
    }
// comments in English only
getGeoErrorMessage(error, actionLabel) {
    if (!error || typeof error.code === 'undefined') {
        return `Failed to get current location for ${actionLabel}.`;
    }

    if (error.code === 1) {
        return 'Location permission denied. Please allow location access and try again.';
    }
    if (error.code === 2) {
        return 'Location unavailable. Please turn on GPS/Location Services and try again.';
    }
    if (error.code === 3) {
        return 'Location request timed out. Please move to an open area and try again.';
    }

    return `Failed to get current location for ${actionLabel}.`;
}

    // ========= handlers =========
handleCheckIn() {
    if (!navigator.geolocation) {
        this.toast('Error', 'Geolocation is not supported by this browser.', 'error');
        return;
    }

    // comments in English only
    // Prevent double clicks while a request is already running
    if (this.isSaving) {
        return;
    }

    this.isSaving = true;

    const options = {
        enableHighAccuracy: true,
        maximumAge: 0,
        timeout: 15000 // 15 seconds
    };

    navigator.geolocation.getCurrentPosition(
        (pos) => {
            const latitude = pos.coords.latitude;
            const longitude = pos.coords.longitude;

            this.saveLocation({ latitude, longitude, isCheckIn: true })
                .finally(() => {
                    this.isSaving = false;
                });
        },
        (error) => {
            const msg = this.getGeoErrorMessage(error, 'check-in');
            this.toast('Error', msg, 'error');
            this.isSaving = false;
        },
        options
    );
}


    async handleCheckOut() {
        this.isPrefilling = true;
        try {
            const existing = await getEventRemarks({ eventId: this.recordId });
            this.remarksText = existing || '';
        } catch (e) {
            this.remarksText = '';
        } finally {
            this.isPrefilling = false;
        }
        this.showRemarksModal = true;
    }

    handleRemarksChange(evt) {
        this.remarksText = evt.target.value || '';
    }

    handleCancelRemarks() {
        this.showRemarksModal = false;
        this.remarksText = '';
    }

    async handleSaveRemarksAndCheckout() {
        this.isSaving = true;
        try {
            if (this.remarksText && this.remarksText.trim().length > 0) {
                await updateEventRemarks({
                    eventId: this.recordId,
                    remarks: this.remarksText.trim()
                });
            }
            if (!navigator.geolocation) {
                this.isSaving = false;
                this.toast('Error', 'Geolocation is not supported by this browser.', 'error');
                return;
            }
            navigator.geolocation.getCurrentPosition(
                async pos => {
                    const latitude = pos.coords.latitude;
                    const longitude = pos.coords.longitude;
                    try {
                        await this.saveLocation({ latitude, longitude, isCheckIn: false });
                        this.showRemarksModal = false;
                        this.remarksText = '';
                    } catch (e) {
                        // handled in saveLocation
                    } finally {
                        this.isSaving = false;
                    }
                },
                () => {
                    this.isSaving = false;
                    this.toast('Error', 'Failed to get current location for check-out.', 'error');
                },
                { enableHighAccuracy: true, maximumAge: 0 }
            );
        } catch (e) {
            this.isSaving = false;
            this.toast('Error', 'Failed to save remarks.', 'error');
        }
    }

async handleNotCompleted() {
    try {
        await markEventNotCompleted({ eventId: this.recordId });

        // Optimistic local flip so buttons react immediately
        this.isNotCompleted = true;

        this.toast('Success', 'Marked as Not Completed.', 'success');

        // Centralized refresh: LDS + cache-busted status
        this.refreshRecordUI();
    } catch (e) {
        this.toast('Error', 'Failed to mark as Not Completed.', 'error');
    }
}

    // ========= shared save =========
    async saveLocation({ latitude, longitude, isCheckIn }) {
        try {
            await updateEventLocation({
                eventId: this.recordId,
                lat: latitude,
                lon: longitude,
                isCheckIn: isCheckIn
            });

            // Optimistic flip so UI reacts instantly
            if (isCheckIn) {
                this.isCheckedIn = true;
                this.showCheckInDescription = true;
            } else {
                this.isCheckedOut = true;
            }

            this.toast(
                'Success',
                isCheckIn ? 'Check-in location saved successfully.' : 'Check-out location saved successfully.',
                'success'
            );

            // Centralized refresh: LDS + fresh server status (cache-busted)
            this.refreshRecordUI();
        } catch (e) {
            this.toast('Error', 'Failed to save event location.', 'error');
            // rethrow if you want upstream handling
        }
    }

    // ========= utils =========
    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}