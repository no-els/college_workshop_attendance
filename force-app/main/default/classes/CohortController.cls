public with sharing class CohortController {

    @AuraEnabled(cacheable=true)
    public static List<Cohort__c> getCohorts() {
        return [SELECT Id, Name, CreatedDate FROM Cohort__c ORDER BY CreatedDate DESC];
    }

    @AuraEnabled
    public static Id createCohort(String name) {
        Cohort__c newCohort = new Cohort__c(Name = name);
        insert newCohort;
        return newCohort.Id;
    }

    @AuraEnabled
    public static List<Cohort_Member__c> getCohortMembers(Id cohortId) {
        return [
            SELECT Id, Contact__c, Contact__r.Name, Role__c 
            FROM Cohort_Member__c 
            WHERE Cohort__c = :cohortId
        ];
    }

@AuraEnabled
public static void addMembers(List<Cohort_Member__c> newMembers) {
    if (newMembers == null || newMembers.isEmpty()) return;

    // Assume all records belong to same cohort
    Id cohortId = newMembers[0].Cohort__c;

    // Extract Contact Ids
    Set<Id> newContactIds = new Set<Id>();
    for (Cohort_Member__c cm : newMembers) {
        if (cm.Contact__c != null) {
            newContactIds.add(cm.Contact__c);
        }
    }

    // Query existing members
    Set<Id> existingContactIds = new Set<Id>();
    for (Cohort_Member__c existing : [
        SELECT Id, Contact__c 
        FROM Cohort_Member__c 
        WHERE Cohort__c = :cohortId AND Contact__c IN :newContactIds
    ]) {
        existingContactIds.add(existing.Contact__c);
    }

    // Filter out any duplicates
    List<Cohort_Member__c> toInsert = new List<Cohort_Member__c>();
    for (Cohort_Member__c cm : newMembers) {
        if (!existingContactIds.contains(cm.Contact__c)) {
            toInsert.add(cm);
        }
    }

    if (!toInsert.isEmpty()) {
        insert toInsert;
    }
}



    @AuraEnabled
    public static void updateMemberRole(Id membershipId, String role) {
        Cohort_Member__c member = [SELECT Id, Role__c FROM Cohort_Member__c WHERE Id = :membershipId];
        member.Role__c = role;
        update member;
    }

    @AuraEnabled
    public static void deleteMember(Id membershipId) {
        delete [SELECT Id FROM Cohort_Member__c WHERE Id = :membershipId];
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getCohortDetails(Id cohortId) {
        Cohort__c cohort = [
            SELECT Id, Name 
            FROM Cohort__c 
            WHERE Id = :cohortId
            LIMIT 1
        ];

        List<Cohort_Member__c> members = [
            SELECT Id, Contact__c, Contact__r.Name, Role__c 
            FROM Cohort_Member__c 
            WHERE Cohort__c = :cohortId
        ];

        return new Map<String, Object>{
            'cohort' => cohort,
            'members' => members
        };
    }
}
