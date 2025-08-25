trigger AttendeeTrigger on Attendee__c (after insert, after update, after delete, after undelete) {
    if (Trigger.isAfter) {
        AttendeeTriggerHandler.handleWorkshopCompletion(Trigger.new, Trigger.oldMap, Trigger.operationType);
    }
}
