// sharePointIntegration.js - Updated with only SharePoint button
import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord } from 'lightning/uiRecordApi';
import createAccountInSAP from '@salesforce/apex/SharePointIntegrationService.createAccountInSAP';
import updateAccountStatus from '@salesforce/apex/SharePointIntegrationController.updateAccountStatus';
import getAccountContacts from '@salesforce/apex/SharePointIntegrationController.getAccountContacts';
import getAccountSalesAreas from '@salesforce/apex/SharePointIntegrationController.getAccountSalesAreas';
import getAccountTaxNumbers from '@salesforce/apex/SharePointIntegrationController.getAccountTaxNumbers';
import getAccountCreditProfiles from '@salesforce/apex/SharePointIntegrationController.getAccountCreditProfiles';

// Account fields for validation
const ACCOUNT_FIELDS = [
    'Account.Id',
    'Account.Name',
    'Account.Account_Name2__c',
    'Account.City__c',
    'Account.Province__c',
    'Account.Postal_Code__c',
    'Account.AddressLine_1__c',
    'Account.Addess_Line_2__c',
    'Account.Country_Code__c',
    'Account.Company_Code__c',
    'Account.Reconciliation_Account__c',
    'Account.Payment_Terms_FI_Role__c',
    'Account.Phone',
    'Account.Cell__c',
    'Account.Email__c',
    'Account.Business_Vertical__c',
    'Account.Account_Status__c',
    'Account.SAP_Customer_Number__c',
    'Account.Share_Point_Number__c'
];

export default class SharePointIntegration extends LightningElement {
    @api recordId;
    @track isLoading = false;
    @track account;
    @track validationErrors = [];

    @wire(getRecord, { recordId: '$recordId', fields: ACCOUNT_FIELDS })
    wiredAccount({ error, data }) {
        if (data) {
            this.account = data;
        } else if (error) {
            this.showToast('Error', 'Failed to load account data: ' + error.body.message, 'error');
        }
    }

    // Method to refresh the record page
    refreshRecordPage() {
        try {
            // Force refresh of record page
            this.dispatchEvent(
                new CustomEvent('recordupdated', {
                    detail: { recordId: this.recordId }
                })
            );

            // Backup refresh using Aura event
            // (Kept as-is per your existing code)
            /* eslint-disable no-eval */
            eval("$A.get('e.force:refreshView').fire();");
            /* eslint-enable no-eval */
        } catch (e) {
            // Full page reload as last resort
            setTimeout(() => {
                window.location.reload();
            }, 1000);
        }
    }

    async handleSendForApproval() {
        this.isLoading = true;
        this.validationErrors = [];
        let statusUpdated = false;

        try {
            // Step 1: Validate ALL SharePoint required fields
            const accountValidation = await this.validateSharePointRequiredFields();
            if (!accountValidation.isValid) {
                this.validationErrors = accountValidation.errors;
                this.showValidationErrors();
                return;
            }

            // Step 2: Validate related objects for SharePoint
            const relatedValidation = await this.validateRelatedObjectsForSharePoint();
            if (!relatedValidation.isValid) {
                this.validationErrors = relatedValidation.errors;
                this.showValidationErrors();
                return;
            }

            // Step 3: Update Account Status to Pending Approval
            await updateAccountStatus({ accountId: this.recordId, status: 'Pending Approval' });
            statusUpdated = true;

            // Step 4: Call SharePoint API
            try {
                await createAccountInSAP({ accountId: this.recordId });

                // Success - update final status (kept as-is)
                try {
                    await updateAccountStatus({ accountId: this.recordId, status: 'Approval Submitted' });
                } catch (statusError) {
                    // Non-blocking
                    // console.warn('Final status update warning:', statusError);
                }

                this.showToast('Success', 'Account has been sent for approval successfully!', 'success');
                this.refreshRecordPage();

            } catch (sharePointApiError) {
                throw sharePointApiError;
            }

        } catch (error) {
            // Update status to failed if it was updated to pending
            if (statusUpdated) {
                try {
                    await updateAccountStatus({ accountId: this.recordId, status: 'Approval Failed' });
                } catch (statusError) {
                    // Non-blocking
                }
            }

            // Extract actual API error message from the response
            let apiErrorMessage = '';

            if (error.message && error.message.includes('SAP Response Body:')) {
                try {
                    const jsonStart = error.message.indexOf('{');
                    if (jsonStart !== -1) {
                        const jsonStr = error.message.substring(jsonStart);
                        const errorResponse = JSON.parse(jsonStr);

                        if (errorResponse.errors) {
                            let validationErrors = [];
                            Object.keys(errorResponse.errors).forEach(field => {
                                const fieldErrors = errorResponse.errors[field];
                                if (Array.isArray(fieldErrors)) {
                                    fieldErrors.forEach(err => {
                                        validationErrors.push(`${field}: ${err}`);
                                    });
                                }
                            });

                            if (validationErrors.length > 0) {
                                apiErrorMessage = 'SharePoint API Validation Errors:\n• ' + validationErrors.join('\n• ');
                            }
                        } else if (errorResponse.title) {
                            apiErrorMessage = `SharePoint API Error: ${errorResponse.title}`;
                        }
                    }
                } catch (parseError) {
                    // Parsing failed; fall through to generic message
                }
            }

            if (!apiErrorMessage) {
                apiErrorMessage = error.body && error.body.message ? error.body.message : error.message;
            }

            this.showToast(
                'SharePoint Integration Failed',
                'There was an issue submitting the account to SharePoint for approval:\n\n' +
                    apiErrorMessage +
                    '\n\nPlease fix the above issues and try again.',
                'error'
            );

        } finally {
            this.isLoading = false;
        }
    }

