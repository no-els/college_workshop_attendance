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

}