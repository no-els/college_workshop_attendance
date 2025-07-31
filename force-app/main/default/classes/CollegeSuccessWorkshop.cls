public with sharing class CollegeSuccessWorkshop {
    @AuraEnabled(cacheable=true)
    public static List<Contact> getContactsAll() {
        // Remove non-numeric characters from the query
        return [SELECT Id, Name, Phone, Site__c, Site_2__c FROM Contact];
    }
}