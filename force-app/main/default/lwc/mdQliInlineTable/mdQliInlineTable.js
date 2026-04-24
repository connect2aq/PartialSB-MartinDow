import { LightningElement, api, track, wire } from 'lwc';
import getRecords from '@salesforce/apex/RelatedInlineTableCtrl.getRecords';
import saveRecords from '@salesforce/apex/RelatedInlineTableCtrl.saveRecords';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import CHILD_OBJECT from '@salesforce/schema/MD_Quote_Line_Item__c';
import PRICE_ADJ_TYPE from '@salesforce/schema/MD_Quote_Line_Item__c.Price_Adjustment_Type__c';

export default class MdQliInlineTable extends LightningElement {
    @api recordId;
    @api childObjectApiName = 'MD_Quote_Line_Item__c';
    @api parentLookupFieldApiName = 'QuoteId__c';
    @api limitSize = 200;
    @api fieldApiNames = 'Name,Material_Number__c,Material_Description__c,Quantity__c,UnitPrice__c,Price_Adjustment_Type__c,Price_Adjustment_Value__c,Per_Kit__c,Per_Test__c,Discounts__c,TotalPrice__c';
    @api columnsJson = '';

    @track rows = [];
    @track columns = [];
    @track draftValues = [];
    @track tableErrors = null;
    picklistOptions = [];
    recordTypeId;

    @wire(getObjectInfo, { objectApiName: CHILD_OBJECT })
    wiredObjectInfo({ data, error }) {
        if (data) {
            this.recordTypeId = data.defaultRecordTypeId;
            console.log('✅ Record Type ID:', this.recordTypeId);
        } else if (error) {
            console.error('❌ Object Info Error:', error);
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$recordTypeId',
        fieldApiName: PRICE_ADJ_TYPE
    })
    wiredPicklist({ data, error }) {
        if (data) {
            this.picklistOptions = data.values.map(v => ({ 
                label: v.label, 
                value: v.value 
            }));
            console.log('✅ Picklist Values:', JSON.stringify(this.picklistOptions));
            this.columns = this.buildColumns();
        } else if (error) {
            console.error('❌ Picklist Error:', error);
            this.picklistOptions = [];
        }
    }

    connectedCallback() {
        this.columns = this.buildColumns();
        this.loadData();
    }

    buildColumns() {
        if (this.columnsJson) {
            try {
                return JSON.parse(this.columnsJson);
            } catch (e) {
                console.warn('Invalid columnsJson');
            }
        }

        return [
            {
                label: 'Name',
                fieldName: 'recordUrl',
                type: 'url',
                editable: false,
                typeAttributes: { 
                    label: { fieldName: 'Name' }, 
                    target: '_blank' 
                }
            },
            { 
                label: 'Material Number', 
                fieldName: 'Material_Number__c', 
                type: 'text', 
                editable: false 
            },
            { 
                label: 'Material Description', 
                fieldName: 'Material_Description__c', 
                type: 'text', 
                editable: false, 
                wrapText: true 
            },
            { 
                label: 'Quantity', 
                fieldName: 'Quantity__c', 
                type: 'number', 
                editable: true,
                typeAttributes: { 
                    minimumFractionDigits: 0,
                    maximumFractionDigits: 2
                }
            },
            { 
                label: 'Unit Price', 
                fieldName: 'UnitPrice__c', 
                type: 'currency', 
                editable: true,
                typeAttributes: {
                    minimumFractionDigits: 2,
                    maximumFractionDigits: 2
                }
            },
            {
    label: 'Price Adjustment Type',
    fieldName: 'Price_Adjustment_Type__c',
    type: 'picklist',          // was 'text'
    editable: true,
    wrapText: false,
    typeAttributes: {
        // show all values from getPicklistValues
        options: this.picklistOptions, 
        placeholder: 'Select'
        // Note: datatable itself supplies 'value' and 'editedValue'
    }
},
            { 
                label: 'Price Adjustment Value', 
                fieldName: 'Price_Adjustment_Value__c', 
                type: 'number', 
                editable: true,
                typeAttributes: {
                    minimumFractionDigits: 2,
                    maximumFractionDigits: 2
                }
            },
            { 
                label: 'Per Kit', 
                fieldName: 'Per_Kit__c', 
                type: 'number', 
                editable: true,
                typeAttributes: {
                    minimumFractionDigits: 0,
                    maximumFractionDigits: 2
                }
            },
            { 
                label: 'Per Test', 
                fieldName: 'Per_Test__c', 
                type: 'number', 
                editable: true,
                typeAttributes: {
                    minimumFractionDigits: 0,
                    maximumFractionDigits: 2
                }
            },
            { 
                label: 'Discounts', 
                fieldName: 'Discounts__c', 
                type: 'currency', 
                editable: false 
            },
            { 
                label: 'Total Price', 
                fieldName: 'TotalPrice__c', 
                type: 'currency', 
                editable: false 
            }
        ];
    }

