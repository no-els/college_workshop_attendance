/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@IsTest
private class CollegeSuccessWorkshopTest {

    @testSetup
    static void seed() {
        // Contacts
        insert new List<Contact>{
            new Contact(LastName = 'Alpha', Phone = '555-0001'),
            new Contact(LastName = 'Beta',  Phone = '555-0002'),
            new Contact(LastName = 'Gamma', Phone = '555-0003')
        };

        // Series
        Workshop_Series__c s1 = new Workshop_Series__c(Name='Series A', School_Year__c='24-25');
        Workshop_Series__c s2 = new Workshop_Series__c(Name='Series B', School_Year__c='25-26');
        insert new List<Workshop_Series__c>{ s1, s2 };

        // Workshops — Program__c as TEXT/PICKLIST values (no Program object)
        insert new List<Workshop__c>{
            new Workshop__c(Name='WS A1', Date__c=Date.today().addDays(-10),
                Workshop_Series__c=s1.Id, Near_Peer_Workshop__c=false, Program__c='College Success'),
            new Workshop__c(Name='WS A2', Date__c=Date.today().addDays(-5),
                Workshop_Series__c=s1.Id, Near_Peer_Workshop__c=true,  Program__c='College Success'),
            new Workshop__c(Name='WS B1', Date__c=Date.today().addDays(1),
                Workshop_Series__c=s2.Id, Near_Peer_Workshop__c=false, Program__c='Parent Partner Program'),
            new Workshop__c(Name='WS Loose', Date__c=Date.today(),
                Near_Peer_Workshop__c=false, Program__c='College Success') // no series on purpose
        };

        // Attendees
        Workshop__c wA1 = [SELECT Id FROM Workshop__c WHERE Name='WS A1' LIMIT 1];
        Contact cAlpha = [SELECT Id, LastName FROM Contact WHERE LastName='Alpha' LIMIT 1];
        Contact cBeta  = [SELECT Id, LastName FROM Contact WHERE LastName='Beta' LIMIT 1];

        insert new Attendee__c(
            Name = cAlpha.LastName, Client__c = cAlpha.Id, Workshop__c = wA1.Id,
            Attendee_Status__c = 'Present', Near_Peer_Status__c = 'Mentor'
        );
        insert new Attendee__c(
            Name = cBeta.LastName, Client__c = cBeta.Id, Workshop__c = wA1.Id,
            Attendee_Status__c = 'Excused Absence', Near_Peer_Status__c = 'Mentee'
        );
    }

    @IsTest
    static void testGetContactsAll() {
        Test.startTest();
        List<Contact> got = CollegeSuccessWorkshop.getContactsAll();
        Test.stopTest();
        System.assert(!got.isEmpty(), 'Should return contacts');
    }

    @IsTest
    static void testSearchWorkshops() {
        Test.startTest();
        List<Workshop__c> found = CollegeSuccessWorkshop.searchWorkshops('WS A');
        Test.stopTest();
        System.assert(!found.isEmpty(), 'Should find workshops with "WS A"');
    }

    @IsTest
    static void testNearPeerFlagUpdate() {
        Workshop__c w = [SELECT Id, Near_Peer_Workshop__c FROM Workshop__c WHERE Name='WS A1' LIMIT 1];
        Boolean before = w.Near_Peer_Workshop__c;

        Test.startTest();
        Boolean got = CollegeSuccessWorkshop.getNearPeerFlag(w.Id);
        CollegeSuccessWorkshop.updateWorkshopNearPeer(w.Id, !before);
        Test.stopTest();

        Boolean after = [SELECT Near_Peer_Workshop__c FROM Workshop__c WHERE Id=:w.Id].Near_Peer_Workshop__c;
        System.assertEquals(before, got);
        System.assertEquals(!before, after);
    }

    @IsTest
    static void testUpdateAttendeeStatusAttendance() {
        Attendee__c a = [SELECT Id FROM Attendee__c LIMIT 1];

        Test.startTest();
        CollegeSuccessWorkshop.updateAttendeeStatus(a.Id, 'N/A');
        CollegeSuccessWorkshop.updateAttendeeAttendance(a.Id, 'Present');
        Test.stopTest();

        Attendee__c got = [SELECT Near_Peer_Status__c, Attendee_Status__c FROM Attendee__c WHERE Id=:a.Id];
        System.assertEquals('N/A', got.Near_Peer_Status__c);
        System.assertEquals('Present', got.Attendee_Status__c);
    }

    @IsTest
    static void testGetAttendees() {
        Workshop__c w = [SELECT Id FROM Workshop__c WHERE Name='WS A1' LIMIT 1];

        Test.startTest();
        List<Attendee__c> atts = CollegeSuccessWorkshop.getAttendees(w.Id);
        Test.stopTest();

        System.assertEquals(2, atts.size(), 'Expected two attendees on WS A1');
        System.assertNotEquals(null, atts[0].Client__r.Phone, 'Should include client phone');
    }

