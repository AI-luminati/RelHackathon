// File: AgentforceCreateTask.cls - Create new Jira tasks via conversation
public with sharing class AgentforceCreateTask {
    
    // Method to create a new Jira task
    @InvocableMethod(label='Create New Jira Task' description='Creates a new Jira task from conversational input')
    public static List<CreateTaskResponse> createNewTask(List<CreateTaskRequest> requests) {
        List<CreateTaskResponse> responses = new List<CreateTaskResponse>();
        
        for (CreateTaskRequest request : requests) {
            CreateTaskResponse response = new CreateTaskResponse();
            
            try {
                // Validate required inputs
                if (String.isBlank(request.taskSummary)) {
                    response.success = false;
                    response.errorMessage = 'Task summary is required';
                    response.formattedMessage = 'Please provide a summary for the task you want to create (e.g., "Fix user login bug").';
                    responses.add(response);
                    continue;
                }
                
                // Set defaults for optional fields
                String projectKey = String.isNotBlank(request.projectKey) ? request.projectKey : getDefaultProject();
                String issueType = String.isNotBlank(request.issueType) ? request.issueType : 'Task';
                String priority = String.isNotBlank(request.priority) ? request.priority : 'Medium';
                String initialStatus = String.isNotBlank(request.initialStatus) ? request.initialStatus : 'to-do';
                
                // Parse and validate due date
                String dueDateFormatted = null;
                if (String.isNotBlank(request.dueDate)) {
                    dueDateFormatted = parseDueDateFromInput(request.dueDate);
                    if (String.isBlank(dueDateFormatted)) {
                        response.success = false;
                        response.errorMessage = 'Invalid due date format';
                        response.formattedMessage = 'Please provide the due date in format YYYY-MM-DD (e.g., 2025-06-15) or use phrases like "tomorrow", "next week", "in 3 days".';
                        responses.add(response);
                        continue;
                    }
                }
                
                // If no project specified, try to get user's most common project
                if (String.isBlank(projectKey)) {
                    projectKey = getUsersMainProject();
                }
                
                if (String.isBlank(projectKey)) {
                    response.success = false;
                    response.errorMessage = 'No project specified and no default project found';
                    response.formattedMessage = 'Please specify which project to create the task in (e.g., "Create a task in SCRUM project for user login bug").';
                    responses.add(response);
                    continue;
                }
                
                // Clean up the task summary
                String cleanSummary = cleanTaskSummary(request.taskSummary);
                
                // Build issue data for creation
                Map<String, Object> issueData = new Map<String, Object>{
                    'projectKey' => projectKey,
                    'issueTypeId' => getIssueTypeId(projectKey, issueType),
                    'summary' => cleanSummary,
                    'description' => String.isNotBlank(request.description) ? request.description : '',
                    'priorityId' => getPriorityId(priority),
                    'initialStatus' => initialStatus,
                    'dueDate' => dueDateFormatted,
                    'assigneeId' => '' // Will assign to current user by default
                };
                
                // Validate we have required IDs
                if (String.isBlank((String)issueData.get('issueTypeId'))) {
                    response.success = false;
                    response.errorMessage = 'Invalid issue type: ' + issueType;
                    response.formattedMessage = 'I couldn\'t find the issue type "' + issueType + '". Try using "Task", "Bug", or "Story".';
                    responses.add(response);
                    continue;
                }
                
                // Create the issue using existing JiraController method
                String createResult = JiraController.createJiraIssue(JSON.serialize(issueData));
                
                if (createResult != null && createResult.startsWith('SUCCESS:')) {
                    // Extract issue key from success message
                    String issueKey = extractIssueKey(createResult);
                    
                    response.success = true;
                    response.issueKey = issueKey;
                    response.taskSummary = cleanSummary;
                    response.projectKey = projectKey;
                    response.priority = priority;
                    response.issueType = issueType;
                    response.status = mapInitialStatusToDisplay(initialStatus);
                    response.taskDueDate = dueDateFormatted; // Using taskDueDate to avoid conflicts
                    
                    // Generate success message
                    response.formattedMessage = formatSuccessMessage(response);
                    
                    // Trigger background sync to update local data
                    try {
                        JiraController.syncJiraData();
                    } catch (Exception syncEx) {
                        System.debug('Background sync failed after task creation: ' + syncEx.getMessage());
                    }
                    
                } else {
                    // Creation failed
                    response.success = false;
                    response.errorMessage = createResult != null ? createResult : 'Unknown error occurred';
                    response.formattedMessage = 'Sorry, I couldn\'t create the task. ' + parseCreateError(createResult);
                }
                
            } catch (Exception e) {
                response.success = false;
                response.errorMessage = 'Error creating task: ' + e.getMessage();
                response.formattedMessage = 'Sorry, I encountered an error while creating your task. Please try again.';
                System.debug('Error in createNewTask: ' + e.getMessage() + '. Stack: ' + e.getStackTraceString());
            }
            
            responses.add(response);
        }
        
        return responses;
    }
    
    // Helper method to parse due date from conversational input
    private static String parseDueDateFromInput(String dueDateInput) {
        if (String.isBlank(dueDateInput)) {
            return null;
        }
        
        String input = dueDateInput.trim().toLowerCase();
        Date today = Date.today();
        Date targetDate = null;
        
        try {
            // Handle relative dates
            if (input == 'today') {
                targetDate = today;
            } else if (input == 'tomorrow') {
                targetDate = today.addDays(1);
            } else if (input == 'next week' || input == 'in a week') {
                targetDate = today.addDays(7);
            } else if (input == 'next month' || input == 'in a month') {
                targetDate = today.addMonths(1);
            } else if (input.startsWith('in ') && input.endsWith(' days')) {
                // Parse "in X days"
                String numberPart = input.substring(3, input.length() - 5).trim();
                Integer days = Integer.valueOf(numberPart);
                targetDate = today.addDays(days);
            } else if (input.startsWith('in ') && input.endsWith(' weeks')) {
                // Parse "in X weeks"
                String numberPart = input.substring(3, input.length() - 6).trim();
                Integer weeks = Integer.valueOf(numberPart);
                targetDate = today.addDays(weeks * 7);
            } else if (input.startsWith('in ') && input.endsWith(' months')) {
                // Parse "in X months"
                String numberPart = input.substring(3, input.length() - 7).trim();
                Integer months = Integer.valueOf(numberPart);
                targetDate = today.addMonths(months);
            } else {
                // Try to parse as direct date format
                // Handle YYYY-MM-DD
                if (dueDateInput.contains('-') && dueDateInput.length() >= 8) {
                    targetDate = Date.valueOf(dueDateInput);
                }
                // Handle MM/DD/YYYY or M/D/YYYY
                else if (dueDateInput.contains('/')) {
                    String[] parts = dueDateInput.split('/');
                    if (parts.size() == 3) {
                        Integer month = Integer.valueOf(parts[0]);
                        Integer day = Integer.valueOf(parts[1]);
                        Integer year = Integer.valueOf(parts[2]);
                        targetDate = Date.newInstance(year, month, day);
                    }
                }
            }
            
            if (targetDate != null) {
                // Return in YYYY-MM-DD format for Jira
                return String.valueOf(targetDate.year()) + '-' + 
                       String.valueOf(targetDate.month()).leftPad(2, '0') + '-' + 
                       String.valueOf(targetDate.day()).leftPad(2, '0');
            }
            
        } catch (Exception e) {
            System.debug('Error parsing due date input: ' + dueDateInput + '. Error: ' + e.getMessage());
        }
        
        return null;
    }
    
    // Helper method to clean up task summary from conversational input
    private static String cleanTaskSummary(String rawSummary) {
        String cleaned = rawSummary.trim();
        
        // Remove common conversational prefixes
        if (cleaned.toLowerCase().startsWith('create a task for ')) {
            cleaned = cleaned.substring(18);
        } else if (cleaned.toLowerCase().startsWith('create task for ')) {
            cleaned = cleaned.substring(16);
        } else if (cleaned.toLowerCase().startsWith('new task for ')) {
            cleaned = cleaned.substring(13);
        } else if (cleaned.toLowerCase().startsWith('create ')) {
            cleaned = cleaned.substring(7);
        }
        
        // Capitalize first letter
        if (String.isNotBlank(cleaned)) {
            cleaned = cleaned.substring(0, 1).toUpperCase() + cleaned.substring(1);
        }
        
        return cleaned;
    }
    
    // Helper method to get default project (most commonly used)
    private static String getUsersMainProject() {
        try {
            List<AggregateResult> projectCounts = [
                SELECT Project_Key__c, COUNT(Id) taskCount
                FROM Jira_Issue__c 
                WHERE User_ID__c = :UserInfo.getUserId()
                AND Project_Key__c != null
                GROUP BY Project_Key__c 
                ORDER BY COUNT(Id) DESC 
                LIMIT 1
            ];
            
            if (!projectCounts.isEmpty()) {
                return (String) projectCounts[0].get('Project_Key__c');
            }
        } catch (Exception e) {
            System.debug('Error getting user main project: ' + e.getMessage());
        }
        return null;
    }
    
    // Helper method to get default project key
    private static String getDefaultProject() {
        // You can customize this to return your organization's default project
        return 'SCRUM'; // Change this to your default project key
    }
    
    // Helper method to get issue type ID
    private static String getIssueTypeId(String projectKey, String issueTypeName) {
        try {
            List<JiraController.JiraIssueType> issueTypes = JiraController.getJiraIssueTypes(projectKey);
            for (JiraController.JiraIssueType issueType : issueTypes) {
                if (issueType.name.equalsIgnoreCase(issueTypeName)) {
                    return issueType.id;
                }
            }
            
            // If exact match not found, try partial match
            for (JiraController.JiraIssueType issueType : issueTypes) {
                if (issueType.name.toLowerCase().contains(issueTypeName.toLowerCase())) {
                    return issueType.id;
                }
            }
            
            // Default to first available issue type
            if (!issueTypes.isEmpty()) {
                return issueTypes[0].id;
            }
        } catch (Exception e) {
            System.debug('Error getting issue type ID: ' + e.getMessage());
        }
        return null;
    }
    
    // Helper method to get priority ID
    private static String getPriorityId(String priorityName) {
        try {
            List<JiraController.JiraPriority> priorities = JiraController.getJiraPriorities();
            for (JiraController.JiraPriority priority : priorities) {
                if (priority.name.equalsIgnoreCase(priorityName)) {
                    return priority.id;
                }
            }
            
            // Default to Medium if available
            for (JiraController.JiraPriority priority : priorities) {
                if (priority.name.toLowerCase().contains('medium')) {
                    return priority.id;
                }
            }
        } catch (Exception e) {
            System.debug('Error getting priority ID: ' + e.getMessage());
        }
        return null;
    }
    
    // Helper method to extract issue key from success message
    private static String extractIssueKey(String successMessage) {
        try {
            // Pattern: "SUCCESS: Issue SCRUM-123 created successfully"
            String[] parts = successMessage.split(' ');
            for (String part : parts) {
                if (part.contains('-') && part.length() > 3) {
                    return part;
                }
            }
        } catch (Exception e) {
            System.debug('Error extracting issue key: ' + e.getMessage());
        }
        return 'New Task';
    }
    
    // Helper method to map initial status to display name
    private static String mapInitialStatusToDisplay(String initialStatus) {
        if (initialStatus == 'to-do') return 'To Do';
        if (initialStatus == 'in-progress') return 'In Progress';
        if (initialStatus == 'done') return 'Done';
        return 'To Do';
    }
    
    // Helper method to format success message
    private static String formatSuccessMessage(CreateTaskResponse response) {
        String message = '✅ Successfully created new task!\n\n';
        message += '🎫 ' + response.issueKey + ': ' + response.taskSummary + ' (Priority: ' + response.priority + ')\n';
        message += '  • Status: ' + response.status + '\n';
        message += '  • Project: ' + response.projectKey + '\n';
        message += '  • Type: ' + response.issueType + '\n';
        message += '  • Assigned to: You\n';
        
        // Add due date if specified
        if (String.isNotBlank(response.taskDueDate)) {
            try {
                Date dueDate = Date.valueOf(response.taskDueDate);
                message += '  • Due: ' + dueDate.format() + '\n';
            } catch (Exception e) {
                message += '  • Due: ' + response.taskDueDate + '\n';
            }
        }
        
        message += '\n💡 Your new task is ready to work on!';
        
        return message;
    }
    
    // Helper method to parse creation errors
    private static String parseCreateError(String errorResult) {
        if (String.isBlank(errorResult)) {
            return 'Please try again.';
        }
        
        if (errorResult.toLowerCase().contains('project')) {
            return 'Please specify a valid project name.';
        }
        
        if (errorResult.toLowerCase().contains('issue type')) {
            return 'Please specify a valid issue type like Task, Bug, or Story.';
        }
        
        return 'Please check your input and try again.';
    }
    
    // Input class for the invocable method
    public class CreateTaskRequest {
        @InvocableVariable(label='Task Summary' description='Summary/title of the task to create' required=true)
        public String taskSummary;
        
        @InvocableVariable(label='Project Key' description='Jira project key (optional - will use default)')
        public String projectKey;
        
        @InvocableVariable(label='Description' description='Detailed description of the task (optional)')
        public String description;
        
        @InvocableVariable(label='Issue Type' description='Type of issue: Task, Bug, Story (optional - defaults to Task)')
        public String issueType;
        
        @InvocableVariable(label='Priority' description='Priority: High, Medium, Low (optional - defaults to Medium)')
        public String priority;
        
        @InvocableVariable(label='Initial Status' description='Starting status: to-do, in-progress, done (optional - defaults to to-do)')
        public String initialStatus;
        
        @InvocableVariable(label='Due Date' description='Due date: YYYY-MM-DD, "tomorrow", "next week", "in 3 days", etc. (optional)')
        public String dueDate;
    }
    
    // Output class for the invocable method
    public class CreateTaskResponse {
        @InvocableVariable(label='Success' description='Whether the task was created successfully')
        public Boolean success;
        
        @InvocableVariable(label='Issue Key' description='The created task key (e.g., SCRUM-123)')
        public String issueKey;
        
        @InvocableVariable(label='Task Summary' description='Summary/title of the created task')
        public String taskSummary;
        
        @InvocableVariable(label='Project Key' description='Project the task was created in')
        public String projectKey;
        
        @InvocableVariable(label='Priority' description='Priority of the created task')
        public String priority;
        
        @InvocableVariable(label='Issue Type' description='Type of the created issue')
        public String issueType;
        
        @InvocableVariable(label='Status' description='Initial status of the created task')
        public String status;
        
        @InvocableVariable(label='Task Due Date' description='Due date that was set for the task')
        public String taskDueDate;
        
        @InvocableVariable(label='Formatted Message' description='Ready-to-display success/error message')
        public String formattedMessage;
        
        @InvocableVariable(label='Error Message' description='Technical error details if creation failed')
        public String errorMessage;
    }
}