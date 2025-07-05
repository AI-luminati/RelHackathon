// File: AgentforceTaskSummary.cls - Get user task summary breakdown
public with sharing class AgentforceTaskSummary {
    
    // Method: Get all user tasks with status breakdown
    @InvocableMethod(label='Get User Task Summary' description='Returns summary of all user tasks by status')
    public static List<TaskSummaryResponse> getUserTaskSummary(List<TaskSummaryRequest> requests) {
        List<TaskSummaryResponse> responses = new List<TaskSummaryResponse>();
        
        for (TaskSummaryRequest request : requests) {
            TaskSummaryResponse response = new TaskSummaryResponse();
            
            try {
                String userId = String.isNotBlank(request.userId) ? request.userId : UserInfo.getUserId();
                
                // Get counts by status category
                Map<String, Integer> statusCounts = new Map<String, Integer>{
                    'Open' => 0,
                    'In Progress' => 0,
                    'Done' => 0
                };
                
                List<AggregateResult> results = [
                    SELECT Status_Category__c, COUNT(Id) taskCount
                    FROM Jira_Issue__c 
                    WHERE User_ID__c = :userId
                    GROUP BY Status_Category__c
                ];
                
                for (AggregateResult result : results) {
                    String statusCategory = (String) result.get('Status_Category__c');
                    Integer count = (Integer) result.get('taskCount');
                    if (statusCounts.containsKey(statusCategory)) {
                        statusCounts.put(statusCategory, count);
                    }
                }
                
                response.openTasks = statusCounts.get('Open');
                response.inProgressTasks = statusCounts.get('In Progress');
                response.doneTasks = statusCounts.get('Done');
                response.totalTasks = response.openTasks + response.inProgressTasks + response.doneTasks;
                
                // Format summary message
                String summary = 'Your task summary:\n';
                summary += '📋 Open: ' + response.openTasks + '\n';
                summary += '🔄 In Progress: ' + response.inProgressTasks + '\n';
                summary += '✅ Done: ' + response.doneTasks + '\n';
                summary += '📊 Total: ' + response.totalTasks;
                
                response.formattedSummary = summary;
                response.success = true;
                
            } catch (Exception e) {
                response.success = false;
                response.errorMessage = 'Error retrieving task summary: ' + e.getMessage();
                response.formattedSummary = 'Sorry, I couldn\'t get your task summary right now. Please try again.';
                System.debug('Error in getUserTaskSummary: ' + e.getMessage());
            }
            
            responses.add(response);
        }
        
        return responses;
    }
    
    // Input class for the invocable method
    public class TaskSummaryRequest {
        @InvocableVariable(label='User ID' description='Salesforce User ID (optional - defaults to current user)')
        public String userId;
    }
    
    // Response class for task summary
    public class TaskSummaryResponse {
        @InvocableVariable(label='Success' description='Whether the operation was successful')
        public Boolean success;
        
        @InvocableVariable(label='Open Tasks' description='Number of open tasks')
        public Integer openTasks;
        
        @InvocableVariable(label='In Progress Tasks' description='Number of in progress tasks')
        public Integer inProgressTasks;
        
        @InvocableVariable(label='Done Tasks' description='Number of completed tasks')
        public Integer doneTasks;
        
        @InvocableVariable(label='Total Tasks' description='Total number of tasks')
        public Integer totalTasks;
        
        @InvocableVariable(label='Formatted Summary' description='Ready-to-display summary message')
        public String formattedSummary;
        
        @InvocableVariable(label='Error Message' description='Error details if operation failed')
        public String errorMessage;
    }
}