// File: JiraSyncService.cls - FIXED Due Date Parsing
public with sharing class JiraSyncService {
    
    // Method to sync Jira issues to custom object
    @AuraEnabled
    public static void syncJiraIssuesToCustomObject(List<JiraController.JiraIssue> jiraIssues) {
        if (jiraIssues == null || jiraIssues.isEmpty()) {
            return;
        }
        
        try {
            // Get current user ID for tracking
            String currentUserId = UserInfo.getUserId();
            
            // Create a map of Jira IDs for efficient querying
            Set<String> jiraIds = new Set<String>();
            Set<String> issueKeys = new Set<String>();
            
            for (JiraController.JiraIssue issue : jiraIssues) {
                if (String.isNotBlank(issue.id)) {
                    jiraIds.add(issue.id);
                }
                if (String.isNotBlank(issue.key)) {
                    issueKeys.add(issue.key);
                }
            }
            
            // Query existing records
            Map<String, Jira_Issue__c> existingIssuesById = new Map<String, Jira_Issue__c>();
            Map<String, Jira_Issue__c> existingIssuesByKey = new Map<String, Jira_Issue__c>();
            
            for (Jira_Issue__c existingIssue : [
                SELECT Id, Jira_ID__c, Issue_Key__c, Summary__c, Status__c, Status_ID__c, 
                       Priority__c, Issue_Type__c, Due_Date__c, Is_Overdue__c, Assignee__c, 
                       Jira_Link__c, User_ID__c, Last_Synced__c
                FROM Jira_Issue__c 
                WHERE (Jira_ID__c IN :jiraIds OR Issue_Key__c IN :issueKeys) 
                AND User_ID__c = :currentUserId
            ]) {
                if (String.isNotBlank(existingIssue.Jira_ID__c)) {
                    existingIssuesById.put(existingIssue.Jira_ID__c, existingIssue);
                }
                if (String.isNotBlank(existingIssue.Issue_Key__c)) {
                    existingIssuesByKey.put(existingIssue.Issue_Key__c, existingIssue);
                }
            }
            
            List<Jira_Issue__c> recordsToUpsert = new List<Jira_Issue__c>();
            
            // Process each Jira issue
            for (JiraController.JiraIssue jiraIssue : jiraIssues) {
                Jira_Issue__c customIssue = null;
                
                // Try to find existing record by Jira ID first, then by Issue Key
                if (String.isNotBlank(jiraIssue.id) && existingIssuesById.containsKey(jiraIssue.id)) {
                    customIssue = existingIssuesById.get(jiraIssue.id);
                } else if (String.isNotBlank(jiraIssue.key) && existingIssuesByKey.containsKey(jiraIssue.key)) {
                    customIssue = existingIssuesByKey.get(jiraIssue.key);
                } else {
                    // Create new record
                    customIssue = new Jira_Issue__c();
                }
                
                // Map Jira issue data to custom object fields
                customIssue.Jira_ID__c = jiraIssue.id;
                customIssue.Issue_Key__c = jiraIssue.key;
                customIssue.Summary__c = truncateText(jiraIssue.summary, 255);
                customIssue.Status__c = truncateText(jiraIssue.status, 50);
                customIssue.Status_ID__c = truncateText(jiraIssue.statusId, 20);
                customIssue.Priority__c = truncateText(jiraIssue.priority, 20);
                customIssue.Issue_Type__c = truncateText(jiraIssue.issueType, 50);
                customIssue.Is_Overdue__c = jiraIssue.isOverdue != null ? jiraIssue.isOverdue : false;
                customIssue.Assignee__c = truncateText(jiraIssue.assignee, 100);
                customIssue.Jira_Link__c = truncateText(jiraIssue.jiraLink, 255);
                customIssue.User_ID__c = currentUserId;
                customIssue.Last_Synced__c = DateTime.now();
                
                // FIXED: Parse due date with better logic  
                customIssue.Due_Date__c = parseDueDateImproved(jiraIssue.dueDate);
                
                // Extract project key from issue key (e.g., PROJ-123 -> PROJ)
                if (String.isNotBlank(jiraIssue.key) && jiraIssue.key.contains('-')) {
                    customIssue.Project_Key__c = jiraIssue.key.split('-')[0];
                }
                
                // Determine status category based on status
                customIssue.Status_Category__c = determineStatusCategory(jiraIssue.status);
                
                recordsToUpsert.add(customIssue);
            }
            
            // Perform upsert operation
            if (!recordsToUpsert.isEmpty()) {
                Database.UpsertResult[] results = Database.upsert(recordsToUpsert, Jira_Issue__c.Jira_ID__c, false);
                
                // Log any failures
                for (Integer i = 0; i < results.size(); i++) {
                    if (!results[i].isSuccess()) {
                        System.debug('Failed to upsert Jira issue: ' + recordsToUpsert[i].Issue_Key__c + 
                                   '. Errors: ' + results[i].getErrors());
                    }
                }
            }
            
        } catch (Exception e) {
            System.debug('Error syncing Jira issues to custom object: ' + e.getMessage() + 
                        '. Stack: ' + e.getStackTraceString());
            throw new AuraHandledException('Failed to sync Jira data: ' + e.getMessage());
        }
    }
    
    // FIXED: Improved due date parsing method - MINIMAL CHANGE
    private static Date parseDueDateImproved(String dueDateStr) {
        if (String.isBlank(dueDateStr) || dueDateStr == 'N/A') {
            return null;
        }
        
        try {
            // Clean up the date string
            String cleanDateStr = dueDateStr.trim();
            
            // Case 1: ISO format from Jira API (YYYY-MM-DD or YYYY-MM-DDTHH:mm:ss.sssZ)
            if (cleanDateStr.contains('T')) {
                String datePart = cleanDateStr.split('T')[0];
                return Date.valueOf(datePart);
            }
            
            // Case 2: US format (M/D/YYYY or MM/DD/YYYY) - common in formatted display
            if (cleanDateStr.contains('/')) {
                String[] dateParts = cleanDateStr.split('/');
                if (dateParts.size() == 3) {
                    try {
                        Integer month = Integer.valueOf(dateParts[0]);
                        Integer day = Integer.valueOf(dateParts[1]);
                        Integer year = Integer.valueOf(dateParts[2]);
                        return Date.newInstance(year, month, day);
                    } catch (Exception e) {
                        System.debug('Error parsing slash date: ' + cleanDateStr);
                    }
                }
            }
            
            // Case 3: Simple date format (YYYY-MM-DD) or other formats
            if (cleanDateStr.contains('-')) {
                // Try direct Date.valueOf first (handles YYYY-MM-DD)
                try {
                    return Date.valueOf(cleanDateStr);
                } catch (Exception e) {
                    // If that fails, try DD-MM-YYYY format
                    String[] dateParts = cleanDateStr.split('-');
                    if (dateParts.size() == 3 && dateParts[0].length() == 2) {
                        Integer day = Integer.valueOf(dateParts[0]);
                        Integer month = Integer.valueOf(dateParts[1]);
                        Integer year = Integer.valueOf(dateParts[2]);
                        return Date.newInstance(year, month, day);
                    }
                }
            }
            
            // Case 4: Try direct Date.valueOf as last resort
            return Date.valueOf(cleanDateStr);
            
        } catch (Exception e) {
            System.debug('Error parsing due date: ' + dueDateStr + '. Error: ' + e.getMessage());
        }
        
        return null;
    }
    
    // Helper method to truncate text to specified length
    private static String truncateText(String text, Integer maxLength) {
        if (String.isBlank(text)) {
            return text;
        }
        return text.length() > maxLength ? text.substring(0, maxLength) : text;
    }
    
    // Helper method to determine status category
    private static String determineStatusCategory(String status) {
        if (String.isBlank(status)) {
            return 'Open';
        }
        
        String statusLower = status.toLowerCase();
        
        // Done statuses
        if (statusLower.contains('done') || statusLower.contains('closed') || 
            statusLower.contains('resolved') || statusLower.contains('complete')) {
            return 'Done';
        }
        
        // In Progress statuses
        if (statusLower.contains('progress') || statusLower.contains('development') || 
            statusLower.contains('review') || statusLower.contains('testing') ||
            statusLower.contains('working') || statusLower.contains('active')) {
            return 'In Progress';
        }
        
        // Default to Open for new, open, to do, etc.
        return 'Open';
    }
    
    // Method to clean up old synced records (optional - call periodically)
    @AuraEnabled
    public static void cleanupOldSyncedRecords(Integer daysOld) {
        try {
            DateTime cutoffDate = DateTime.now().addDays(-daysOld);
            
            List<Jira_Issue__c> recordsToDelete = [
                SELECT Id 
                FROM Jira_Issue__c 
                WHERE Last_Synced__c < :cutoffDate 
                AND Status_Category__c = 'Done'
                LIMIT 1000
            ];
            
            if (!recordsToDelete.isEmpty()) {
                delete recordsToDelete;
                System.debug('Cleaned up ' + recordsToDelete.size() + ' old Jira sync records');
            }
            
        } catch (Exception e) {
            System.debug('Error cleaning up old sync records: ' + e.getMessage());
        }
    }
    
    // Method to get synced issues for a user
    @AuraEnabled(cacheable=true)
    public static List<Jira_Issue__c> getSyncedJiraIssues() {
        try {
            return [
                SELECT Id, Jira_ID__c, Issue_Key__c, Summary__c, Status__c, Status_ID__c,
                       Priority__c, Issue_Type__c, Due_Date__c, Is_Overdue__c, Assignee__c,
                       Jira_Link__c, Last_Synced__c, Project_Key__c, Status_Category__c,
                       Created_Date_Jira__c, Updated_Date_Jira__c
                FROM Jira_Issue__c
                WHERE User_ID__c = :UserInfo.getUserId()
                ORDER BY Last_Synced__c DESC, Priority__c DESC
                LIMIT 200
            ];
        } catch (Exception e) {
            System.debug('Error retrieving synced Jira issues: ' + e.getMessage());
            throw new AuraHandledException('Failed to retrieve synced issues: ' + e.getMessage());
        }
    }
}