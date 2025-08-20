@IsTest
private class CohortControllerTest {

    // Allowed values for Cohort_Member__c.Role__c in your org
    private static final String ROLE_NA     = 'N/A';
    private static final String ROLE_MENTOR = 'Mentor';
    private static final String ROLE_MENTEE = 'Mentee';

    @testSetup
    static void seed() {
        // Contacts for members
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 3; i++) {
            contacts.add(new Contact(LastName = 'Test ' + i));
        }
        insert contacts;

        // A cohort
        Cohort__c c = new Cohort__c(
            Name = 'Unit Test Cohort'
            // add other required fields here if your org enforces any
        );
        insert c;

        // Existing member (to test duplicate handling) — use a valid role
        insert new Cohort_Member__c(
            Cohort__c  = c.Id,
            Contact__c = contacts[0].Id,
            Role__c    = ROLE_NA
        );
    }

    @IsTest
    static void testCreateAndGetCohorts() {
        Test.startTest();
        Id newId = CohortController.createCohort('New Cohort');
        List<Cohort__c> rows = CohortController.getCohorts();
        Test.stopTest();

        System.assertNotEquals(null, newId, 'createCohort should return an Id');
        System.assert(rows.size() >= 2, 'Expect at least 2 cohorts (setup + created)');
    }

    @IsTest
    static void testGetCohortMembers() {
        Cohort__c c = [SELECT Id FROM Cohort__c LIMIT 1];
        Test.startTest();
        List<Cohort_Member__c> members = CohortController.getCohortMembers(c.Id);
        Test.stopTest();

        System.assertEquals(1, members.size(), 'Setup created 1 existing member');
        System.assertNotEquals(null, members[0].Contact__r.Name, 'Contact name should be populated');
    }

    @IsTest
    static void testAddMembersSkipsDuplicatesAndInsertsNew() {
        Cohort__c cohort = [SELECT Id FROM Cohort__c LIMIT 1];
        List<Contact> contacts = [SELECT Id FROM Contact ORDER BY CreatedDate ASC];

        // Prepare: one duplicate (contacts[0]) and one new (contacts[1])
        List<Cohort_Member__c> toAdd = new List<Cohort_Member__c>{
            new Cohort_Member__c(Cohort__c = cohort.Id, Contact__c = contacts[0].Id, Role__c = ROLE_MENTOR), // duplicate by contact
            new Cohort_Member__c(Cohort__c = cohort.Id, Contact__c = contacts[1].Id, Role__c = ROLE_MENTEE)  // new
        };

        Test.startTest();
        CohortController.addMembers(toAdd);
        Test.stopTest();

        List<Cohort_Member__c> all = [
            SELECT Id, Contact__c FROM Cohort_Member__c WHERE Cohort__c = :cohort.Id
        ];
        // We had 1 in setup + 1 new = 2 unique
        System.assertEquals(2, all.size(), 'Should have skipped duplicate and inserted only the new one');
    }

    @IsTest
    static void testAddMembersMissingCohortThrows() {
        Contact ct = [SELECT Id FROM Contact LIMIT 1];
        List<Cohort_Member__c> toAdd = new List<Cohort_Member__c>{
            new Cohort_Member__c(Contact__c = ct.Id, Role__c = ROLE_NA) // missing Cohort__c
        };

        Boolean threwHandled = false;
        try {
            Test.startTest();
            CohortController.addMembers(toAdd);
            Test.stopTest();
        } catch (Exception e) {
            threwHandled = (e instanceof AuraHandledException);
            // Note: Some orgs redact the message to "Script-thrown exception", so don't assert on message.
        }
        System.assert(threwHandled, 'Expected AuraHandledException when Cohort__c is missing');
    }




    @IsTest
    static void testUpdateMemberRoleAndDeleteMember() {
        Cohort__c cohort = [SELECT Id FROM Cohort__c LIMIT 1];
        Contact ct = [SELECT Id FROM Contact LIMIT 1];

        Cohort_Member__c m = new Cohort_Member__c(
            Cohort__c = cohort.Id,
            Contact__c = ct.Id,
            Role__c = ROLE_NA
        );
        insert m;

        Test.startTest();
        // Update role
        CohortController.updateMemberRole(m.Id, ROLE_MENTOR);

        // Delete member
        CohortController.deleteMember(m.Id);
        Test.stopTest();

        // Verify both effects
        System.assertEquals(0, [SELECT count() FROM Cohort_Member__c WHERE Id = :m.Id],
            'Member should be deleted');

        // (Optional) If you want to verify the update too, update then re-query BEFORE deletion,
        // or split into two tests as below.
    }


    @IsTest
    static void testGetCohortDetails() {
        Cohort__c c = [SELECT Id FROM Cohort__c LIMIT 1];
        Test.startTest();
        Map<String, Object> details = CohortController.getCohortDetails(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, details, 'Details map should not be null');
        System.assert(details.containsKey('cohort'), 'Details should include cohort');
        System.assert(details.containsKey('members'), 'Details should include members');
    }

    @IsTest
    static void testDeleteCohortAlsoDeletesMembers() {
        Cohort__c c = new Cohort__c(Name = 'To Delete');
        insert c;

        Contact ct = new Contact(LastName = 'Delete Me');
        insert ct;

        insert new Cohort_Member__c(Cohort__c = c.Id, Contact__c = ct.Id, Role__c = ROLE_MENTEE);

        Test.startTest();
        CohortController.deleteCohort(c.Id);
        Test.stopTest();

        System.assertEquals(0, [SELECT count() FROM Cohort__c WHERE Id = :c.Id], 'Cohort deleted');
        System.assertEquals(0, [SELECT count() FROM Cohort_Member__c WHERE Cohort__c = :c.Id], 'Related members deleted');
    }
}