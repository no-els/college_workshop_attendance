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
        List<Contact> cs = new List<Contact>{
            new Contact(LastName = 'Alpha',  Phone = '555-0001'),
            new Contact(LastName = 'Beta',   Phone = '555-0002'),
            new Contact(LastName = 'Gamma',  Phone = '555-0003')
        };
        insert cs;

        // A series for grouping
        Workshop_Series__c s1 = new Workshop_Series__c(
            Name = 'Series A',
            School_Year__c = '24-25'
        );
        insert s1;

        Workshop_Series__c s2 = new Workshop_Series__c(
            Name = 'Series B',
            School_Year__c = '25-26'
        );
        insert s2;

        // Workshops (some in series, some not)
        List<Workshop__c> ws = new List<Workshop__c>{
            new Workshop__c(Name='WS A1', Date__c=Date.today().addDays(-10), Workshop_Series__c=s1.Id, Near_Peer_Workshop__c=false),
            new Workshop__c(Name='WS A2', Date__c=Date.today().addDays(-5),  Workshop_Series__c=s1.Id, Near_Peer_Workshop__c=true),
            new Workshop__c(Name='WS B1', Date__c=Date.today().addDays(1),   Workshop_Series__c=s2.Id, Near_Peer_Workshop__c=false),
            new Workshop__c(Name='WS Loose', Date__c=Date.today(), Near_Peer_Workshop__c=false)
        };
        insert ws;

        // Attendees linked to one workshop
        insert new Attendee__c(
            Name = cs[0].LastName,
            Client__c = cs[0].Id,
            Workshop__c = ws[0].Id,
            Attendee_Status__c = 'Present',
            Near_Peer_Status__c = 'Mentor'
        );
        insert new Attendee__c(
            Name = cs[1].LastName,
            Client__c = cs[1].Id,
            Workshop__c = ws[0].Id,
            Attendee_Status__c = 'Excused Absence',
            Near_Peer_Status__c = 'Mentee'
        );
    }

    @IsTest
    static void testGetContactsAll() {
        Test.startTest();
        List<Contact> got = CollegeSuccessWorkshop.getContactsAll();
        Test.stopTest();
        System.assert(got.size() >= 3, 'Should return seeded contacts');
    }

    @IsTest
    static void testSearchWorkshops() {
        Test.startTest();
        List<Workshop__c> found = CollegeSuccessWorkshop.searchWorkshops('WS A');
        Test.stopTest();
        System.assert(!found.isEmpty(), 'Should find workshops by LIKE name');
    }

    @IsTest
    static void testNearPeerFlagAndUpdate() {
        Workshop__c w = [SELECT Id, Near_Peer_Workshop__c FROM Workshop__c WHERE Name = 'WS A1' LIMIT 1];

        Test.startTest();
        Boolean before = CollegeSuccessWorkshop.getNearPeerFlag(w.Id);
        CollegeSuccessWorkshop.updateWorkshopNearPeer(w.Id, !before);
        Boolean after  = CollegeSuccessWorkshop.getNearPeerFlag(w.Id);
        Test.stopTest();

        System.assertEquals(!before, after, 'Near peer flag should toggle');
    }

    @IsTest
    static void testUpdateAttendeeStatusAndAttendance() {
        Attendee__c a = [SELECT Id, Attendee_Status__c, Near_Peer_Status__c FROM Attendee__c LIMIT 1];

        Test.startTest();
        CollegeSuccessWorkshop.updateAttendeeStatus(a.Id, 'N/A');
        CollegeSuccessWorkshop.updateAttendeeAttendance(a.Id, 'Present');
        Test.stopTest();

        a = [SELECT Attendee_Status__c, Near_Peer_Status__c FROM Attendee__c WHERE Id = :a.Id];
        System.assertEquals('Present', a.Attendee_Status__c, 'Attendance updated');
        System.assertEquals('N/A', a.Near_Peer_Status__c, 'Near peer status updated');
    }

    @IsTest
    static void testGetAttendees() {
        Workshop__c w = [SELECT Id FROM Workshop__c WHERE Name = 'WS A1' LIMIT 1];
        Test.startTest();
        List<Attendee__c> attendees = CollegeSuccessWorkshop.getAttendees(w.Id);
        Test.stopTest();

        System.assertEquals(2, attendees.size(), 'Two attendees seeded for WS A1');
        System.assertNotEquals(null, attendees[0].Client__r.Phone, 'Child fields should be selected');
    }

    @IsTest
    static void testGetWorkshopsGroupedBySeries() {
        Test.startTest();
        Map<Id, List<Workshop__c>> m = CollegeSuccessWorkshop.getWorkshopsGroupedBySeries();
        Test.stopTest();

        // Should contain entries for both s1 and s2 (series with workshops)
        System.assert(!m.isEmpty(), 'Map should not be empty');
        Integer total = 0;
        for (Id k : m.keySet()) total += m.get(k).size();
        System.assert(total >= 3, 'Should have grouped workshops for both series');
    }

    @IsTest
