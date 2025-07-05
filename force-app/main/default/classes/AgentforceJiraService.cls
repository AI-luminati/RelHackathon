// File: AgentforceJiraService.cls - Get user tasks in progress
public with sharing class AgentforceJiraService {
    
    // Method to get user's current tasks in progress
    @InvocableMethod(label='Get User Tasks In Progress' description='Returns tasks currently in progress for the user')
    public static List<TaskProgressResponse> getUserTasksInProgress(List<TaskProgressRequest> requests) {
        List<TaskProgressResponse> responses = new List<TaskProgressResponse>();
        
        for (TaskProgressRequest request : requests) {
            TaskProgressResponse response = new TaskProgressResponse();
            
            try {
                // Get user ID - use current user if not specified
                String userId = String.isNotBlank(request.userId) ? request.userId : UserInfo.getUserId();
                
                // Query tasks in progress
                List<Jira_Issue__c> inProgressTasks = [
                    SELECT Id, Issue_Key__c, Summary__c, Priority__c, Status__c, 
                           Project_Key__c, Assignee__c, Due_Date__c, Is_Overdue__c,
                           Jira_Link__c, Last_Synced__c
                    FROM Jira_Issue__c 
                    WHERE User_ID__c = :userId 
                    AND Status_Category__c = 'In Progress'
                    ORDER BY Priority__c DESC, Issue_Key__c ASC
                    LIMIT 50
                ];
                
                // Build response
                response.taskCount = inProgressTasks.size();
                response.tasks = new List<TaskSummary>();
                
                for (Jira_Issue__c task : inProgressTasks) {
                    TaskSummary taskSummary = new TaskSummary();
                    taskSummary.issueKey = task.Issue_Key__c;
                    taskSummary.summary = task.Summary__c;
                    taskSummary.priority = task.Priority__c;
                    taskSummary.status = task.Status__c;
                    taskSummary.project = task.Project_Key__c;
                    taskSummary.assignee = task.Assignee__c;
                    taskSummary.isOverdue = task.Is_Overdue__c;
                    taskSummary.dueDate = task.Due_Date__c;
                    taskSummary.jiraLink = task.Jira_Link__c;
                    
                    response.tasks.add(taskSummary);
                }
                
                // Generate formatted message
                response.formattedMessage = formatTasksMessage(response.taskCount, response.tasks);
                response.success = true;
                
            } catch (Exception e) {
                response.success = false;
                response.errorMessage = 'Error retrieving tasks: ' + e.getMessage();
                response.formattedMessage = 'Sorry, I couldn\'t retrieve your tasks right now. Please try again.';
                System.debug('Error in getUserTasksInProgress: ' + e.getMessage());
            }
            
            responses.add(response);
        }
        
        return responses;
    }
    
    // Helper method to format the message for Agentforce - GROUPED TASKS WITH SPACING
    private static String formatTasksMessage(Integer taskCount, List<TaskSummary> tasks) {
        if (taskCount == 0) {
            return 'Great! You don\'t have any tasks in progress right now. Ready to start something new? 🚀';
        }
        
        String message = 'You have ' + taskCount + ' task' + (taskCount > 1 ? 's' : '') + ' in progress:\n';
        
        for (Integer i = 0; i < tasks.size(); i++) {
            TaskSummary task = tasks[i];
            
            // Task header
            message += '▶ ' + task.issueKey + ': ' + task.summary + ' (Priority: ' + (String.isNotBlank(task.priority) ? task.priority : 'MEDIUM') + ')\n';
            
            // Task details indented
            message += '  • Status: ' + task.status + '\n';
            
            if (String.isNotBlank(task.project)) {
                message += '  • Project: ' + task.project + '\n';
            }
            
            if (task.isOverdue == true) {
                message += '  • ⚠️ OVERDUE\n';
            } else if (task.dueDate != null) {
                message += '  • Due: ' + task.dueDate.format() + '\n';
            }
            
            // Add blank line between tasks (except for the last one)
            if (i < tasks.size() - 1) {
                message += '\n';
            }
        }
        
        return message.trim();
    }
    
    // Input class for the invocable method
    public class TaskProgressRequest {
        @InvocableVariable(label='User ID' description='Salesforce User ID (optional - defaults to current user)')
        public String userId;
    }
    
    // Output class for the invocable method
    public class TaskProgressResponse {
        @InvocableVariable(label='Success' description='Whether the operation was successful')
        public Boolean success;
        
        @InvocableVariable(label='Task Count' description='Number of tasks in progress')
        public Integer taskCount;
        
        @InvocableVariable(label='Formatted Message' description='Ready-to-display message for the user')
        public String formattedMessage;
        
        @InvocableVariable(label='Error Message' description='Error details if operation failed')
        public String errorMessage;
        
        @InvocableVariable(label='Tasks' description='List of task details')
        public List<TaskSummary> tasks;
    }
    
    // Task summary class
    public class TaskSummary {
        @InvocableVariable(label='Issue Key' description='Jira issue key (e.g., SCRUM-2)')
        public String issueKey;
        
        @InvocableVariable(label='Summary' description='Task summary/title')
        public String summary;
        
        @InvocableVariable(label='Priority' description='Task priority')
        public String priority;
        
        @InvocableVariable(label='Status' description='Current status')
        public String status;
        
        @InvocableVariable(label='Project' description='Project key')
        public String project;
        
        @InvocableVariable(label='Assignee' description='Person assigned to task')
        public String assignee;
        
        @InvocableVariable(label='Is Overdue' description='Whether task is overdue')
        public Boolean isOverdue;
        
        @InvocableVariable(label='Due Date' description='When task is due')
        public Date dueDate;
        
        @InvocableVariable(label='Jira Link' description='Link to Jira issue')
        public String jiraLink;
    }
}