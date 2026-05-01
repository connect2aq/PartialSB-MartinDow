import { LightningElement, api, track, wire } from 'lwc';
import getRecords from '@salesforce/apex/RelatedInlineTableCtrl.getRecords';
import saveRecords from '@salesforce/apex/RelatedInlineTableCtrl.saveRecords';
import searchMaterials from '@salesforce/apex/MDProductSearchController.searchMaterials';
import saveSelectedProducts from '@salesforce/apex/MDOpportunityLineItemController.saveSelectedProducts';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import CHILD_OBJECT from '@salesforce/schema/MD_Quote_Line_Item__c';
import PRICE_ADJ_TYPE from '@salesforce/schema/MD_Quote_Line_Item__c.Price_Adjustment_Type__c';

// Fields that exist in the exported CSV but must NOT be sent to Apex on import
// (formula/rollup — Salesforce recalculates them)
const READONLY_IMPORT_FIELDS = new Set(['Discounts__c', 'TotalPrice__c', 'Name', 'recordUrl']);

// Columns exported in the CSV, in order
const EXPORT_COLUMNS = [
    { header: 'Id',                     field: 'Id' },
    { header: 'Material Number',        field: 'Material_Number__c' },
    { header: 'Material Description',   field: 'Material_Description__c' },
    { header: 'Quantity',               field: 'Quantity__c' },
    { header: 'Unit Price',             field: 'UnitPrice__c' },
    { header: 'Price Adjustment Type',  field: 'Price_Adjustment_Type__c' },
    { header: 'Price Adjustment Value', field: 'Price_Adjustment_Value__c' },
    { header: 'Per Kit',                field: 'Per_Kit__c' },
    { header: 'Per Test',               field: 'Per_Test__c' },
    { header: 'Discounts',              field: 'Discounts__c' },
    { header: 'Total Price',            field: 'TotalPrice__c' }
];

// Supported numeric fields for validation
const NUMBER_FIELDS = new Set([
    'Quantity__c', 'UnitPrice__c', 'Price_Adjustment_Value__c', 'Per_Kit__c', 'Per_Test__c'
]);

export default class MdQliInlineTable extends LightningElement {
    @api recordId;
    @api objectApiName;                  // auto-injected by the platform when placed directly on a record page
    @api parentObjectApiName = '';       // explicit override — set this in App Builder if objectApiName is not injected
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
    _detectedParentObjectApiName = '';  // auto-resolved from lookup field schema

    // ── Modal 1: Re-import exported CSV (update / insert with full data) ──────
    @track showCsvModal = false;
    @track csvPreviewRows = [];
    @track csvErrors = [];
    @track isImportingCsv = false;

    // ── Modal 2: Import New Items (material lookup from catalog) ──────────────
    @track showNewItemsModal = false;
    @track newItemsPreviewRows = [];
    @track newItemsErrors = [];
    @track isResolvingMaterials = false;
    @track isInsertingNewItems = false;

    // Maps CSV header labels (lowercase) → Salesforce API field name
    CSV_HEADER_MAP = {
        'id':                           'Id',
        'material number':              'Material_Number__c',
        'material_number__c':           'Material_Number__c',
        'materialnumber':               'Material_Number__c',
        'material no.':                 'Material_Number__c',
        'material description':         'Material_Description__c',
        'material_description__c':      'Material_Description__c',
        'materialdescription':          'Material_Description__c',
        'description':                  'Material_Description__c',
        'quantity':                     'Quantity__c',
        'quantity__c':                  'Quantity__c',
        'qty':                          'Quantity__c',
        'unit price':                   'UnitPrice__c',
        'unitprice__c':                 'UnitPrice__c',
        'unitprice':                    'UnitPrice__c',
        'price':                        'UnitPrice__c',
        'price adjustment type':        'Price_Adjustment_Type__c',
        'price_adjustment_type__c':     'Price_Adjustment_Type__c',
        'adj type':                     'Price_Adjustment_Type__c',
        'adjustment type':              'Price_Adjustment_Type__c',
        'price adjustment value':       'Price_Adjustment_Value__c',
        'price_adjustment_value__c':    'Price_Adjustment_Value__c',
        'adj value':                    'Price_Adjustment_Value__c',
        'adjustment value':             'Price_Adjustment_Value__c',
        'per kit':                      'Per_Kit__c',
        'per_kit__c':                   'Per_Kit__c',
        'perkit':                       'Per_Kit__c',
        'per test':                     'Per_Test__c',
        'per_test__c':                  'Per_Test__c',
        'pertest':                      'Per_Test__c',
        // Read-only reference columns from export — mapped for preview display only
        'discounts':                    'Discounts__c',
        'discounts__c':                 'Discounts__c',
        'total price':                  'TotalPrice__c',
        'totalprice__c':                'TotalPrice__c',
        'totalprice':                   'TotalPrice__c'
    };

