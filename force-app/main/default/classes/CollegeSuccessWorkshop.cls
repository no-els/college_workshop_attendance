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

@AuraEnabled
public static void addBatchAttendance(List<Map<String, String>> records) {
    if (records == null || records.isEmpty()) return;

    Set<Id> contactIds = new Set<Id>();
    Set<Id> workshopIds = new Set<Id>();

    // Collect Contact and Workshop Ids
    for (Map<String, String> record : records) {
        contactIds.add(record.get('ContactId'));
        workshopIds.add(record.get('WorkshopId'));
    }

    // Fetch contact names
    Map<Id, Contact> contactsMap = new Map<Id, Contact>(
        [SELECT Id, Name FROM Contact WHERE Id IN :contactIds]
    );

    // Fetch existing attendees to avoid duplicates
    Set<String> existingKeys = new Set<String>();
    for (Attendee__c existing : [
        SELECT Id, Client__c, Workshop__c 
        FROM Attendee__c 
        WHERE Client__c IN :contactIds AND Workshop__c IN :workshopIds
    ]) {
        existingKeys.add(existing.Client__c + '-' + existing.Workshop__c);
    }

    // Build list of new attendees
    List<Attendee__c> attendeesToInsert = new List<Attendee__c>();

    for (Map<String, String> record : records) {
        String contactId = record.get('ContactId');
        String workshopId = record.get('WorkshopId');
        String status = record.get('Status'); // Present, Excused Absence, etc.
        String nearPeer = record.get('Near_Peer'); // Mentor, Mentee, N/A

        String key = contactId + '-' + workshopId;
        if (existingKeys.contains(key)) continue;

        Contact c = contactsMap.get(contactId);
        if (c == null) continue;

        attendeesToInsert.add(new Attendee__c(
            Client__c = contactId,
            Workshop__c = workshopId,
            Name = c.Name,
            Attendee_Status__c = status,
            Near_Peer_Status__c = nearPeer
        ));
    }

    if (!attendeesToInsert.isEmpty()) {
        insert attendeesToInsert;
    }
}



public class AttendanceWrapper {
    @AuraEnabled public Id contactId;
    @AuraEnabled public String status;
}




}