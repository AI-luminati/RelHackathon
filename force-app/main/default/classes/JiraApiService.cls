// File: JiraApiService.cls - Pure Jira API operations (no sync)
public with sharing class JiraApiService {
    
    // Get Jira issues - pure API call, no sync
    @AuraEnabled(cacheable=true)
    public static List<JiraController.JiraIssue> getJiraIssues() {
        List<JiraController.JiraIssue> issuesToReturn = new List<JiraController.JiraIssue>();
        Http http = new Http();
        HttpRequest request = new HttpRequest();

        request.setEndpoint('callout:Jira_Integration/rest/api/latest/search'); 
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');

        String jqlQuery = 'assignee = currentUser() AND (statusCategory != Done OR (statusCategory = Done AND updated >= -30d)) ORDER BY priority DESC, updated DESC';

        Map<String, Object> requestBodyMap = new Map<String, Object>{
            'jql' => jqlQuery,
            'fields' => new List<String>{ 
                'summary', 'status', 'priority', 'issuetype', 'duedate', 'assignee', 'key'
            },
            'maxResults' => 50
        };
        request.setBody(JSON.serialize(requestBodyMap));

        String jiraBaseUrl = '';
        try {
            List<NamedCredential> ncs = [SELECT Id, Endpoint FROM NamedCredential WHERE DeveloperName = 'Jira_Integration' LIMIT 1];
            if (!ncs.isEmpty() && ncs[0].Endpoint != null) {
                jiraBaseUrl = ncs[0].Endpoint;
            }

            HttpResponse response = http.send(request);

            if (response.getStatusCode() == 200) {
                Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                List<Object> jiraApiIssues = (List<Object>) results.get('issues');

                if (jiraApiIssues != null) {
                    for (Object issueObj : jiraApiIssues) {
                        Map<String, Object> issueMap = (Map<String, Object>) issueObj;
                        String id = (String) issueMap.get('id');
                        String key = (String) issueMap.get('key');
                        Map<String, Object> fields = (Map<String, Object>) issueMap.get('fields');

                        if (fields != null) {
                            String summary = (String) fields.get('summary');
                            
                            Map<String, Object> statusMap = (Map<String, Object>) fields.get('status');
                            String statusName = statusMap != null ? (String) statusMap.get('name') : 'N/A';
                            String statusId = statusMap != null ? (String) statusMap.get('id') : '';

                            Map<String, Object> priorityMap = (Map<String, Object>) fields.get('priority');
                            String priorityName = priorityMap != null ? (String) priorityMap.get('name') : 'Medium';

                            Map<String, Object> issueTypeMap = (Map<String, Object>) fields.get('issuetype');
                            String issueTypeName = issueTypeMap != null ? (String) issueTypeMap.get('name') : 'Task';
                            
                            String dueDate = (String) fields.get('duedate');

                            Map<String, Object> assigneeMap = (Map<String, Object>) fields.get('assignee');
                            String assigneeName = assigneeMap != null ? (String) assigneeMap.get('displayName') : 'Unassigned';
                            
                            JiraController.JiraIssue issue = new JiraController.JiraIssue(id, key, summary, statusName, statusId, priorityName, issueTypeName, dueDate, assigneeName, jiraBaseUrl);
                            
                            // Get available transitions for this issue
                            issue.availableStatuses = getAvailableTransitions(key);
                            
                            issuesToReturn.add(issue);
                        }
                    }
                }
            } else {
                System.debug('Jira API Callout Error: ' + response.getStatusCode() + ' ' + response.getStatus());
                throw new AuraHandledException('Error fetching Jira issues (' + response.getStatusCode() + ')');
            }
        } catch (Exception e) {
            System.debug('Exception during Jira callout: ' + e.getMessage());
            throw new AuraHandledException('System error during Jira callout: ' + e.getMessage());
        }
        return issuesToReturn;
    }

    // Update issue status - pure API call, no sync
    @AuraEnabled
    public static String updateJiraIssueStatus(String issueKey, String transitionId) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();

        request.setEndpoint('callout:Jira_Integration/rest/api/latest/issue/' + issueKey + '/transitions');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');

        Map<String, Object> requestBody = new Map<String, Object>{
            'transition' => new Map<String, Object>{
                'id' => transitionId
            }
        };
        
        request.setBody(JSON.serialize(requestBody));

        try {
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 204) {
                return 'SUCCESS';
            } else {
                System.debug('Error updating issue status: ' + response.getStatusCode() + ' ' + response.getBody());
                throw new AuraHandledException('Failed to update issue status in Jira. Status: ' + response.getStatusCode());
            }
        } catch (Exception e) {
            System.debug('Exception updating issue status: ' + e.getMessage());
            throw new AuraHandledException('System error updating issue status: ' + e.getMessage());
        }
    }

    // Get available status transitions for a specific issue
    @AuraEnabled
    public static List<JiraController.StatusOption> getAvailableTransitions(String issueKey) {
        List<JiraController.StatusOption> transitions = new List<JiraController.StatusOption>();
        Http http = new Http();
        HttpRequest request = new HttpRequest();

        request.setEndpoint('callout:Jira_Integration/rest/api/latest/issue/' + issueKey + '/transitions');
        request.setMethod('GET');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');

        try {
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                List<Object> transitionsList = (List<Object>) results.get('transitions');
                
                if (transitionsList != null) {
                    for (Object transitionObj : transitionsList) {
                        Map<String, Object> transition = (Map<String, Object>) transitionObj;
                        String transitionId = (String) transition.get('id');
                        String transitionName = (String) transition.get('name');
                        
                        Map<String, Object> toStatus = (Map<String, Object>) transition.get('to');
                        String statusName = toStatus != null ? (String) toStatus.get('name') : transitionName;
                        String statusId = toStatus != null ? (String) toStatus.get('id') : '';
                        
                        transitions.add(new JiraController.StatusOption(statusName, statusId, transitionId));
                    }
                }
            } else {
                System.debug('Error getting transitions for ' + issueKey + ': ' + response.getStatusCode());
            }
        } catch (Exception e) {
            System.debug('Exception getting transitions: ' + e.getMessage());
        }
        
        return transitions;
    }
}