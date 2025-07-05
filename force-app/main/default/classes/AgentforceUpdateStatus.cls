// File: AgentforceUpdateStatus.cls - Update Jira task status via conversation
public with sharing class AgentforceUpdateStatus {
    
    // Method to update task status
    @InvocableMethod(label='Update Task Status' description='Updates a Jira task status and syncs the changes')
    public static List<UpdateStatusResponse> updateTaskStatus(List<UpdateStatusRequest> requests) {
        List<UpdateStatusResponse> responses = new List<UpdateStatusResponse>();
        
        for (UpdateStatusRequest request : requests) {
            UpdateStatusResponse response = new UpdateStatusResponse();
            
            try {
                // Validate required inputs
                if (String.isBlank(request.issueKey)) {
                    response.success = false;
                    response.errorMessage = 'Issue key is required (e.g., SCRUM-2)';
                    response.formattedMessage = 'Please provide the task key (like SCRUM-2) that you want to update.';
                    responses.add(response);
                    continue;
                }
                
                if (String.isBlank(request.newStatus)) {
                    response.success = false;
                    response.errorMessage = 'New status is required';
                    response.formattedMessage = 'Please specify what status you want to change ' + request.issueKey + ' to (like "Done", "In Progress", or "To Do").';
                    responses.add(response);
                    continue;
                }
                
                // Clean up inputs
                String issueKey = request.issueKey.trim().toUpperCase();
                String newStatus = request.newStatus.trim();
                String userId = String.isNotBlank(request.userId) ? request.userId : UserInfo.getUserId();
                
                // First, verify the task exists and belongs to user
                List<Jira_Issue__c> existingTasks = [
                    SELECT Id, Issue_Key__c, Summary__c, Status__c, Project_Key__c, Status_ID__c
                    FROM Jira_Issue__c 
                    WHERE Issue_Key__c = :issueKey 
                    AND User_ID__c = :userId 
                    LIMIT 1
                ];
                
                if (existingTasks.isEmpty()) {
                    response.success = false;
                    response.errorMessage = 'Task not found: ' + issueKey;
                    response.formattedMessage = 'I couldn\'t find task ' + issueKey + ' in your assigned tasks. Please check the task key and try again.';
                    responses.add(response);
                    continue;
                }
                
                Jira_Issue__c currentTask = existingTasks[0];
                String oldStatus = currentTask.Status__c;
                
                // Check if already in the target status
                if (oldStatus.equalsIgnoreCase(newStatus)) {
                    response.success = true;
                    response.issueKey = issueKey;
                    response.oldStatus = oldStatus;
                    response.newStatus = newStatus;
                    response.formattedMessage = '✅ Task ' + issueKey + ' is already in "' + oldStatus + '" status.';
                    responses.add(response);
                    continue;
                }
                
                // Map user-friendly status names to Jira transitions
                String targetTransition = mapStatusToTransition(newStatus);
                if (String.isBlank(targetTransition)) {
                    response.success = false;
                    response.errorMessage = 'Invalid status: ' + newStatus;
                    response.formattedMessage = 'I don\'t recognize the status "' + newStatus + '". Try using "To Do", "In Progress", or "Done".';
                    responses.add(response);
                    continue;
                }
                
                // Get available transitions for this issue
                List<JiraController.StatusOption> availableTransitions = JiraController.getAvailableTransitions(issueKey);
                String transitionId = null;
                
                // Find the transition that matches our target
                for (JiraController.StatusOption transition : availableTransitions) {
                    if (transition.label.equalsIgnoreCase(targetTransition) || 
                        transition.label.equalsIgnoreCase(newStatus)) {
                        transitionId = transition.transitionId;
                        break;
                    }
                }
                
                if (String.isBlank(transitionId)) {
                    // Try to find partial matches
                    for (JiraController.StatusOption transition : availableTransitions) {
                        if (transition.label.toLowerCase().contains(targetTransition.toLowerCase()) ||
                            targetTransition.toLowerCase().contains(transition.label.toLowerCase())) {
                            transitionId = transition.transitionId;
                            break;
                        }
                    }
                }
                
                if (String.isBlank(transitionId)) {
                    response.success = false;
                    response.errorMessage = 'Status transition not available';
                    String availableStatuses = '';
                    for (JiraController.StatusOption transition : availableTransitions) {
                        availableStatuses += '"' + transition.label + '", ';
                    }
                    if (availableStatuses.length() > 2) {
                        availableStatuses = availableStatuses.substring(0, availableStatuses.length() - 2);
                    }
                    response.formattedMessage = 'Cannot move ' + issueKey + ' to "' + newStatus + '". Available statuses: ' + availableStatuses + '.';
                    responses.add(response);
                    continue;
                }
                
                // Perform the status update in Jira
                String updateResult = JiraController.updateJiraIssueStatus(issueKey, transitionId);
                
                if (updateResult == 'SUCCESS') {
                    // Update was successful
                    response.success = true;
                    response.issueKey = issueKey;
                    response.taskSummary = currentTask.Summary__c;
                    response.oldStatus = oldStatus;
                    response.newStatus = targetTransition;
                    response.projectKey = currentTask.Project_Key__c;
                    
                    // Generate success message
                    String statusEmoji = getStatusEmoji(targetTransition);
                    response.formattedMessage = statusEmoji + ' Successfully updated ' + issueKey + ': ' + currentTask.Summary__c + '\n';
                    response.formattedMessage += '  Status changed from "' + oldStatus + '" to "' + targetTransition + '"\n';
                    response.formattedMessage += '  Project: ' + currentTask.Project_Key__c;
                    
                    // Trigger background sync to update local data
                    try {
                        JiraController.syncJiraData();
                    } catch (Exception syncEx) {
                        System.debug('Background sync failed after status update: ' + syncEx.getMessage());
                    }
                    
                } else {
                    // Update failed
                    response.success = false;
                    response.errorMessage = 'Jira update failed: ' + updateResult;
                    response.formattedMessage = 'Sorry, I couldn\'t update ' + issueKey + ' in Jira. Please try again or update it manually in Jira.';
                }
                
            } catch (Exception e) {
                response.success = false;
                response.errorMessage = 'Error updating task status: ' + e.getMessage();
                response.formattedMessage = 'Sorry, I encountered an error while updating the task. Please try again.';
                System.debug('Error in updateTaskStatus: ' + e.getMessage() + '. Stack: ' + e.getStackTraceString());
            }
            
            responses.add(response);
        }
        
        return responses;
    }
    
    // Helper method to map user-friendly status names to Jira transition names
    private static String mapStatusToTransition(String userStatus) {
        String status = userStatus.toLowerCase().trim();
        
        // Done/Complete statuses
        if (status.contains('done') || status.contains('complete') || status.contains('finish') || 
            status.contains('close') || status.contains('resolve')) {
            return 'Done';
        }
        
        // In Progress statuses
        if (status.contains('progress') || status.contains('start') || status.contains('working') || 
            status.contains('active') || status.contains('begin')) {
            return 'In Progress';
        }
        
        // Open/To Do statuses
        if (status.contains('open') || status.contains('todo') || status.contains('to do') || 
            status.contains('backlog') || status.contains('ready')) {
            return 'To Do';
        }
        
        // Exact matches
        if (status == 'done') return 'Done';
        if (status == 'in progress') return 'In Progress';
        if (status == 'to do') return 'To Do';
        
        return null; // Unrecognized status
    }
    
    // Helper method to get appropriate emoji for status
    private static String getStatusEmoji(String status) {
        if (status.toLowerCase().contains('done') || status.toLowerCase().contains('complete')) {
            return '✅';
        }
        if (status.toLowerCase().contains('progress')) {
            return '🔄';
        }
        if (status.toLowerCase().contains('open') || status.toLowerCase().contains('to do')) {
            return '📋';
        }
        return '🔄'; // Default
    }
    
    // Input class for the invocable method
    public class UpdateStatusRequest {
        @InvocableVariable(label='Issue Key' description='Jira issue key (e.g., SCRUM-2)' required=true)
        public String issueKey;
        
        @InvocableVariable(label='New Status' description='Target status (e.g., Done, In Progress, To Do)' required=true)
        public String newStatus;
        
        @InvocableVariable(label='User ID' description='Salesforce User ID (optional - defaults to current user)')
        public String userId;
    }
    
    // Output class for the invocable method
    public class UpdateStatusResponse {
        @InvocableVariable(label='Success' description='Whether the update was successful')
        public Boolean success;
        
        @InvocableVariable(label='Issue Key' description='The updated issue key')
        public String issueKey;
        
        @InvocableVariable(label='Task Summary' description='Summary/title of the updated task')
        public String taskSummary;
        
        @InvocableVariable(label='Old Status' description='Previous status of the task')
        public String oldStatus;
        
        @InvocableVariable(label='New Status' description='New status of the task')
        public String newStatus;
        
        @InvocableVariable(label='Project Key' description='Project the task belongs to')
        public String projectKey;
        
        @InvocableVariable(label='Formatted Message' description='Ready-to-display success/error message')
        public String formattedMessage;
        
        @InvocableVariable(label='Error Message' description='Technical error details if update failed')
        public String errorMessage;
    }
}