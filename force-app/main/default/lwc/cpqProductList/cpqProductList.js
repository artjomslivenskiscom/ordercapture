import { LightningElement, api, wire } from 'lwc';
import callCpqAppHandler from '@salesforce/apex/CPQCaller.callCpqAppHandler';

import { publish, MessageContext } from 'lightning/messageService';
import productToAddChannel from '@salesforce/messageChannel/CPQAddProductChannel__c';

const CPQ_GET_CARTS_PRODUCTS_METHOD = 'getCartsProducts';

const actions = [
    { label: 'Add', name: 'add' },
];

const columns = [
    { label: 'Name', fieldName: 'name', sortable: 'true' },
    { label: 'Recurring Price', fieldName: 'recurringPrice' },
    { label: 'List Price', fieldName: 'listPrice', type: 'currency' },
    {
        type: 'action',
        typeAttributes: { rowActions: actions },
    },
];

export default class CpqProductList extends LightningElement {
    @api recordId;
    data = [];
    columns = columns;
    error;

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        callCpqAppHandler({
                methodName: CPQ_GET_CARTS_PRODUCTS_METHOD,
                inputMap: {
                    methodName: CPQ_GET_CARTS_PRODUCTS_METHOD,
                    cartId: this.recordId
                }
            })
            .then((result) => {
                this.data = JSON.parse(result).records.map(record => ({
                    name: record.fields.Name.value,
                    listPrice: record.fields.UnitPrice.value,
                    recurringPrice: record.fields.vlocity_cmt__RecurringPrice__c.value,
                    priceBookEntryId: record.fields.Id.value,
                    actions: record.actions
                }));
                this.error = undefined;
            })
            .catch((error) => {
                this.error = JSON.stringify(error);
                this.data = undefined;
            });
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const productToAdd = event.detail.row;

        switch (actionName) {
            case 'add':
                this.addProduct(productToAdd);
                break;
            default:
        }
    }

    addProduct(productToAdd) {
        const payload = {
            priceBookEntryId: productToAdd.priceBookEntryId,
            actions: productToAdd.actions
        };
        publish(this.messageContext, productToAddChannel, payload);
    }
}