    // Validate ALL SharePoint required fields
    async validateSharePointRequiredFields() {
        const errors = [];

        if (!this.account) {
            errors.push('Account data not loaded');
            return { isValid: false, errors };
        }

        const requiredFields = [
            { field: 'Name', label: 'Account Name', objectName: 'Account' },
            { field: 'Account_Name2__c', label: 'Account Name 2', objectName: 'Account' },
            { field: 'City__c', label: 'City', objectName: 'Account' },
            { field: 'Province__c', label: 'Province', objectName: 'Account' },
            { field: 'Postal_Code__c', label: 'Postal Code', objectName: 'Account' },
            { field: 'AddressLine_1__c', label: 'Address Line 1', objectName: 'Account' },
            { field: 'Addess_Line_2__c', label: 'Address Line 2', objectName: 'Account' },
            { field: 'Country_Code__c', label: 'Country Code', objectName: 'Account' },
            { field: 'Company_Code__c', label: 'Company Code', objectName: 'Account' },
            { field: 'Reconciliation_Account__c', label: 'Reconciliation Account', objectName: 'Account' },
            { field: 'Payment_Terms_FI_Role__c', label: 'Payment Terms FI Role', objectName: 'Account' },
            { field: 'Business_Vertical__c', label: 'Business Vertical', objectName: 'Account' }
        ];

        requiredFields.forEach(fieldInfo => {
            const value = this.account.fields[fieldInfo.field]?.value;
            if (!value || (typeof value === 'string' && value.trim() === '')) {
                errors.push(`Field is required in ${fieldInfo.objectName}: ${fieldInfo.label}`);
            }
        });

        return { isValid: errors.length === 0, errors };
    }

    // Enhanced validation for SharePoint related objects
    async validateRelatedObjectsForSharePoint() {
        const errors = [];

        try {
            // Contacts
            const contactValidation = await this.validateContactsForSharePoint();
            if (!contactValidation.isValid) {
                errors.push(...contactValidation.errors);
            }

            // Sales Areas
            const salesAreaValidation = await this.validateSalesAreasForSharePoint();
            if (!salesAreaValidation.isValid) {
                errors.push(...salesAreaValidation.errors);
            }

            // Tax Numbers (optional but if present should be valid)
            const taxNumberValidation = await this.validateTaxNumbersForSharePoint();
            if (!taxNumberValidation.isValid) {
                errors.push(...taxNumberValidation.errors);
            }

            // Credit Profiles (optional but if present should be valid)
            const creditProfileValidation = await this.validateCreditProfilesForSharePoint();
            if (!creditProfileValidation.isValid) {
                errors.push(...creditProfileValidation.errors);
            }

        } catch (error) {
            errors.push('Error validating related objects: ' + error.message);
        }

        return { isValid: errors.length === 0, errors };
    }

    // Contacts validation (now includes Primary_Contact__c requirement)
    async validateContactsForSharePoint() {
        try {
            const contacts = await getAccountContacts({ accountId: this.recordId });
            const errors = [];

            if (!contacts || contacts.length === 0) {
                errors.push('Please create at least 1 record to send for approval: Contact');
                return { isValid: false, errors };
            }

            // NEW: require at least one Primary Contact
            const hasPrimary = contacts.some(c => c.Primary_Contact__c === true);
            if (!hasPrimary) {
                errors.push('At least one Contact must have Primary_Contact__c checked (TRUE).');
            }

            // Existing rule: At least one of Email / Phone / MobilePhone should be present across contacts
            let hasValidContact = false;
            contacts.forEach(contact => {
                if (contact.Email || contact.Phone || contact.MobilePhone) {
                    hasValidContact = true;
                }
            });
            if (!hasValidContact) {
                errors.push('Please fill at least one of Email, Phone, or Mobile Phone in Contact records');
            }

            return { isValid: errors.length === 0, errors };
        } catch (error) {
            return { isValid: false, errors: ['Error validating Contact records: ' + error.message] };
        }
    }

