@isTest
private class OKRControllerTest {

    @testSetup
    static void makeData() {
        Objective__c obj = new Objective__c(
            Name = 'Test Objective 2023',
            Year__c = 2023,
            OwnerId = UserInfo.getUserId()
        );
        insert obj;

        Key_Result__c kr = new Key_Result__c(
            Name = 'Test KR Sales',
            Objective__c = obj.Id
        );
        insert kr;

        List<KR_Target__c> targets = new List<KR_Target__c>();
        targets.add(new KR_Target__c(Key_Result__c = kr.Id, Type__c = 'Call', Target_Value__c = 10, Current_Value__c = 0));
        targets.add(new KR_Target__c(Key_Result__c = kr.Id, Type__c = 'Opportunity', Target_Value__c = 5, Current_Value__c = 0));
        targets.add(new KR_Target__c(Key_Result__c = kr.Id, Type__c = 'Lead', Target_Value__c = 20, Current_Value__c = 0));
        targets.add(new KR_Target__c(Key_Result__c = kr.Id, Type__c = 'Survey', Target_Value__c = 5, Current_Value__c = 0));
        insert targets;

        
    }
}