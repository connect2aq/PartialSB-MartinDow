import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';
import getPlanEvents from '@salesforce/apex/MD_PlanEventListController.getPlanEvents';

export default class MdPlanEventList extends NavigationMixin(LightningElement) {
    @api recordId;
    @api title = 'Visit Events';
    @api limitSize = 50;

    rows = [];
    wiredResult;

    // English comments only
    columns = [
        {
            type: 'button-icon',
            fixedWidth: 44,
            typeAttributes: {
                iconName: 'utility:edit',
                name: 'edit',
                title: 'Edit',
                alternativeText: 'Edit',
                variant: 'border-filled'
            }
        },
        {
            label: 'Purpose of the Meeting',
            fieldName: 'eventUrl',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'eventSubject' },
                target: '_blank'
            }
        },
        {
            label: 'Customer Name',
            fieldName: 'accountUrl',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'accountName' },
                target: '_blank'
            }
        },
        {
            label: 'Contact Person',
            fieldName: 'contactUrl',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'contactName' },
                target: '_blank'
            }
        },
{
    label: 'Start',
    fieldName: 'startDateTime',
    type: 'date',
    typeAttributes: {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        hour12: true
    }
},
{
    label: 'End',
    fieldName: 'endDateTime',
    type: 'date',
    typeAttributes: {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        hour12: true
    }
},

        { label: 'Visit Type', fieldName: 'visitType', type: 'text' },
        {
            label: 'Business Opportunity',
            fieldName: 'oppUrl',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'oppName' },
                target: '_blank'
            }
        },
        {
            label: 'Service Request',
            fieldName: 'caseUrl',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'caseName' },
                target: '_blank'
            }
        }
    ];

    @wire(getPlanEvents, { planId: '$recordId', limitSize: '$limitSize' })
    wiredEvents(result) {
        this.wiredResult = result;
        if (result.data) {
            this.rows = result.data;
        }
    }

    get hasRows() {
        return this.rows && this.rows.length > 0;
    }

    async handleRefresh() {
        if (this.wiredResult) {
            await refreshApex(this.wiredResult);
        }
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'edit') {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: row.Id,
                    objectApiName: 'Event',
                    actionName: 'edit'
                }
            });
        }
    }
}