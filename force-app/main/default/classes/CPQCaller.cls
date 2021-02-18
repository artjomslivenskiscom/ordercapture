public with sharing class CPQCaller {

    @AuraEnabled
    public static String callCpqAppHandler(Map<String, Object> inputMap) {

        // Roundtrip Serialization and Deserialization to ensure inputMap consistency for input parameters
        inputMap = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(inputMap));
        Map<String, Object> outputMap = new Map<String, Object>();

        // Call to Vlocity CPQ
        vlocity_cmt.CpqAppHandler cpqAppHandlerService = new vlocity_cmt.CpqAppHandler();
        cpqAppHandlerService.invokeMethod((String) inputMap.get('methodName'), inputMap, outputMap, null);

        return JSON.serialize(outputMap.get('result'));
    }
}