    // ── Wires ─────────────────────────────────────────────────────────────────
    @wire(getObjectInfo, { objectApiName: CHILD_OBJECT })
    wiredObjectInfo({ data, error }) {
        if (data) {
            this.recordTypeId = data.defaultRecordTypeId;

            // Auto-detect parent object API name from the lookup field's schema.
            // This removes the need for any App Builder configuration.
            const lookupField = data.fields[this.parentLookupFieldApiName];
            if (lookupField && lookupField.referenceToInfos && lookupField.referenceToInfos.length > 0) {
                this._detectedParentObjectApiName = lookupField.referenceToInfos[0].apiName;
                console.log('✅ Auto-detected parent object:', this._detectedParentObjectApiName);
            }
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
            this.picklistOptions = data.values.map(v => ({ label: v.label, value: v.value }));
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
            try { return JSON.parse(this.columnsJson); } catch (e) { console.warn('Invalid columnsJson'); }
        }
        return [
            { label: 'Name', fieldName: 'recordUrl', type: 'url', editable: false,
              typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' } },
            { label: 'Material Number', fieldName: 'Material_Number__c', type: 'text', editable: false },
            { label: 'Material Description', fieldName: 'Material_Description__c', type: 'text', editable: false, wrapText: true },
            { label: 'Quantity', fieldName: 'Quantity__c', type: 'number', editable: true,
              typeAttributes: { minimumFractionDigits: 0, maximumFractionDigits: 2 } },
            { label: 'Unit Price', fieldName: 'UnitPrice__c', type: 'currency', editable: true,
              typeAttributes: { minimumFractionDigits: 2, maximumFractionDigits: 2 } },
            { label: 'Price Adjustment Type', fieldName: 'Price_Adjustment_Type__c', type: 'picklist', editable: true,
              typeAttributes: { options: this.picklistOptions, placeholder: 'Select' } },
            { label: 'Price Adjustment Value', fieldName: 'Price_Adjustment_Value__c', type: 'number', editable: true,
              typeAttributes: { minimumFractionDigits: 2, maximumFractionDigits: 2 } },
            { label: 'Per Kit', fieldName: 'Per_Kit__c', type: 'number', editable: true,
              typeAttributes: { minimumFractionDigits: 0, maximumFractionDigits: 2 } },
            { label: 'Per Test', fieldName: 'Per_Test__c', type: 'number', editable: true,
              typeAttributes: { minimumFractionDigits: 0, maximumFractionDigits: 2 } },
            { label: 'Discounts', fieldName: 'Discounts__c', type: 'currency', editable: false,
              typeAttributes: { minimumFractionDigits: 2, maximumFractionDigits: 2 } },
            { label: 'Total Price', fieldName: 'TotalPrice__c', type: 'currency', editable: false,
              typeAttributes: { minimumFractionDigits: 2, maximumFractionDigits: 2 } }
        ];
    }

    async loadData() {
        if (!this.childObjectApiName || !this.parentLookupFieldApiName || !this.recordId) {
            this.showToast('Missing Inputs', 'Required fields missing', 'error');
            return;
        }
        const fieldList = (this.fieldApiNames || '')
            .split(',').map(f => f.trim()).filter(f => !!f && f.toLowerCase() !== 'id');
        try {
            const result = await getRecords({
                objectApiName: this.childObjectApiName,
                fieldApiNames: fieldList,
                whereClause: `${this.parentLookupFieldApiName} = '${this.recordId}'`,
                limitSize: this.limitSize
            });
            this.rows = (result || []).map(r => ({ ...r, recordUrl: `/${r.Id}` }));
            console.log('✅ Loaded rows:', this.rows.length);
        } catch (e) {
            console.error('❌ Load error:', e);
            this.showToast('Load Error', e?.body?.message || e?.message, 'error');
        }
    }

    handleRefresh = () => { this.tableErrors = null; this.draftValues = []; this.loadData(); };
    handleCancel  = () => { this.draftValues = []; this.tableErrors = null; };

    async handleSave(event) {
        const drafts = event?.detail?.draftValues || [];
        if (!drafts.length) return;

        const processedDrafts = drafts.map(draft => {
            const processed = { ...draft };
            ['Quantity__c','UnitPrice__c','Price_Adjustment_Value__c','Per_Kit__c','Per_Test__c'].forEach(field => {
                if (processed[field] !== undefined && processed[field] !== null && processed[field] !== '') {
                    const n = parseFloat(processed[field]);
                    processed[field] = isNaN(n) ? null : n;
                }
            });
            return processed;
        });

        try {
            const response = await saveRecords({ objectApiName: this.childObjectApiName, draftValues: processedDrafts });
            if (response && response.hasErrors) {
                const rowErrors = {};
                (response.rowErrors || []).forEach(err => {
                    rowErrors[err.id] = { title: 'Validation error', messages: [err.message], fieldNames: err.fieldNames || [] };
                });
                this.tableErrors = { rows: rowErrors };
                const failedIds = new Set((response.rowErrors || []).map(e => e.id));
                this.draftValues = drafts.filter(d => failedIds.has(d.Id));
                this.showToast('Partial Save', 'Some rows failed. Check errors.', 'warning');
            } else {
                this.draftValues = []; this.tableErrors = null;
                this.showToast('Success!', 'Changes saved successfully.', 'success');
                await this.loadData();
                setTimeout(() => { window.location.reload(); }, 1000);
            }
        } catch (e) {
            console.error('❌ Save error:', e);
            this.showToast('Save Error', e?.body?.message || e?.message, 'error');
        }
    }

    // ── Export CSV ────────────────────────────────────────────────────────────
    handleExportCsv() {
        if (!this.rows || this.rows.length === 0) {
            this.showToast('No Data', 'There are no rows to export.', 'warning');
            return;
        }
        const headerRow = EXPORT_COLUMNS.map(c => `"${c.header}"`).join(',');
        const dataRows = this.rows.map(row =>
            EXPORT_COLUMNS.map(c => {
                const val = row[c.field];
                if (val === null || val === undefined) return '';
                return `"${String(val).replace(/"/g, '""')}"`;
            }).join(',')
        );
        this.downloadCsv([headerRow, ...dataRows].join('\n'), 'qli_export.csv');
        this.showToast('Exported', `${this.rows.length} row(s) exported. Edit then use Import CSV.`, 'success');
    }

    // ── Modal 1: Re-import CSV (update / full insert) ─────────────────────────
    get csvValidRows()   { return this.csvPreviewRows.filter(r => !r._hasError); }
    get csvUpdateCount() { return this.csvValidRows.filter(r => r._isUpdate).length; }
    get csvInsertCount() { return this.csvValidRows.filter(r => !r._isUpdate).length; }
    get csvErrorCount()  { return this.csvPreviewRows.filter(r => r._hasError).length; }
    get hasCsvErrors()   { return this.csvErrors.length > 0; }
    get hasCsvPreviewRows() { return this.csvPreviewRows.length > 0; }
    get isImportDisabled() { return this.csvValidRows.length === 0 || this.isImportingCsv; }
    get importButtonLabel() {
        if (this.isImportingCsv) return 'Importing...';
        const parts = [];
        if (this.csvUpdateCount) parts.push(`Update ${this.csvUpdateCount}`);
        if (this.csvInsertCount) parts.push(`Insert ${this.csvInsertCount}`);
        return parts.length ? parts.join(' / ') : 'Import';
    }

    handleImportCsvClick() {
        const input = this.template.querySelector('[data-id="csvFileInput"]');
        if (input) { input.value = ''; input.click(); }
    }

    handleFileChange(event) {
        const file = event.target.files[0];
        if (!file) return;
        const reader = new FileReader();
        reader.onload = (e) => {
            try {
                const text = e.target.result.replace(/^\uFEFF/, '');
                const { previewRows, errors } = this.processCSV(text);
                this.csvPreviewRows = previewRows;
                this.csvErrors = errors;
                this.showCsvModal = true;
            } catch (err) {
                this.showToast('Parse Error', err.message || 'Failed to parse CSV.', 'error');
            }
        };
        reader.readAsText(file);
    }

    processCSV(text) {
        const lines = text.split(/\r?\n/).map(l => l.trim()).filter(l => l.length > 0);
        if (lines.length < 2) throw new Error('CSV must contain a header row and at least one data row.');

        const rawHeaders = this.splitCsvLine(lines[0]);
        const headerMap = {};
        rawHeaders.forEach((h, idx) => {
            const apiName = this.CSV_HEADER_MAP[h.trim().toLowerCase()];
            if (apiName) headerMap[idx] = apiName;
        });

        const knownFields = Object.values(headerMap);
        const errors = [];
        if (!knownFields.includes('Quantity__c')) {
            errors.push('Required column "Quantity" is missing from the CSV header.');
        }

        const validPicklistSet = new Set(this.picklistOptions.map(o => o.value.toLowerCase()));

        // Only IDs that belong to this record's existing line items are valid for update.
        // Foreign IDs (exported from a different parent record) must be treated as inserts.
        const currentLineItemIds = new Set((this.rows || []).map(r => r.Id).filter(Boolean));

        const previewRows = lines.slice(1).map((line, idx) => {
            const values = this.splitCsvLine(line);
            const row = { _rowNum: idx + 1, _hasError: false, _errorMsg: '', _isUpdate: false };
            const rowErrors = [];

            Object.entries(headerMap).forEach(([colIdx, apiName]) => {
                const raw = (values[parseInt(colIdx, 10)] || '').trim();
                if (apiName === 'Id') {
                    if (raw && currentLineItemIds.has(raw)) {
                        // ID belongs to this record — safe to update
                        row.Id = raw; row._isUpdate = true;
                    }
                    // else: ID is from a different record (cross-import) — ignore, will insert
                    return;
                }
                if (READONLY_IMPORT_FIELDS.has(apiName)) { row[apiName] = raw || null; return; }
                if (!raw) { row[apiName] = null; return; }

                if (NUMBER_FIELDS.has(apiName)) {
                    const num = parseFloat(raw);
                    if (isNaN(num)) {
                        rowErrors.push(`"${apiName.replace(/__c$/i,'').replace(/_/g,' ')}" must be a number (got "${raw}")`);
                        row[apiName] = raw;
                    } else if (apiName === 'Quantity__c' && num <= 0) {
                        rowErrors.push('Quantity must be greater than 0');
                        row[apiName] = num;
                    } else {
                        row[apiName] = num;
                    }
                } else if (apiName === 'Price_Adjustment_Type__c') {
                    const picklistMatch = this.picklistOptions.find(o => o.value.toLowerCase() === raw.toLowerCase());
                    if (this.picklistOptions.length > 0 && !picklistMatch) {
                        rowErrors.push(`"${raw}" is not a valid Price Adjustment Type`);
                    }
                    row[apiName] = picklistMatch ? picklistMatch.value : raw;
                } else {
                    row[apiName] = raw;
                }
            });

            if (knownFields.includes('Quantity__c') && (row.Quantity__c === null || row.Quantity__c === undefined)) {
                rowErrors.push('Quantity is required');
            }
            if (rowErrors.length > 0) {
                row._hasError = true; row._errorMsg = rowErrors.join('; ');
                errors.push(`Row ${idx + 1}: ${row._errorMsg}`);
            }
            return row;
        });

        return { previewRows, errors };
    }

    buildImportRecord(row) {
        const internalKeys = new Set(['_rowNum', '_hasError', '_errorMsg', '_isUpdate']);
        const record = {};
        if (row._isUpdate && row.Id) { record.Id = row.Id; }
        else { record[this.parentLookupFieldApiName] = this.recordId; }

        Object.entries(row).forEach(([k, v]) => {
            if (internalKeys.has(k) || k === 'Id' || READONLY_IMPORT_FIELDS.has(k)) return;
            if (v === null || v === undefined || v === '') return;
            record[k] = v;
        });
        return record;
    }

    async handleConfirmImport() {
        const validRows = this.csvValidRows;
        if (!validRows.length) return;
        this.isImportingCsv = true;
        try {
            const response = await saveRecords({
                objectApiName: this.childObjectApiName,
                draftValues: validRows.map(r => this.buildImportRecord(r))
            });
            if (response && response.hasErrors) {
                const msgs = (response.rowErrors || []).map(e => `Row ${e.id}: ${e.message}`).join('\n');
                this.showToast('Partial Import', `Some rows failed:\n${msgs}`, 'warning');
            } else {
                const parts = [];
                if (this.csvUpdateCount) parts.push(`${this.csvUpdateCount} updated`);
                if (this.csvInsertCount) parts.push(`${this.csvInsertCount} inserted`);
                this.showToast('Import Successful', parts.join(', ') + '.', 'success');
                this.handleCsvModalClose();
                await this.loadData();
                setTimeout(() => { window.location.reload(); }, 1500);
            }
        } catch (e) {
            console.error('❌ CSV import error:', e);
            this.showToast('Import Error', e?.body?.message || e?.message || 'Import failed.', 'error');
        } finally {
            this.isImportingCsv = false;
        }
    }

    handleCsvModalClose() {
        this.showCsvModal = false; this.csvPreviewRows = []; this.csvErrors = [];
    }

    // ── Modal 2: Import New Items (auto-resolve from material catalog) ─────────
    get newItemsValidRows()    { return this.newItemsPreviewRows.filter(r => !r._hasError); }
    get newItemsValidCount()   { return this.newItemsValidRows.length; }
    get newItemsErrorCount()   { return this.newItemsPreviewRows.filter(r => r._hasError).length; }
    get hasNewItemsErrors()    { return this.newItemsErrors.length > 0; }
    get hasNewItemsPreviewRows() { return this.newItemsPreviewRows.length > 0; }
    get isNewItemsImportDisabled() { return this.newItemsValidRows.length === 0 || this.isInsertingNewItems || this.isResolvingMaterials; }
    get newItemsImportButtonLabel() {
        if (this.isInsertingNewItems) return 'Inserting...';
        return `Insert ${this.newItemsValidCount} Item(s)`;
    }

    handleNewItemsCsvClick() {
        const input = this.template.querySelector('[data-id="newItemsFileInput"]');
        if (input) { input.value = ''; input.click(); }
    }

    handleNewItemsFileChange(event) {
        const file = event.target.files[0];
        if (!file) return;
        const reader = new FileReader();
        reader.onload = async (e) => {
            try {
                const text = e.target.result.replace(/^\uFEFF/, '');
                const { parsedRows, errors } = this.parseNewItemsCsv(text);
                this.newItemsPreviewRows = parsedRows;
                this.newItemsErrors = errors;
                this.showNewItemsModal = true;

                if (parsedRows.length > 0) {
                    // Resolve material details from catalog for all rows
                    await this.resolveMaterials();
                }
            } catch (err) {
                this.showToast('Parse Error', err.message || 'Failed to parse CSV.', 'error');
            }
        };
        reader.readAsText(file);
    }

    // Parses the new-items CSV — only Material Number and Quantity are required.
    // Description is auto-resolved from the catalog; all other fields are optional overrides.
    parseNewItemsCsv(text) {
        const lines = text.split(/\r?\n/).map(l => l.trim()).filter(l => l.length > 0);
        if (lines.length < 2) throw new Error('CSV must contain a header row and at least one data row.');

        const rawHeaders = this.splitCsvLine(lines[0]);
        const headerMap = {};
        rawHeaders.forEach((h, idx) => {
            const apiName = this.CSV_HEADER_MAP[h.trim().toLowerCase()];
            // Skip Id and readonly fields — new items are always inserts
            if (apiName && apiName !== 'Id' && !READONLY_IMPORT_FIELDS.has(apiName)) {
                headerMap[idx] = apiName;
            }
        });

        const knownFields = Object.values(headerMap);
        const errors = [];

        if (!knownFields.includes('Material_Number__c')) {
            errors.push('Required column "Material Number" is missing from the CSV header.');
        }
        if (!knownFields.includes('Quantity__c')) {
            errors.push('Required column "Quantity" is missing from the CSV header.');
        }

        const validPicklistSet = new Set(this.picklistOptions.map(o => o.value.toLowerCase()));

        const parsedRows = lines.slice(1).map((line, idx) => {
            const values = this.splitCsvLine(line);
            const row = {
                _rowNum: idx + 1,
                _hasError: false,
                _errorMsg: '',
                _resolved: false,
                _pricedFromCatalog: false
            };
            const rowErrors = [];

            Object.entries(headerMap).forEach(([colIdx, apiName]) => {
                const raw = (values[parseInt(colIdx, 10)] || '').trim();
                if (!raw) { row[apiName] = null; return; }

                if (NUMBER_FIELDS.has(apiName)) {
                    const num = parseFloat(raw);
                    if (isNaN(num)) {
                        rowErrors.push(`"${apiName.replace(/__c$/i,'').replace(/_/g,' ')}" must be a number (got "${raw}")`);
                        row[apiName] = raw;
                    } else if (apiName === 'Quantity__c' && num <= 0) {
                        rowErrors.push('Quantity must be greater than 0');
                        row[apiName] = num;
                    } else {
                        row[apiName] = num;
                    }
                } else if (apiName === 'Price_Adjustment_Type__c') {
                    const picklistMatch = this.picklistOptions.find(o => o.value.toLowerCase() === raw.toLowerCase());
                    if (this.picklistOptions.length > 0 && !picklistMatch) {
                        rowErrors.push(`"${raw}" is not a valid Price Adjustment Type. Valid values: ${this.picklistOptions.map(o => o.value).join(', ')}`);
                    }
                    row[apiName] = picklistMatch ? picklistMatch.value : raw;
                } else {
                    row[apiName] = raw;
                }
            });

            if (knownFields.includes('Material_Number__c') && !row.Material_Number__c) {
                rowErrors.push('Material Number is required');
            }
            if (knownFields.includes('Quantity__c') && (row.Quantity__c === null || row.Quantity__c === undefined)) {
                rowErrors.push('Quantity is required');
            }

            if (rowErrors.length > 0) {
                row._hasError = true; row._errorMsg = rowErrors.join('; ');
                errors.push(`Row ${idx + 1}: ${row._errorMsg}`);
            }
            return row;
        });

        return { parsedRows, errors };
    }

    // Calls searchMaterials for each unique Material Number in the CSV rows,
    // then enriches each row with Description__c → Material_Description__c
    // and Price__c → UnitPrice__c (unless the CSV already has a Unit Price).
    async resolveMaterials() {
        this.isResolvingMaterials = true;
        try {
            // Collect unique, non-errored material numbers
            const uniqueNums = [
                ...new Set(
                    this.newItemsPreviewRows
                        .filter(r => !r._hasError && r.Material_Number__c)
                        .map(r => r.Material_Number__c)
                )
            ];

            if (uniqueNums.length === 0) return;

            // Call searchMaterials in parallel for each unique material number
            const searchPromises = uniqueNums.map(num =>
                searchMaterials({
                    searchText: num,
                    group1: '', group2: '', group3: '', group4: '', group5: '',
                    industryStandard: ''
                })
                .then(results => ({ num, results: results || [] }))
                .catch(() => ({ num, results: [] }))
            );

            const allSearchResults = await Promise.all(searchPromises);

            // Build map: materialNumber → exact match from search results
            const materialMap = {};
            allSearchResults.forEach(({ num, results }) => {
                const exact = results.find(r => r.Material_Number__c === num);
                if (exact) materialMap[num] = exact;
            });

            // Enrich each preview row with resolved data
            const unresolvedNums = [];
            this.newItemsPreviewRows = this.newItemsPreviewRows.map(row => {
                if (row._hasError) return row;

                const material = materialMap[row.Material_Number__c];
                if (!material) {
                    unresolvedNums.push(row.Material_Number__c);
                    return {
                        ...row,
                        _hasError: true,
                        _errorMsg: `Material "${row.Material_Number__c}" not found in catalog`
                    };
                }

                return {
                    ...row,
                    Material_Description__c: material.Description__c || '',
                    UnitPrice__c: parseFloat(material.Price__c) || 0,  // always from catalogue
                    _materialRecordId: material.Id,   // needed by saveSelectedProducts
                    _resolved: true,
                    _pricedFromCatalog: true
                };
            });

            // Surface unresolved material numbers as errors
            if (unresolvedNums.length > 0) {
                const newErrors = unresolvedNums.map(n => `Material "${n}" not found in catalog — check the material number`);
                this.newItemsErrors = [...this.newItemsErrors, ...newErrors];
            }
        } catch (e) {
            console.error('❌ Material resolve error:', e);
            this.showToast('Lookup Error', e?.body?.message || e?.message || 'Failed to look up materials.', 'error');
        } finally {
            this.isResolvingMaterials = false;
        }
    }

    async handleConfirmNewItems() {
        const validRows = this.newItemsValidRows;
        if (!validRows.length) return;
        this.isInsertingNewItems = true;
        try {
            // Priority: platform-injected → App Builder property → auto-detected from schema
            const objName = this.objectApiName
                || this.parentObjectApiName
                || this._detectedParentObjectApiName
                || '';

            if (!objName) {
                this.showToast(
                    'Configuration Missing',
                    'Could not determine parent object. Please set "Parent Object API Name" on the component in App Builder (e.g. MD_Quote__c).',
                    'error'
                );
                return;
            }

            // Split valid rows: existing material numbers → update, new ones → insert.
            // saveSelectedProducts stores materialNumber in Name (not Material_Number__c),
            // so fall back to Name when Material_Number__c is blank.
            const existingByMaterial = {};
            (this.rows || []).forEach(r => {
                const matKey = (r.Material_Number__c || r.Name || '').trim();
                if (matKey) existingByMaterial[matKey] = r.Id;
            });
            const EXTRA_FIELDS_UPSERT = [
                'Price_Adjustment_Type__c', 'Price_Adjustment_Value__c', 'Per_Kit__c', 'Per_Test__c'
            ];
            const rowsToUpdate = [];
            const rowsToInsert = [];
            validRows.forEach(row => {
                const matNum = String(row.Material_Number__c || '').trim();
                const existingId = existingByMaterial[matNum];
                if (existingId) {
                    rowsToUpdate.push({ ...row, _existingId: existingId });
                } else {
                    rowsToInsert.push(row);
                }
            });

            // Step 0 — Update existing line items (quantity only + any extra CSV fields).
            // UnitPrice__c is intentionally excluded — the existing record already has the
            // correct price and sending 0 would fail validation rules.
            if (rowsToUpdate.length > 0) {
                const updateDrafts = rowsToUpdate.map(row => {
                    const draft = {
                        Id:          row._existingId,
                        Quantity__c: row.Quantity__c != null ? row.Quantity__c : 1
                    };
                    EXTRA_FIELDS_UPSERT.forEach(f => {
                        if (row[f] !== null && row[f] !== undefined && row[f] !== '') draft[f] = row[f];
                    });
                    return draft;
                });
                console.log('✏️ Updating existing items:', JSON.stringify(updateDrafts));
                const updateResp = await saveRecords({ objectApiName: this.childObjectApiName, draftValues: updateDrafts });
                if (updateResp && updateResp.hasErrors) {
                    const msgs = (updateResp.rowErrors || []).map(e => e.message).join('; ');
                    this.showToast('Update Failed', `Could not update existing items: ${msgs}`, 'error');
                    return;
                }
            }

            if (rowsToInsert.length === 0) {
                // Nothing to insert — reload and finish
                await this.loadData();
                this.showToast('Success!', `${rowsToUpdate.length} existing item(s) updated.`, 'success');
                this.handleNewItemsModalClose();
                setTimeout(() => { window.location.reload(); }, 1500);
                return;
            }

            // Snapshot existing IDs before insert so we can identify new records afterwards.
            // Also capture a SOQL-safe timestamp (1 second before now) so we can query
            // freshly-inserted records via a different whereClause — this bypasses the
            // cacheable=true LWC cache on getRecords which would otherwise return stale data.
            const existingIds = new Set(this.rows.map(r => r.Id));
            const insertStart = new Date(Date.now() - 1000);
            const insertStartSoql = insertStart.toISOString().replace(/\.\d{3}Z$/, 'Z');

            // Step 1 — Insert new-only rows via saveSelectedProducts
            let selectedProducts = rowsToInsert.map(row => ({
                materialId:     row._materialRecordId ? String(row._materialRecordId) : '',
                materialNumber: row.Material_Number__c  ? String(row.Material_Number__c)  : '',
                quantity:       row.Quantity__c  != null ? String(row.Quantity__c)  : '1',
                price:          row.UnitPrice__c != null ? String(row.UnitPrice__c) : '0'
            }));
            // Strip reactive proxies exactly as mdProductSearch does
            selectedProducts = JSON.parse(JSON.stringify(selectedProducts));

            console.log('📦 saveSelectedProducts:', JSON.stringify({ varRecId: this.recordId, objName, itemCount: selectedProducts.length }));

            await saveSelectedProducts({ varRecId: this.recordId, selectedProducts, objName });

            // Step 2 — Query new records using a timestamp-filtered whereClause.
            // Using a different whereClause than loadData() produces a different cache key,
            // forcing the platform to hit the DB and return the just-inserted records.
            const fieldList = (this.fieldApiNames || '')
                .split(',').map(f => f.trim()).filter(f => !!f && f.toLowerCase() !== 'id');
            const freshResult = await getRecords({
                objectApiName: this.childObjectApiName,
                fieldApiNames: fieldList,
                whereClause: `${this.parentLookupFieldApiName} = '${this.recordId}' AND CreatedDate >= ${insertStartSoql}`,
                limitSize: 200
            });
            // Filter out anything that was already there before the insert (safety net)
            let newRecords = (freshResult || [])
                .map(r => ({ ...r }))
                .filter(r => !existingIds.has(r.Id));
            console.log('🆕 New records (fresh query):', newRecords.length, '| Rows to insert:', rowsToInsert.length);

            // Also refresh the grid with the regular loadData
            await this.loadData();

            // Step 3 — Follow-up update for ALL fields saveSelectedProducts does not handle:
            //   Price_Adjustment_Type__c, Price_Adjustment_Value__c, Per_Kit__c, Per_Test__c
            const EXTRA_FIELDS = [
                'Price_Adjustment_Type__c',
                'Price_Adjustment_Value__c',
                'Per_Kit__c',
                'Per_Test__c'
            ];

            // Build queue by Material_Number__c for name-based matching
            const newRecordQueue = {};
            newRecords.forEach(r => {
                const key = r.Material_Number__c;
                if (!newRecordQueue[key]) newRecordQueue[key] = [];
                newRecordQueue[key].push(r.Id);
            });

            // For every inserted row: try Material_Number__c queue match first,
            // fall back to positional match if the field isn't populated on the new record.
            const updateDrafts = [];
            rowsToInsert.forEach((row, idx) => {
                const queue = newRecordQueue[row.Material_Number__c];
                let recordId;
                if (queue && queue.length > 0) {
                    recordId = queue.shift();
                } else if (newRecords[idx]) {
                    // Positional fallback: nth CSV row → nth new record
                    recordId = newRecords[idx].Id;
                    console.warn(`⚠️ Queue miss for "${row.Material_Number__c}", using positional match: ${recordId}`);
                } else {
                    console.warn(`⚠️ No record to match for row ${idx}: ${row.Material_Number__c}`);
                    return;
                }

                const draft = { Id: recordId };
                EXTRA_FIELDS.forEach(f => {
                    if (row[f] !== null && row[f] !== undefined && row[f] !== '') {
                        draft[f] = row[f];
                    }
                });

                // Only push if there is at least one extra field to set
                const hasExtra = Object.keys(draft).length > 1;
                if (hasExtra) updateDrafts.push(draft);
            });

            if (updateDrafts.length > 0) {
                console.log('📝 Follow-up update drafts:', JSON.stringify(updateDrafts));
                const updateResponse = await saveRecords({ objectApiName: this.childObjectApiName, draftValues: updateDrafts });
                await this.loadData();
                if (updateResponse && updateResponse.hasErrors) {
                    const msgs = (updateResponse.rowErrors || []).map(e => e.message).join('; ');
                    this.showToast('Partial Success', `Items created but some fields failed to save: ${msgs}`, 'warning');
                    this.handleNewItemsModalClose();
                    return;
                }
            }

            const parts = [];
            if (rowsToUpdate.length) parts.push(`${rowsToUpdate.length} updated`);
            if (rowsToInsert.length) parts.push(`${rowsToInsert.length} added`);
            this.showToast('Success!', parts.join(', ') + '.', 'success');
            this.handleNewItemsModalClose();
            setTimeout(() => { window.location.reload(); }, 1500);
        } catch (e) {
            console.error('❌ New items insert error:', e);
            this.showToast('Insert Error', e?.body?.message || e?.message || 'Insert failed.', 'error');
        } finally {
            this.isInsertingNewItems = false;
        }
    }

    handleNewItemsModalClose() {
        this.showNewItemsModal = false; this.newItemsPreviewRows = []; this.newItemsErrors = [];
    }

    // ── Shared CSV helpers ────────────────────────────────────────────────────
    // Parses one CSV line, respecting double-quoted fields (commas, escaped quotes)
    splitCsvLine(line) {
        const result = [];
        let current = '';
        let inQuotes = false;
        for (let i = 0; i < line.length; i++) {
            const ch = line[i];
            if (ch === '"') {
                if (inQuotes && line[i + 1] === '"') { current += '"'; i++; }
                else { inQuotes = !inQuotes; }
            } else if (ch === ',' && !inQuotes) {
                result.push(current); current = '';
            } else {
                current += ch;
            }
        }
        result.push(current);
        return result;
    }

    // Triggers a CSV file download in the browser
    downloadCsv(csvContent, filename) {
        const encodedUri = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csvContent);
        const link = document.createElement('a');
        link.setAttribute('href', encodedUri);
        link.setAttribute('download', filename);
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}