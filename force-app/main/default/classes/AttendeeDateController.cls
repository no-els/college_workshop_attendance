public with sharing class AttendeeDateController {
    @AuraEnabled(cacheable=true)
    public static Date getDate(Id attendeeId) {
        Attendee__c a = [
            SELECT Date__c
            FROM Attendee__c
            WHERE Id = :attendeeId
            LIMIT 1
        ];
        return a.Date__c;
    }

    @AuraEnabled
    public static void setDate(Id attendeeId, Date newDate) {
        update new Attendee__c(Id = attendeeId, Date__c = newDate);
    }

    @AuraEnabled
    public static void clearDate(Id attendeeId) {
        update new Attendee__c(Id = attendeeId, Date__c = null);
    }


    //
    // --- new show/hide column persistence methods ---
    //
    @AuraEnabled
    public static Boolean getShowDateFlag(Id workshopId) {
        Workshop__c w = [
            SELECT Show_Date__c
            FROM Workshop__c
            WHERE Id = :workshopId
            LIMIT 1
        ];
        return w.Show_Date__c;
    }

    @AuraEnabled
    public static void updateShowDateFlag(Id workshopId, Boolean showDate) {
        Workshop__c w = new Workshop__c(Id = workshopId);
        w.Show_Date__c = showDate;
        update w;

    }
    
}