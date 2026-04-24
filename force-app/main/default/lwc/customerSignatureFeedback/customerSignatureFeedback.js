// customerSignatureFeedback.js
import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import ID_FIELD from '@salesforce/schema/MD_Case__c.Id';
import CUSTOMER_SIGNATURE_FIELD from '@salesforce/schema/MD_Case__c.Customer_Signature__c';
import REMARKS_FIELD from '@salesforce/schema/MD_Case__c.Remarks__c';
import FIELD_SERVICE_SIGNATURE_FIELD from '@salesforce/schema/MD_Case__c.Field_Service_Signature__c';

const FIELDS = [CUSTOMER_SIGNATURE_FIELD, REMARKS_FIELD, FIELD_SERVICE_SIGNATURE_FIELD];

export default class CustomerSignatureFeedback extends LightningElement {
    @api recordId; // Current MD_Case__c record ID
    
    // UI State Management
    @track showCustomerSection = false;
    @track showFieldServiceSection = false;
    @track isLoading = false;
    @track showSuccess = false;
    @track errorMessage = '';
    @track successMessage = '';
    
    // Customer Data
    @track customerFeedback = '';
    @track customerName = '';
    
    // Field Service Data
    @track fieldServiceName = '';
    
    // Canvas and drawing properties for Customer
    customerIsDrawing = false;
    customerCanvas;
    customerContext;
    customerSignatureData = null;
    
    // Canvas and drawing properties for Field Service
    fieldServiceIsDrawing = false;
    fieldServiceCanvas;
    fieldServiceContext;
    fieldServiceSignatureData = null;
    
    // Wire to get current record data
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    record;

    // Computed Properties
    get showInitialButtons() {
        return !this.showCustomerSection && !this.showFieldServiceSection;
    }

    get showCustomerNameSignature() {
        return this.customerName && this.customerName.length > 0;
    }

    get showFieldServiceNameSignature() {
        return this.fieldServiceName && this.fieldServiceName.length > 0;
    }

    // Section Management Methods
    openCustomerSection() {
        this.showCustomerSection = true;
        this.clearMessages();
        // Initialize customer canvas after DOM update
        setTimeout(() => {
            this.initializeCustomerCanvas();
        }, 100);
    }

    closeCustomerSection() {
        this.showCustomerSection = false;
        this.clearCustomerData();
    }

    openFieldServiceSection() {
        this.showFieldServiceSection = true;
        this.clearMessages();
        // Initialize field service canvas after DOM update
        setTimeout(() => {
            this.initializeFieldServiceCanvas();
        }, 100);
    }

    closeFieldServiceSection() {
        this.showFieldServiceSection = false;
        this.clearFieldServiceData();
    }

    // Canvas Initialization Methods
    initializeCustomerCanvas() {
        this.customerCanvas = this.refs.customerSignatureCanvas;
        if (this.customerCanvas) {
            this.customerContext = this.customerCanvas.getContext('2d');
            this.setupCanvas(this.customerCanvas, this.customerContext);
        }
    }

    initializeFieldServiceCanvas() {
        this.fieldServiceCanvas = this.refs.fieldServiceSignatureCanvas;
        if (this.fieldServiceCanvas) {
            this.fieldServiceContext = this.fieldServiceCanvas.getContext('2d');
            this.setupCanvas(this.fieldServiceCanvas, this.fieldServiceContext);
        }
    }

    setupCanvas(canvas, context) {
        // Set canvas size
        canvas.width = 400;
        canvas.height = 200;
        
        // Set drawing properties
        context.strokeStyle = '#000000';
        context.lineWidth = 2;
        context.lineCap = 'round';
        context.lineJoin = 'round';
        
        // Set background color
        context.fillStyle = '#ffffff';
        context.fillRect(0, 0, canvas.width, canvas.height);
    }

    // Input Change Handlers
    handleFeedbackChange(event) {
        this.customerFeedback = event.target.value;
        this.clearMessages();
    }

    handleCustomerNameChange(event) {
        this.customerName = event.target.value;
        this.clearMessages();
    }

    handleFieldServiceNameChange(event) {
        this.fieldServiceName = event.target.value;
        this.clearMessages();
    }

    // Customer Drawing Methods
    startCustomerDrawing(event) {
        this.customerIsDrawing = true;
        this.clearMessages();
        this.startDrawing(event, this.customerCanvas, this.customerContext);
    }

    drawCustomer(event) {
        if (!this.customerIsDrawing) return;
        this.draw(event, this.customerCanvas, this.customerContext);
    }

    stopCustomerDrawing() {
        this.customerIsDrawing = false;
        this.stopDrawing(this.customerContext);
        this.captureCustomerSignatureData();
    }