    @IsTest
    static void testGetWorkshopsGroupedBySeries() {
        Test.startTest();
        Map<Id, List<Workshop__c>> m = CollegeSuccessWorkshop.getWorkshopsGroupedBySeries();
        Test.stopTest();

        System.assert(!m.isEmpty(), 'Grouped map should not be empty');
        Integer total = 0;
        for (Id k : m.keySet()) total += m.get(k).size();
        System.assert(total >= 3, 'Should have grouped workshops for both series');
    }

    @IsTest
    static void testAddBatchAttendance() {
        Workshop__c w = [SELECT Id FROM Workshop__c WHERE Name='WS A1' LIMIT 1];
        Contact c = [SELECT Id, Name FROM Contact WHERE LastName='Gamma' LIMIT 1];

        // Build rows: ensure one new attendee is inserted
        List<Map<String,String>> rows = new List<Map<String,String>>{
            new Map<String,String>{
                'ContactId' => (String)c.Id,
                'WorkshopId' => (String)w.Id,
                'Status' => 'Present',
                'Near_Peer' => 'Mentor'
            }
        };

        Integer before = [SELECT COUNT() FROM Attendee__c WHERE Workshop__c = :w.Id];

        Test.startTest();
        CollegeSuccessWorkshop.addBatchAttendance(rows);
        Test.stopTest();

        Integer after = [SELECT COUNT() FROM Attendee__c WHERE Workshop__c = :w.Id];
        System.assertEquals(before + 1, after, 'Should insert one attendee');
    }

    @IsTest
    static void testYearsSeriesWorkshops() {
        Test.startTest();
        List<CollegeSuccessWorkshop.YearDTO> years = CollegeSuccessWorkshop.getYearsSeriesWorkshops();
        Test.stopTest();

        System.assert(!years.isEmpty(), 'Should return years');
        System.assert(!years[0].series.isEmpty(), 'Series should not be empty');
        System.assert(!years[0].series[0].workshops.isEmpty(), 'Workshops should not be empty');
    }

    @IsTest
    static void testCompletedFlagUpdate() {
        Workshop__c w = [SELECT Id, Completed__c FROM Workshop__c WHERE Name='WS A1' LIMIT 1];
        Boolean before = w.Completed__c;

        Test.startTest();
        Boolean got = CollegeSuccessWorkshop.getCompletedFlag(w.Id);
        CollegeSuccessWorkshop.updateWorkshopCompleted(w.Id, !before);
        Test.stopTest();

        Boolean after = [SELECT Completed__c FROM Workshop__c WHERE Id=:w.Id].Completed__c;
        System.assertEquals(before, got);
        System.assertEquals(!before, after);
    }

    @IsTest
    static void testAddAttendee() {
        Workshop__c w = [SELECT Id FROM Workshop__c WHERE Name='WS A1' LIMIT 1];
        Contact c = [SELECT Id FROM Contact WHERE LastName='Gamma' LIMIT 1];

        Test.startTest();
        Boolean added = CollegeSuccessWorkshop.addAttendee(c.Id, w.Id);
        Test.stopTest();

        System.assertEquals(true, added, 'Should insert new attendee');
    }

    @IsTest
    static void testGetWorkshopById() {
        Workshop__c w = [SELECT Id FROM Workshop__c WHERE Name='WS A1' LIMIT 1];

        Test.startTest();
        Workshop__c got = CollegeSuccessWorkshop.getWorkshopById(w.Id);
        Test.stopTest();

        System.assertEquals(w.Id, got.Id);
    }

    @IsTest
    static void testCreateParentContact() {
        String firstName = 'Test';
        String lastName = 'Parent';
        String phone = '555-1234';
        String site1 = 'Alvarado';
        String site2 = 'Balboa High';

        Test.startTest();
        Id contactId = CollegeSuccessWorkshop.createParentContact(firstName, lastName, phone, site1, site2);
        Test.stopTest();

        // Verify the contact was created with correct data
        Contact createdContact = [
            SELECT Id, FirstName, LastName, Phone, Site__c, Site_2__c, RecordType.DeveloperName
            FROM Contact 
            WHERE Id = :contactId
        ];

        System.assertEquals(firstName, createdContact.FirstName, 'First name should match');
        System.assertEquals(lastName, createdContact.LastName, 'Last name should match');
        System.assertEquals(phone, createdContact.Phone, 'Phone should match');
        System.assertEquals(site1, createdContact.Site__c, 'Site 1 should match');
        System.assertEquals(site2, createdContact.Site_2__c, 'Site 2 should match');
        System.assertEquals('Parent', createdContact.RecordType.DeveloperName, 'Record type should be Parent');
    }

