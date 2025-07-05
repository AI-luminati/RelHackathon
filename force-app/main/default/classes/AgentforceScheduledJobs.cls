// File: AgentforceScheduledJobs.cls - Manage scheduled jobs visibility based on permissions
public with sharing class AgentforceScheduledJobs {
    
    // Custom Permission API Name - Create this in Setup
    private static final String ADMIN_PERMISSION = 'View_All_Scheduled_Jobs';
    // Permission Set API Name - Alternative method
    private static final String PERMISSION_SET_NAME = 'View_All_Scheduled_Jobs';
    
    @InvocableMethod(label='Get Scheduled Jobs' description='Retrieves scheduled jobs based on user permissions and query type')
    public static List<ScheduledJobResponse> getScheduledJobs(List<ScheduledJobRequest> requests) {
        List<ScheduledJobResponse> responses = new List<ScheduledJobResponse>();
        
        for (ScheduledJobRequest request : requests) {
            ScheduledJobResponse response = new ScheduledJobResponse();
            
            try {
                // Check if user has admin permission using multiple methods
                Boolean hasAdminAccess = checkUserPermissions();
                
                // Determine query scope based on request and permissions
                String queryScope = determineQueryScope(request.queryType, hasAdminAccess);
                
                // Get scheduled jobs based on scope
                List<CronTrigger> scheduledJobs = getJobsByScope(queryScope, hasAdminAccess);
                
                // Process and format the response
                response = processJobsResponse(scheduledJobs, queryScope, hasAdminAccess, request.queryType);
                response.success = true;
                
            } catch (Exception e) {
                response.success = false;
                response.errorMessage = 'Error retrieving scheduled jobs: ' + e.getMessage();
                response.formattedMessage = 'Sorry, I couldn\'t retrieve the scheduled jobs. Please try again.';
                System.debug('Error in getScheduledJobs: ' + e.getMessage());
            }
            
            responses.add(response);
        }
        
        return responses;
    }
    
    // Enhanced permission checking method
    private static Boolean checkUserPermissions() {
        try {
            // Method 1: Check if user is System Admin (always has access)
            List<Profile> adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
            if (!adminProfile.isEmpty() && UserInfo.getProfileId() == adminProfile[0].Id) {
                System.debug('Permission granted - User is System Administrator');
                return true;
            }
            
            // Method 2: Check via Custom Permission
            if (FeatureManagement.checkPermission(ADMIN_PERMISSION)) {
                System.debug('Permission granted via Custom Permission: ' + ADMIN_PERMISSION);
                return true;
            }
            
            // Method 3: Check via Permission Set Assignment
            List<PermissionSetAssignment> permissionSets = [
                SELECT Id, PermissionSet.Name, PermissionSet.Label
                FROM PermissionSetAssignment 
                WHERE AssigneeId = :UserInfo.getUserId() 
                AND PermissionSet.Name = :PERMISSION_SET_NAME
                AND IsActive = true
                LIMIT 1
            ];
            
            if (!permissionSets.isEmpty()) {
                System.debug('Permission granted via Permission Set: ' + PERMISSION_SET_NAME);
                return true;
            }
            
            System.debug('No admin permissions found for user: ' + UserInfo.getUserId());
            return false;
            
        } catch (Exception e) {
            System.debug('Error checking permissions: ' + e.getMessage());
            return false;
        }
    }
    
    // Determine what scope of jobs to retrieve
    private static String determineQueryScope(String queryType, Boolean hasAdminAccess) {
        if (String.isBlank(queryType)) {
            return hasAdminAccess ? 'ALL' : 'MY';
        }
        
        String lowerQuery = queryType.toLowerCase();
        
        // Handle "my" queries - always return user's jobs regardless of permissions
        if (lowerQuery.contains('my') || lowerQuery.contains('mine') || 
            lowerQuery.contains('created by me') || lowerQuery.contains('i created')) {
            return 'MY';
        }
        
        // Handle "all" queries - only if user has permission
        if (lowerQuery.contains('all') || lowerQuery.contains('organization') || 
            lowerQuery.contains('org') || lowerQuery.contains('everyone')) {
            return hasAdminAccess ? 'ALL' : 'MY';
        }
        
        // Handle count queries
        if (lowerQuery.contains('count') || lowerQuery.contains('how many')) {
            if (lowerQuery.contains('my') || lowerQuery.contains('mine')) {
                return 'MY_COUNT';
            } else {
                return hasAdminAccess ? 'ALL_COUNT' : 'MY_COUNT';
            }
        }
        
        // Default behavior based on permissions
        return hasAdminAccess ? 'ALL' : 'MY';
    }
    
    // Get jobs based on determined scope
    private static List<CronTrigger> getJobsByScope(String scope, Boolean hasAdminAccess) {
        String currentUserId = UserInfo.getUserId();
        
        if (scope == 'MY' || scope == 'MY_COUNT') {
            return [
                SELECT Id, CronJobDetail.Name, CronJobDetail.JobType, CronExpression, 
                       State, StartTime, EndTime, NextFireTime, PreviousFireTime,
                       CreatedBy.Name, CreatedById, CreatedDate, TimesTriggered
                FROM CronTrigger 
                WHERE CreatedById = :currentUserId
                ORDER BY CreatedDate DESC
                LIMIT 100
            ];
        } else if (scope == 'ALL' || scope == 'ALL_COUNT') {
            if (!hasAdminAccess) {
                // Fallback to user's jobs if no permission
                return getJobsByScope('MY', false);
            }
            return [
                SELECT Id, CronJobDetail.Name, CronJobDetail.JobType, CronExpression, 
                       State, StartTime, EndTime, NextFireTime, PreviousFireTime,
                       CreatedBy.Name, CreatedById, CreatedDate, TimesTriggered
                FROM CronTrigger 
                ORDER BY CreatedDate DESC
                LIMIT 200
            ];
        } else {
            return new List<CronTrigger>();
        }
    }
    
    // Process jobs and create formatted response
    private static ScheduledJobResponse processJobsResponse(List<CronTrigger> jobs, String scope, Boolean hasAdminAccess, String originalQuery) {
        ScheduledJobResponse response = new ScheduledJobResponse();
        
        // Set basic response data
        response.totalCount = jobs.size();
        response.hasAdminAccess = hasAdminAccess;
        response.queryScope = scope;
        
        // Count jobs by user if showing all jobs
        if (scope.contains('ALL') && hasAdminAccess) {
            response.myJobsCount = countJobsByUser(jobs, UserInfo.getUserId());
            response.otherUsersCount = response.totalCount - response.myJobsCount;
        } else {
            response.myJobsCount = response.totalCount;
            response.otherUsersCount = 0;
        }
        
        // Handle count-only queries
        if (scope.contains('COUNT')) {
            response.formattedMessage = formatCountResponse(response, originalQuery);
            return response;
        }
        
        // Format the main response message
        response.formattedMessage = formatJobsResponse(response, originalQuery, jobs);
        
        return response;
    }
    
    // Count jobs created by specific user
    private static Integer countJobsByUser(List<CronTrigger> jobs, Id userId) {
        Integer count = 0;
        for (CronTrigger job : jobs) {
            if (job.CreatedById == userId) {
                count++;
            }
        }
        return count;
    }
    
    // Format count-only responses
    private static String formatCountResponse(ScheduledJobResponse response, String originalQuery) {
        String message = '';
        
        if (originalQuery != null && originalQuery.toLowerCase().contains('my')) {
            message = '📊 Your Scheduled Jobs Count\n\n';
            message += '🎯 You have created ' + response.myJobsCount + ' scheduled job';
            message += (response.myJobsCount == 1) ? '' : 's';
            
            if (response.hasAdminAccess) {
                message += '\n📈 Total org jobs: ' + response.totalCount;
                message += '\n👥 Jobs by others: ' + response.otherUsersCount;
            }
        } else {
            if (response.hasAdminAccess) {
                message = '📊 Organization Scheduled Jobs Count\n\n';
                message += '🏢 Total scheduled jobs: ' + response.totalCount + '\n';
                message += '🎯 Your jobs: ' + response.myJobsCount + '\n';
                message += '👥 Jobs by others: ' + response.otherUsersCount;
            } else {
                message = '📊 Your Scheduled Jobs Count\n\n';
                message += '🎯 You have created ' + response.myJobsCount + ' scheduled job';
                message += (response.myJobsCount == 1) ? '' : 's';
                message += '\n\n💡 You can only see jobs you created. Contact your admin for org-wide access.';
            }
        }
        
        return message;
    }
    
    // Format main jobs listing response
    private static String formatJobsResponse(ScheduledJobResponse response, String originalQuery, List<CronTrigger> jobs) {
        String message = '';
        
        if (response.totalCount == 0) {
            if (originalQuery != null && originalQuery.toLowerCase().contains('my')) {
                message = '📅 No Scheduled Jobs Found\n\n';
                message += '🎯 You haven\'t created any scheduled jobs yet.\n';
                message += '💡 Would you like help creating a new scheduled job?';
            } else {
                message = '📅 No Scheduled Jobs Found\n\n';
                message += '🏢 No scheduled jobs found in the system.\n';
                message += '💡 Would you like help creating a new scheduled job?';
            }
            return message;
        }
        
        // Header based on query type
        if (originalQuery != null && originalQuery.toLowerCase().contains('my')) {
            message = '📅 Your Scheduled Jobs (' + response.myJobsCount + ')\n\n';
        } else {
            if (response.hasAdminAccess) {
                message = '📅 All Scheduled Jobs (' + response.totalCount + ')\n';
                message += '🎯 Your jobs: ' + response.myJobsCount + ' | 👥 Others: ' + response.otherUsersCount + '\n\n';
            } else {
                message = '📅 Your Scheduled Jobs (' + response.myJobsCount + ')\n';
                message += '💡 Showing only jobs you created\n\n';
            }
        }
        
        // List jobs
        for (Integer i = 0; i < jobs.size() && i < 10; i++) {
            CronTrigger job = jobs[i];
            
            message += job.CronJobDetail.Name + '\n';
            message += '  • Type: ' + job.CronJobDetail.JobType + '\n';
            message += '  • Status: ' + job.State + '\n';
            message += '  • Created by: ' + job.CreatedBy.Name;
            
            if (job.CreatedById == UserInfo.getUserId()) {
                message += ' (You) 🎯\n';
            } else {
                message += '\n';
            }
            
            if (job.NextFireTime != null) {
                message += '  • Next run: ' + job.NextFireTime.format('MMM d, yyyy h:mm a') + '\n';
            }
            
            message += '  • Times run: ' + job.TimesTriggered + '\n\n';
        }
        
        if (response.totalCount > 10) {
            message += '... and ' + (response.totalCount - 10) + ' more jobs\n\n';
        }
        
        message += '💡 Need help managing these jobs?';
        
        return message;
    }
    
    // Input class for the invocable method
    public class ScheduledJobRequest {
        @InvocableVariable(label='Query Type' description='Type of query: my, all, count, etc.')
        public String queryType;
    }
    
    // Output class for the invocable method
    public class ScheduledJobResponse {
        @InvocableVariable(label='Success' description='Whether the operation was successful')
        public Boolean success;
        
        @InvocableVariable(label='Total Count' description='Total number of jobs found')
        public Integer totalCount;
        
        @InvocableVariable(label='My Jobs Count' description='Number of jobs created by current user')
        public Integer myJobsCount;
        
        @InvocableVariable(label='Other Users Count' description='Number of jobs created by other users')
        public Integer otherUsersCount;
        
        @InvocableVariable(label='Has Admin Access' description='Whether user has permission to see all jobs')
        public Boolean hasAdminAccess;
        
        @InvocableVariable(label='Query Scope' description='Scope of the query performed')
        public String queryScope;
        
        @InvocableVariable(label='Formatted Message' description='Ready-to-display response message')
        public String formattedMessage;
        
        @InvocableVariable(label='Error Message' description='Error details if operation failed')
        public String errorMessage;
    }
}