@IsTest
private class AttendeeSeriesCompletionService_Tests {

    @IsTest
    static void testMultipleSeriesRules_DI() {
        // ===== Inject rules instead of inserting CMDT =====
        List<AttendeeSeriesCompletionService.Rule> rules = new List<AttendeeSeriesCompletionService.Rule>();

        AttendeeSeriesCompletionService.Rule npm = new AttendeeSeriesCompletionService.Rule();
        npm.seriesName = 'Near Peer Mentoring Fall 2025';
        npm.requirementName = 'Fall 2025';
        npm.targetFieldApi = 'Completed_Near_Peer_Mentoring_Series__c';
        npm.maxMisses = 1;
        npm.qualifyingStatuses = new Set<String>{ 'Present', 'Excused Absence' };
        npm.active = true;
        rules.add(npm);

        AttendeeSeriesCompletionService.Rule cr = new AttendeeSeriesCompletionService.Rule();
        cr.seriesName = 'Career Readiness Fall 2025';
        cr.requirementName = 'Fall 2025';
        cr.targetFieldApi = 'Completed_Career_Readiness__c'; // corrected API
        cr.maxMisses = 4;
        cr.qualifyingStatuses = new Set<String>{ 'Present', 'Excused Absence' };
        cr.active = true;
        rules.add(cr);

        AttendeeSeriesCompletionService.setTestRules(rules);

        // ===== Required picklists (use your safe values) =====
        final String SCHOOL_YEAR = '25-26';       // safe value per your org (or '24-25')
        final String PROGRAM     = 'College Success'; // safe value per your org

        // ===== Series (School_Year__c required) =====
        Workshop_Series__c seriesNPM = new Workshop_Series__c(
            Name='Near Peer Mentoring Fall 2025',
            School_Year__c=SCHOOL_YEAR
        );
        Workshop_Series__c seriesCR  = new Workshop_Series__c(
            Name='Career Readiness Fall 2025',
            School_Year__c=SCHOOL_YEAR
        );
        insert new List<Workshop_Series__c>{ seriesNPM, seriesCR };

        // NPM: 5 workshops; CR: 10 workshops
        List<Workshop__c> npmWs = new List<Workshop__c>();
        for (Integer i=0; i<5; i++) {
            npmWs.add(new Workshop__c(
                Name='NPM ' + i,
                Workshop_Series__c = seriesNPM.Id,
                Program__c = PROGRAM
            ));
        }
        List<Workshop__c> crWs = new List<Workshop__c>();
        for (Integer i=0; i<10; i++) {
            crWs.add(new Workshop__c(
                Name='CR ' + i,
                Workshop_Series__c = seriesCR.Id,
                Program__c = PROGRAM
            ));
        }
        insert npmWs;
        insert crWs;

        // Student
        Contact student = new Contact(LastName='Test');
        insert student;

        // Semester req row (include both target fields)
        Incentivized_Student_Req_Semester__c req = new Incentivized_Student_Req_Semester__c(
            Name='Fall 2025',
            Student__c = student.Id,
            Completed_Near_Peer_Mentoring_Series__c = 'No',
            Completed_Career_Readiness__c = 'No'
        );
        insert req;

        // ----- NPM: attend 4 of 5 (miss 1 allowed) → Yes -----
        insert new Attendee__c(Client__c=student.Id, Workshop__c=npmWs[0].Id, Attendee_Status__c='Present');
        insert new Attendee__c(Client__c=student.Id, Workshop__c=npmWs[1].Id, Attendee_Status__c='Excused Absence');
        insert new Attendee__c(Client__c=student.Id, Workshop__c=npmWs[2].Id, Attendee_Status__c='Present');
        insert new Attendee__c(Client__c=student.Id, Workshop__c=npmWs[3].Id, Attendee_Status__c='Present');

        req = [
            SELECT Completed_Near_Peer_Mentoring_Series__c, Completed_Career_Readiness__c
            FROM Incentivized_Student_Req_Semester__c WHERE Id=:req.Id
        ];
        System.assertEquals('Yes', req.Completed_Near_Peer_Mentoring_Series__c, 'NPM should be Yes after 4/5');

        // ----- NPM: delete one → 3/5 → No -----
        delete [SELECT Id FROM Attendee__c WHERE Client__c=:student.Id AND Workshop__c IN :npmWs LIMIT 1];
        req = [
            SELECT Completed_Near_Peer_Mentoring_Series__c
            FROM Incentivized_Student_Req_Semester__c WHERE Id=:req.Id
        ];
        System.assertEquals('No', req.Completed_Near_Peer_Mentoring_Series__c, 'NPM should revert to No at 3/5');

        // ----- CR: attend 6 of 10 (miss up to 4) → Yes -----
        List<Attendee__c> crAttend = new List<Attendee__c>();
        for (Integer i=0; i<6; i++) {
            crAttend.add(new Attendee__c(Client__c=student.Id, Workshop__c=crWs[i].Id, Attendee_Status__c='Present'));
        }
        insert crAttend;

        req = [
            SELECT Completed_Career_Readiness__c
            FROM Incentivized_Student_Req_Semester__c WHERE Id=:req.Id
        ];
        System.assertEquals('Yes', req.Completed_Career_Readiness__c, 'CR should be Yes at 6/10 (miss 4 allowed)');

        // ----- Set CR to N/A → further attendance does not change it -----
        update new Incentivized_Student_Req_Semester__c(Id=req.Id, Completed_Career_Readiness__c='N/A');

        insert new Attendee__c(Client__c=student.Id, Workshop__c=crWs[6].Id, Attendee_Status__c='Present');

        req = [
            SELECT Completed_Career_Readiness__c
            FROM Incentivized_Student_Req_Semester__c WHERE Id=:req.Id
        ];
        System.assertEquals('N/A', req.Completed_Career_Readiness__c, 'CR should remain N/A');
    }
}
