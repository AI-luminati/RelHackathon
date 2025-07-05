// File: JiraController.cls - Enhanced and Fixed Create Issue functionality
public with sharing class JiraController {

    // Wrapper class to represent a Jira Issue in a format suitable for LWC
    public class JiraIssue {
        @AuraEnabled public String id { get; set; }          // Jira internal ID
        @AuraEnabled public String key { get; set; }         // e.g., PROJ-123
        @AuraEnabled public String summary { get; set; }
        @AuraEnabled public String status { get; set; }      // e.g., "Open", "In Progress", "Done"
        @AuraEnabled public String statusId { get; set; }    // Jira status ID for transitions
        @AuraEnabled public String priority { get; set; }    // e.g., "High", "Medium", "Low"
        @AuraEnabled public String issueType { get; set; }   // e.g., "Bug", "Story", "Task"
        @AuraEnabled public String iconName { get; set; }    // SLDS icon name based on issueType
        @AuraEnabled public String dueDate { get; set; }     // Formatted due date
        @AuraEnabled public Boolean isOverdue { get; set; }
        @AuraEnabled public String priorityColorClass { get; set; } // CSS class for priority color
        @AuraEnabled public String assignee { get; set; }    // Assignee display name
        @AuraEnabled public String jiraLink { get; set; }    // Direct link to the Jira issue
        @AuraEnabled public List<StatusOption> availableStatuses { get; set; } // Available status transitions

        public JiraIssue(String id, String key, String summary, String status, String statusId, String priority, String issueType, String dueDateStr, String assigneeName, String jiraBaseUrl) {
            this.id = id;
            this.key = key;
            this.summary = summary;
            this.status = status;
            this.statusId = statusId;
            this.priority = priority?.toUpperCase(); // Normalize
            this.issueType = issueType;
            this.assignee = assigneeName;
            this.availableStatuses = new List<StatusOption>();
            
            // Construct Jira link, handling potential null or trailing slash in jiraBaseUrl
            if (String.isNotBlank(jiraBaseUrl) && String.isNotBlank(key)) {
                String cleanBaseUrl = jiraBaseUrl;
                while(cleanBaseUrl.endsWith('/')) {
                    cleanBaseUrl = cleanBaseUrl.substring(0, cleanBaseUrl.length() - 1);
                }
                this.jiraLink = cleanBaseUrl + '/browse/' + key;
            } else {
                this.jiraLink = '#'; // Fallback link
            }

            // Map issue type to SLDS icon
            if (issueType == 'Bug') {
                this.iconName = 'utility:bug';
            } else if (issueType == 'Story' || issueType == 'Epic') {
                this.iconName = 'utility:bookmark';
            } else if (issueType == 'Task' || issueType == 'Sub-task') {
                this.iconName = 'utility:task';
            } else {
                this.iconName = 'utility:custom_apps'; // Default
            }

            // Format Due Date and check if overdue
            if (String.isNotBlank(dueDateStr)) {
                try {
                    // Jira often returns YYYY-MM-DD for duedate field if only date is set.
                    // If it includes time, it might be YYYY-MM-DDTHH:mm:ss.sssZ
                    Date d = Date.valueOf(dueDateStr.split('T')[0]); 
                    this.dueDate = d.format(); // Format as per user's locale
                    if (d < Date.today()) {
                        this.isOverdue = true;
                    } else {
                        this.isOverdue = false;
                    }
                } catch (Exception e) {
                    System.debug('Error parsing due date: ' + dueDateStr + '. Error: ' + e.getMessage());
                    this.dueDate = 'N/A';
                    this.isOverdue = false;
                }
            } else {
                this.dueDate = 'N/A';
                this.isOverdue = false;
            }

            // Determine priority color class (matches your image)
            if (this.priority == 'HIGH' || this.priority == 'HIGHEST') {
                this.priorityColorClass = 'priority-high';
            } else if (this.priority == 'MEDIUM') {
                this.priorityColorClass = 'priority-medium';
            } else if (this.priority == 'LOW' || this.priority == 'LOWEST') {
                this.priorityColorClass = 'priority-low';
            } else {
                this.priorityColorClass = 'priority-default';
            }
        }
    }

    // Wrapper for status options in dropdowns
    public class StatusOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String transitionId { get; set; }

        public StatusOption(String label, String value, String transitionId) {
            this.label = label;
            this.value = value;
            this.transitionId = transitionId;
        }
    }

    // Wrapper for projects
    public class JiraProject {
        @AuraEnabled public String key { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String id { get; set; }

        public JiraProject(String key, String name, String id) {
            this.key = key;
            this.name = name;
            this.id = id;
        }
    }

    // Wrapper for issue types
    public class JiraIssueType {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String description { get; set; }

        public JiraIssueType(String id, String name, String description) {
            this.id = id;
            this.name = name;
            this.description = description;
        }
    }

    // Wrapper for priorities
    public class JiraPriority {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }

        public JiraPriority(String id, String name) {
            this.id = id;
            this.name = name;
        }
    }

    // Wrapper for assignees
    public class JiraAssignee {
        @AuraEnabled public String accountId { get; set; }
        @AuraEnabled public String displayName { get; set; }
        @AuraEnabled public String emailAddress { get; set; }

        public JiraAssignee(String accountId, String displayName, String emailAddress) {
            this.accountId = accountId;
            this.displayName = displayName;
            this.emailAddress = emailAddress;
        }
    }

    // MAIN METHOD - Always cacheable, always fast, always works
    @AuraEnabled(cacheable=true)
    public static List<JiraIssue> getJiraIssuesForCurrentUser() {
        List<JiraIssue> issuesToReturn = new List<JiraIssue>();
        Http http = new Http();
        HttpRequest request = new HttpRequest();

        request.setEndpoint('callout:Jira_Integration/rest/api/latest/search'); 
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');

        // Updated JQL query to include Done tasks from the last 30 days along with active tasks
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
                            
                            JiraIssue issue = new JiraIssue(id, key, summary, statusName, statusId, priorityName, issueTypeName, dueDate, assigneeName, jiraBaseUrl);
                            
                            // Get available transitions for this issue
                            issue.availableStatuses = getAvailableTransitions(key);
                            
                            issuesToReturn.add(issue);
                        }
                    }
                }
                
            } else {
                System.debug('Jira API Callout Error: ' + response.getStatusCode() + ' ' + response.getStatus());
                System.debug('Response Body: ' + response.getBody());
                throw new AuraHandledException('Error fetching Jira issues (' + response.getStatusCode() + '). Details: ' + response.getBody());
            }
        } catch (Exception e) {
            System.debug('Exception during Jira callout: ' + e.getMessage() + '. Stack: ' + e.getStackTraceString());
            throw new AuraHandledException('System error during Jira callout. Please check logs. Message: ' + e.getMessage());
        }
        return issuesToReturn;
    }

    // Get available projects for issue creation
    @AuraEnabled(cacheable=true)
    public static List<JiraProject> getJiraProjects() {
        List<JiraProject> projects = new List<JiraProject>();
        Http http = new Http();
        HttpRequest request = new HttpRequest();

        request.setEndpoint('callout:Jira_Integration/rest/api/latest/project');
        request.setMethod('GET');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');

        try {
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                List<Object> projectsList = (List<Object>) JSON.deserializeUntyped(response.getBody());
                
                if (projectsList != null) {
                    for (Object projectObj : projectsList) {
                        Map<String, Object> project = (Map<String, Object>) projectObj;
                        String key = (String) project.get('key');
                        String name = (String) project.get('name');
                        String id = (String) project.get('id');
                        
                        if (String.isNotBlank(key) && String.isNotBlank(name)) {
                            projects.add(new JiraProject(key, name, id));
                        }
                    }
                }
            } else {
                System.debug('Error getting projects: ' + response.getStatusCode() + ' ' + response.getBody());
                throw new AuraHandledException('Failed to fetch Jira projects. Status: ' + response.getStatusCode());
            }
        } catch (Exception e) {
            System.debug('Exception getting projects: ' + e.getMessage());
            throw new AuraHandledException('Error fetching projects: ' + e.getMessage());
        }
        
        return projects;
    }

    // Get issue types for a specific project
    @AuraEnabled
    public static List<JiraIssueType> getJiraIssueTypes(String projectKey) {
        List<JiraIssueType> issueTypes = new List<JiraIssueType>();
        Http http = new Http();
        HttpRequest request = new HttpRequest();

        request.setEndpoint('callout:Jira_Integration/rest/api/latest/project/' + projectKey);
        request.setMethod('GET');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');

        try {
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                Map<String, Object> project = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                List<Object> issueTypesList = (List<Object>) project.get('issueTypes');
                
                if (issueTypesList != null) {
                    for (Object issueTypeObj : issueTypesList) {
                        Map<String, Object> issueType = (Map<String, Object>) issueTypeObj;
                        String id = (String) issueType.get('id');
                        String name = (String) issueType.get('name');
                        String description = (String) issueType.get('description');
                        
                        // Filter out subtask types for simplicity
                        Boolean isSubtask = (Boolean) issueType.get('subtask');
                        if (isSubtask != true && String.isNotBlank(id) && String.isNotBlank(name)) {
                            issueTypes.add(new JiraIssueType(id, name, description));
                        }
                    }
                }
            } else {
                System.debug('Error getting issue types: ' + response.getStatusCode() + ' ' + response.getBody());
                throw new AuraHandledException('Failed to fetch issue types. Status: ' + response.getStatusCode());
            }
        } catch (Exception e) {
            System.debug('Exception getting issue types: ' + e.getMessage());
            throw new AuraHandledException('Error fetching issue types: ' + e.getMessage());
        }
        
        return issueTypes;
    }

    // Get available priorities
    @AuraEnabled(cacheable=true)
    public static List<JiraPriority> getJiraPriorities() {
        List<JiraPriority> priorities = new List<JiraPriority>();
        Http http = new Http();
        HttpRequest request = new HttpRequest();

        request.setEndpoint('callout:Jira_Integration/rest/api/latest/priority');
        request.setMethod('GET');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');

        try {
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                List<Object> prioritiesList = (List<Object>) JSON.deserializeUntyped(response.getBody());
                
                if (prioritiesList != null) {
                    for (Object priorityObj : prioritiesList) {
                        Map<String, Object> priority = (Map<String, Object>) priorityObj;
                        String id = (String) priority.get('id');
                        String name = (String) priority.get('name');
                        
                        if (String.isNotBlank(id) && String.isNotBlank(name)) {
                            priorities.add(new JiraPriority(id, name));
                        }
                    }
                }
            } else {
                System.debug('Error getting priorities: ' + response.getStatusCode() + ' ' + response.getBody());
                throw new AuraHandledException('Failed to fetch priorities. Status: ' + response.getStatusCode());
            }
        } catch (Exception e) {
            System.debug('Exception getting priorities: ' + e.getMessage());
            throw new AuraHandledException('Error fetching priorities: ' + e.getMessage());
        }
        
        return priorities;
    }

    // Get available assignees for a project
    @AuraEnabled
    public static List<JiraAssignee> getJiraAssignees(String projectKey) {
        List<JiraAssignee> assignees = new List<JiraAssignee>();
        Http http = new Http();
        HttpRequest request = new HttpRequest();

        request.setEndpoint('callout:Jira_Integration/rest/api/latest/user/assignable/search?project=' + projectKey);
        request.setMethod('GET');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');

        try {
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                List<Object> assigneesList = (List<Object>) JSON.deserializeUntyped(response.getBody());
                
                if (assigneesList != null) {
                    for (Object assigneeObj : assigneesList) {
                        Map<String, Object> assignee = (Map<String, Object>) assigneeObj;
                        String accountId = (String) assignee.get('accountId');
                        String displayName = (String) assignee.get('displayName');
                        String emailAddress = (String) assignee.get('emailAddress');
                        
                        if (String.isNotBlank(accountId) && String.isNotBlank(displayName)) {
                            assignees.add(new JiraAssignee(accountId, displayName, emailAddress));
                        }
                    }
                }
            } else {
                System.debug('Error getting assignees: ' + response.getStatusCode() + ' ' + response.getBody());
                // Don't throw error for assignees - just return empty list
            }
        } catch (Exception e) {
            System.debug('Exception getting assignees: ' + e.getMessage());
            // Don't throw error for assignees - just return empty list
        }
        
        return assignees;
    }

    // Create a new Jira issue - ROBUST VERSION WITH PROPER ASSIGNEE HANDLING
    @AuraEnabled
    public static String createJiraIssue(String issueData) {
        try {
            Map<String, Object> issueMap = (Map<String, Object>) JSON.deserializeUntyped(issueData);
            
            String projectKey = (String) issueMap.get('projectKey');
            String issueTypeId = (String) issueMap.get('issueTypeId');
            String summary = (String) issueMap.get('summary');
            String description = (String) issueMap.get('description');
            String priorityId = (String) issueMap.get('priorityId');
            String dueDate = (String) issueMap.get('dueDate');
            String assigneeId = (String) issueMap.get('assigneeId');
            String initialStatus = (String) issueMap.get('initialStatus');

            if (String.isBlank(projectKey) || String.isBlank(issueTypeId) || String.isBlank(summary)) {
                throw new AuraHandledException('Project, Issue Type, and Summary are required fields.');
            }

            // Strategy 1: Try creating with assignee in the initial request
            String result = createIssueWithAssignee(projectKey, issueTypeId, summary, description, assigneeId);
            
            if (result.startsWith('SUCCESS:')) {
                String issueKey = result.substring(result.indexOf('Issue ') + 6, result.indexOf(' created'));
                
                // Strategy 2: Try to update additional fields after creation
                updateAdditionalFieldsAfterCreation(issueKey, priorityId, dueDate, null); // Don't update assignee again
                
                // Strategy 3: Try to transition to initial status if specified
                if (String.isNotBlank(initialStatus) && initialStatus != 'to-do') {
                    transitionIssueToInitialStatus(issueKey, initialStatus);
                }
                
                return result;
            } else {
                throw new AuraHandledException(result);
            }
            
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            System.debug('Exception creating issue: ' + e.getMessage() + '. Stack: ' + e.getStackTraceString());
            throw new AuraHandledException('System error creating issue: ' + e.getMessage());
        }
    }

    // Helper method: Create issue with assignee included from the start
    private static String createIssueWithAssignee(String projectKey, String issueTypeId, String summary, String description, String assigneeId) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();

        request.setEndpoint('callout:Jira_Integration/rest/api/latest/issue');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');

        // Start with required fields
        Map<String, Object> fields = new Map<String, Object>{
            'project' => new Map<String, Object>{ 'key' => projectKey },
            'issuetype' => new Map<String, Object>{ 'id' => issueTypeId },
            'summary' => summary
        };

        // Add description if provided
        if (String.isNotBlank(description)) {
            fields.put('description', description);
        }

        // CRITICAL: Handle assignee properly
        if (String.isBlank(assigneeId)) {
            // If no specific assignee selected, assign to current user
            String currentUser = getCurrentJiraUser();
            if (String.isNotBlank(currentUser)) {
                fields.put('assignee', new Map<String, Object>{ 'accountId' => currentUser });
            }
        } else {
            // Assign to specific user
            fields.put('assignee', new Map<String, Object>{ 'accountId' => assigneeId });
        }

        Map<String, Object> requestBody = new Map<String, Object>{
            'fields' => fields
        };

        String requestBodyJson = JSON.serialize(requestBody);
        System.debug('Create issue with assignee request: ' + requestBodyJson);
        request.setBody(requestBodyJson);

        try {
            HttpResponse response = http.send(request);
            System.debug('Create issue with assignee response: ' + response.getStatusCode() + ' - ' + response.getBody());
            
            if (response.getStatusCode() == 201) {
                Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                String issueKey = (String) result.get('key');
                String issueId = (String) result.get('id');
                
                return 'SUCCESS: Issue ' + issueKey + ' created successfully';
            } else {
                // If assignee fails, try without assignee but then assign afterward
                System.debug('Create with assignee failed, trying fallback method');
                return createIssueWithoutAssigneeThenAssign(projectKey, issueTypeId, summary, description, assigneeId);
            }
        } catch (Exception e) {
            System.debug('Exception in create with assignee: ' + e.getMessage());
            // Fallback: try without assignee
            return createIssueWithoutAssigneeThenAssign(projectKey, issueTypeId, summary, description, assigneeId);
        }
    }

    // Fallback method: Create without assignee then assign afterward
    private static String createIssueWithoutAssigneeThenAssign(String projectKey, String issueTypeId, String summary, String description, String assigneeId) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();

        request.setEndpoint('callout:Jira_Integration/rest/api/latest/issue');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');

        // Minimal fields only
        Map<String, Object> fields = new Map<String, Object>{
            'project' => new Map<String, Object>{ 'key' => projectKey },
            'issuetype' => new Map<String, Object>{ 'id' => issueTypeId },
            'summary' => summary
        };

        if (String.isNotBlank(description)) {
            fields.put('description', description);
        }

        Map<String, Object> requestBody = new Map<String, Object>{
            'fields' => fields
        };

        request.setBody(JSON.serialize(requestBody));

        try {
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 201) {
                Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                String issueKey = (String) result.get('key');
                
                // Now assign the issue to current user or specified user
                assignIssueToUser(issueKey, assigneeId);
                
                return 'SUCCESS: Issue ' + issueKey + ' created successfully';
            } else {
                String errorMessage = parseJiraError(response);
                return 'ERROR: ' + errorMessage;
            }
        } catch (Exception e) {
            System.debug('Exception in fallback create: ' + e.getMessage());
            return 'ERROR: System error during issue creation: ' + e.getMessage();
        }
    }

    // Helper method: Assign issue to user after creation - IMPROVED
    private static void assignIssueToUser(String issueKey, String assigneeId) {
        try {
            Http http = new Http();
            HttpRequest request = new HttpRequest();

            request.setEndpoint('callout:Jira_Integration/rest/api/latest/issue/' + issueKey + '/assignee');
            request.setMethod('PUT');
            request.setHeader('Content-Type', 'application/json');
            request.setHeader('Accept', 'application/json');

            Map<String, Object> assigneeBody;
            
            if (String.isBlank(assigneeId)) {
                // Try multiple approaches to assign to current user
                String currentUser = getCurrentJiraUser();
                if (String.isNotBlank(currentUser)) {
                    // Try with accountId first (modern Jira)
                    assigneeBody = new Map<String, Object>{ 'accountId' => currentUser };
                } else {
                    // Fallback: try to assign to the user making the API call
                    assigneeBody = new Map<String, Object>{ 'accountId' => null }; // This should assign to current user
                }
            } else {
                assigneeBody = new Map<String, Object>{ 'accountId' => assigneeId };
            }

            request.setBody(JSON.serialize(assigneeBody));
            
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 204) {
                System.debug('Successfully assigned issue ' + issueKey + ' to user');
            } else {
                System.debug('Failed to assign issue ' + issueKey + ': ' + response.getBody());
                
                // Try alternative assignment method
                assignIssueAlternativeMethod(issueKey, assigneeId);
            }
        } catch (Exception e) {
            System.debug('Exception assigning issue ' + issueKey + ': ' + e.getMessage());
            // Try alternative assignment method
            assignIssueAlternativeMethod(issueKey, assigneeId);
        }
    }

    // Alternative assignment method using issue update API
    private static void assignIssueAlternativeMethod(String issueKey, String assigneeId) {
        try {
            Http http = new Http();
            HttpRequest request = new HttpRequest();

            request.setEndpoint('callout:Jira_Integration/rest/api/latest/issue/' + issueKey);
            request.setMethod('PUT');
            request.setHeader('Content-Type', 'application/json');
            request.setHeader('Accept', 'application/json');

            Map<String, Object> fields = new Map<String, Object>();
            
            if (String.isBlank(assigneeId)) {
                // Get current user info
                String currentUser = getCurrentJiraUser();
                if (String.isNotBlank(currentUser)) {
                    fields.put('assignee', new Map<String, Object>{ 'accountId' => currentUser });
                }
            } else {
                fields.put('assignee', new Map<String, Object>{ 'accountId' => assigneeId });
            }

            if (!fields.isEmpty()) {
                Map<String, Object> updateBody = new Map<String, Object>{
                    'fields' => fields
                };
                
                request.setBody(JSON.serialize(updateBody));
                HttpResponse response = http.send(request);
                
                if (response.getStatusCode() == 204) {
                    System.debug('Successfully assigned issue ' + issueKey + ' using alternative method');
                } else {
                    System.debug('Alternative assignment also failed for ' + issueKey + ': ' + response.getBody());
                }
            }
        } catch (Exception e) {
            System.debug('Alternative assignment method failed for ' + issueKey + ': ' + e.getMessage());
        }
    }

    // Helper method: Get current Jira user - IMPROVED
    private static String getCurrentJiraUser() {
        try {
            Http http = new Http();
            HttpRequest request = new HttpRequest();

            request.setEndpoint('callout:Jira_Integration/rest/api/latest/myself');
            request.setMethod('GET');
            request.setHeader('Content-Type', 'application/json');
            request.setHeader('Accept', 'application/json');

            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                Map<String, Object> user = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                String accountId = (String) user.get('accountId');
                String userName = (String) user.get('name');
                String key = (String) user.get('key');
                
                System.debug('Current Jira user - AccountId: ' + accountId + ', Name: ' + userName + ', Key: ' + key);
                
                // Return account ID if available (modern Jira), otherwise username, otherwise key
                if (String.isNotBlank(accountId)) {
                    return accountId;
                } else if (String.isNotBlank(userName)) {
                    return userName;
                } else {
                    return key;
                }
            } else {
                System.debug('Failed to get current user: ' + response.getStatusCode() + ' - ' + response.getBody());
            }
        } catch (Exception e) {
            System.debug('Exception getting current user: ' + e.getMessage());
        }
        return null;
    }

    // Helper method: Create issue with only essential fields and handle initial status
    private static String createIssueWithMinimalFields(String projectKey, String issueTypeId, String summary, String description) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();

        request.setEndpoint('callout:Jira_Integration/rest/api/latest/issue');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');

        // Start with absolute minimal required fields
        Map<String, Object> fields = new Map<String, Object>{
            'project' => new Map<String, Object>{ 'key' => projectKey },
            'issuetype' => new Map<String, Object>{ 'id' => issueTypeId },
            'summary' => summary
        };

        // Only add description if provided and not empty
        if (String.isNotBlank(description)) {
            fields.put('description', description);
        }

        Map<String, Object> requestBody = new Map<String, Object>{
            'fields' => fields
        };

        String requestBodyJson = JSON.serialize(requestBody);
        System.debug('Create issue minimal request: ' + requestBodyJson);
        request.setBody(requestBodyJson);

        try {
            HttpResponse response = http.send(request);
            System.debug('Create issue minimal response: ' + response.getStatusCode() + ' - ' + response.getBody());
            
            if (response.getStatusCode() == 201) {
                Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                String issueKey = (String) result.get('key');
                String issueId = (String) result.get('id');
                
                return 'SUCCESS: Issue ' + issueKey + ' created successfully';
            } else {
                // Parse and return error details
                String errorMessage = parseJiraError(response);
                return 'ERROR: ' + errorMessage;
            }
        } catch (Exception e) {
            System.debug('Exception in minimal create: ' + e.getMessage());
            return 'ERROR: System error during issue creation: ' + e.getMessage();
        }
    }

    // Helper method: Update additional fields after issue creation including status transitions
    private static void updateAdditionalFieldsAfterCreation(String issueKey, String priorityId, String dueDate, String assigneeId) {
        List<String> updateResults = new List<String>();
        
        // Try to update priority
        if (String.isNotBlank(priorityId)) {
            String priorityResult = updateSingleField(issueKey, 'priority', new Map<String, Object>{ 'id' => priorityId });
            if (!priorityResult.startsWith('SUCCESS')) {
                updateResults.add('Priority update failed: ' + priorityResult);
            }
        }
        
        // Try to update due date
        if (String.isNotBlank(dueDate)) {
            try {
                Date.valueOf(dueDate); // Validate date format
                String dueDateResult = updateSingleField(issueKey, 'duedate', dueDate);
                if (!dueDateResult.startsWith('SUCCESS')) {
                    updateResults.add('Due date update failed: ' + dueDateResult);
                }
            } catch (Exception e) {
                updateResults.add('Invalid due date format: ' + dueDate);
            }
        }
        
        // Try to update assignee
        if (String.isNotBlank(assigneeId)) {
            String assigneeResult = updateSingleField(issueKey, 'assignee', new Map<String, Object>{ 'id' => assigneeId });
            if (!assigneeResult.startsWith('SUCCESS')) {
                updateResults.add('Assignee update failed: ' + assigneeResult);
            }
        }
        
        // Log any update failures (but don't fail the main creation)
        if (!updateResults.isEmpty()) {
            System.debug('Some field updates failed for issue ' + issueKey + ': ' + String.join(updateResults, '; '));
        }
    }

    // Helper method: Transition issue to desired initial status after creation
    private static void transitionIssueToInitialStatus(String issueKey, String initialStatus) {
        if (String.isBlank(initialStatus) || initialStatus == 'to-do') {
            // Default status is usually "To Do" or similar, no need to transition
            return;
        }
        
        try {
            // Get available transitions for this issue
            List<StatusOption> transitions = getAvailableTransitions(issueKey);
            
            String targetStatusName = '';
            if (initialStatus == 'in-progress') {
                targetStatusName = 'In Progress';
            } else if (initialStatus == 'done') {
                targetStatusName = 'Done';
            }
            
            if (String.isNotBlank(targetStatusName)) {
                // Find the transition that leads to the target status
                for (StatusOption transition : transitions) {
                    if (transition.label.equalsIgnoreCase(targetStatusName)) {
                        // Attempt the transition
                        String transitionResult = updateJiraIssueStatus(issueKey, transition.transitionId);
                        if (transitionResult == 'SUCCESS') {
                            System.debug('Successfully transitioned ' + issueKey + ' to ' + targetStatusName);
                        } else {
                            System.debug('Failed to transition ' + issueKey + ' to ' + targetStatusName + ': ' + transitionResult);
                        }
                        break;
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Exception during status transition for ' + issueKey + ': ' + e.getMessage());
            // Don't fail the creation for transition issues
        }
    }

    // Helper method: Update a single field on an existing issue
    private static String updateSingleField(String issueKey, String fieldName, Object fieldValue) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();

        request.setEndpoint('callout:Jira_Integration/rest/api/latest/issue/' + issueKey);
        request.setMethod('PUT');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');

        Map<String, Object> fields = new Map<String, Object>();
        fields.put(fieldName, fieldValue);
        
        Map<String, Object> updateBody = new Map<String, Object>{
            'fields' => fields
        };
        
        request.setBody(JSON.serialize(updateBody));

        try {
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 204) {
                return 'SUCCESS: ' + fieldName + ' updated';
            } else {
                String errorMsg = parseJiraError(response);
                System.debug('Failed to update ' + fieldName + ' for ' + issueKey + ': ' + errorMsg);
                return 'ERROR: ' + errorMsg;
            }
        } catch (Exception e) {
            System.debug('Exception updating ' + fieldName + ': ' + e.getMessage());
            return 'ERROR: ' + e.getMessage();
        }
    }

    // Debug method to check current user and assignees
    @AuraEnabled
    public static String debugCurrentUser() {
        try {
            String currentUser = getCurrentJiraUser();
            System.debug('Current Jira User ID: ' + currentUser);
            return 'Current User: ' + currentUser;
        } catch (Exception e) {
            return 'Error getting current user: ' + e.getMessage();
        }
    }
    private static String parseJiraError(HttpResponse response) {
        String errorMessage = 'Failed to process request';
        try {
            Map<String, Object> errorResponse = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            if (errorResponse.containsKey('errors')) {
                Map<String, Object> errors = (Map<String, Object>) errorResponse.get('errors');
                List<String> errorMessages = new List<String>();
                for (String field : errors.keySet()) {
                    errorMessages.add(field + ': ' + errors.get(field));
                }
                errorMessage = String.join(errorMessages, ', ');
            } else if (errorResponse.containsKey('errorMessages')) {
                List<Object> errorMessages = (List<Object>) errorResponse.get('errorMessages');
                if (errorMessages != null && !errorMessages.isEmpty()) {
                    errorMessage = String.valueOf(errorMessages[0]);
                }
            }
        } catch (Exception parseEx) {
            System.debug('Could not parse error response: ' + parseEx.getMessage());
            errorMessage = 'HTTP ' + response.getStatusCode() + ': ' + response.getStatus();
        }
        return errorMessage;
    }

    // Get available status transitions for a specific issue
    @AuraEnabled
    public static List<StatusOption> getAvailableTransitions(String issueKey) {
        List<StatusOption> transitions = new List<StatusOption>();
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
                        
                        transitions.add(new StatusOption(statusName, statusId, transitionId));
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

    // Update issue status in Jira - SIMPLE & FAST
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
                throw new AuraHandledException('Failed to update issue status in Jira. Status: ' + response.getStatusCode() + '. Response: ' + response.getBody());
            }
        } catch (Exception e) {
            System.debug('Exception updating issue status: ' + e.getMessage());
            throw new AuraHandledException('System error updating issue status: ' + e.getMessage());
        }
    }
    
    // SEPARATE SYNC METHOD - Called only when needed, doesn't interfere with UI
    @AuraEnabled
    public static String syncJiraData() {
        try {
            List<JiraIssue> issues = getJiraIssuesForCurrentUser();
            if (!issues.isEmpty()) {
                JiraSyncService.syncJiraIssuesToCustomObject(issues);
            }
            return 'SUCCESS: Synced ' + issues.size() + ' issues';
        } catch (Exception e) {
            System.debug('Sync error: ' + e.getMessage());
            throw new AuraHandledException('Sync failed: ' + e.getMessage());
        }
    }
}