import { LightningElement, api, wire, track } from 'lwc';
import callCpqAppHandler from '@salesforce/apex/CPQCaller.callCpqAppHandler';

import { subscribe, unsubscribe, APPLICATION_SCOPE, MessageContext } from 'lightning/messageService';
import productToAddChannel from '@salesforce/messageChannel/CPQAddProductChannel__c';

const CPQ_GET_CARTS_ITEMS_METHOD = 'getCartsItems';
const CPQ_PUT_CARTS_ITEMS_METHOD = 'putCartsItems';

const columns = [
    { label: 'Name', fieldName: 'name' },
    { label: 'Quantity', fieldName: 'quantity' },
    { label: 'Recurring Charge', fieldName: 'recurringCharge', type: 'currency' },
    { label: 'Recurring Total', fieldName: 'recurringTotal', type: 'currency' },
    { label: 'One Time Charge', fieldName: 'oneTimeCharge', type: 'currency' },
    { label: 'One Time Total', fieldName: 'oneTimeTotal', type: 'currency' }
];

export default class CpqProductCart extends LightningElement {
    @api recordId;
    data = [];
    columns = columns;
    error;
    loaded = false;

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        callCpqAppHandler({
            inputMap: {
                methodName: CPQ_GET_CARTS_ITEMS_METHOD,
                cartId: this.recordId,
                price: false,
                validate: false
            }
        })
        .then((result) => {
            this.data = JSON.parse(result).records.map(record => ({
                name: record.fields.Name,
                quantity: record.fields.Quantity.value,
                recurringCharge: record.fields.vlocity_cmt__RecurringCharge__c.value,
                recurringTotal: record.fields.vlocity_cmt__RecurringTotal__c.value,
                oneTimeCharge: record.fields.vlocity_cmt__OneTimeCharge__c.value,
                oneTimeTotal: record.fields.vlocity_cmt__OneTimeTotal__c.value,
                fields: record.fields,
                actions: record.actions
            }));
            this.error = undefined;
            this.loaded = true;
        })
        .catch((error) => {
            this.error = JSON.stringify(error);
            this.loaded = true;
        });

    this.subscribeToMessageChannel();
}


    subscribeToMessageChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                productToAddChannel,
                (message) => this.handleMessage(message),
                { scope: APPLICATION_SCOPE }
            );
        }
    }

    unsubscribeToMessageChannel() {
        unsubscribe(this.subscription);
        this.subscription = null;
    }

    disconnectedCallback() {
        this.unsubscribeToMessageChannel();
    }

    handleMessage(productToAdd) {
        const index = this.data.findIndex(product => product.fields.PricebookEntryId.value === productToAdd.priceBookEntryId);

        if (index == -1) {
            this.addProduct(productToAdd);
        } else {
            this.updateProductInCart(index);
        }
    }

    addProduct(productToAdd) {
        this.loaded = false;

        callCpqAppHandler({
                inputMap: productToAdd.actions.addtocart.remote.params
            })
            .then((result) => {
                this.data = this.data.concat(JSON.parse(result).records.map(record => ({
                    name: record.fields.Name,
                    quantity: record.fields.Quantity.value,
                    recurringCharge: record.fields.vlocity_cmt__RecurringCharge__c.value,
                    recurringTotal: record.fields.vlocity_cmt__RecurringTotal__c.value,
                    oneTimeCharge: record.fields.vlocity_cmt__OneTimeCharge__c.value,
                    oneTimeTotal: record.fields.vlocity_cmt__OneTimeTotal__c.value,
                    fields: record.fields
                })));
                this.error = undefined;
                this.loaded = true;
            })
            .catch((error) => {
                this.error = JSON.stringify(error);
                this.data = undefined;
                this.loaded = true;
            });
    }

    updateProductInCart(index) {
        this.loaded = false;

        let params = {
            methodName: CPQ_PUT_CARTS_ITEMS_METHOD,
            cartId: this.recordId,
            items: {
                records: []
            },
            price: true,
            validate: true
        };
        this.data[index].fields.Quantity.value++;
        params.items.records.push(this.data[index].fields);

        callCpqAppHandler({
                inputMap: params
            })
            .then((result) => {
                this.data.splice(index, 1, ...JSON.parse(result).records.map(record => ({
                    name: record.fields.Name,
                    quantity: record.fields.Quantity.value,
                    recurringCharge: record.fields.vlocity_cmt__RecurringCharge__c.value,
                    recurringTotal: record.fields.vlocity_cmt__RecurringTotal__c.value,
                    oneTimeCharge: record.fields.vlocity_cmt__OneTimeCharge__c.value,
                    oneTimeTotal: record.fields.vlocity_cmt__OneTimeTotal__c.value,
                    fields: record.fields,
                })));
                this.data = [...this.data];
                this.error = undefined;
                this.loaded = true;
            })
            .catch((error) => {
                this.error = JSON.stringify(error);
                this.loaded = true;
            });
    }
}