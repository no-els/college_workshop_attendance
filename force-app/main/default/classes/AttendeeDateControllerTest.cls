@IsTest
public class AttendeeDateControllerTest {
    
    @TestSetup
    static void setupData() {
        // Workshop requires Program__c (picklist): "College Success" or "Parent Partner Program"
        Workshop__c w = new Workshop__c(
            Name = 'Test Workshop',
            Show_Date__c = false,
            Program__c = 'College Success' // required picklist value
        );
        insert w;

        // Attendee needs to point at the workshop; include a starting date
        Attendee__c a = new Attendee__c(
            Name = 'Test Attendee',
            Workshop__c = w.Id,
            Date__c = Date.today()
        );
        insert a;
    }
    
    @IsTest
    static void testGetDate() {
        Attendee__c a = [SELECT Id, Date__c FROM Attendee__c LIMIT 1];
        Test.startTest();
        Date result = AttendeeDateController.getDate(a.Id);
        Test.stopTest();
        System.assertEquals(a.Date__c, result, 'getDate should return the attendee Date__c');
    }
    
    @IsTest
    static void testSetDate() {
        Attendee__c a = [SELECT Id, Date__c FROM Attendee__c LIMIT 1];
        Date newDate = Date.today().addDays(7);
        Test.startTest();
        AttendeeDateController.setDate(a.Id, newDate);
        Test.stopTest();
        Attendee__c updated = [SELECT Date__c FROM Attendee__c WHERE Id = :a.Id];
        System.assertEquals(newDate, updated.Date__c, 'setDate should update Date__c');
    }
    
    @IsTest
    static void testClearDate() {
        Attendee__c a = [SELECT Id FROM Attendee__c LIMIT 1];
        Test.startTest();
        AttendeeDateController.clearDate(a.Id);
        Test.stopTest();
        Attendee__c updated = [SELECT Date__c FROM Attendee__c WHERE Id = :a.Id];
        System.assertEquals(null, updated.Date__c, 'clearDate should null out Date__c');
    }
    
    @IsTest
    static void testGetShowDateFlag() {
        Workshop__c w = [SELECT Id, Show_Date__c FROM Workshop__c LIMIT 1];
        Test.startTest();
        Boolean flag = AttendeeDateController.getShowDateFlag(w.Id);
        Test.stopTest();
        System.assertEquals(w.Show_Date__c, flag, 'getShowDateFlag should reflect current value');
    }
    
    @IsTest
    static void testUpdateShowDateFlag() {
        Workshop__c w = [SELECT Id FROM Workshop__c LIMIT 1];
        Test.startTest();
        AttendeeDateController.updateShowDateFlag(w.Id, true);
        Test.stopTest();
        Workshop__c updated = [SELECT Show_Date__c FROM Workshop__c WHERE Id = :w.Id];
        System.assertEquals(true, updated.Show_Date__c, 'updateShowDateFlag should set the value to true');
    }
}