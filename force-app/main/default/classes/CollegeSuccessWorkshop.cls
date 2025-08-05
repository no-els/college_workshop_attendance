public with sharing class CollegeSuccessWorkshop {
    @AuraEnabled(cacheable=true)
    public static List<Contact> getContactsAll() {
        // Remove non-numeric characters from the query
        return [SELECT Id, Name, Phone, Site__c, Site_2__c FROM Contact];
    }
    @AuraEnabled(cacheable=true)
    public static List<Workshop__c> searchWorkshops(String searchTerm) {
        String query = '%' + searchTerm + '%';
        return [SELECT Id, Name, Date__c, Site__c, Near_Peer_Workshop__c FROM Workshop__c WHERE Name LIKE :query order by Date__c, Name];
    }
    @AuraEnabled
public static Boolean getNearPeerFlag(Id workshopId) {
    Workshop__c w = [SELECT Near_Peer_Workshop__c FROM Workshop__c WHERE Id = :workshopId LIMIT 1];
    return w.Near_Peer_Workshop__c;
}

@AuraEnabled
public static void updateWorkshopNearPeer(Id workshopId, Boolean isNearPeer) {
    Workshop__c w = new Workshop__c(Id = workshopId);
    w.Near_Peer_Workshop__c = isNearPeer;
    update w;
}

@AuraEnabled
public static void updateAttendeeStatus(String attendeeId, String newStatus) {
    Attendee__c attendee = [SELECT Id, Near_Peer_Status__c FROM Attendee__c WHERE Id = :attendeeId LIMIT 1];
    attendee.Near_Peer_Status__c = newStatus;
    update attendee;
}

@AuraEnabled(cacheable=true)
    public static List<Attendee__c> getAttendees(Id workshopId) {
        try {
            return [SELECT Name, 
            Client__c, 
            Workshop__c,
            Client__r.Phone, 
            Client__r.Site__c, 
            Near_Peer_Status__c 
            FROM Attendee__c WHERE Workshop__c = :workshopId order by CreatedDate asc];
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }


@AuraEnabled(cacheable=true)
public static Map<Id, List<Workshop__c>> getWorkshopsGroupedBySeries() {
    Map<Id, List<Workshop__c>> seriesToWorkshops = new Map<Id, List<Workshop__c>>();

    List<Workshop__c> workshops = [
        SELECT Id, Name, Workshop_Series__r.Name, Workshop_Series__c, Date__c, Site__c 
        FROM Workshop__c 
        WHERE Workshop_Series__c != null
        ORDER BY Workshop_Series__r.Name, Date__c
    ];

    for (Workshop__c w : workshops) {
        if (!seriesToWorkshops.containsKey(w.Workshop_Series__c)) {
            seriesToWorkshops.put(w.Workshop_Series__c, new List<Workshop__c>());
        }
        seriesToWorkshops.get(w.Workshop_Series__c).add(w);
    }

    return seriesToWorkshops;
}

@AuraEnabled(cacheable=true)
public static List<Cohort__c> getCohorts() {
    return [SELECT Id, Name FROM Cohort__c];
}



}