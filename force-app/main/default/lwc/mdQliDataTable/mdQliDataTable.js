import LightningDatatable from 'lightning/datatable';
import picklistView from './picklistView.html';
import picklistEdit from './picklistEdit.html';

export default class MdQliDataTable extends LightningDatatable {
    // Register a custom 'picklist' type
    static customTypes = {
        picklist: {
            template: picklistView,        // read/view mode
            editTemplate: picklistEdit,    // inline edit mode
            standardCellLayout: true,      // enables keyboard & accessibility
            typeAttributes: ['options', 'placeholder', 'value']
        }
    };
}