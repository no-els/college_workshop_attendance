public class AttendeeSeriesCompletionService {
    // === CONFIG ===
    private static final String TARGET_SERIES_NAME = 'Near Peer Mentoring Fall 2025';
    private static final Set<String> QUALIFYING_STATUSES = new Set<String>{ 'Present', 'Excused Absence' };
    private static final String TARGET_REQ_NAME = 'Fall 2025'; // scholarship requirement name
    // ==============

    public static void recalculateForClients(Set<Id> workshopIdsTouched, Set<Id> clientIdsTouched) {
        // 1) Identify series
        Set<Id> seriesIds = new Set<Id>();
        for (Workshop__c w : [
            SELECT Id, Workshop_Series__c, Workshop_Series__r.Name
            FROM Workshop__c
            WHERE Id IN :workshopIdsTouched
        ]) {
            if (w.Workshop_Series__c != null && w.Workshop_Series__r.Name == TARGET_SERIES_NAME) {
                seriesIds.add(w.Workshop_Series__c);
            }
        }
        if (seriesIds.isEmpty()) return;

        // 2) Count total workshops
        Integer totalWorkshops = 0;
        for (AggregateResult ar : [
            SELECT Workshop_Series__c sid, COUNT(Id) c
            FROM Workshop__c
            WHERE Workshop_Series__c IN :seriesIds
            GROUP BY Workshop_Series__c
        ]) {
            totalWorkshops = Math.max(totalWorkshops, (Integer)ar.get('c'));
        }
        if (totalWorkshops == 0) return;

        // 3) Gather all workshops in series
        Set<Id> allSeriesWorkshopIds = new Set<Id>();
        for (Workshop__c wAll : [
            SELECT Id
            FROM Workshop__c
            WHERE Workshop_Series__c IN :seriesIds
        ]) {
            allSeriesWorkshopIds.add(wAll.Id);
        }
        if (allSeriesWorkshopIds.isEmpty()) return;

        // 4) Count DISTINCT attended workshops per client where status qualifies
        Map<Id, Integer> attendedCountByClient = new Map<Id, Integer>();
        for (AggregateResult ar2 : [
            SELECT Client__c cid, COUNT_DISTINCT(Workshop__c) cnt
            FROM Attendee__c
            WHERE Client__c IN :clientIdsTouched
              AND Workshop__c IN :allSeriesWorkshopIds
              AND Attendee_Status__c IN :QUALIFYING_STATUSES
            GROUP BY Client__c
        ]) {
            attendedCountByClient.put((Id)ar2.get('cid'), (Integer)ar2.get('cnt'));
        }

        Integer threshold = Math.max(totalWorkshops - 1, 0); // can miss one

        // 5) Fetch only semester reqs named "Fall 2025"
        List<Incentivized_Student_Req_Semester__c> reqs = [
            SELECT Id, Student__c, Name, Completed_Near_Peer_Mentoring_Series__c
            FROM Incentivized_Student_Req_Semester__c
            WHERE Student__c IN :clientIdsTouched
              AND Name = :TARGET_REQ_NAME
        ];
        if (reqs.isEmpty()) return;

        // 6) Update picklist Yes/No, but don’t touch N/A
        List<Incentivized_Student_Req_Semester__c> toUpdate = new List<Incentivized_Student_Req_Semester__c>();
        for (Incentivized_Student_Req_Semester__c r : reqs) {
            String current = r.Completed_Near_Peer_Mentoring_Series__c;
            if (current == 'N/A') continue;

            Integer attended = attendedCountByClient.get(r.Student__c);
            String shouldBe = (attended != null && attended >= threshold) ? 'Yes' : 'No';

            if (current != shouldBe) {
                r.Completed_Near_Peer_Mentoring_Series__c = shouldBe;
                toUpdate.add(r);
            }
        }

        if (!toUpdate.isEmpty()) update toUpdate;
    }
}
