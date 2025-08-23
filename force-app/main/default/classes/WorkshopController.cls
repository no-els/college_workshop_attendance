public with sharing class WorkshopController {
    
    @AuraEnabled(cacheable=true)
    public static List<Workshop__c> searchWorkshops(String searchTerm) {
        String query = '%' + searchTerm + '%';
        return [SELECT Id, Name, Date__c, Site__c FROM Workshop__c WHERE Name LIKE :query order by Date__c, Name];
    }
    @AuraEnabled(cacheable=true)
    public static List<Attendee__c> getAttendees(Id workshopId) {
        try {
        return [SELECT Name, Client__c, Workshop__c, Client__r.Phone, Client__r.Site__c FROM Attendee__c WHERE Workshop__c = :workshopId order by CreatedDate asc];
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
    @AuraEnabled(cacheable=true)
    public static List<Workshop__c> getWorkshop(Id workshopId) {
        return [SELECT Id, Name, Date__c, Site__c FROM Workshop__c WHERE Id =:workshopId];
    }

    @AuraEnabled(cacheable=true)
    public static List<Contact> getContacts() {
        // Remove non-numeric characters from the query
        return [SELECT Id, Name, Phone, Site__c, Site_2__c FROM Contact WHERE RecordType.DeveloperName = 'Parent'];
    }
    @AuraEnabled
    public static Boolean addAttendee(String contactId, String workshopId){
        // Check if this attendee already exists
        List<Attendee__c> existing = [SELECT Id FROM Attendee__c 
        WHERE Client__c = :contactId 
        AND Workshop__c = :workshopId 
        LIMIT 1];
        // Fetch Contact Name
        Contact c = [SELECT Name FROM Contact WHERE Id = :contactId LIMIT 1];

        if (!existing.isEmpty()) {
        return False;
        }
        Attendee__c newAttendee = new Attendee__c(
            Client__c = contactId,
            Workshop__c = workshopId,
            Name = c.name
        );
        insert newAttendee;
        return True;
    }
    @AuraEnabled
    public static String deleteAttendee(String attendeeId) {
        try {
            Attendee__c attendee = [SELECT Id FROM Attendee__c WHERE Id = :attendeeId LIMIT 1];
            delete attendee;
            return 'Success';
            } 
        catch (Exception e) {
            return 'Error: ' + e.getMessage();
            }
    }

    @AuraEnabled
    public static void updateContact(String contactId, String name, String phone, String site) {
        // Retrieve the contact record (handle potential nulls or add try/catch as needed)
        Contact con = [SELECT Id, Name, Phone, Site__c FROM Contact WHERE Id = :contactId LIMIT 1];
        con.Phone = phone;
        con.Site__c = site;
        update con;
    }

}