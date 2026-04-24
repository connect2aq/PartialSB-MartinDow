import { LightningElement, api, track } from "lwc";
import getMaterialGroupOptions from "@salesforce/apex/MDProductSearchController.getMaterialGroupOptions";
import getLatestPriceInventory from "@salesforce/apex/MDPriceInventoryController.getLatestPriceInventory";
import saveSelectedProducts from "@salesforce/apex/MDOpportunityLineItemController.saveSelectedProducts";
import searchMaterials from "@salesforce/apex/MDProductSearchController.searchMaterials";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";
import { getRecord } from "lightning/uiRecordApi";
import { wire } from "lwc";

export default class MdProductSearch extends LightningElement {
    // Search-related
    @track searchTerm = "";
    @track typeaheadOptions = [];
    @track showTypeahead = false;

    // Results
    @track searchResults = [];
    @track paginatedResults = [];
    @track showNoResults = false;
    @track isSearchLoading = false;
    @track viewMode = 'card'; // default
    @track selectedItems = new Set();
    @track allProducts = [];
    // Selected products
    @track selectedProducts = [];
    @track isModalOpen = false;
    @track modalData = [];

    // Pagination
    currentPage = 1;
    pageSize = 50;
    totalPages = 1;

    // Notifications
    @track showSaveSuccess = false;
    @track showSaveError = false;
    @track saveErrorMessage = "";

    // Opportunity/parent context
    @api recordId; // This will be set automatically by LWC on record pages
    @api objectApiName;
    @api source;
    @track varRecId = null;
    @track hide;
    @track parentRecordAPIName = null; // Used to store the parent record details

    // Material Group dropdowns
    @track group1Options = [];
    @track group2Options = [];
    @track group3Options = [];
    @track group4Options = [];
    @track group5Options = [];
    @track selectedGroup1 = "";
    @track selectedGroup2 = "";
    @track selectedGroup3 = "";
    @track selectedGroup4 = "";
    @track selectedGroup5 = "";

    vendorOptions = [
        { label: "All", value: "" },
        { label: "AV - AlphaVenus", value: "AV" },
        { label: "A - Boule", value: "A" },
        { label: "B - Boule", value: "B" },
        { label: "DYM - Dymind", value: "DYM" },
        { label: "ER - Erba", value: "ER" },
        { label: "HW - Headway", value: "HW" },
        { label: "NV - Nova", value: "NV" },
        { label: "OR - OCD", value: "OR" },
        { label: "STA - Stago", value: "STA" },
        { label: "CPART - VitalScientific", value: "CPART" },
        { label: "D - VitalScientific", value: "D" },
        { label: "E - VitalScientific", value: "E" },
        { label: "LOC - VitalScientific", value: "LOC" },
        { label: "DSERV - VitalScientific", value: "DSERV" },
        { label: "CSERV - VitalScientific", value: "CSERV" },
        { label: "PKG - VitalScientific", value: "PKG" },
        { label: "INST - VitalScientific", value: "INST" },
        { label: "PART - VitalScientific", value: "PART" },
        { label: "DM - VitalScientific", value: "DM" },
        { label: "U - VitalScientific", value: "U" },
        { label: "S - VitalScientific", value: "S" },
        { label: "F - VitalScientific", value: "F" },
        { label: "YHLO - YHLO", value: "YHLO" },
        { label: "ZYB - ZYBIO", value: "ZYB" }
    ];
    technologyOptions = [
        { label: "All", value: "" },
        { label: "XRAY - Xray", value: "XRAY" },
        { label: "HM - Heamatology", value: "HM" },
        { label: "COAG - Coagulation", value: "COAG" },
        { label: "ELCT - Electrolyte", value: "ELCT" },
        { label: "URIN - Urine", value: "URIN" },
        { label: "UBT - Urea Breath Test", value: "UBT" },
        { label: "ABG - Arterial Blood Gas", value: "ABG" },
        { label: "POC - Point of Care", value: "POC" },
        { label: "IMA - Immunoassay", value: "IMA" },
        { label: "CC - Clinical Chemistry", value: "CC" },
        { label: "ELT - Electrolyte", value: "ELT" }
    ];
    productTypeOptions = [
        { label: "All", value: "" },
        { label: "CON - Consumable", value: "CON" },
        { label: "INS - Instrument", value: "INS" },
        { label: "CPART - Part", value: "CPART" },
        { label: "CSERV - Part", value: "CSERV" },
        { label: "DSERV - Part", value: "DSERV" },
        { label: "PAR - Part", value: "PAR" },
        { label: "BLK - Reagent", value: "BLK" },
        { label: "PKG - Reagent", value: "PKG" },
        { label: "R - Reagent", value: "R" }
    ];
    selectedVendor = "";
    selectedTechnology = "";
    selectedProductType = "";
    get cardViewVariant() {
        return this.viewMode === 'card' ? 'brand' : 'border';
    }
    get listViewVariant() {
        return this.viewMode === 'list' ? 'brand' : 'border';
    }
    get showCardView() {
        console.log('>>>>showCardView-->cardView: ' + this.isCardView + ' , search results length: ' + this.searchResults.length);

        return this.isCardView && this.searchResults && this.searchResults.length > 0;
    }
    get showListView() {
        console.log('>>>>showListView-->listView: ' + this.isListView + ' , search results length: ' + this.searchResults.length);
        return this.isListView && this.searchResults && this.searchResults.length > 0;
    }