    // Sales Areas validation
    async validateSalesAreasForSharePoint() {
        try {
            const salesAreas = await getAccountSalesAreas({ accountId: this.recordId });
            const errors = [];

            if (!salesAreas || salesAreas.length === 0) {
                errors.push('Please create at least 1 record to send for approval: Sales Area');
                return { isValid: false, errors };
            }

            const requiredSalesAreaFields = [
                { field: 'Sales_Org__c', label: 'Sales Organization', objectName: 'Sales Area' },
                { field: 'Distribution_Channel__c', label: 'Distribution Channel', objectName: 'Sales Area' },
                { field: 'Division__c', label: 'Division', objectName: 'Sales Area' },
                { field: 'Customer_Group__c', label: 'Customer Group', objectName: 'Sales Area' },
                { field: 'Sales_District__c', label: 'Sales District', objectName: 'Sales Area' },
                { field: 'Sales_Office__c', label: 'Sales Office', objectName: 'Sales Area' },
                { field: 'Currency__c', label: 'Currency', objectName: 'Sales Area' },
                { field: 'Sales_Group__c', label: 'Sales Group', objectName: 'Sales Area' },
                { field: 'Price_Group__c', label: 'Price Group', objectName: 'Sales Area' },
                { field: 'Pricing_Procedure_Indicator__c', label: 'Pricing Procedure Indicator', objectName: 'Sales Area' },
                { field: 'Delivering_Plant__c', label: 'Delivering Plant', objectName: 'Sales Area' },
                { field: 'Incoterms__c', label: 'Incoterms', objectName: 'Sales Area' },
                { field: 'Incoterms_Description__c', label: 'Incoterms Description', objectName: 'Sales Area' },
                { field: 'Payment_Terms__c', label: 'Payment Terms', objectName: 'Sales Area' },
                { field: 'Customer_Account_Assignment_Group__c', label: 'Customer Account Assignment Group', objectName: 'Sales Area' },
                { field: 'Output_Tax_Category_MWST_Code__c', label: 'Output Tax Category MWST Code', objectName: 'Sales Area' },
                { field: 'Output_Tax_Category_ZMST_Code__c', label: 'Output Tax Category ZMST Code', objectName: 'Sales Area' },
                { field: 'Output_Tax_Category_ZMWS_Code__c', label: 'Output Tax Category ZMWS Code', objectName: 'Sales Area' },
                { field: 'Output_Tax_Category_ZPK2_Code__c', label: 'Output Tax Category ZPK2 Code', objectName: 'Sales Area' }
            ];

            salesAreas.forEach(salesArea => {
                requiredSalesAreaFields.forEach(fieldInfo => {
                    const value = salesArea[fieldInfo.field];
                    if (!value || (typeof value === 'string' && value.trim() === '')) {
                        errors.push(`Field is required in ${fieldInfo.objectName}: ${fieldInfo.label}`);
                    }
                });
            });

            return { isValid: errors.length === 0, errors };
        } catch (error) {
            return { isValid: false, errors: ['Error validating Sales Area records: ' + error.message] };
        }
    }

    // Tax Numbers validation (optional but if present should be valid)
    async validateTaxNumbersForSharePoint() {
        try {
            const taxNumbers = await getAccountTaxNumbers({ accountId: this.recordId });
            const errors = [];

            if (taxNumbers && taxNumbers.length > 0) {
                taxNumbers.forEach(taxNumber => {
                    if (!taxNumber.Tax_Category_Code__c || taxNumber.Tax_Category_Code__c.trim() === '') {
                        errors.push('Field is required in Tax Number: Tax Category Code');
                    }
                    if (!taxNumber.Category_Value__c || taxNumber.Category_Value__c.trim() === '') {
                        errors.push('Field is required in Tax Number: Category Value');
                    }
                });
            }

            return { isValid: errors.length === 0, errors };
        } catch (error) {
            return { isValid: false, errors: ['Error validating Tax Number records: ' + error.message] };
        }
    }

    // Credit Profiles validation (optional but if present should be valid)
    async validateCreditProfilesForSharePoint() {
        try {
            const creditProfiles = await getAccountCreditProfiles({ accountId: this.recordId });
            const errors = [];

            if (creditProfiles && creditProfiles.length > 0) {
                creditProfiles.forEach(creditProfile => {
                    if (!creditProfile.Credit_Limit__c) {
                        errors.push('Field is required in Credit Profile: Credit Limit');
                    }
                });
            }

            return { isValid: errors.length === 0, errors };
        } catch (error) {
            return { isValid: false, errors: ['Error validating Credit Profile records: ' + error.message] };
        }
    }

    showValidationErrors() {
        let errorMessage = 'Please fix the following issues:\n\n';
        this.validationErrors.forEach((error, index) => {
            errorMessage += `${index + 1}. ${error}\n`;
        });

        this.showToast('Validation Failed', errorMessage, 'error');
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'sticky'
        });
        this.dispatchEvent(event);
    }
}