// File: JiraBackgroundSync.cls - Handles background sync operations
public with sharing class JiraBackgroundSync {
    
    // Sync data in background without interfering with UI
    @AuraEnabled
    public static String performBackgroundSync() {
        try {
            // Get fresh data from Jira using the API service
            List<JiraController.JiraIssue> issues = JiraApiService.getJiraIssues();
            
            // Sync to custom object using existing sync service
            if (!issues.isEmpty()) {
                JiraSyncService.syncJiraIssuesToCustomObject(issues);
            }
            
            return 'SUCCESS: Synced ' + issues.size() + ' issues';
        } catch (Exception e) {
            System.debug('Background sync error: ' + e.getMessage());
            // Don't throw error for background operations - just log
            return 'ERROR: ' + e.getMessage();
        }
    }
    
    // Future method for async sync (doesn't block UI)
    @future(callout=true)
    public static void performAsyncSync() {
        try {
            List<JiraController.JiraIssue> issues = JiraApiService.getJiraIssues();
            if (!issues.isEmpty()) {
                JiraSyncService.syncJiraIssuesToCustomObject(issues);
            }
            System.debug('Async sync completed for ' + issues.size() + ' issues');
        } catch (Exception e) {
            System.debug('Async sync error: ' + e.getMessage());
        }
    }
    
    // Method to sync specific issue after status change
    @AuraEnabled
    public static String syncSingleIssue(String issueKey) {
        try {
            // Get all issues and find the specific one
            List<JiraController.JiraIssue> allIssues = JiraApiService.getJiraIssues();
            List<JiraController.JiraIssue> singleIssueList = new List<JiraController.JiraIssue>();
            
            for (JiraController.JiraIssue issue : allIssues) {
                if (issue.key == issueKey) {
                    singleIssueList.add(issue);
                    break;
                }
            }
            
            if (!singleIssueList.isEmpty()) {
                JiraSyncService.syncJiraIssuesToCustomObject(singleIssueList);
                return 'SUCCESS: Synced issue ' + issueKey;
            } else {
                return 'ERROR: Issue not found';
            }
        } catch (Exception e) {
            System.debug('Single issue sync error: ' + e.getMessage());
            return 'ERROR: ' + e.getMessage();
        }
    }
}