    get isListView() {
        return this.viewMode === 'list';
    }
    get isCardView() {
        return this.viewMode === 'card';
    }
    connectedCallback() {
        console.log("Before Record ID:", this.recordId);
        console.log("Page Source:", this.source);
        // If recordId is set (e.g. on an Opportunity/Quote/Order/Customer Demand record page), use it as parentId
        if (this.recordId) {
            this.varRecId = this.recordId;
            this.parentRecordAPIName = this.objectApiName;
            console.log("Parent Record:", this.parentRecordAPIName);
            console.log("Record ID:", this.varRecId);
        }

        // Load Material Group options
        getMaterialGroupOptions()
            .then((result) => {
                this.group1Options = this.buildOptions(result.Material_Group_1__c);
                this.group2Options = this.buildOptions(result.Material_Group_2__c);
                this.group3Options = this.buildOptions(result.Material_Group_3__c);
                this.group4Options = this.buildOptions(result.Material_Group_4__c);
                this.group5Options = this.buildOptions(result.Material_Group_5__c);
            })
            .catch((error) => {
                console.error("Error loading Material Group options", error);
            });
    }

    buildOptions(values) {
        let opts = [{ label: "All", value: "" }];
        if (values) {
            opts = opts.concat(values.map((v) => ({ label: v, value: v })));
        }
        return opts;
    }

    handleGroup1Change(event) {
        this.selectedGroup1 = event.detail.value;
    }
    handleGroup2Change(event) {
        this.selectedGroup2 = event.detail.value;
    }
    handleGroup3Change(event) {
        this.selectedGroup3 = event.detail.value;
    }
    handleGroup4Change(event) {
        this.selectedGroup4 = event.detail.value;
    }
    handleGroup5Change(event) {
        this.selectedGroup5 = event.detail.value;
    }

    handleSearchInput(event) {
        this.searchTerm = event.target.value;
    }

    // UPDATED: do not clear selectedProducts on view change
    handleCardView() {
        console.log('handlecardView-->current viewMode-->' + this.viewMode);

        // Switch to card view without clearing selection
        this.viewMode = 'card';
        console.log('handleCardView-->viewMode-->' + this.viewMode);

        // Just reset the visual state of "card select all" checkbox if present
        setTimeout(() => {
            const cardSelectAll = this.template.querySelector('[data-id="cardSelectAllDataId"]');
            console.log('>>>>handleCardView-->cardSelectAll-->' + cardSelectAll);
            if (cardSelectAll) {
                cardSelectAll.checked = false;
            }
        }, 100);
    }

