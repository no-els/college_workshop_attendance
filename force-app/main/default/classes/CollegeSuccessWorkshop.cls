public with sharing class CollegeSuccessWorkshop {

    // --- helpers ---
private static final String CONTACT_PREFIX  = Contact.SObjectType.getDescribe().getKeyPrefix();
private static final String WORKSHOP_PREFIX = Workshop__c.SObjectType.getDescribe().getKeyPrefix();
private static final String ATTENDEE_PREFIX = Attendee__c.SObjectType.getDescribe().getKeyPrefix();

private static void ensureIdPrefix(String idStr, String expectedPrefix, String label) {
    if (String.isBlank(idStr) || idStr.length() < 15 || !idStr.startsWith(expectedPrefix)) {
        throw new AuraHandledException('Error: invalid ' + label + ' Id');
    }
}

private static Boolean picklistAllows(Schema.SObjectField fieldRef, String value) {
    if (String.isBlank(value)) return false;
    Schema.DescribeFieldResult d = fieldRef.getDescribe();
    if (!d.isRestrictedPicklist()) return true;
    for (Schema.PicklistEntry e : d.getPicklistValues()) {
        if (e.getValue() == value) return true;
    }
    return false;
}

    @AuraEnabled(cacheable=true)
public static List<Contact> getContactsAll() {
    return [
        SELECT Id, Name, Phone, Site__c, Site_2__c, Extended_Day_Account__c, RecordType.Name
        FROM Contact
        WHERE RecordType.DeveloperName IN ('Student', 'Parent')
          AND Extended_Day_Account__c = null
    ];
}

    @AuraEnabled(cacheable=true)
    public static List<Workshop__c> searchWorkshops(String searchTerm, String program) {
        String query = '%' + searchTerm + '%';
        String soql = 'SELECT Id, Name, Date__c, Site__c, Near_Peer_Workshop__c FROM Workshop__c WHERE Name LIKE :query';
        
        if (String.isNotBlank(program)) {
            soql += ' AND Program__c = :program';
        }
        
        soql += ' ORDER BY Date__c, Name';
        return Database.query(soql);
    }
    @AuraEnabled
@AuraEnabled
public static Boolean getNearPeerFlag(Id workshopId) {
    try {
        String wid = String.valueOf(workshopId);
        ensureIdPrefix(wid, WORKSHOP_PREFIX, 'workshop');
        List<Workshop__c> ws = [
            SELECT Near_Peer_Workshop__c FROM Workshop__c WHERE Id = :workshopId LIMIT 1
        ];
        if (ws.isEmpty()) throw new AuraHandledException('Error: workshop not found');
        return ws[0].Near_Peer_Workshop__c;
    } catch (Exception e) {
        throw new AuraHandledException('Error: ' + e.getMessage());
    }
}


@AuraEnabled
public static void updateWorkshopNearPeer(Id workshopId, Boolean isNearPeer) {
    try {
        String wid = String.valueOf(workshopId);
        ensureIdPrefix(wid, WORKSHOP_PREFIX, 'workshop');
        List<Workshop__c> ws = [SELECT Id FROM Workshop__c WHERE Id = :workshopId LIMIT 1];
        if (ws.isEmpty()) throw new AuraHandledException('Error: workshop not found');

        Workshop__c w = new Workshop__c(Id = workshopId, Near_Peer_Workshop__c = isNearPeer);
        update w;
    } catch (Exception e) {
        throw new AuraHandledException('Error: ' + e.getMessage());
    }
}


@AuraEnabled
public static void updateAttendeeStatus(String attendeeId, String newStatus) {
    try {
        ensureIdPrefix(attendeeId, ATTENDEE_PREFIX, 'attendee');
        List<Attendee__c> atts = [
            SELECT Id, Near_Peer_Status__c FROM Attendee__c WHERE Id = :attendeeId LIMIT 1
        ];
        if (atts.isEmpty()) throw new AuraHandledException('Error: attendee not found');
        atts[0].Near_Peer_Status__c = newStatus;
        update atts[0];
    } catch (Exception e) {
        throw new AuraHandledException('Error: ' + e.getMessage());
    }
}


@AuraEnabled
public static void updateAttendeeAttendance(String attendeeId, String attendanceStatus){
    try {
        ensureIdPrefix(attendeeId, ATTENDEE_PREFIX, 'attendee');
        List<Attendee__c> atts = [
            SELECT Id, Attendee_Status__c FROM Attendee__c WHERE Id = :attendeeId LIMIT 1
        ];
        if (atts.isEmpty()) throw new AuraHandledException('Error: attendee not found');
        atts[0].Attendee_Status__c = attendanceStatus;
        update atts[0];
    } catch (Exception e) {
        throw new AuraHandledException('Error: ' + e.getMessage());
    }
}


@AuraEnabled(cacheable=true)
    public static List<Attendee__c> getAttendees(Id workshopId) {
        try {
            return [SELECT Name, 
            Client__c, 
            Workshop__c,
            Client__r.Phone, 
            Client__r.Site__c, 
            Near_Peer_Status__c,
            Attendee_Status__c,
            Date__c
            FROM Attendee__c WHERE Workshop__c = :workshopId order by CreatedDate asc];
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }


@AuraEnabled(cacheable=true)
public static Map<Id, List<Workshop__c>> getWorkshopsGroupedBySeries() {
    Map<Id, List<Workshop__c>> seriesToWorkshops = new Map<Id, List<Workshop__c>>();

    List<Workshop__c> workshops = [
        SELECT Id, Name, Workshop_Series__r.Name, Workshop_Series__c, Date__c, Site__c 
        FROM Workshop__c 
        WHERE Workshop_Series__c != null
        ORDER BY Workshop_Series__r.Name, Date__c
    ];

    for (Workshop__c w : workshops) {
        if (!seriesToWorkshops.containsKey(w.Workshop_Series__c)) {
            seriesToWorkshops.put(w.Workshop_Series__c, new List<Workshop__c>());
        }
        seriesToWorkshops.get(w.Workshop_Series__c).add(w);
    }

    return seriesToWorkshops;
}

@AuraEnabled(cacheable=true)
public static List<Cohort__c> getCohorts() {
    return [SELECT Id, Name FROM Cohort__c];
}

@AuraEnabled
public static void addBatchAttendance(List<Map<String, String>> records) {
    if (records == null || records.isEmpty()) return;

    Set<Id> contactIds = new Set<Id>();
    Set<Id> workshopIds = new Set<Id>();

    // Collect Contact and Workshop Ids (cast to Id explicitly)
    for (Map<String, String> row : records) {
        String contactIdStr  = row.get('ContactId');
        String workshopIdStr = row.get('WorkshopId');
        if (String.isNotBlank(contactIdStr))  contactIds.add((Id)contactIdStr);
        if (String.isNotBlank(workshopIdStr)) workshopIds.add((Id)workshopIdStr);
    }

    // Fetch contact names
    Map<Id, Contact> contactsMap = new Map<Id, Contact>(
        [SELECT Id, Name FROM Contact WHERE Id IN :contactIds]
    );

    // Fetch existing attendees to avoid duplicates
    Set<String> existingKeys = new Set<String>();
    for (Attendee__c existing : [
        SELECT Id, Client__c, Workshop__c
        FROM Attendee__c
        WHERE Client__c IN :contactIds AND Workshop__c IN :workshopIds
    ]) {
        existingKeys.add(String.valueOf(existing.Client__c) + '-' + String.valueOf(existing.Workshop__c));
    }

    // Build list of new attendees
    List<Attendee__c> toInsert = new List<Attendee__c>();

    for (Map<String, String> row : records) {
        String contactIdStr  = row.get('ContactId');
        String workshopIdStr = row.get('WorkshopId');
        if (String.isBlank(contactIdStr) || String.isBlank(workshopIdStr)) continue;

        Id contactId  = (Id)contactIdStr;
        Id workshopId = (Id)workshopIdStr;

        String key = String.valueOf(contactId) + '-' + String.valueOf(workshopId);
        if (existingKeys.contains(key)) continue;

        Contact c = contactsMap.get(contactId);
        if (c == null) continue;

        // Normalize picklist strings (trim)
        String status  = String.isBlank(row.get('Status'))    ? null : row.get('Status').trim();
        String nearPeer= String.isBlank(row.get('Near_Peer')) ? null : row.get('Near_Peer').trim();

        toInsert.add(new Attendee__c(
            Client__c           = contactId,
            Workshop__c         = workshopId,
            Name                = c.Name,
            Attendee_Status__c  = 'Present',    // ensure these values exist in your picklist
            Near_Peer_Status__c = nearPeer   // e.g., 'Mentor', 'Mentee', 'N/A'
        ));
    }

    if (!toInsert.isEmpty()) {
        insert toInsert;
    }
}




public class AttendanceWrapper {
    @AuraEnabled public Id contactId;
    @AuraEnabled public String status;
}

@AuraEnabled(cacheable=true)
public static List<YearDTO> getYearsSeriesWorkshops() {
    // 0) Who can see which Program__c values?
    Set<String> allowed = new Set<String>(MgSecurity.getAllowedPrograms());
    if (allowed.isEmpty()) return new List<YearDTO>();

    // 1) Pull series, but only bring back child Workshops whose Program__c is allowed
    List<Workshop_Series__c> seriesRows = [
        SELECT Id, Name, School_Year__c,
               (SELECT Id, Name, Date__c, Site__c, Near_Peer_Workshop__c, Program__c
                FROM Workshops__r
                WHERE Program__c IN :allowed
                ORDER BY Date__c DESC)
        FROM Workshop_Series__c
        WHERE School_Year__c != null
        ORDER BY School_Year__c, Name
    ];

    // 2) Group into Year -> Series -> Workshops (skip empty series)
    Map<String, YearDTO> yearMap = new Map<String, YearDTO>();

    for (Workshop_Series__c s : seriesRows) {
        if (String.isBlank(s.School_Year__c)) continue;

        // skip series that have 0 visible workshops after the filter
        if (s.Workshops__r == null || s.Workshops__r.isEmpty()) continue;

        YearDTO y = yearMap.get(s.School_Year__c);
        if (y == null) {
            y = new YearDTO();
            y.value = s.School_Year__c;  // e.g. "24-25"
            y.label = s.School_Year__c;
            y.series = new List<SeriesDTO>();
            yearMap.put(y.value, y);
        }

        SeriesDTO sd = new SeriesDTO();
        sd.seriesId = s.Id;
        sd.seriesName = s.Name;
        sd.workshops = new List<WorkshopDTO>();

        for (Workshop__c w : s.Workshops__r) {
            sd.workshops.add(new WorkshopDTO(w));
        }

        // (defensive) only add if we actually have workshops
        if (!sd.workshops.isEmpty()) y.series.add(sd);
    }

    // 3) Sort years desc
    List<YearDTO> out = new List<YearDTO>(yearMap.values());
    out.sort(new YearSorter());
    return out;
}


    // ----- DTOs -----
    public class YearDTO {
        @AuraEnabled public String label;         // "24-25"
        @AuraEnabled public String value;         // "24-25"
        @AuraEnabled public List<SeriesDTO> series;
    }

    public class SeriesDTO {
        @AuraEnabled public String seriesId;
        @AuraEnabled public String seriesName;
        @AuraEnabled public List<WorkshopDTO> workshops;
    }

    public class WorkshopDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public Date   the_date;
        @AuraEnabled public String site;
        @AuraEnabled public Boolean nearPeer;

        public WorkshopDTO(Workshop__c w) {
            id       = w.Id;
            name     = w.Name;
            the_date = w.Date__c;
            site     = String.valueOf(w.Site__c);
            nearPeer = w.Near_Peer_Workshop__c;
        }
    }

    // Sorter to order YearDTOs by their "value" descending (e.g., 27-28 > 26-27)
    public class YearSorter implements System.Comparator<YearDTO> {
        public Integer compare(YearDTO a, YearDTO b) {
        Integer aStart = Integer.valueOf(a.value.substring(0, 2));
        Integer bStart = Integer.valueOf(b.value.substring(0, 2));

        // Descending: higher start year first (e.g., 27-28 before 26-27)
        if (aStart == bStart) return 0;
        return (aStart > bStart) ? -1 : 1;
        }
    }

@AuraEnabled
public static Boolean getCompletedFlag(Id workshopId) {
    try {
        String wid = String.valueOf(workshopId);
        ensureIdPrefix(wid, WORKSHOP_PREFIX, 'workshop');
        List<Workshop__c> ws = [
            SELECT Completed__c FROM Workshop__c WHERE Id = :workshopId LIMIT 1
        ];
        if (ws.isEmpty()) throw new AuraHandledException('Error: workshop not found');
        return ws[0].Completed__c;
    } catch (Exception e) {
        throw new AuraHandledException('Error: ' + e.getMessage());
    }
}


 @AuraEnabled
public static void updateWorkshopCompleted(Id workshopId, Boolean completed) {
    try {
        String wid = String.valueOf(workshopId);
        ensureIdPrefix(wid, WORKSHOP_PREFIX, 'workshop');
        List<Workshop__c> ws = [SELECT Id FROM Workshop__c WHERE Id = :workshopId LIMIT 1];
        if (ws.isEmpty()) throw new AuraHandledException('Error: workshop not found');

        update new Workshop__c(Id = workshopId, Completed__c = completed);
    } catch (Exception e) {
        throw new AuraHandledException('Error: ' + e.getMessage());
    }
}



@AuraEnabled
public static Boolean addAttendee(String contactId, String workshopId){
    try {
        // quick prefix guard; if wrong type, treat as invalid and return false (per test)
        if (String.isBlank(contactId) || !contactId.startsWith(CONTACT_PREFIX))  return false;
        if (String.isBlank(workshopId) || !workshopId.startsWith(WORKSHOP_PREFIX)) return false;

        // avoid single-row assignment queries everywhere
        List<Attendee__c> existing = [
            SELECT Id FROM Attendee__c
            WHERE Client__c = :contactId AND Workshop__c = :workshopId
            LIMIT 1
        ];
        if (!existing.isEmpty()) return false;

        List<Contact> cs = [SELECT Name FROM Contact WHERE Id = :contactId LIMIT 1];
        if (cs.isEmpty()) return false;

        Attendee__c newAttendee = new Attendee__c(
            Client__c = (Id)contactId,
            Workshop__c = (Id)workshopId,
            Name = cs[0].Name,
            Attendee_Status__c = 'Present'
        );
        insert newAttendee;
        return true;
    } catch (Exception e) {
        // For this method, tests expect "graceful" failure → false, not exception
        return false;
    }
}


@AuraEnabled
public static Workshop__c getWorkshopById(Id workshopId) {
    try {
        String wid = String.valueOf(workshopId);
        ensureIdPrefix(wid, WORKSHOP_PREFIX, 'workshop');
        List<Workshop__c> ws = [
            SELECT Id, Name, Completed__c, Date__c, Site__c,
                   Near_Peer_Workshop__c, Program__c, Show_Date__c
            FROM Workshop__c
            WHERE Id = :workshopId
            LIMIT 1
        ];
        if (ws.isEmpty()) throw new AuraHandledException('Error: workshop not found');
        return ws[0];
    } catch (Exception e) {
        throw new AuraHandledException('Error: ' + e.getMessage());
    }
}


@AuraEnabled
public static Id createParentContact(String firstName, String lastName, String phone, String site1, String site2) {
    // Resolve Parent record type safely
    Id parentRecordTypeId = Schema.SObjectType.Contact
        .getRecordTypeInfosByDeveloperName()
        .get('Parent')
        .getRecordTypeId();

    Contact c = new Contact(
        FirstName = firstName,
        LastName  = lastName,
        Phone     = phone,
        RecordTypeId = parentRecordTypeId
    );

    // Only set picklists if allowed (prevents INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST)
    if (picklistAllows(Contact.Site__c, site1)) c.Site__c   = site1;
    if (picklistAllows(Contact.Site_2__c, site2)) c.Site_2__c = site2;

    // Bypass duplicate rules if any are active org-wide
    Database.DMLOptions dmo = new Database.DMLOptions();
    dmo.DuplicateRuleHeader.allowSave = true;
    c.setOptions(dmo);

    insert c;
    return c.Id;
}

}