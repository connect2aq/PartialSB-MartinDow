import { LightningElement, api, track } from "lwc";

export default class MultiSelectDropdown extends LightningElement {
  @api label = "";
  @api placeholder = "Select options";
  @api options = [];

  _selectedValues = [];

  @api
  get selectedValues() {
    return this._selectedValues;
  }

  set selectedValues(value) {
    this._selectedValues = value || [];
  }

  // Public method to clear selections (called by parent reset)
  @api
  clear() {
    this._selectedValues = [];
    this.searchTerm = "";
    this.closePopover();
  }

  @track searchTerm = "";
  @track showPopover = false;
  _boundOutsideClick = null;
  _boundCloseOthersHandler = null;

  connectedCallback() {
    // Listen for other dropdowns opening
    this._boundCloseOthersHandler = this.handleOtherDropdownOpened.bind(this);
    window.addEventListener(
      "multiselectdropdownopened",
      this._boundCloseOthersHandler
    );
  }

  handleOtherDropdownOpened(event) {
    // Close this dropdown if another one opened
    if (event.detail.source !== this && this.showPopover) {
      this.closePopover();
    }
  }

  // Computed property for selected count badge
  @api
  get selectedCount() {
    return this._selectedValues?.length || 0;
  }

  get hasSelections() {
    return this.selectedCount > 0;
  }

  // Options with search filtering and checked state
  get filteredOptions() {
    const list = this.options || [];
    const term = (this.searchTerm || "").trim().toLowerCase();

    // Apply search filtering
    const filtered = !term
      ? list
      : list.filter((opt) => {
          const label = (opt.label || "").toString().toLowerCase();
          const value = (opt.value || "").toString().toLowerCase();
          return label.includes(term) || value.includes(term);
        });

    // Determine checked state for each option
    const selectedSet = new Set(this._selectedValues || []);
    const hasIndividualSelections = selectedSet.size > 0;

    return filtered.map((opt) => ({
      ...opt,
      checked:
        opt.value === "" ? !hasIndividualSelections : selectedSet.has(opt.value)
    }));
  }

  // CSS class binding for SLDS combobox
  get comboboxClass() {
    const base =
      "slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click";
    return this.showPopover ? `${base} slds-is-open` : base;
  }

  // Toggle popover open/close
  handleTogglePopover(event) {
    if (event) event.stopPropagation();

    // If opening, close all other dropdowns first
    if (!this.showPopover) {
      // Dispatch event to close other dropdowns
      const closeOthersEvent = new CustomEvent("multiselectdropdownopened", {
        bubbles: true,
        composed: true,
        detail: { source: this }
      });
      this.dispatchEvent(closeOthersEvent);
    }

    this.showPopover = !this.showPopover;

    if (this.showPopover) {
      // Attach outside click handler
      this._boundOutsideClick = this.handleOutsideClick.bind(this);
      window.addEventListener("click", this._boundOutsideClick);
    } else {
      this.closePopover();
    }
  }

  closePopover() {
    this.showPopover = false;
    if (this._boundOutsideClick) {
      window.removeEventListener("click", this._boundOutsideClick);
      this._boundOutsideClick = null;
    }
  }

  handleOutsideClick(e) {
    const combobox = this.template.querySelector(".slds-combobox");
    if (combobox && !combobox.contains(e.target)) {
      this.closePopover();
    }
  }

  handleSearchInput(event) {
    this.searchTerm = event.target.value || "";
  }

  handleCheckboxClick(event) {
    // Prevent checkbox click from closing popover
    if (event) {
      event.stopPropagation();
    }
  }

  handleToggleSelection(event) {
    // Stop event propagation
    if (event) {
      event.stopPropagation();
    }

    // Get checkbox state
    const checkbox = event.target;
    const value = checkbox.dataset.value;
    const isChecked = checkbox.checked;

    let newSelectedValues;

    // Handle "All" option (empty value)
    if (value === "") {
      // Deselect all individual selections
      newSelectedValues = [];
    } else {
      // Toggle individual selection - create new array from current values
      const currentSelections = new Set(this._selectedValues || []);

      if (isChecked) {
        currentSelections.add(value);
      } else {
        currentSelections.delete(value);
      }

      newSelectedValues = Array.from(currentSelections);
    }

    // Keep popover open for multi-select
    this.showPopover = true;

    // Dispatch change event to parent with new values
    this.dispatchEvent(
      new CustomEvent("change", {
        detail: {
          value: newSelectedValues
        },
        bubbles: true,
        composed: true
      })
    );
  }

  // Cleanup on disconnect
  disconnectedCallback() {
    if (this._boundOutsideClick) {
      window.removeEventListener("click", this._boundOutsideClick);
      this._boundOutsideClick = null;
    }
    if (this._boundCloseOthersHandler) {
      window.removeEventListener(
        "multiselectdropdownopened",
        this._boundCloseOthersHandler
      );
      this._boundCloseOthersHandler = null;
    }
  }
}