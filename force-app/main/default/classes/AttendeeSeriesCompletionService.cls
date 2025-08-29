public class AttendeeSeriesCompletionService {
    // ===== Types =====
    public class Rule {
        public String seriesName;
        public String requirementName;
        public String targetFieldApi;       // field on Incentivized_Student_Req_Semester__c
        public Integer maxMisses;
        public Set<String> qualifyingStatuses;
        public Boolean active;
    }

    // ===== Entry point =====
    public static void recalculateForClients(Set<Id> workshopIdsTouched, Set<Id> clientIdsTouched) {
        if (workshopIdsTouched == null || workshopIdsTouched.isEmpty() ||
            clientIdsTouched == null || clientIdsTouched.isEmpty()) {
            return;
        }

        // 1) Load rules (CMDT)
        List<Series_Completion_Rule__mdt> ruleMdts = [
            SELECT Active__c, Series_Name__c, Requirement_Name__c, Target_Field_API__c, Max_Misses__c, Qualifying_Statuses__c
            FROM Series_Completion_Rule__mdt
            WHERE Active__c = TRUE
        ];
        if (ruleMdts.isEmpty()) return;

        // Build quick lookup by series name
        Map<String, List<Rule>> rulesBySeriesName = new Map<String, List<Rule>>();
        Set<String> allRequirementNames = new Set<String>();
        Set<String> unionQualStatuses = new Set<String>();

        for (Series_Completion_Rule__mdt m : ruleMdts) {
            Rule r = new Rule();
            r.active = m.Active__c;
            r.seriesName = m.Series_Name__c;
            r.requirementName = m.Requirement_Name__c;
            r.targetFieldApi = m.Target_Field_API__c;
            r.maxMisses = (m.Max_Misses__c == null ? 0 : Integer.valueOf(m.Max_Misses__c));
            r.qualifyingStatuses = new Set<String>();
            if (String.isNotBlank(m.Qualifying_Statuses__c)) {
                for (String s : m.Qualifying_Statuses__c.split('[;,\n\r]+')) {
                    String trimmed = s != null ? s.trim() : null;
                    if (!String.isBlank(trimmed)) {
                        r.qualifyingStatuses.add(trimmed);
                        unionQualStatuses.add(trimmed);
                    }
                }
            }
            rulesBySeriesName.putIfAbsent(r.seriesName, new List<Rule>());
            rulesBySeriesName.get(r.seriesName).add(r);
            if (!String.isBlank(r.requirementName)) allRequirementNames.add(r.requirementName);
        }

        if (rulesBySeriesName.isEmpty()) return;

        // 2) From touched workshops, find series IDs whose NAMES match any active rule
        Map<Id, String> seriesIdToName = new Map<Id, String>();
        Map<Id, Id> workshopIdToSeriesId = new Map<Id, Id>();

        for (Workshop__c w : [
            SELECT Id, Workshop_Series__c, Workshop_Series__r.Name
            FROM Workshop__c
            WHERE Id IN :workshopIdsTouched
        ]) {
            if (w.Workshop_Series__c != null && rulesBySeriesName.containsKey(w.Workshop_Series__r.Name)) {
                seriesIdToName.put(w.Workshop_Series__c, w.Workshop_Series__r.Name);
                workshopIdToSeriesId.put(w.Id, w.Workshop_Series__c);
            }
        }
        if (seriesIdToName.isEmpty()) return;

        Set<Id> seriesIds = new Set<Id>(seriesIdToName.keySet());

        // 3) Count total workshops per series
        Map<Id, Integer> totalWorkshopsBySeries = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Workshop_Series__c sid, COUNT(Id) c
            FROM Workshop__c
            WHERE Workshop_Series__c IN :seriesIds
            GROUP BY Workshop_Series__c
        ]) {
            totalWorkshopsBySeries.put((Id)ar.get('sid'), (Integer)ar.get('c'));
        }
        if (totalWorkshopsBySeries.isEmpty()) return;

        // 4) Gather ALL workshops in those series (for bulk attendee scan + map workshop->series)
        Set<Id> allSeriesWorkshopIds = new Set<Id>();
        for (Workshop__c wAll : [
            SELECT Id, Workshop_Series__c
            FROM Workshop__c
            WHERE Workshop_Series__c IN :seriesIds
        ]) {
            allSeriesWorkshopIds.add(wAll.Id);
            workshopIdToSeriesId.put(wAll.Id, wAll.Workshop_Series__c);
        }
        if (allSeriesWorkshopIds.isEmpty()) return;

        // 5) Pull attendees once; we’ll apply rule-specific status checks in-memory
        //    Filter by the union of all qualifying statuses to keep rows small.
        List<Attendee__c> attendees = new List<Attendee__c>();
        if (!unionQualStatuses.isEmpty()) {
            attendees = [
                SELECT Client__c, Workshop__c, Attendee_Status__c
                FROM Attendee__c
                WHERE Client__c IN :clientIdsTouched
                  AND Workshop__c IN :allSeriesWorkshopIds
                  AND Attendee_Status__c IN :unionQualStatuses
            ];
        }
        if (attendees.isEmpty()) attendees = new List<Attendee__c>();

        // 6) Build: for each rule, for each client → distinct workshops attended that qualify
        // Key = rule index (we’ll use Rule reference), then ClientId → Set<WorkshopId>
        Map<Rule, Map<Id, Set<Id>>> attendedByRuleClient = new Map<Rule, Map<Id, Set<Id>>>();

        // Pre-expand seriesId -> rules list
        Map<Id, List<Rule>> rulesBySeriesId = new Map<Id, List<Rule>>();
        for (Id sid : seriesIds) {
            String sn = seriesIdToName.get(sid);
            if (rulesBySeriesName.containsKey(sn)) {
                rulesBySeriesId.put(sid, rulesBySeriesName.get(sn));
            }
        }

        for (Attendee__c a : attendees) {
            Id sid = workshopIdToSeriesId.get(a.Workshop__c);
            if (sid == null) continue;
            List<Rule> rules = rulesBySeriesId.get(sid);
            if (rules == null) continue;

            for (Rule r : rules) {
                if (r.qualifyingStatuses.contains(a.Attendee_Status__c)) {
                    attendedByRuleClient.putIfAbsent(r, new Map<Id, Set<Id>>());
                    attendedByRuleClient.get(r).putIfAbsent(a.Client__c, new Set<Id>());
                    attendedByRuleClient.get(r).get(a.Client__c).add(a.Workshop__c);
                }
            }
        }

        // 7) Load the semester reqs for all relevant students (Name IN allRequirementNames)
        if (allRequirementNames.isEmpty()) return;

        Map<Id, List<Incentivized_Student_Req_Semester__c>> reqsByStudent = new Map<Id, List<Incentivized_Student_Req_Semester__c>>();
        List<Incentivized_Student_Req_Semester__c> reqs = [
            SELECT Id, Student__c, Name,
                   Completed_Near_Peer_Mentoring_Series__c,
                   Completed_Career_Readiness_Series__c
                   // ^ include any picklist fields you plan to update
            FROM Incentivized_Student_Req_Semester__c
            WHERE Student__c IN :clientIdsTouched
              AND Name IN :allRequirementNames
        ];
        for (Incentivized_Student_Req_Semester__c r : reqs) {
            reqsByStudent.putIfAbsent(r.Student__c, new List<Incentivized_Student_Req_Semester__c>());
            reqsByStudent.get(r.Student__c).add(r);
        }
        if (reqsByStudent.isEmpty()) return;

        // 8) For each rule + student, compute “Yes/No” and update the rule’s target field (skipping N/A)
        List<SObject> toUpdate = new List<SObject>();

        for (Id sid : seriesIds) {
            Integer total = totalWorkshopsBySeries.get(sid);
            if (total == null || total <= 0) continue;

            List<Rule> rules = rulesBySeriesId.get(sid);
            if (rules == null) continue;

            for (Rule r : rules) {
                Integer threshold = Math.max(total - (r.maxMisses == null ? 0 : r.maxMisses), 0);
                Map<Id, Set<Id>> perClient = attendedByRuleClient.get(r);
                Set<Id> clientsToConsider = new Set<Id>(clientIdsTouched);

                for (Id clientId : clientsToConsider) {
                    List<Incentivized_Student_Req_Semester__c> rows = reqsByStudent.get(clientId);
                    if (rows == null) continue;

                    Integer attendedCount = 0;
                    if (perClient != null && perClient.containsKey(clientId)) {
                        attendedCount = perClient.get(clientId).size();
                    }
                    String shouldBe = (attendedCount >= threshold) ? 'Yes' : 'No';

                    for (Incentivized_Student_Req_Semester__c row : rows) {
                        if (row.Name != r.requirementName) continue;

                        // Read current value dynamically; skip if N/A
                        String currentVal;
                        try {
                            currentVal = (String)row.get(r.targetFieldApi);
                        } catch (Exception e) {
                            // Misconfigured Target_Field_API__c; skip quietly
                            continue;
                        }
                        if (currentVal == 'N/A') continue;

                        if (currentVal != shouldBe) {
                            Incentivized_Student_Req_Semester__c upd = new Incentivized_Student_Req_Semester__c(Id=row.Id);
                            try {
                                upd.put(r.targetFieldApi, shouldBe);
                                toUpdate.add(upd);
                            } catch (Exception e) {
                                // invalid field name/value; skip this row
                            }
                        }
                    }
                }
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }
}
