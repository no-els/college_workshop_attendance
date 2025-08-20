public with sharing class MgSecurity {

    // Return List<String> (not Set) for LWC
    @AuraEnabled(cacheable=true)
    public static List<String> getAllowedPrograms() {
        // Use Profile.Name (DeveloperName is not on Profile)
        String profName = [
            SELECT Profile.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ].Profile.Name;

        // Query your CMDT (make sure it exists with these field API names)
        List<ProgramAccessRule__mdt> rules = [
            SELECT ProgramName__c, ProfileName__c
            FROM ProgramAccessRule__mdt
            WHERE ProfileName__c = :profName
        ];

        // Build a unique set, then return as a list
        Set<String> programs = new Set<String>();
        for (ProgramAccessRule__mdt rule : rules) {
            if (rule.ProgramName__c != null && rule.ProgramName__c.trim().length() > 0) {
                programs.add(rule.ProgramName__c.trim());
            }
        }
        return new List<String>(programs);
    }
}