    async loadData() {
        if (!this.childObjectApiName || !this.parentLookupFieldApiName || !this.recordId) {
            this.showToast('Missing Inputs', 'Required fields missing', 'error');
            return;
        }

        const fieldList = (this.fieldApiNames || '')
            .split(',')
            .map(f => f.trim())
            .filter(f => !!f && f.toLowerCase() !== 'id');

        try {
            const result = await getRecords({
                objectApiName: this.childObjectApiName,
                fieldApiNames: fieldList,
                whereClause: `${this.parentLookupFieldApiName} = '${this.recordId}'`,
                limitSize: this.limitSize
            });

            this.rows = (result || []).map(r => ({
                ...r,
                recordUrl: `/${r.Id}`
            }));
            
            console.log('✅ Loaded rows:', this.rows.length);
        } catch (e) {
            console.error('❌ Load error:', e);
            this.showToast('Load Error', e?.body?.message || e?.message, 'error');
        }
    }

    handleRefresh = () => {
        this.tableErrors = null;
        this.draftValues = [];
        this.loadData();
    };

    handleCancel = () => {
        this.draftValues = [];
        this.tableErrors = null;
    };

    async handleSave(event) {
        const drafts = event?.detail?.draftValues || [];
        if (!drafts.length) return;

        console.log('📝 Original drafts:', JSON.stringify(drafts));

        const processedDrafts = drafts.map(draft => {
            const processed = { ...draft };
            
            const numberFields = [
                'Quantity__c', 
                'UnitPrice__c', 
                'Price_Adjustment_Value__c', 
                'Per_Kit__c', 
                'Per_Test__c'
            ];
            
            numberFields.forEach(field => {
                if (processed[field] !== undefined && processed[field] !== null && processed[field] !== '') {
                    const numValue = parseFloat(processed[field]);
                    processed[field] = isNaN(numValue) ? null : numValue;
                }
            });
            
            return processed;
        });

        console.log('✅ Processed drafts:', JSON.stringify(processedDrafts));

        try {
            const response = await saveRecords({
                objectApiName: this.childObjectApiName,
                draftValues: processedDrafts
            });

            if (response && response.hasErrors) {
                const rowErrors = {};
                (response.rowErrors || []).forEach(err => {
                    rowErrors[err.id] = {
                        title: 'Validation error',
                        messages: [err.message],
                        fieldNames: err.fieldNames || []
                    };
                });
                this.tableErrors = { rows: rowErrors };

                const failedIds = new Set((response.rowErrors || []).map(e => e.id));
                this.draftValues = drafts.filter(d => failedIds.has(d.Id));

                this.showToast('Partial Save', 'Some rows failed. Check errors.', 'warning');
            } else {
                this.draftValues = [];
                this.tableErrors = null;

                this.showToast('Success!', 'Changes saved successfully.', 'success');
                
                // Reload data first
                await this.loadData();
                
                // Force page refresh after a short delay
                setTimeout(() => {
                    window.location.reload();
                }, 1000);
            }
        } catch (e) {
            console.error('❌ Save error:', e);
            this.showToast('Save Error', e?.body?.message || e?.message, 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }
}