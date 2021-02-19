/*
* @Author       : Artjoms Livenskis
* @Email        : livenskis.artjoms@drei.com
* @Date         : 19.02.2020
* @Description  : Test Order/OrderItem capture with CPQCaller
*               : Test includes adding active PricebookEntry, inactive PricebookEntry, causing Exceptions
*/

@IsTest
private class CPQCallerTest {

    // TestData
    private static final String ACCOUNT_NAME = 'Test Account Name';
    private static final String STATUS_DRAFT = 'Draft';
    private static final String STATUS_ACTIVATED = 'Activated';
    private static final String PRODUCT2_ACTIVE_PBE_NAME = 'Product For Active PricebookEntry';
    private static final String PRODUCT2_INACTIVE_PBE_NAME = 'Product For Inactive PricebookEntry';
	private static final Id STANDARD_PRICEBOOK_ID = Test.getStandardPricebookId();

    // Properties for InputMap required for CPQCaller
    private static final String CARTID_KEY = 'cartId';
	private static final String ITEMS_KEY = 'items';
    private static final String ITEMID_KEY = 'itemId';
	private static final String METHOD_NAME_KEY = 'methodName';
    private static final String METHOD_NAME_VALUE = 'postCartsItems';

    // Assert
    private static final String RESPONSE_MESSAGES_KEY = 'messages';
    private static final String RESPONSE_MESSAGE_KEY = 'message';
    private static final String RESPONSE_MESSAGE_POSITIVE = 'Successfully added.';
    private static final String RESPONSE_MESSAGE_NEGATIVE = 'Product incorrectly configured. Please contact your administrator.';
    private static final String EXCEPTION_MESSAGE = 'Script-thrown exception';

    @TestSetup
    static void testSetup() {

        Account account = new Account(Name = ACCOUNT_NAME);
        insert account;

        Contract contract = new Contract(AccountId = account.Id,
                                         Status = STATUS_DRAFT,
                                         StartDate = Date.today(),
                                         ContractTerm = 12);
        insert contract;

        contract.Status = STATUS_ACTIVATED;
        update contract;

        Order order = new Order(AccountId = account.Id,
                                Status = STATUS_DRAFT,
                                EffectiveDate = Date.today(),
                                ContractId = contract.Id,
                                Pricebook2Id = STANDARD_PRICEBOOK_ID);
        insert order;

        Product2 productForActivePBE = new Product2(Name = PRODUCT2_ACTIVE_PBE_NAME,
                                                 IsActive = true);

        Product2 productForInActivePBE = new Product2(Name = PRODUCT2_INACTIVE_PBE_NAME,
                                                 IsActive = true);

        insert new List<Product2>{productForActivePBE, productForInActivePBE};

        PricebookEntry pricebookEntryActive = new PricebookEntry(Pricebook2Id = STANDARD_PRICEBOOK_ID,
                                                              Product2Id = productForActivePBE.Id,
                                                              UnitPrice = 10,
                                                              IsActive = true);

        PricebookEntry pricebookEntryInActive = new PricebookEntry(Pricebook2Id = STANDARD_PRICEBOOK_ID,
                                                              Product2Id = productForInActivePBE.Id,
                                                              UnitPrice = 20,
                                                              IsActive = false);

        insert new List<PricebookEntry>{pricebookEntryActive, pricebookEntryInActive};
    }

    @IsTest
    static void testAddProductPositive() {

        Map<String, Object> result = new Map<String, String>();

        Order order = [SELECT Id
                       FROM Order
                       WHERE Status = :STATUS_DRAFT LIMIT 1];

        PricebookEntry pricebookEntryOne = [SELECT Id
                                            FROM PricebookEntry 
                                            WHERE IsActive = true LIMIT 1];

        Map<String, Object> itemMap = new Map<String, Object>{ITEMID_KEY => pricebookEntryOne.Id};
        List<Object> items = new List<Object>{itemMap};

        Map<String, Object> inputMap = new Map<String, Object>();
        inputMap.put(ITEMS_KEY, items);
        inputMap.put(CARTID_KEY, order.Id);
        inputMap.put(METHOD_NAME_KEY, METHOD_NAME_VALUE);

        Test.startTest();
        	result = (Map<String, Object>) JSON.deserializeUntyped(CPQCaller.callCpqAppHandler(inputMap));
        Test.stopTest();

        List<OrderItem> orderItemList = [SELECT Id, Product2.Name 
                                         FROM OrderItem 
                                         WHERE OrderId = :order.Id];

        List<Object> messageList = (List<Object>) result.get(RESPONSE_MESSAGES_KEY);
        Map<String, Object> message = (Map<String, Object>) messageList[0];

        System.assertEquals(RESPONSE_MESSAGE_POSITIVE, message.get(RESPONSE_MESSAGE_KEY), 'Unexpected response message!');
        System.assertEquals(PRODUCT2_ACTIVE_PBE_NAME, orderItemList[0].Product2.Name, 'Incorrect product added to Order!');
        System.assert(orderItemList.size() > 0, 'Product was not added to Order!');
    }

    @IsTest
    static void testAddProductNegative() {

        Map<String, Object> result = new Map<String, String>();

        Order order = [SELECT Id
                       FROM Order
                       WHERE Status = :STATUS_DRAFT LIMIT 1];

        PricebookEntry pricebookEntryOne = [SELECT Id
                                            FROM PricebookEntry 
                                            WHERE IsActive = false LIMIT 1];

        Map<String, Object> itemMap = new Map<String, Object>{ITEMID_KEY => pricebookEntryOne.Id};
        List<Object> items = new List<Object>{itemMap};

        Map<String, Object> inputMap = new Map<String, Object>();
        inputMap.put(ITEMS_KEY, items);
        inputMap.put(CARTID_KEY, order.Id);
        inputMap.put(METHOD_NAME_KEY, METHOD_NAME_VALUE);

        Test.startTest();
        	result = (Map<String, Object>) JSON.deserializeUntyped(CPQCaller.callCpqAppHandler(inputMap));
        Test.stopTest();

        List<OrderItem> orderItemList = [SELECT Id
                                         FROM OrderItem 
                                         WHERE OrderId = :order.Id];

        List<Object> messageList = (List<Object>) result.get(RESPONSE_MESSAGES_KEY);
        Map<String, Object> message = (Map<String, Object>) messageList[0];

        System.assertEquals(RESPONSE_MESSAGE_NEGATIVE, message.get(RESPONSE_MESSAGE_KEY), 'Unexpected response message!');
        System.assert(orderItemList.size() == 0, 'Order should not have any products!');
    }

    @IsTest
    static void testAddProductException() {

        try {
            CPQCaller.callCpqAppHandler(null);
        }
        catch (AuraHandledException ex) {
            System.assertEquals(EXCEPTION_MESSAGE, ex.getMessage(), 'Unexpected Exception message!');
        }
    }
}