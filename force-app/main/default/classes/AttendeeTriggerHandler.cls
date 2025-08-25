public class AttendeeTriggerHandler {
    
    public static void handleWorkshopCompletion(List<Attendee__c> newAttendees, Map<Id, Attendee__c> oldAttendeesMap, TriggerOperation operationType) {
        
        // Collect all affected contact IDs
        Set<Id> contactIds = new Set<Id>();
        
        if (operationType == TriggerOperation.AFTER_DELETE) {
            List<Attendee__c> oldAttendees = (List<Attendee__c>)Trigger.old;
            for (Attendee__c attendee : oldAttendees) {
                if (attendee.Client__c != null) {
                    contactIds.add(attendee.Client__c);
                }
            }
        } else {
            for (Attendee__c attendee : newAttendees) {
                if (attendee.Client__c != null) {
                    contactIds.add(attendee.Client__c);
                }
            }
        }
        
        if (!contactIds.isEmpty()) {
            updateWorkshopCompletionStatus(contactIds);
        }
    }
    
    private static void updateWorkshopCompletionStatus(Set<Id> contactIds) {
        // Get the specific workshop series
        Workshop_Series__c series = [SELECT Id, Name FROM Workshop_Series__c 
                                    WHERE Name = 'Near Peer Mentoring Fall 2025' LIMIT 1];
        
        if (series == null) return;
        
        // Get all workshops in the series
        List<Workshop__c> seriesWorkshops = [SELECT Id FROM Workshop__c 
                                            WHERE Workshop_Series__c = :series.Id];
        
        Integer totalWorkshops = seriesWorkshops.size();
        if (totalWorkshops == 0) return;
        
        // Get attendance records for these contacts and workshops
        List<Attendee__c> attendances = [SELECT Client__c, Workshop__c 
                                        FROM Attendee__c 
                                        WHERE Client__c IN :contactIds 
                                        AND Workshop__c IN :seriesWorkshops];
        
        // Group attendance by contact
        Map<Id, Set<Id>> contactToWorkshops = new Map<Id, Set<Id>>();
        for (Attendee__c attendance : attendances) {
            if (!contactToWorkshops.containsKey(attendance.Client__c)) {
                contactToWorkshops.put(attendance.Client__c, new Set<Id>());
            }
            contactToWorkshops.get(attendance.Client__c).add(attendance.Workshop__c);
        }
        
        // Update the checkbox for each contact
        List<Incentivized_Student_Req_Semester__c> recordsToUpdate = new List<Incentivized_Student_Req_Semester__c>();
        
        for (Id contactId : contactIds) {
            Set<Id> attendedWorkshops = contactToWorkshops.get(contactId);
            Integer attendedCount = attendedWorkshops != null ? attendedWorkshops.size() : 0;
            
            // Check if they can miss one workshop (attended all but one)
            Boolean completed = (attendedCount >= (totalWorkshops - 1));
            
            // Find and update the Incentivized Student record
            List<Incentivized_Student_Req_Semester__c> studentRecords = [
                SELECT Id, Completed_Near_Peer_Mentoring_Series__c 
                FROM Incentivized_Student_Req_Semester__c 
                WHERE Student__c = :contactId
            ];
            
            for (Incentivized_Student_Req_Semester__c record : studentRecords) {
                // Handle picklist field with values: Yes, No, N/A
                String currentValue = record.Completed_Near_Peer_Mentoring_Series__c;
                
                // Skip if current value is N/A
                if (currentValue == 'N/A') {
                    continue;
                }
                
                // Determine what the new value should be
                String newValue = completed ? 'Yes' : 'No';
                
                // Only update if the value is actually changing
                if (currentValue != newValue) {
                    record.Completed_Near_Peer_Mentoring_Series__c = newValue;
                    recordsToUpdate.add(record);
                }
            }
        }
        
        if (!recordsToUpdate.isEmpty()) {
            update recordsToUpdate;
        }
    }
}
