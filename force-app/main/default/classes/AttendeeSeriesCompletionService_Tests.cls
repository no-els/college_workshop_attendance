@IsTest
private class AttendeeSeriesCompletionService_Tests {
    @IsTest
    static void testCompletionLogic() {
        // Series (no Program__c needed)
        Workshop_Series__c series = new Workshop_Series__c(
            Name='Near Peer Mentoring Fall 2025'
        );
        insert series;

        // 5 Workshops — Program__c is REQUIRED here
        List<Workshop__c> ws = new List<Workshop__c>();
        for (Integer i=0; i<5; i++) {
            ws.add(new Workshop__c(
                Name='W' + i,
                Workshop_Series__c=series.Id,
                Program__c='College Success' // valid picklist: 'College Success' or 'Parent Partner Program'
            ));
        }
        insert ws;

        // Student
        Contact student = new Contact(LastName='Test');
        insert student;

        // Semester requirement
        Incentivized_Student_Req_Semester__c req = new Incentivized_Student_Req_Semester__c(
            Name='Fall 2025',
            Student__c = student.Id,
            Completed_Near_Peer_Mentoring_Series__c = 'No'
        );
        insert req;

        // Attend 4 workshops (Present/Excused Absence) → should be Yes
        insert new Attendee__c(Client__c=student.Id, Workshop__c=ws[0].Id, Attendee_Status__c='Present');
        insert new Attendee__c(Client__c=student.Id, Workshop__c=ws[1].Id, Attendee_Status__c='Excused Absence');
        insert new Attendee__c(Client__c=student.Id, Workshop__c=ws[2].Id, Attendee_Status__c='Present');
        insert new Attendee__c(Client__c=student.Id, Workshop__c=ws[3].Id, Attendee_Status__c='Present');

        req = [SELECT Completed_Near_Peer_Mentoring_Series__c FROM Incentivized_Student_Req_Semester__c WHERE Id=:req.Id];
        System.assertEquals('Yes', req.Completed_Near_Peer_Mentoring_Series__c);

        // Delete one → 3 of 5 → should revert to No
        delete [SELECT Id FROM Attendee__c WHERE Client__c=:student.Id LIMIT 1];
        req = [SELECT Completed_Near_Peer_Mentoring_Series__c FROM Incentivized_Student_Req_Semester__c WHERE Id=:req.Id];
        System.assertEquals('No', req.Completed_Near_Peer_Mentoring_Series__c);

        // Set N/A → remains N/A even if more attendance is added
        update new Incentivized_Student_Req_Semester__c(Id=req.Id, Completed_Near_Peer_Mentoring_Series__c='N/A');
        insert new Attendee__c(Client__c=student.Id, Workshop__c=ws[4].Id, Attendee_Status__c='Present');

        req = [SELECT Completed_Near_Peer_Mentoring_Series__c FROM Incentivized_Student_Req_Semester__c WHERE Id=:req.Id];
        System.assertEquals('N/A', req.Completed_Near_Peer_Mentoring_Series__c);
    }
}