    // UPDATED: do not clear selectedProducts on view change
    handleListView() {
        console.log('handlelistView-->current viewMode-->' + this.viewMode);

        // Switch to list view without clearing selection
        this.viewMode = 'list';
        console.log('handlelistView-->viewMode-->' + this.viewMode);

        // Just reset the visual state of "list select all" checkbox if present
        setTimeout(() => {
            const listSelectAll = this.template.querySelector('[data-id="listSelectAllDataId"]');
            console.log('>>>>handlelistView-->listSelectAll-->' + listSelectAll);
            if (listSelectAll) {
                listSelectAll.checked = false;
            }
        }, 100);
    }

    handleSearchClick() {
        this.isSearchLoading = true;
        // ...existing code...
        console.log("Search clicked with term:", this.searchTerm);

        // Check: at least one filter (3+ chars in search box or any dropdown selected or new dropdowns)
        const hasSearchText = this.searchTerm && this.searchTerm.trim().length >= 3;
        const hasDropdown =
            this.selectedGroup1 ||
            this.selectedGroup2 ||
            this.selectedGroup3 ||
            this.selectedGroup4 ||
            this.selectedGroup5;
        const hasVendorTechProd =
            this.selectedVendor ||
            this.selectedTechnology ||
            this.selectedProductType;
        if (!hasSearchText && !hasDropdown && !hasVendorTechProd) {
            this.isSearchLoading = false;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Add a filter",
                    message:
                        "Please enter at least 3 characters in the search box or select a filter.",
                    variant: "error"
                })
            );
            return;
        }

        const industryStandardSearch = this.buildIndustryStandardSearch();
        console.log("Industry Standard Search:", industryStandardSearch);
        searchMaterials({
            searchText: this.searchTerm,
            group1: this.selectedGroup1,
            group2: this.selectedGroup2,
            group3: this.selectedGroup3,
            group4: this.selectedGroup4,
            group5: this.selectedGroup5,
            industryStandard: industryStandardSearch
        })
            .then((result) => {
                console.log('>>>>mdProductSearch.js-->searchMaterials-->objectApiName: ' + this.objectApiName);
                console.log('>>>>mdProductSearch.js-->searchMaterials-->objectApiName res: ' + !!this.objectApiName);
                const showSelect = !!this.objectApiName;
                this.searchResults = result.map((item) => {
                    const isSelected = this.selectedProducts.some(
                        (sel) => sel.Material_Number__c === item.Material_Number__c
                    );
                    const price = Number(item.Price__c || 0) || 0;
                    const priceFormatted = new Intl.NumberFormat("en-US", {
                        style: "decimal",
                        minimumFractionDigits: 2,
                        maximumFractionDigits: 2
                    }).format(Number(price));

                    return {
                        ...item,
                        isSelected,
                        selectLabel: showSelect ? (isSelected ? "Unselect" : "Select") : "",
                        selectVariant: showSelect
                            ? isSelected
                                ? "destructive"
                                : "success"
                            : "",
                        productLabel: `${item.Material_Number__c} - ${item.Description__c}`,
                        detailsFetched: false,
                        price,
                        priceFormatted,
                        quantity: 1,
                        quantityInputId: "quantity-" + item.Material_Number__c,
                        statusLabel: item.IsActive__c ? "Active" : "Inactive",
                        statusClass: item.IsActive__c ? "" : "status-inactive"
                    };
                });
                console.log('>>>>mdProductSearch.js-->searchMaterials-->search Results count: ' + this.searchResults.length);
                this.allProducts = this.searchResults;
                console.log('>>>>mdProductSearch.js-->searchMaterials-->all Products Results count: ' + this.allProducts.length);
                this.showNoResults = this.searchResults.length === 0;
                this.currentPage = 1;
                this.totalPages = Math.ceil(this.searchResults.length / this.pageSize);
                this.paginateResults();
                this.isSearchLoading = false;
                console.log('>>>>handleSearchClick-->viewMode-->' + this.viewMode);
                if (this.viewMode == 'card') {
                    this.handleCardView();
                } else {
                    this.handleListView();
                }
            })
            .catch((error) => {
                console.error(error);
                this.isSearchLoading = false;
            });
    }

    // paginateResults() {
    //   const start = (this.currentPage - 1) * this.pageSize;
    //   const end = start + this.pageSize;
    //   this.paginatedResults = this.searchResults.slice(start, end);
    // }
    paginateResults() {
        let start = (this.currentPage - 1) * this.pageSize;
        let end = start + this.pageSize;
        this.paginatedResults = this.searchResults.slice(start, end).map((item) => {
            return {
                ...item,
                quantityInputId:
                    item.quantityInputId || "quantity-" + item.Material_Number__c
            };
        });
    }

    handlePrevPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.paginateResults();
        }
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.paginateResults();
        }
    }

    handleSelectToggle(event) {
        const matNum = event.target.dataset.id;
        const item = this.searchResults.find(
            (x) => x.Material_Number__c === matNum
        );
        if (!item) return;

        if (item.isSelected) {
            item.isSelected = false;
            this.selectedProducts = this.selectedProducts.filter(
                (x) => x.Material_Number__c !== item.Material_Number__c
            );
        } else {
            item.isSelected = true;
            // Robust price assignment: use latest available price, coerce to number if possible
            let price = item.price;
            let quantity =
                typeof item.quantity === "number" && !isNaN(item.quantity)
                    ? item.quantity
                    : 1;
            // Set productLabel as in searchResults
            let productLabel =
                item.productLabel ||
                `${item.Material_Number__c} - ${item.Description__c || ""}`;
            this.selectedProducts = [
                ...this.selectedProducts.filter(
                    (x) => x.Material_Number__c !== item.Material_Number__c
                ),
                {
                    Id: item.Id,
                    Material_Number__c: item.Material_Number__c,
                    quantity,
                    price,
                    productLabel
                }
            ];
        }

        const showSelect = !!this.objectApiName;
        item.selectLabel = showSelect
            ? item.isSelected
                ? "Unselect"
                : "Select"
            : "";
        item.selectVariant = showSelect
            ? item.isSelected
                ? "destructive"
                : "success"
            : "";
        this.paginateResults();
    }

    // UPDATED: multi-search friendly checkbox handler
    //Changes by Yousuf 
    handleCheckboxChange(event) {
        console.log('>>>>mdProductSearch-->handleCheckboxChange-->event : ' + JSON.stringify(event.target));
        const materialId = event.target.dataset.id;
        const checked = event.detail?.checked ?? event.target.checked;
        console.log('>>>>mdProductSearch-->handleCheckboxChange-->material ID : ' + JSON.stringify(materialId));
        console.log('>>>>mdProductSearch-->handleCheckboxChange-->checked : ' + checked);

        if (checked) {
            // Add to Set
            this.selectedItems.add(materialId);

            // Also add full product object to selectedProducts if not already present
            const exists = this.selectedProducts.some(
                (p) => p.Material_Number__c === materialId
            );
            if (!exists) {
                const product = this.allProducts.find(
                    (p) => p.Material_Number__c === materialId
                );
                if (product) {
                    this.selectedProducts = [...this.selectedProducts, product];
                }
            }
        } else {
            // Remove from Set
            this.selectedItems.delete(materialId);

            // Remove from selectedProducts
            this.selectedProducts = this.selectedProducts.filter(
                (p) => p.Material_Number__c !== materialId
            );
        }

        // Force reactivity (Set is not reactive by default)
        this.selectedItems = new Set(this.selectedItems);

        // Update flags on current results
        this.updateSelectionFlags();

        console.log('>>>>handleCheckboxChange-->selectedItems size : ' + this.selectedItems.size);
        console.log('>>>>handleCheckboxChange-->selectedProducts size : ' + this.selectedProducts.length);
    }

    //Update Paginated Records
    updateSelectionFlags() {
        this.allProducts = this.allProducts.map(item => {
            return {
                ...item,
                isSelected: this.selectedItems.has(item.Material_Number__c)
            };
        });
        this.searchResults = this.allProducts;
        this.paginateResults();
    }

    // UPDATED: list select all for multi-search
    // Optional: handleListSelectAll Select all / deselect all
    handleListSelectAll(event) {
        console.log('>>>>handleListSelectAll-->event' + event);
        const checked = event.detail?.checked ?? event.target.checked;
        console.log('>>>>handleListSelectAll-->checked:' + checked);

        if (checked) {
            // Add all visible products into global selection
            this.allProducts.forEach((res) => {
                const id = res.Material_Number__c;
                this.selectedItems.add(id);

                const already = this.selectedProducts.some(
                    (p) => p.Material_Number__c === id
                );
                if (!already) {
                    this.selectedProducts = [...this.selectedProducts, res];
                }
            });
        } else {
            // Remove all visible products from selection
            this.allProducts.forEach((res) => {
                const id = res.Material_Number__c;
                this.selectedItems.delete(id);
            });

            // Remove all visible products from selectedProducts
            this.selectedProducts = this.selectedProducts.filter(
                (p) => !this.allProducts.some(
                    (res) => res.Material_Number__c === p.Material_Number__c
                )
            );
        }

        this.selectedItems = new Set(this.selectedItems);
        this.updateSelectionFlags();

        console.log('>>>>handleListSelectAll-->selectedItems size-->' + this.selectedItems.size);
        console.log('>>>>handleListSelectAll-->selectedProducts size-->' + this.selectedProducts.length);
    }

    // UPDATED: card select all for multi-search
    // Optional: handleCardSelectAll Select all / deselect all
    handleCardSelectAll(event) {
        console.log('>>>>handleCardSelectAll-->event' + event);
        const checked = event.detail?.checked ?? event.target.checked;
        console.log('>>>>handleCardSelectAll-->checked:' + checked);

        if (checked) {
            // Add all visible products into global selection
            this.allProducts.forEach((res) => {
                const id = res.Material_Number__c;
                this.selectedItems.add(id);

                const already = this.selectedProducts.some(
                    (p) => p.Material_Number__c === id
                );
                if (!already) {
                    this.selectedProducts = [...this.selectedProducts, res];
                }
            });
        } else {
            // Remove all visible products from selection
            this.allProducts.forEach((res) => {
                const id = res.Material_Number__c;
                this.selectedItems.delete(id);
            });

            // Remove all visible products from selectedProducts
            this.selectedProducts = this.selectedProducts.filter(
                (p) => !this.allProducts.some(
                    (res) => res.Material_Number__c === p.Material_Number__c
                )
            );
        }

        this.selectedItems = new Set(this.selectedItems);
        this.updateSelectionFlags();

        console.log('>>>>handleCardSelectAll-->selectedItems size-->' + this.selectedItems.size);
        console.log('>>>>handleCardSelectAll-->selectedProducts size-->' + this.selectedProducts.length);
    }

    // Utility
    get isAnySelected() {
        return this.selectedItems.size > 0;
    }

    handleBulkAction() {
        const selectedIds = Array.from(this.selectedItems);
        // this.selectedProducts = selectedIds;
        const isSelected = this.selectedProducts.some(
            (sel) => sel.Material_Number__c === item.Material_Number__c
        );
        this.selectedProducts = isSelected;
        console.log('>>>>handleBulkAction-->Selected Material IDs:', selectedIds);
        console.log('>>>>handleBulkAction-->Selected Products:', selectedProducts);
        // Perform bulk action here
    }

    getSelectedProducts() {
        return this.selectedProducts.length <= 0;
    }

    closeModal() {
        this.isModalOpen = false;
    }

    handleViewDetails(event) {
        const itemId = event.target.dataset.id;
        this.isModalOpen = true;
    }

    // UPDATED: keep Set and selectedProducts in sync when unselecting from panel
    handleUnselectProduct(event) {
        const matNum = event.target.dataset.id;
        // Use Material_Number__c for selectedProducts
        this.selectedProducts = this.selectedProducts.filter(
            (x) => x.Material_Number__c !== matNum
        );

        // Also remove from checkbox Set
        this.selectedItems.delete(matNum);
        this.selectedItems = new Set(this.selectedItems);

        const item = this.searchResults.find(
            (x) => x.Material_Number__c === matNum
        );
        if (item) {
            item.isSelected = false;
            const showSelect = !!this.objectApiName;
            item.selectLabel = showSelect ? "Select" : "";
            item.selectVariant = showSelect ? "success" : "";
        }

        this.updateSelectionFlags();
    }

    handleQuantityChange(event) {
        const matNum = event.target.dataset.id;
        const value = parseInt(event.target.value, 10);
        // Update in searchResults
        const item = this.searchResults.find(
            (x) => x.Material_Number__c === matNum
        );
        if (item) {
            item.quantity = isNaN(value) ? 0 : value;
        }
        // Always update selectedProducts to match searchResults
        this.selectedProducts = this.selectedProducts.map((prod) => {
            if (prod.Material_Number__c === matNum) {
                return {
                    ...prod,
                    quantity: isNaN(value) ? 1 : value
                };
            }
            return prod;
        });
        this.paginateResults();
    }

    handleFetchPrice(event) {
        const matNum = event.target.dataset.id;
        const item = this.searchResults.find(
            (x) => x.Material_Number__c === matNum
        );
        if (!item) return;

        item.isLoading = true;
        this.paginateResults();
        getLatestPriceInventory({
            materialId: item.Id,
            materialNumberParam: item.Material_Number__c
        })
            .then((result) => {
                console.log('>>>>mdProductSearch-->handleFetchPrice');
                console.log('>>>>mdProductSearch-->handleFetchPrice-->result: ' + JSON.stringify(result));
                item.detailsFetched = true;
                // Map inventory fields for UI
                item.totalAvailableStock = result.inventoryAvailableStock;
                item.totalBlockedStock = result.inventoryBlockedStock;
                item.totalAllocatedStock = result.inventoryAllocatedStock;
                item.totalRestrictedStock = result.inventoryRestrictedStock;
                // Store supplierBatch array for use in UI
                item.supplierBatch = Array.isArray(result.supplierBatch)
                    ? result.supplierBatch.map((b) => ({ ...b }))
                    : [];
                console.log(
                    "[DEBUG] supplierBatch for",
                    item.Material_Number__c,
                    JSON.stringify(item.supplierBatch)
                );
                item.isLoading = false;
                this.paginateResults();
            })
            .catch((error) => {
                item.isLoading = false;
                this.paginateResults();
                console.error(error);
            });
    }

    handleSaveSelected() {
        // 1. Debug before mapping
        console.log("[DEBUG] selectedProducts before save:", this.selectedProducts);
        console.log(
            "[DEBUG] parentRecordAPIName before save:",
            this.parentRecordAPIName
        );
        // 2. Map to plain objects matching Apex wrapper fields as Strings
        let selectedToSave = this.selectedProducts.map((item) => {
            console.log("item.price:", item.price);
            return {
                materialId: item.Id ? String(item.Id) : "",
                materialNumber: item.Material_Number__c
                    ? String(item.Material_Number__c)
                    : "",
                quantity:
                    item.quantity !== undefined && item.quantity !== null
                        ? String(item.quantity)
                        : "",
                price: String(item.price)
            };
        });
        // console.log("item price:", item.price);
        // 3. Remove any reactive proxies
        selectedToSave = JSON.parse(JSON.stringify(selectedToSave));

        // Debug final payload
        console.log("[FINAL] Sending to Apex:", JSON.stringify(selectedToSave));

        // 4. Check varRecId
        if (!this.varRecId) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Error",
                    message: "No Record selected.",
                    variant: "error"
                })
            );
            return;
        }

        // 5. Call Apex method
        console.log("[MAPPED toSave]:", selectedToSave);

        saveSelectedProducts({
            varRecId: this.varRecId,
            selectedProducts: selectedToSave, // matches Apex param name
            objName: this.parentRecordAPIName // pass the parent record API name
        })
            .then(() => {
                this.showSaveSuccess = true;
                this.selectedProducts = [];
                this.searchResults.forEach((item) => {
                    item.isSelected = false;
                    item.selectLabel = "Select";
                    item.selectVariant = "success";
                });

                this.dispatchEvent(
                    new CustomEvent("lineitemsaved", {
                        detail: {
                            varRecId: this.varRecId,
                            savedCount: 0
                        },
                        bubbles: true,
                        composed: true
                    })
                );

                try {
                    // Try to refresh the page using Lightning's refresh mechanism
                    eval("$A.get('e.force:refreshView').fire();");
                } catch (e) {
                    console.log("Standard refresh not available, using page reload");
                    // **SOLUTION 3: Full page refresh as last resort**
                    setTimeout(() => {
                        window.location.reload();
                    }, 1000);
                }

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: "Success",
                        message: "Selected products have been saved.",
                        variant: "success"
                    })
                );
            })
            .catch((error) => {
                console.error(error);
                this.showSaveSuccess = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: "Error",
                        message: error.body?.message || "An error occurred while saving.",
                        variant: "error"
                    })
                );
            });
    }

    get isPrevDisabled() {
        return this.currentPage === 1;
    }

    get isNextDisabled() {
        return this.currentPage === this.totalPages;
    }

    handleVendorChange(event) {
        this.selectedVendor = event.detail.value;
    }
    handleTechnologyChange(event) {
        this.selectedTechnology = event.detail.value;
    }
    handleProductTypeChange(event) {
        this.selectedProductType = event.detail.value;
    }

    buildIndustryStandardSearch() {
        // Always add % at the end of ProductKey for SOQL LIKE
        let vendor = this.selectedVendor ? this.selectedVendor : "%";
        let tech = this.selectedTechnology ? this.selectedTechnology : "%";
        let prod = this.selectedProductType ? this.selectedProductType + "%" : "%";
        // If only product type is selected, vendor and tech are %
        if (
            !this.selectedVendor &&
            !this.selectedTechnology &&
            this.selectedProductType
        ) {
            return `%${this.selectedProductType}%`;
        }
        // If only vendor is selected
        if (
            this.selectedVendor &&
            !this.selectedTechnology &&
            !this.selectedProductType
        ) {
            return `${this.selectedVendor}-%`;
        }
        // If only technology is selected
        if (
            !this.selectedVendor &&
            this.selectedTechnology &&
            !this.selectedProductType
        ) {
            return `%-${this.selectedTechnology}-%`;
        }
        // If vendor and technology
        if (
            this.selectedVendor &&
            this.selectedTechnology &&
            !this.selectedProductType
        ) {
            return `${this.selectedVendor}-${this.selectedTechnology}-%`;
        }
        // If vendor and product type
        if (
            this.selectedVendor &&
            !this.selectedTechnology &&
            this.selectedProductType
        ) {
            return `${this.selectedVendor}-%-${this.selectedProductType}%`;
        }
        // If technology and product type
        if (
            !this.selectedVendor &&
            this.selectedTechnology &&
            this.selectedProductType
        ) {
            return `%-${this.selectedTechnology}-${this.selectedProductType}%`;
        }
        // If all three
        if (
            this.selectedVendor &&
            this.selectedTechnology &&
            this.selectedProductType
        ) {
            return `${this.selectedVendor}-${this.selectedTechnology}-${this.selectedProductType}%`;
        }
        // If none selected
        return "";
    }
    handleResetFilters() {
        this.searchTerm = "";
        this.selectedGroup1 = "";
        this.selectedGroup2 = "";
        this.selectedGroup3 = "";
        this.selectedGroup4 = "";
        this.selectedGroup5 = "";
        this.selectedVendor = "";
        this.selectedTechnology = "";
        this.selectedProductType = "";
        this.searchResults = [];
        this.paginatedResults = [];
        this.showNoResults = false;
    }
    formatDate(dateStr) {
        if (!dateStr) return "";
        const d = new Date(dateStr);
        if (isNaN(d.getTime())) return dateStr;
        return d.toISOString().slice(0, 10);
    }

    handleAllocatedClick(event) {
        const storage = event.target.dataset.storage;
        const material = event.target.dataset.material;
        console.log('>>>>mdProductSearch-->handleAllocatedClick-->storage:' + storage);
        console.log('>>>>mdProductSearch-->handleAllocatedClick-->material:' + material);

        this.paginatedResults = this.paginatedResults.map(item => {
            if (item.Material_Number__c === material) {
                item.supplierBatch = item.supplierBatch.map(supBatch => {
                    if (supBatch.storageLocation === storage) {
                        supBatch.showAllocations = !supBatch.showAllocations;
                    } else {
                        supBatch.showAllocations = false; // optional: close others
                    }
                    return { ...supBatch };
                });
            }
            return { ...item };
        });
    }

    get hasPaginatedResults() {
        return this.paginatedResults && this.paginatedResults.length > 0;
    }
}