static void testAddBatchAttendanceSkipsDuplicatesAndInsertsNew() {
    // Workshop with 2 attendees from @testSetup
    Workshop__c w = [SELECT Id FROM Workshop__c WHERE Name = 'WS A1' LIMIT 1];

    // One existing attendee (duplicate)
    Id existingContactId = [
        SELECT Client__c
        FROM Attendee__c
        WHERE Workshop__c = :w.Id
        LIMIT 1
    ].Client__c;

    // One contact NOT already attending this workshop (the actual new insert)
    Contact newCt = [
        SELECT Id, Name
        FROM Contact
        WHERE Id NOT IN (SELECT Client__c FROM Attendee__c WHERE Workshop__c = :w.Id)
        LIMIT 1
    ];
    System.assertNotEquals(null, newCt, 'Need at least one contact not already attending WS A1');

    // Build input rows (List<Map<String,String>>) with correct Apex syntax
    List<Map<String, String>> rows = new List<Map<String, String>>();
    rows.add(new Map<String, String>{
        'ContactId' => (String)existingContactId, // duplicate row
        'WorkshopId' => (String)w.Id,
        'Status'     => 'Present',
        'Near_Peer'  => 'Mentor'
    });
    rows.add(new Map<String, String>{
        'ContactId' => (String)newCt.Id,          // new row
        'WorkshopId' => (String)w.Id,
        'Status'     => 'Present',
        'Near_Peer'  => 'N/A'
    });

    Integer before = [SELECT count() FROM Attendee__c WHERE Workshop__c = :w.Id];

    Test.startTest();
    CollegeSuccessWorkshop.addBatchAttendance(rows);
    Test.stopTest();

    Integer after = [SELECT count() FROM Attendee__c WHERE Workshop__c = :w.Id];
    System.assertEquals(before + 1, after, 'Should insert only the new attendee');
}



    @IsTest
    static void testGetYearsSeriesWorkshops() {
        Test.startTest();
        List<CollegeSuccessWorkshop.YearDTO> years = CollegeSuccessWorkshop.getYearsSeriesWorkshops();
        Test.stopTest();

        System.assert(!years.isEmpty(), 'Years should not be empty');
        // First year should be the higher (e.g., 25-26 before 24-25)
        if (years.size() > 1) {
            Integer first = Integer.valueOf(years[0].value.substring(0, 2));
            Integer second = Integer.valueOf(years[1].value.substring(0, 2));
            System.assert(first >= second, 'Years should be sorted descending by start year');
        }
        // Ensure DTOs are populated
        System.assert(!years[0].series.isEmpty(), 'Series list should not be empty');
        System.assert(!years[0].series[0].workshops.isEmpty(), 'Workshops list should not be empty');
    }

    @IsTest
    static void testGetCompletedFlagAndUpdate() {
        Workshop__c w = [SELECT Id, Completed__c FROM Workshop__c LIMIT 1];

        Test.startTest();
        Boolean before = CollegeSuccessWorkshop.getCompletedFlag(w.Id);
        CollegeSuccessWorkshop.updateWorkshopCompleted(w.Id, !before);
        Boolean after = CollegeSuccessWorkshop.getCompletedFlag(w.Id);
        Test.stopTest();

        System.assertEquals(!before, after, 'Completed__c should toggle');
    }
}