    @IsTest
    static void testCreateParentContactWithNullValues() {
        String firstName = 'Test';
        String lastName = 'Parent';
        String phone = null;
        String site1 = null;
        String site2 = null;

        Test.startTest();
        Id contactId = CollegeSuccessWorkshop.createParentContact(firstName, lastName, phone, site1, site2);
        Test.stopTest();

        // Verify the contact was created with null values handled properly
        Contact createdContact = [
            SELECT Id, FirstName, LastName, Phone, Site__c, Site_2__c, RecordType.DeveloperName
            FROM Contact 
            WHERE Id = :contactId
        ];

        System.assertEquals(firstName, createdContact.FirstName, 'First name should match');
        System.assertEquals(lastName, createdContact.LastName, 'Last name should match');
        System.assertEquals(null, createdContact.Phone, 'Phone should be null');
        System.assertEquals(null, createdContact.Site__c, 'Site 1 should be null');
        System.assertEquals(null, createdContact.Site_2__c, 'Site 2 should be null');
        System.assertEquals('Parent', createdContact.RecordType.DeveloperName, 'Record type should be Parent');
    }

    @IsTest
    static void testCreateParentContactDuplicate() {
        String firstName = 'Test';
        String lastName = 'Parent';
        String phone = '555-1234';
        String site1 = 'Alvarado';
        String site2 = 'Balboa High';

        Test.startTest();
        // Create first contact
        Id contactId1 = CollegeSuccessWorkshop.createParentContact(firstName, lastName, phone, site1, site2);
        // Create second contact with same name (should be allowed)
        Id contactId2 = CollegeSuccessWorkshop.createParentContact(firstName, lastName, phone, site1, site2);
        Test.stopTest();

        System.assertNotEquals(contactId1, contactId2, 'Should create separate contacts');
        
        List<Contact> contacts = [
            SELECT Id FROM Contact 
            WHERE FirstName = :firstName AND LastName = :lastName
        ];
        System.assertEquals(2, contacts.size(), 'Should have two contacts with same name');
    }

    @IsTest
    static void testGetContactsAllWithRecordType() {
        Test.startTest();
        List<Contact> contacts = CollegeSuccessWorkshop.getContactsAll();
        Test.stopTest();

        System.assert(!contacts.isEmpty(), 'Should return contacts');
        
        // Verify that RecordType.Name is included in the query
        for (Contact c : contacts) {
            System.assertNotEquals(null, c.RecordType, 'RecordType should be included in query');
        }
    }

    @IsTest
    static void testAddAttendeeDuplicate() {
        Workshop__c w = [SELECT Id FROM Workshop__c WHERE Name='WS A1' LIMIT 1];
        Contact c = [SELECT Id FROM Contact WHERE LastName='Alpha' LIMIT 1]; // Already has attendee

        Test.startTest();
        Boolean added = CollegeSuccessWorkshop.addAttendee(c.Id, w.Id);
        Test.stopTest();

        System.assertEquals(false, added, 'Should not add duplicate attendee');
    }

    @IsTest
    static void testAddAttendeeInvalidIds() {
        Test.startTest();
        Boolean added = CollegeSuccessWorkshop.addAttendee('001000000000000', 'a000000000000000');
        Test.stopTest();

        System.assertEquals(false, added, 'Should handle invalid IDs gracefully');
    }

    @IsTest
    static void testUpdateAttendeeStatusInvalidId() {
        Test.startTest();
        try {
            CollegeSuccessWorkshop.updateAttendeeStatus('a000000000000000', 'Mentor');
            System.assert(false, 'Should have thrown an exception');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Error'), 'Should throw error for invalid ID');
        }
        Test.stopTest();
    }