    // Field Service Drawing Methods
    startFieldServiceDrawing(event) {
        this.fieldServiceIsDrawing = true;
        this.clearMessages();
        this.startDrawing(event, this.fieldServiceCanvas, this.fieldServiceContext);
    }

    drawFieldService(event) {
        if (!this.fieldServiceIsDrawing) return;
        this.draw(event, this.fieldServiceCanvas, this.fieldServiceContext);
    }

    stopFieldServiceDrawing() {
        this.fieldServiceIsDrawing = false;
        this.stopDrawing(this.fieldServiceContext);
        this.captureFieldServiceSignatureData();
    }

    // Generic Drawing Methods
    startDrawing(event, canvas, context) {
        event.preventDefault();
        const rect = canvas.getBoundingClientRect();
        const clientX = event.clientX || (event.touches && event.touches[0].clientX);
        const clientY = event.clientY || (event.touches && event.touches[0].clientY);
        
        const x = clientX - rect.left;
        const y = clientY - rect.top;
        
        context.beginPath();
        context.moveTo(x, y);
    }

    draw(event, canvas, context) {
        event.preventDefault();
        const rect = canvas.getBoundingClientRect();
        const clientX = event.clientX || (event.touches && event.touches[0].clientX);
        const clientY = event.clientY || (event.touches && event.touches[0].clientY);
        
        const x = clientX - rect.left;
        const y = clientY - rect.top;
        
        context.lineTo(x, y);
        context.stroke();
    }

    stopDrawing(context) {
        context.closePath();
    }

    // Signature Data Capture Methods
    captureCustomerSignatureData() {
        if (this.customerCanvas) {
            this.customerSignatureData = this.customerCanvas.toDataURL('image/png');
        }
    }

    captureFieldServiceSignatureData() {
        if (this.fieldServiceCanvas) {
            this.fieldServiceSignatureData = this.fieldServiceCanvas.toDataURL('image/png');
        }
    }

    // Clear Methods
    clearCustomerSignature() {
        this.clearMessages();
        this.customerName = '';
        this.customerSignatureData = null;
        
        if (this.customerContext) {
            this.customerContext.fillStyle = '#ffffff';
            this.customerContext.fillRect(0, 0, this.customerCanvas.width, this.customerCanvas.height);
        }
    }

    clearFieldServiceSignature() {
        this.clearMessages();
        this.fieldServiceName = '';
        this.fieldServiceSignatureData = null;
        
        if (this.fieldServiceContext) {
            this.fieldServiceContext.fillStyle = '#ffffff';
            this.fieldServiceContext.fillRect(0, 0, this.fieldServiceCanvas.width, this.fieldServiceCanvas.height);
        }
    }

    clearCustomerData() {
        this.customerFeedback = '';
        this.customerName = '';
        this.customerSignatureData = null;
    }

    clearFieldServiceData() {
        this.fieldServiceName = '';
        this.fieldServiceSignatureData = null;
    }

    // Name Signature Generation Methods
    generateCustomerNameSignature() {
        if (!this.customerName) return null;
        
        // Clear canvas
        this.customerContext.fillStyle = '#ffffff';
        this.customerContext.fillRect(0, 0, this.customerCanvas.width, this.customerCanvas.height);
        
        // Draw name as signature
        this.customerContext.font = '30px "Brush Script MT", cursive';
        this.customerContext.fillStyle = '#000000';
        this.customerContext.textAlign = 'center';
        this.customerContext.fillText(this.customerName, this.customerCanvas.width / 2, this.customerCanvas.height / 2 + 10);
        
        return this.customerCanvas.toDataURL('image/png');
    }

    generateFieldServiceNameSignature() {
        if (!this.fieldServiceName) return null;
        
        // Clear canvas
        this.fieldServiceContext.fillStyle = '#ffffff';
        this.fieldServiceContext.fillRect(0, 0, this.fieldServiceCanvas.width, this.fieldServiceCanvas.height);
        
        // Draw name as signature
        this.fieldServiceContext.font = '30px "Brush Script MT", cursive';
        this.fieldServiceContext.fillStyle = '#000000';
        this.fieldServiceContext.textAlign = 'center';
        this.fieldServiceContext.fillText(this.fieldServiceName, this.fieldServiceCanvas.width / 2, this.fieldServiceCanvas.height / 2 + 10);
        
        return this.fieldServiceCanvas.toDataURL('image/png');
    }

