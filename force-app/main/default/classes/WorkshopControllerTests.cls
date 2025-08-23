@IsTest
private class WorkshopControllerTests {

    // Helper: fetch Contact "Parent" RT if it exists (can't create RTs in tests)
    private static Id getParentContactRecordTypeId() {
        try {
            return [
                SELECT Id
                FROM RecordType
                WHERE SObjectType = 'Contact' AND DeveloperName = 'Parent'
                LIMIT 1
            ].Id;
        } catch (Exception e) {
            return null;
        }
    }

    @testSetup
    static void setupData() {
        Id parentRtId = getParentContactRecordTypeId();

        // Contact (assign Parent RT if available)
        Contact contact1 = new Contact(
            LastName     = 'Test Contact',
            Phone        = '1234567890',
            RecordTypeId = parentRtId
        );
        insert contact1;

        // Workshop: set required picklist Program__c to a valid value
        // Use one of your real values exactly as it appears in the picklist:
        // 'College Success' or 'Parent Partner Program'
        Workshop__c workshop1 = new Workshop__c(
            Name       = 'Test Workshop',
            Date__c    = Date.today(),
            Site__c    = 'Alvarado',
            Program__c = 'College Success'
        );
        insert workshop1;

        // Seed attendee – will pass now that Workshop has Program__c set
        Attendee__c attendee1 = new Attendee__c(
            Client__c   = contact1.Id,
            Workshop__c = workshop1.Id,
            Name        = contact1.LastName
        );
        insert attendee1;
    }

    @IsTest
    static void testSearchWorkshops() {
        List<Workshop__c> results = WorkshopController.searchWorkshops('Test');
        System.assertNotEquals(0, results.size());
        System.assertEquals('Test Workshop', results[0].Name);
    }

    @IsTest
    static void testGetAttendees() {
        Id wId = [SELECT Id FROM Workshop__c WHERE Name = 'Test Workshop' LIMIT 1].Id;
        List<Attendee__c> attendees = WorkshopController.getAttendees(wId);
        System.assertNotEquals(0, attendees.size());
    }

    @IsTest
    static void testGetWorkshop() {
        Id wId = [SELECT Id FROM Workshop__c WHERE Name = 'Test Workshop' LIMIT 1].Id;
        List<Workshop__c> results = WorkshopController.getWorkshop(wId);
        System.assertEquals(1, results.size());
        System.assertEquals('Test Workshop', results[0].Name);
    }

    @IsTest
    static void testGetContacts() {
        // If Parent RT exists, create one such contact so the query returns something
        Id parentRtId = getParentContactRecordTypeId();
        if (parentRtId != null) {
            insert new Contact(LastName='Parent Contact', Phone='5551234567', RecordTypeId=parentRtId);
        }
        List<Contact> contacts = WorkshopController.getContacts();
        System.assertNotEquals(null, contacts); // may be empty if no Parent RT in org
    }

    @IsTest
    static void testAddAttendee() {
        Id parentRtId = getParentContactRecordTypeId();
        Contact newContact = new Contact(
            LastName='New Contact',
            Phone='0987654321',
            RecordTypeId=parentRtId
        );
        insert newContact;

        Id wId = [SELECT Id FROM Workshop__c WHERE Name='Test Workshop' LIMIT 1].Id;

        System.assertEquals(true, WorkshopController.addAttendee(newContact.Id, wId));
        System.assertEquals(false, WorkshopController.addAttendee(newContact.Id, wId));
    }

    @IsTest
    static void testDeleteAttendee() {
        Id attendeeId = [SELECT Id FROM Attendee__c LIMIT 1].Id;
        System.assertEquals('Success', WorkshopController.deleteAttendee(attendeeId));
        String bad = WorkshopController.deleteAttendee('nonexistentId');
        System.assert(bad.startsWith('Error:'));
    }
}
