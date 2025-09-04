public with sharing class AttendeeSeriesCompletionService {
    // ===== Rule DTO built from CMDT (or injected in tests) =====
    public class Rule {
        public String seriesName;
        public String requirementName;
        public String targetFieldApi;       // field on Incentivized_Student_Req_Semester__c
        public Integer maxMisses;
        public Set<String> qualifyingStatuses;
        public Boolean active;
    }

    @TestVisible private static List<Rule> TEST_RULES; // when set in tests, bypass CMDT query

    // ---- Helper to load rules (CMDT in prod, injected in tests) ----
    private static List<Rule> loadActiveRules() {
        if (Test.isRunningTest() && TEST_RULES != null) {
            return TEST_RULES;
        }

        List<Rule> out = new List<Rule>();
        // Query CMDT in production/runtime
        List<Series_Completion_Rule__mdt> ruleMdts = [
            SELECT Active__c, Series_Name__c, Requirement_Name__c, Target_Field_API__c, Max_Misses__c, Qualifying_Statuses__c
            FROM Series_Completion_Rule__mdt
            WHERE Active__c = TRUE
        ];
        for (Series_Completion_Rule__mdt m : ruleMdts) {
            Rule r = new Rule();
            r.active = m.Active__c;
            r.seriesName = m.Series_Name__c;
            r.requirementName = m.Requirement_Name__c;
            r.targetFieldApi = m.Target_Field_API__c;
            r.maxMisses = (m.Max_Misses__c == null ? 0 : Integer.valueOf(m.Max_Misses__c));
            r.qualifyingStatuses = new Set<String>();
            if (String.isNotBlank(m.Qualifying_Statuses__c)) {
                for (String s : m.Qualifying_Statuses__c.split('[;,\n\r,]+')) {
                    String t = (s == null) ? null : s.trim();
                    if (!String.isBlank(t)) r.qualifyingStatuses.add(t);
                }
            }
            out.add(r);
        }
        return out;
    }

    // ---- Public test hook (optional to clear injected rules) ----
    @TestVisible
    static void setTestRules(List<Rule> rules) {
        TEST_RULES = rules;
    }

    // ===== Entry point from trigger =====
    public static void recalculateForClients(Set<Id> workshopIdsTouched, Set<Id> clientIdsTouched) {
        if (workshopIdsTouched == null || workshopIdsTouched.isEmpty() ||
            clientIdsTouched == null || clientIdsTouched.isEmpty()) {
            return;
        }

        // 1) Load rules
        List<Rule> rulesList = loadActiveRules();
        if (rulesList.isEmpty()) return;

        // Index rules by Series Name; gather requirement names & union of statuses
        Map<String, List<Rule>> rulesBySeriesName = new Map<String, List<Rule>>();
        Set<String> allRequirementNames = new Set<String>();
        Set<String> unionQualStatuses = new Set<String>();

        for (Rule r : rulesList) {
            if (String.isBlank(r.seriesName) || String.isBlank(r.requirementName) || String.isBlank(r.targetFieldApi)) {
                continue;
            }
            if (!rulesBySeriesName.containsKey(r.seriesName)) {
                rulesBySeriesName.put(r.seriesName, new List<Rule>());
            }
            rulesBySeriesName.get(r.seriesName).add(r);

            allRequirementNames.add(r.requirementName);
            if (r.qualifyingStatuses != null) unionQualStatuses.addAll(r.qualifyingStatuses);
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

        // 4) Gather ALL workshops in those series
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

        // 5) Pull attendees once; filter by the UNION of all qualifying statuses
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

        // 6) Expand seriesId -> rules list
        Map<Id, List<Rule>> rulesBySeriesId = new Map<Id, List<Rule>>();
        for (Id sid : seriesIds) {
            String sn = seriesIdToName.get(sid);
            if (rulesBySeriesName.containsKey(sn)) {
                rulesBySeriesId.put(sid, rulesBySeriesName.get(sn));
            }
        }

        // Build: for each rule, for each client → distinct workshops attended that qualify
        Map<Rule, Map<Id, Set<Id>>> attendedByRuleClient = new Map<Rule, Map<Id, Set<Id>>>();
        for (Attendee__c a : attendees) {
            Id sid = workshopIdToSeriesId.get(a.Workshop__c);
            if (sid == null) continue;
            List<Rule> seriesRules = rulesBySeriesId.get(sid);
            if (seriesRules == null) continue;

            for (Rule r : seriesRules) {
                if (r.qualifyingStatuses != null && r.qualifyingStatuses.contains(a.Attendee_Status__c)) {
                    if (!attendedByRuleClient.containsKey(r)) {
                        attendedByRuleClient.put(r, new Map<Id, Set<Id>>());
                    }
                    Map<Id, Set<Id>> perClient = attendedByRuleClient.get(r);
                    if (!perClient.containsKey(a.Client__c)) {
                        perClient.put(a.Client__c, new Set<Id>());
                    }
                    perClient.get(a.Client__c).add(a.Workshop__c);
                }
            }
        }

        // 7) Load the semester reqs dynamically (select all target fields referenced by rules)
        if (allRequirementNames.isEmpty()) return;

        Set<String> targetFieldApis = new Set<String>();
        for (Rule r : rulesList) {
            if (!String.isBlank(r.targetFieldApi)) targetFieldApis.add(r.targetFieldApi);
        }

        String baseSelect = 'SELECT Id, Student__c, Name';
        for (String f : targetFieldApis) baseSelect += ', ' + f;
        String soql = baseSelect +
            ' FROM Incentivized_Student_Req_Semester__c' +
            ' WHERE Student__c IN :clientIdsTouched' +
            ' AND Name IN :allRequirementNames';

        List<Incentivized_Student_Req_Semester__c> reqs = Database.query(soql);

        Map<Id, List<Incentivized_Student_Req_Semester__c>> reqsByStudent = new Map<Id, List<Incentivized_Student_Req_Semester__c>>();
        for (Incentivized_Student_Req_Semester__c r : reqs) {
            if (!reqsByStudent.containsKey(r.Student__c)) {
                reqsByStudent.put(r.Student__c, new List<Incentivized_Student_Req_Semester__c>());
            }
            reqsByStudent.get(r.Student__c).add(r);
        }
        if (reqsByStudent.isEmpty()) return;

        // 8) For each rule + student, compute Yes/No and update the rule’s target field (skip N/A)
        List<SObject> toUpdate = new List<SObject>();

        for (Id sid : seriesIds) {
            Integer total = totalWorkshopsBySeries.get(sid);
            if (total == null || total <= 0) continue;

            List<Rule> seriesRules = rulesBySeriesId.get(sid);
            if (seriesRules == null) continue;

            for (Rule r : seriesRules) {
                Integer threshold = Math.max(total - (r.maxMisses == null ? 0 : r.maxMisses), 0);
                Map<Id, Set<Id>> perClient = attendedByRuleClient.get(r);

                for (Id clientId : clientIdsTouched) {
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
                            // Misconfigured Target_Field_API__c; skip
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