    // Validation Methods
    validateCustomerInputs() {
        if (!this.customerFeedback || this.customerFeedback.trim() === '') {
            this.errorMessage = 'Please enter customer feedback/remarks.';
            return false;
        }

        const hasCustomerNameSignature = this.customerName && this.customerName.trim() !== '';
        const hasCustomerDrawnSignature = this.customerSignatureData && !this.isCanvasEmpty(this.customerCanvas, this.customerContext);
        
        if (!hasCustomerNameSignature && !hasCustomerDrawnSignature) {
            this.errorMessage = 'Please provide either a name signature or draw a signature.';
            return false;
        }

        return true;
    }

    validateFieldServiceInputs() {
        const hasFieldServiceNameSignature = this.fieldServiceName && this.fieldServiceName.trim() !== '';
        const hasFieldServiceDrawnSignature = this.fieldServiceSignatureData && !this.isCanvasEmpty(this.fieldServiceCanvas, this.fieldServiceContext);
        
        if (!hasFieldServiceNameSignature && !hasFieldServiceDrawnSignature) {
            this.errorMessage = 'Please provide either a name signature or draw a signature.';
            return false;
        }

        return true;
    }

    isCanvasEmpty(canvas, context) {
        if (!canvas || !context) return true;
        
        const imageData = context.getImageData(0, 0, canvas.width, canvas.height);
        const data = imageData.data;
        
        for (let i = 0; i < data.length; i += 4) {
            if (data[i] !== 255 || data[i + 1] !== 255 || data[i + 2] !== 255) {
                return false;
            }
        }
        return true;
    }

    // Save Methods
    async saveCustomerSignatureAndFeedback() {
        this.clearMessages();
        
        if (!this.validateCustomerInputs()) {
            return;
        }

        this.isLoading = true;

        try {
            let finalCustomerSignature;
            if (this.customerName && this.customerName.trim() !== '') {
                finalCustomerSignature = this.generateCustomerNameSignature();
            } else {
                finalCustomerSignature = this.customerSignatureData;
            }

            const signatureHtml = `<img src="${finalCustomerSignature}" alt="Customer Signature" style="max-width: 400px; height: auto;" />`;

            const fields = {};
            fields[ID_FIELD.fieldApiName] = this.recordId;
            fields[CUSTOMER_SIGNATURE_FIELD.fieldApiName] = signatureHtml;
            fields[REMARKS_FIELD.fieldApiName] = this.customerFeedback.trim();

            const recordInput = { fields };
            await updateRecord(recordInput);

            this.successMessage = 'Customer signature and feedback saved successfully!';
            this.showSuccess = true;
            this.showToast('Success', this.successMessage, 'success');
            
            // Close section after successful save
            setTimeout(() => {
                this.closeCustomerSection();
            }, 2000);

        } catch (error) {
            console.error('Error saving customer signature and feedback:', error);
            this.errorMessage = 'Error saving customer data: ' + (error.body?.message || error.message);
            this.showToast('Error', this.errorMessage, 'error');
        } finally {
            this.isLoading = false;
            setTimeout(() => {
                this.showSuccess = false;
            }, 3000);
        }
    }

    async saveFieldServiceSignature() {
        this.clearMessages();
        
        if (!this.validateFieldServiceInputs()) {
            return;
        }

        this.isLoading = true;

        try {
            let finalFieldServiceSignature;
            if (this.fieldServiceName && this.fieldServiceName.trim() !== '') {
                finalFieldServiceSignature = this.generateFieldServiceNameSignature();
            } else {
                finalFieldServiceSignature = this.fieldServiceSignatureData;
            }

            const signatureHtml = `<img src="${finalFieldServiceSignature}" alt="Field Service Signature" style="max-width: 400px; height: auto;" />`;

            const fields = {};
            fields[ID_FIELD.fieldApiName] = this.recordId;
            fields[FIELD_SERVICE_SIGNATURE_FIELD.fieldApiName] = signatureHtml;

            const recordInput = { fields };
            await updateRecord(recordInput);

            this.successMessage = 'Field service signature saved successfully!';
            this.showSuccess = true;
            this.showToast('Success', this.successMessage, 'success');
            
            // Close modal after successful save
            setTimeout(() => {
                this.closeFieldServiceSection();
            }, 2000);

        } catch (error) {
            console.error('Error saving field service signature:', error);
            this.errorMessage = 'Error saving field service signature: ' + (error.body?.message || error.message);
            this.showToast('Error', this.errorMessage, 'error');
        } finally {
            this.isLoading = false;
            setTimeout(() => {
                this.showSuccess = false;
            }, 3000);
        }
    }

    // Utility Methods
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    clearMessages() {
        this.showSuccess = false;
        this.errorMessage = '';
        this.successMessage = '';
    }
}