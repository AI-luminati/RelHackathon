/**
 * REST endpoint to handle Jira webhooks for real-time sync
 * Configure this endpoint in your Jira webhook settings
 */
@RestResource(urlMapping='/jira/webhook/*')
global with sharing class JiraWebhookHandler {
    
    @HttpPost
    global static void handleWebhook() {
        RestRequest request = RestContext.request;
        RestResponse response = RestContext.response;
        
        try {
            String requestBody = request.requestBody.toString();
            System.debug('Jira Webhook received: ' + requestBody);
            
            Map<String, Object> webhookData = (Map<String, Object>) JSON.deserializeUntyped(requestBody);
            
            // Get webhook event type
            String webhookEvent = (String) webhookData.get('webhookEvent');
            
            if (isRelevantEvent(webhookEvent)) {
                // Extract issue information
                Map<String, Object> issue = (Map<String, Object>) webhookData.get('issue');
                if (issue != null) {
                    String issueKey = (String) issue.get('key');
                    
                    if (String.isNotBlank(issueKey)) {
                        // Handle different event types
                        if (webhookEvent == 'jira:issue_deleted') {
                            // Handle deletion
                            JiraSyncService.deleteJiraIssue(issueKey);
                        } else {
                            // Handle create/update
                            JiraSyncService.handleJiraWebhookUpdate(issueKey);
                        }
                        
                        response.statusCode = 200;
                        response.responseBody = Blob.valueOf('{"status": "success", "message": "Webhook processed"}');
                    } else {
                        response.statusCode = 400;
                        response.responseBody = Blob.valueOf('{"status": "error", "message": "No issue key found"}');
                    }
                } else {
                    response.statusCode = 400;
                    response.responseBody = Blob.valueOf('{"status": "error", "message": "No issue data found"}');
                }
            } else {
                // Event not relevant, but still return success
                response.statusCode = 200;
                response.responseBody = Blob.valueOf('{"status": "ignored", "message": "Event type not relevant"}');
            }
            
        } catch (Exception e) {
            System.debug('Error processing Jira webhook: ' + e.getMessage());
            response.statusCode = 500;
            response.responseBody = Blob.valueOf('{"status": "error", "message": "' + e.getMessage() + '"}');
        }
    }
    
    /**
     * Determine if the webhook event is relevant for our sync
     */
    private static Boolean isRelevantEvent(String webhookEvent) {
        Set<String> relevantEvents = new Set<String>{
            'jira:issue_created',
            'jira:issue_updated',
            'jira:issue_deleted'
        };
        
        return relevantEvents.contains(webhookEvent);
    }
}

/*
JIRA WEBHOOK CONFIGURATION:
1. Go to your Jira Administration
2. Navigate to System > WebHooks
3. Create a new webhook with:
   - URL: https://yourorg.my.salesforce.com/services/apexrest/jira/webhook/
   - Events: Issue Created, Issue Updated, Issue Deleted
   - JQL Filter: assignee = currentUser() (optional, to limit to relevant issues)
   - Authentication: Basic Auth or API Token

SECURITY CONSIDERATIONS:
- Add IP restrictions in Salesforce if possible
- Consider adding a secret token validation
- Monitor webhook usage and limits
*/