    @IsTest
    static void testUpdateAttendeeAttendanceInvalidId() {
        Test.startTest();
        try {
            CollegeSuccessWorkshop.updateAttendeeAttendance('a000000000000000', 'Present');
            System.assert(false, 'Should have thrown an exception');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Error'), 'Should throw error for invalid ID');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetNearPeerFlagInvalidId() {
        Test.startTest();
        try {
            CollegeSuccessWorkshop.getNearPeerFlag('a000000000000000');
            System.assert(false, 'Should have thrown an exception');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Error'), 'Should throw error for invalid ID');
        }
        Test.stopTest();
    }

    @IsTest
    static void testUpdateWorkshopNearPeerInvalidId() {
        Test.startTest();
        try {
            CollegeSuccessWorkshop.updateWorkshopNearPeer('a000000000000000', true);
            System.assert(false, 'Should have thrown an exception');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Error'), 'Should throw error for invalid ID');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetCompletedFlagInvalidId() {
        Test.startTest();
        try {
            CollegeSuccessWorkshop.getCompletedFlag('a000000000000000');
            System.assert(false, 'Should have thrown an exception');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Error'), 'Should throw error for invalid ID');
        }
        Test.stopTest();
    }

    @IsTest
    static void testUpdateWorkshopCompletedInvalidId() {
        Test.startTest();
        try {
            CollegeSuccessWorkshop.updateWorkshopCompleted('a000000000000000', true);
            System.assert(false, 'Should have thrown an exception');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Error'), 'Should throw error for invalid ID');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetWorkshopByIdInvalidId() {
        Test.startTest();
        try {
            CollegeSuccessWorkshop.getWorkshopById('a000000000000000');
            System.assert(false, 'Should have thrown an exception');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Error'), 'Should throw error for invalid ID');
        }
        Test.stopTest();
    }

    @IsTest
    static void testAddBatchAttendanceEmptyList() {
        Test.startTest();
        CollegeSuccessWorkshop.addBatchAttendance(new List<Map<String,String>>());
        Test.stopTest();
        
        // Should not throw any exception
        System.assert(true, 'Should handle empty list gracefully');
    }

    @IsTest
    static void testAddBatchAttendanceNullList() {
        Test.startTest();
        CollegeSuccessWorkshop.addBatchAttendance(null);
        Test.stopTest();
        
        // Should not throw any exception
        System.assert(true, 'Should handle null list gracefully');
    }

    @IsTest
    static void testSearchWorkshopsEmptyString() {
        Test.startTest();
        List<Workshop__c> found = CollegeSuccessWorkshop.searchWorkshops('');
        Test.stopTest();
        
        System.assert(!found.isEmpty(), 'Empty search should return all workshops');
    }

    @IsTest
    static void testSearchWorkshopsNoResults() {
        Test.startTest();
        List<Workshop__c> found = CollegeSuccessWorkshop.searchWorkshops('XYZ123');
        Test.stopTest();
        
        System.assertEquals(0, found.size(), 'Should return empty list for no matches');
    }

    @IsTest
    static void testGetContactsAllWithExtendedDayFilter() {
        // Create a contact with Extended_Day_Account__c to test the filter
        Contact extendedDayContact = new Contact(
            LastName = 'Extended Day Contact',
            Extended_Day_Account__c = 123.45
        );
        insert extendedDayContact;

        Test.startTest();
        List<Contact> contacts = CollegeSuccessWorkshop.getContactsAll();
        Test.stopTest();

        // Verify that the extended day contact is not included
        Boolean foundExtendedDay = false;
        for (Contact c : contacts) {
            if (c.Id == extendedDayContact.Id) {
                foundExtendedDay = true;
                break;
            }
        }
        System.assertEquals(false, foundExtendedDay, 'Extended day contacts should be filtered out');
    }

    @IsTest
    static void testCreateParentContactWithSpecialCharacters() {
        String firstName = 'Test\'s';
        String lastName = 'O\'Connor';
        String phone = '(555) 123-4567';
        String site1 = 'Site & More';
        String site2 = 'Site "Quote"';

        Test.startTest();
        Id contactId = CollegeSuccessWorkshop.createParentContact(firstName, lastName, phone, site1, site2);
        Test.stopTest();

        Contact createdContact = [
            SELECT Id, FirstName, LastName, Phone, Site__c, Site_2__c
            FROM Contact 
            WHERE Id = :contactId
        ];

        System.assertEquals(firstName, createdContact.FirstName, 'Special characters in first name should be preserved');
        System.assertEquals(lastName, createdContact.LastName, 'Special characters in last name should be preserved');
        System.assertEquals(phone, createdContact.Phone, 'Special characters in phone should be preserved');
        System.assertEquals(site1, createdContact.Site__c, 'Special characters in site1 should be preserved');
        System.assertEquals(site2, createdContact.Site_2__c, 'Special characters in site2 should be preserved');
    }

    @IsTest
    static void testGetAttendeesWithNoAttendees() {
        Workshop__c w = [SELECT Id FROM Workshop__c WHERE Name='WS Loose' LIMIT 1]; // No attendees

        Test.startTest();
        List<Attendee__c> atts = CollegeSuccessWorkshop.getAttendees(w.Id);
        Test.stopTest();

        System.assertEquals(0, atts.size(), 'Should return empty list for workshop with no attendees');
    }

    @IsTest
    static void testGetWorkshopsGroupedBySeriesWithNoSeries() {
        // Create a workshop without a series
        Workshop__c looseWorkshop = [SELECT Id FROM Workshop__c WHERE Name='WS Loose' LIMIT 1];

        Test.startTest();
        Map<Id, List<Workshop__c>> m = CollegeSuccessWorkshop.getWorkshopsGroupedBySeries();
        Test.stopTest();

        System.assert(!m.isEmpty(), 'Should still return grouped workshops even with loose workshops');
    }
}