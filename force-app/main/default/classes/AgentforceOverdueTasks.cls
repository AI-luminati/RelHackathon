// File: AgentforceOverdueTasks.cls - Get user's overdue tasks with urgency indicators
public with sharing class AgentforceOverdueTasks {
    
    // Method to get user's overdue tasks
    @InvocableMethod(label='Get User Overdue Tasks' description='Returns tasks that are past due date with urgency indicators')
    public static List<OverdueTasksResponse> getUserOverdueTasks(List<OverdueTasksRequest> requests) {
        List<OverdueTasksResponse> responses = new List<OverdueTasksResponse>();
        
        for (OverdueTasksRequest request : requests) {
            OverdueTasksResponse response = new OverdueTasksResponse();
            
            try {
                // Get user ID - use current user if not specified
                String userId = String.isNotBlank(request.userId) ? request.userId : UserInfo.getUserId();
                
                // Query overdue tasks (not completed and past due date)
                List<Jira_Issue__c> overdueTasks = [
                    SELECT Id, Issue_Key__c, Summary__c, Priority__c, Status__c, 
                           Project_Key__c, Assignee__c, Due_Date__c, Is_Overdue__c,
                           Jira_Link__c, Last_Synced__c, Status_Category__c
                    FROM Jira_Issue__c 
                    WHERE User_ID__c = :userId 
                    AND Is_Overdue__c = true
                    AND Status_Category__c != 'Done'
                    AND Due_Date__c != null
                    ORDER BY Due_Date__c ASC, Priority__c DESC
                    LIMIT 50
                ];
                
                // Build response with urgency calculation
                response.taskCount = overdueTasks.size();
                response.tasks = new List<OverdueTaskSummary>();
                
                Date today = Date.today();
                Integer criticalCount = 0;
                Integer highUrgencyCount = 0;
                Integer mediumUrgencyCount = 0;
                
                for (Jira_Issue__c task : overdueTasks) {
                    OverdueTaskSummary taskSummary = new OverdueTaskSummary();
                    taskSummary.issueKey = task.Issue_Key__c;
                    taskSummary.summary = task.Summary__c;
                    taskSummary.priority = task.Priority__c;
                    taskSummary.status = task.Status__c;
                    taskSummary.project = task.Project_Key__c;
                    taskSummary.assignee = task.Assignee__c;
                    taskSummary.dueDate = task.Due_Date__c;
                    taskSummary.jiraLink = task.Jira_Link__c;
                    
                    // Calculate days overdue and urgency
                    Integer daysOverdue = today.daysBetween(task.Due_Date__c) * -1; // Make positive
                    taskSummary.daysOverdue = daysOverdue;
                    
                    // Determine urgency level
                    if (daysOverdue >= 7) {
                        taskSummary.urgencyLevel = 'CRITICAL';
                        taskSummary.urgencyEmoji = '🚨';
                        criticalCount++;
                    } else if (daysOverdue >= 3) {
                        taskSummary.urgencyLevel = 'HIGH';
                        taskSummary.urgencyEmoji = '⚠️';
                        highUrgencyCount++;
                    } else {
                        taskSummary.urgencyLevel = 'MEDIUM';
                        taskSummary.urgencyEmoji = '⏰';
                        mediumUrgencyCount++;
                    }
                    
                    // Create overdue message
                    if (daysOverdue == 1) {
                        taskSummary.overdueMessage = '1 day overdue';
                    } else {
                        taskSummary.overdueMessage = daysOverdue + ' days overdue';
                    }
                    
                    response.tasks.add(taskSummary);
                }
                
                // Set urgency counts
                response.criticalCount = criticalCount;
                response.highUrgencyCount = highUrgencyCount;
                response.mediumUrgencyCount = mediumUrgencyCount;
                
                // Generate formatted message
                response.formattedMessage = formatOverdueTasksMessage(response);
                response.success = true;
                
            } catch (Exception e) {
                response.success = false;
                response.errorMessage = 'Error retrieving overdue tasks: ' + e.getMessage();
                response.formattedMessage = 'Sorry, I couldn\'t retrieve your overdue tasks right now. Please try again.';
                System.debug('Error in getUserOverdueTasks: ' + e.getMessage());
            }
            
            responses.add(response);
        }
        
        return responses;
    }
    
    // Helper method to format the overdue tasks message with urgency indicators
    private static String formatOverdueTasksMessage(OverdueTasksResponse response) {
        if (response.taskCount == 0) {
            return '🎉 Excellent! You don\'t have any overdue tasks. Keep up the great work!';
        }
        
        String message = '';
        
        // Add urgency summary header
        if (response.criticalCount > 0) {
            message += '🚨 URGENT: You have ' + response.taskCount + ' overdue task' + (response.taskCount > 1 ? 's' : '') + ' requiring immediate attention!\n\n';
        } else if (response.highUrgencyCount > 0) {
            message += '⚠️ ATTENTION: You have ' + response.taskCount + ' overdue task' + (response.taskCount > 1 ? 's' : '') + ' that need priority focus.\n\n';
        } else {
            message += '⏰ You have ' + response.taskCount + ' overdue task' + (response.taskCount > 1 ? 's' : '') + ':\n\n';
        }
        
        // Group tasks by urgency for better organization
        List<OverdueTaskSummary> criticalTasks = new List<OverdueTaskSummary>();
        List<OverdueTaskSummary> highTasks = new List<OverdueTaskSummary>();
        List<OverdueTaskSummary> mediumTasks = new List<OverdueTaskSummary>();
        
        for (OverdueTaskSummary task : response.tasks) {
            if (task.urgencyLevel == 'CRITICAL') {
                criticalTasks.add(task);
            } else if (task.urgencyLevel == 'HIGH') {
                highTasks.add(task);
            } else {
                mediumTasks.add(task);
            }
        }
        
        // Display critical tasks first
        if (!criticalTasks.isEmpty()) {
            message += formatTaskGroup(criticalTasks);
            if (!highTasks.isEmpty() || !mediumTasks.isEmpty()) {
                message += '\n';
            }
        }
        
        // Display high urgency tasks  
        if (!highTasks.isEmpty()) {
            message += formatTaskGroup(highTasks);
            if (!mediumTasks.isEmpty()) {
                message += '\n';
            }
        }
        
        // Display medium urgency tasks
        if (!mediumTasks.isEmpty()) {
            message += formatTaskGroup(mediumTasks);
        }
        
        // Add action recommendation
        message += '\n\n💡 Recommendation: ';
        if (response.criticalCount > 0) {
            message += 'Focus on critical tasks first. Consider updating stakeholders on delays.';
        } else if (response.highUrgencyCount > 0) {
            message += 'Prioritize these tasks today to prevent further delays.';
        } else {
            message += 'These tasks need attention soon. Plan to complete them today if possible.';
        }
        
        return message.trim();
    }
    
    // Helper method to format a group of tasks - IMPROVED FORMATTING
    private static String formatTaskGroup(List<OverdueTaskSummary> tasks) {
        String groupMessage = '';
        
        for (Integer i = 0; i < tasks.size(); i++) {
            OverdueTaskSummary task = tasks[i];
            
            // Task header with emoji and basic info
            groupMessage += task.urgencyEmoji + ' ' + task.issueKey + ': ' + task.summary + ' (Priority: ' + 
                           (String.isNotBlank(task.priority) ? task.priority : 'MEDIUM') + ')\n';
            
            // Task details with nice spacing
            groupMessage += '  • Status: ' + task.status + '\n';
            groupMessage += '  • Project: ' + task.project + '\n';
            groupMessage += '  • Due: ' + task.dueDate.format() + ' (' + task.overdueMessage + ')\n';
            
            // Add spacing between tasks (except last one)
            if (i < tasks.size() - 1) {
                groupMessage += '\n';
            }
        }
        
        return groupMessage;
    }
    
    // Input class for the invocable method
    public class OverdueTasksRequest {
        @InvocableVariable(label='User ID' description='Salesforce User ID (optional - defaults to current user)')
        public String userId;
    }
    
    // Output class for the invocable method
    public class OverdueTasksResponse {
        @InvocableVariable(label='Success' description='Whether the operation was successful')
        public Boolean success;
        
        @InvocableVariable(label='Task Count' description='Total number of overdue tasks')
        public Integer taskCount;
        
        @InvocableVariable(label='Critical Count' description='Number of critically overdue tasks (7+ days)')
        public Integer criticalCount;
        
        @InvocableVariable(label='High Urgency Count' description='Number of high urgency tasks (3-6 days)')
        public Integer highUrgencyCount;
        
        @InvocableVariable(label='Medium Urgency Count' description='Number of medium urgency tasks (1-2 days)')
        public Integer mediumUrgencyCount;
        
        @InvocableVariable(label='Formatted Message' description='Ready-to-display message for the user')
        public String formattedMessage;
        
        @InvocableVariable(label='Error Message' description='Error details if operation failed')
        public String errorMessage;
        
        @InvocableVariable(label='Tasks' description='List of overdue task details')
        public List<OverdueTaskSummary> tasks;
    }
    
    // Overdue task summary class with urgency indicators
    public class OverdueTaskSummary {
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
        
        @InvocableVariable(label='Due Date' description='When task was due')
        public Date dueDate;
        
        @InvocableVariable(label='Days Overdue' description='Number of days past due')
        public Integer daysOverdue;
        
        @InvocableVariable(label='Urgency Level' description='CRITICAL, HIGH, or MEDIUM urgency')
        public String urgencyLevel;
        
        @InvocableVariable(label='Urgency Emoji' description='Emoji indicating urgency level')
        public String urgencyEmoji;
        
        @InvocableVariable(label='Overdue Message' description='Human-readable overdue duration')
        public String overdueMessage;
        
        @InvocableVariable(label='Jira Link' description='Link to Jira issue')
        public String jiraLink;
    }
}