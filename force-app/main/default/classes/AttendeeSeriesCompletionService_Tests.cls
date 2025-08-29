@IsTest
private class AttendeeSeriesCompletionService_Tests {
    @IsTest
    static void testMultipleSeriesRules() {
        // ===== Custom Metadata (two active rules) =====
        insert new Series_Completion_Rule__mdt(
            DeveloperName = 'NPM_Fall_2025',
            MasterLabel   = 'NPM Fall 2025',
            Active__c = true,
            Series_Name__c = 'Near Peer Mentoring Fall 2025',
            Requirement_Name__c = 'Fall 2025',
            Target_Field_API__c = 'Completed_Near_Peer_Mentoring_Series__c',
            Max_Misses__c = 1,
            Qualifying_Statuses__c = 'Present;Excused Absence'
        );
        insert new Series_Completion_Rule__mdt(
            DeveloperName = 'CR_Fall_2025',
            MasterLabel   = 'Career Readiness Fall 2025',
            Active__c = true,
            Series_Name__c = 'Career Readiness Fall 2025',
            Requirement_Name__c = 'Fall 2025',
            Target_Field_API__c = 'Completed_Career_Readiness_Series__c',
            Max_Misses__c = 4,
            Qualifying_Statuses__c = 'Present;Excused Absence'
        );

        // ===== Series =====
        Workshop_Series__c seriesNPM = new Workshop_Series__c(Name='Near Peer Mentoring Fall 2025');
        Workshop_Series__c seriesCR  = new Workshop_Series__c(Name='Career Readiness Fall 2025');
        insert new List<Workshop_Series__c>{ seriesNPM, seriesCR };

        // NPM: 5 workshops; CR: 10 workshops
        List<Workshop__c> npmWs = new List<Workshop__c>();
        for (Integer i=0; i<5; i++) {
            npmWs.add(new Workshop__c(
                Name='NPM ' + i,
                Workshop_Series__c = seriesNPM.Id,
                Program__c='College Success'
            ));
        }
        List<Workshop__c> crWs = new List<Workshop__c>();
        for (Integer i=0; i<10; i++) {
            crWs.add(new Workshop__c(
                Name='CR ' + i,
                Workshop_Series__c = seriesCR.Id,
                Program__c='College Success'
            ));
        }
        insert npmWs;
        insert crWs;

        // Student
        Contact student = new Contact(LastName='Test');
        insert student;

        // Semester req row (both target fields exist on this object)
        Incentivized_Student_Req_Semester__c req = new Incentivized_Student_Req_Semester__c(
            Name='Fall 2025',
            Student__c = student.Id,
            Completed_Near_Peer_Mentoring_Series__c = 'No',
            Completed_Career_Readiness_Series__c = 'No'
        );
        insert req;

        // ----- NPM: attend 4 of 5 (miss 1 allowed) → Yes -----
        insert new Attendee__c(Client__c=student.Id, Workshop__c=npmWs[0].Id, Attendee_Status__c='Present');
        insert new Attendee__c(Client__c=student.Id, Workshop__c=npmWs[1].Id, Attendee_Status__c='Excused Absence');
        insert new Attendee__c(Client__c=student.Id, Workshop__c=npmWs[2].Id, Attendee_Status__c='Present');
        insert new Attendee__c(Client__c=student.Id, Workshop__c=npmWs[3].Id, Attendee_Status__c='Present');

        req = [
            SELECT Completed_Near_Peer_Mentoring_Series__c, Completed_Career_Readiness_Series__c
            FROM Incentivized_Student_Req_Semester__c WHERE Id=:req.Id
        ];
        System.assertEquals('Yes', req.Completed_Near_Peer_Mentoring_Series__c, 'NPM should be Yes after 4/5');

        // ----- NPM: delete one → 3/5 → No -----
        delete [SELECT Id FROM Attendee__c WHERE Client__c=:student.Id AND Workshop__c IN :npmWs LIMIT 1];
        req = [
            SELECT Completed_Near_Peer_Mentoring_Series__c FROM Incentivized_Student_Req_Semester__c WHERE Id=:req.Id
        ];
        System.assertEquals('No', req.Completed_Near_Peer_Mentoring_Series__c, 'NPM should revert to No at 3/5');

        // ----- CR: attend 6 of 10 (miss up to 4) → Yes -----
        List<Attendee__c> crAttend = new List<Attendee__c>();
        for (Integer i=0; i<6; i++) {
            crAttend.add(new Attendee__c(Client__c=student.Id, Workshop__c=crWs[i].Id, Attendee_Status__c='Present'));
        }
        insert crAttend;

        req = [
            SELECT Completed_Career_Readiness_Series__c
            FROM Incentivized_Student_Req_Semester__c WHERE Id=:req.Id
        ];
        System.assertEquals('Yes', req.Completed_Career_Readiness_Series__c, 'CR should be Yes at 6/10 (miss 4 allowed)');

        // ----- Set CR field to N/A → further attendance does not change it -----
        update new Incentivized_Student_Req_Semester__c(Id=req.Id, Completed_Career_Readiness_Series__c='N/A');

        insert new Attendee__c(Client__c=student.Id, Workshop__c=crWs[6].Id, Attendee_Status__c='Present');

        req = [
            SELECT Completed_Career_Readiness_Series__c
            FROM Incentivized_Student_Req_Semester__c WHERE Id=:req.Id
        ];
        System.assertEquals('N/A', req.Completed_Career_Readiness_Series__c, 'CR should remain N/A');
    }
}
