trigger AttendeeAfterChange on Attendee__c (after insert, after update, after delete, after undelete) {
    List<Attendee__c> rows = new List<Attendee__c>();
    if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) rows.addAll(Trigger.new);
    if (Trigger.isDelete) rows.addAll(Trigger.old);

    Set<Id> workshopIds = new Set<Id>();
    Set<Id> clientIds   = new Set<Id>();

    for (Attendee__c a : rows) {
        if (a.Workshop__c != null) workshopIds.add(a.Workshop__c);
        if (a.Client__c   != null) clientIds.add(a.Client__c);
    }

    if (!workshopIds.isEmpty() && !clientIds.isEmpty()) {
        AttendeeSeriesCompletionService.recalculateForClients(workshopIds, clientIds);
    }
}
