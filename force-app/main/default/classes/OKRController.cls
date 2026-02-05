public with sharing class OKRController {

    public class ObjectiveWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal year;
        @AuraEnabled public String ownerName;
        @AuraEnabled public List<KeyResultWrapper> keyResults;

        public ObjectiveWrapper(Objective__c obj) {
            this.id = obj.Id;
            this.name = obj.Name;
            this.year = obj.Year__c;
            this.ownerName = obj.OwnerId != null ? obj.Owner.Name : '';
            this.keyResults = new List<KeyResultWrapper>();
            
            if (obj.Key_Results__r != null) {
                for (Key_Result__c kr : obj.Key_Results__r) {
                    this.keyResults.add(new KeyResultWrapper(kr));
                }
            }
        }
    }

    public class KeyResultWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public List<KRTargetWrapper> targets;

        public KeyResultWrapper(Key_Result__c kr) {
            this.id = kr.Id;
            this.name = kr.Name;
            this.targets = new List<KRTargetWrapper>();
            
            if (kr.KR_Targets__r != null) {
                for (KR_Target__c target : kr.KR_Targets__r) {
                    this.targets.add(new KRTargetWrapper(target));
                }
            }
        }
    }

    public class KRTargetWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String type;
        @AuraEnabled public Decimal targetValue;
        @AuraEnabled public Decimal currentValue;
        @AuraEnabled public Decimal progressPercent;

        public KRTargetWrapper(KR_Target__c target) {
            this.id = target.Id;
            this.type = target.Type__c; 
            this.targetValue = target.Target_Value__c != null ? target.Target_Value__c : 0;
            this.currentValue = target.Current_Value__c != null ? target.Current_Value__c : 0;
            
            if (this.targetValue > 0) {
                this.progressPercent = (this.currentValue / this.targetValue) * 100;
            } else {
                this.progressPercent = 0;
            }
        }
    }



    @AuraEnabled(cacheable=true)
    public static List<User> getActiveUsers() {
        return [SELECT Id, Name FROM User WHERE IsActive = TRUE ORDER BY Name];
    }


    @AuraEnabled(cacheable=true)
    public static List<ObjectiveWrapper> getOKRData(String year, String ownerId) {
        List<ObjectiveWrapper> result = new List<ObjectiveWrapper>();
        Map<Id, ObjectiveWrapper> objectiveMap = new Map<Id, ObjectiveWrapper>();

        String query = 'SELECT Id, Name, Year__c, Owner.Name, OwnerId FROM Objective__c';
        List<String> conditions = new List<String>();

        if (String.isNotBlank(year)) {
            if (year.isNumeric()) {
                 conditions.add('Year__c = ' + String.escapeSingleQuotes(year));
            }
        }
        
        if (String.isNotBlank(ownerId)) {
            conditions.add('OwnerId = \'' + String.escapeSingleQuotes(ownerId) + '\'');
        }

        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }
        
        query += ' ORDER BY Year__c DESC, Name ASC';

        List<Objective__c> objectives = Database.query(query);

        for (Objective__c obj : objectives) {
            ObjectiveWrapper wrapper = new ObjectiveWrapper(obj);
            result.add(wrapper);
            objectiveMap.put(obj.Id, wrapper);
        }

        if (!objectiveMap.isEmpty()) {
            List<Key_Result__c> krs = [
                SELECT Id, Name, Objective__c,
                    (SELECT Id, Type__c, Target_Value__c, Current_Value__c 
                    FROM KR_Targets__r 
                    ORDER BY Type__c)
                FROM Key_Result__c
                WHERE Objective__c IN :objectiveMap.keySet()
                ORDER BY Name
            ];

            for (Key_Result__c kr : krs) {
                if (objectiveMap.containsKey(kr.Objective__c)) {
                    objectiveMap.get(kr.Objective__c).keyResults.add(new KeyResultWrapper(kr));
                }
            }
        }

        return result;
    }


    @AuraEnabled
    public static void recalculateProgress(List<Id> keyResultIds) {
        if (keyResultIds == null || keyResultIds.isEmpty()) return;

        List<KR_Target__c> targetsToUpdate = [
            SELECT Id, Key_Result__c, Type__c 
            FROM KR_Target__c 
            WHERE Key_Result__c IN :keyResultIds
        ];

        Map<Id, Map<String, Integer>> countsMap = new Map<Id, Map<String, Integer>>();

        for (Id krId : keyResultIds) {
            countsMap.put(krId, new Map<String, Integer>());
        }

        for (AggregateResult ar : [
            SELECT Key_Result__c krId, COUNT(Id) cnt 
            FROM Task 
            WHERE Key_Result__c IN :keyResultIds 
            AND TaskSubtype = 'Call'
            GROUP BY Key_Result__c
        ]) {
            setCount(countsMap, (Id)ar.get('krId'), 'Calls', (Integer)ar.get('cnt'));
        }

        for (AggregateResult ar : [
            SELECT Key_Result__c krId, COUNT(Id) cnt 
            FROM Event 
            WHERE Key_Result__c IN :keyResultIds 
            GROUP BY Key_Result__c
        ]) {
            setCount(countsMap, (Id)ar.get('krId'), 'Events', (Integer)ar.get('cnt'));
        }

        for (AggregateResult ar : [
            SELECT Key_Result__c krId, COUNT(Id) cnt 
            FROM Opportunity 
            WHERE Key_Result__c IN :keyResultIds 
            GROUP BY Key_Result__c
        ]) {
            setCount(countsMap, (Id)ar.get('krId'), 'Opportunity', (Integer)ar.get('cnt'));
        }

        for (AggregateResult ar : [
            SELECT Key_Result__c krId, COUNT(Id) cnt 
            FROM Contract 
            WHERE Key_Result__c IN :keyResultIds 
            GROUP BY Key_Result__c
        ]) {
            setCount(countsMap, (Id)ar.get('krId'), 'Contracts', (Integer)ar.get('cnt'));
        }

        for (AggregateResult ar : [
            SELECT Key_Result__c krId, COUNT(Id) cnt 
            FROM Lead 
            WHERE Key_Result__c IN :keyResultIds 
            AND LeadSource = 'Web'
            GROUP BY Key_Result__c
        ]) {
            setCount(countsMap, (Id)ar.get('krId'), 'Leads', (Integer)ar.get('cnt'));
        }

        for (AggregateResult ar : [
            SELECT Key_Result__c krId, COUNT(Id) cnt 
            FROM Survey__c 
            WHERE Key_Result__c IN :keyResultIds 
            GROUP BY Key_Result__c
        ]) {
            setCount(countsMap, (Id)ar.get('krId'), 'Surveys', (Integer)ar.get('cnt'));
        }

        for (AggregateResult ar : [
            SELECT Key_Result__c krId, COUNT(Id) cnt 
            FROM Review__c 
            WHERE Key_Result__c IN :keyResultIds 
            GROUP BY Key_Result__c
        ]) {
            setCount(countsMap, (Id)ar.get('krId'), 'Reviews', (Integer)ar.get('cnt'));
        }
        
        for (AggregateResult ar : [
            SELECT Key_Result__c krId, COUNT(Id) cnt 
            FROM Google_Review__c 
            WHERE Key_Result__c IN :keyResultIds 
            GROUP BY Key_Result__c
        ]) {
            setCount(countsMap, (Id)ar.get('krId'), 'Google Reviews', (Integer)ar.get('cnt'));
        }
        
        for (AggregateResult ar : [
            SELECT Key_Result__c krId, COUNT(Id) cnt 
            FROM Case_Study__c 
            WHERE Key_Result__c IN :keyResultIds 
            GROUP BY Key_Result__c
        ]) {
            setCount(countsMap, (Id)ar.get('krId'), 'Case Studies', (Integer)ar.get('cnt'));
        }

        List<KR_Target__c> toUpdate = new List<KR_Target__c>();
        
        for (KR_Target__c target : targetsToUpdate) {
            Integer count = 0;
            if (countsMap.containsKey(target.Key_Result__c) && 
                countsMap.get(target.Key_Result__c).containsKey(target.Type__c)) {
                
                count = countsMap.get(target.Key_Result__c).get(target.Type__c);
            }
            
            target.Current_Value__c = count;
            toUpdate.add(target);
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    private static void setCount(Map<Id, Map<String, Integer>> mainMap, Id krId, String type, Integer count) {
        if (!mainMap.containsKey(krId)) {
            mainMap.put(krId, new Map<String, Integer>());
        }
        mainMap.get(krId).put(type, count);
    }
}