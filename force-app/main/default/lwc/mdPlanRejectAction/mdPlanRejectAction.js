import { LightningElement, api } from 'lwc';
import processApproval from '@salesforce/apex/MDPlanApprovalService.processApproval';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class MdPlanRejectAction extends LightningElement {
    @api recordId;
    comment = '';

    // Handle textarea change
    handleCommentChange(event) {
        this.comment = event.target.value;
    }

    // Handle Reject click
    handleReject() {
        processApproval({
            recordId: this.recordId,
            action: 'Reject',
            comment: this.comment
        })
            .then(result => {
                const variant = result.success ? 'success' : 'error';
                const title = result.success ? 'Success' : 'Error';

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: title,
                        message: result.message,
                        variant: variant
                    })
                );

                if (result.success) {
                    this.dispatchEvent(new CloseActionScreenEvent());
                }
            })
            .catch(error => {
                let message = 'Unexpected error occurred.';
                if (error && error.body && error.body.message) {
                    message = error.body.message;
                }

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: message,
                        variant: 'error'
                    })
                );
            });
    }

    // Handle Cancel click
    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}