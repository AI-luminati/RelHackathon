// File: AgentforceApexClasses.cls - Manage Apex classes visibility based on permissions
public with sharing class AgentforceApexClasses {
    
    // Custom Permission API Name - Create this in Setup
    private static final String ADMIN_PERMISSION = 'View_All_Apex_Classes';
    // Permission Set API Name - Alternative method
    private static final String PERMISSION_SET_NAME = 'View_All_Apex_Classes';
    
    @InvocableMethod(label='Get Apex Classes With Permissions' description='Retrieves Apex classes based on user permissions and query type for Agentforce')
    public static List<ApexClassResponse> getApexClassesWithPermissions(List<ApexClassRequest> requests) {
        List<ApexClassResponse> responses = new List<ApexClassResponse>();
        
        for (ApexClassRequest request : requests) {
            ApexClassResponse response = new ApexClassResponse();
            
            try {
                // Check if user has admin permission using multiple methods
                Boolean hasAdminAccess = checkUserPermissions();
                
                // Determine query scope based on request and permissions
                String queryScope = determineQueryScope(request.queryType, hasAdminAccess);
                
                // Get Apex classes based on scope
                List<ApexClass> apexClasses = getClassesByScope(queryScope, hasAdminAccess);
                
                // Process and format the response
                response = processClassesResponse(apexClasses, queryScope, hasAdminAccess, request.queryType);
                response.success = true;
                
                // CRITICAL: Ensure the message is properly set for Agentforce
                if (String.isBlank(response.message)) {
                    response.message = response.formattedMessage;
                }
                
            } catch (Exception e) {
                response.success = false;
                response.errorMessage = 'Error retrieving Apex classes: ' + e.getMessage();
                response.formattedMessage = 'Sorry, I could not retrieve the Apex classes. Please try again or contact your administrator.';
                response.message = response.formattedMessage; // For Agentforce compatibility
                System.debug('Error in getApexClassesWithPermissions: ' + e.getMessage());
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
    
    // Determine what scope of classes to retrieve
    private static String determineQueryScope(String queryType, Boolean hasAdminAccess) {
        if (String.isBlank(queryType)) {
            return hasAdminAccess ? 'ALL' : 'MY';
        }
        
        String lowerQuery = queryType.toLowerCase();
        
        // Handle "my" queries - always return user's classes regardless of permissions
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
        
        // Handle specific status queries
        if (lowerQuery.contains('active') || lowerQuery.contains('deployed')) {
            return hasAdminAccess ? 'ALL_ACTIVE' : 'MY_ACTIVE';
        }
        
        if (lowerQuery.contains('inactive') || lowerQuery.contains('deleted')) {
            return hasAdminAccess ? 'ALL_INACTIVE' : 'MY_INACTIVE';
        }
        
        // Handle API version queries
        if (lowerQuery.contains('api version') || lowerQuery.contains('version')) {
            return hasAdminAccess ? 'ALL_VERSIONS' : 'MY_VERSIONS';
        }
        
        // Default behavior based on permissions
        return hasAdminAccess ? 'ALL' : 'MY';
    }
    
    // Get classes based on determined scope
    private static List<ApexClass> getClassesByScope(String scope, Boolean hasAdminAccess) {
        String currentUserId = UserInfo.getUserId();
        
        if (scope == 'MY' || scope == 'MY_COUNT' || scope == 'MY_ACTIVE' || scope == 'MY_INACTIVE' || scope == 'MY_VERSIONS') {
            String statusFilter = '';
            if (scope == 'MY_ACTIVE') {
                statusFilter = ' AND Status = \'Active\'';
            } else if (scope == 'MY_INACTIVE') {
                statusFilter = ' AND Status = \'Deleted\'';
            }
            
            String query = 'SELECT Id, Name, Status, ApiVersion, LengthWithoutComments, ' +
                          'CreatedBy.Name, CreatedById, CreatedDate, LastModifiedBy.Name, ' +
                          'LastModifiedById, LastModifiedDate, Body ' +
                          'FROM ApexClass ' +
                          'WHERE CreatedById = :currentUserId' + statusFilter + ' ' +
                          'ORDER BY Name ASC ' +
                          'LIMIT 100';
            
            return Database.query(query);
            
        } else if (scope.startsWith('ALL')) {
            if (!hasAdminAccess) {
                // Fallback to user's classes if no permission
                return getClassesByScope('MY', false);
            }
            
            String statusFilter = '';
            if (scope == 'ALL_ACTIVE') {
                statusFilter = ' WHERE Status = \'Active\'';
            } else if (scope == 'ALL_INACTIVE') {
                statusFilter = ' WHERE Status = \'Deleted\'';
            }
            
            String query = 'SELECT Id, Name, Status, ApiVersion, LengthWithoutComments, ' +
                          'CreatedBy.Name, CreatedById, CreatedDate, LastModifiedBy.Name, ' +
                          'LastModifiedById, LastModifiedDate, Body ' +
                          'FROM ApexClass' + statusFilter + ' ' +
                          'ORDER BY Name ASC ' +
                          'LIMIT 200';
            
            return Database.query(query);
            
        } else {
            return new List<ApexClass>();
        }
    }
    
    // Process classes and create formatted response
    private static ApexClassResponse processClassesResponse(List<ApexClass> classes, String scope, Boolean hasAdminAccess, String originalQuery) {
        ApexClassResponse response = new ApexClassResponse();
        
        // Set basic response data
        response.totalCount = classes.size();
        response.hasAdminAccess = hasAdminAccess;
        response.queryScope = scope;
        
        // Count classes by user if showing all classes
        if (scope.contains('ALL') && hasAdminAccess) {
            response.myClassesCount = countClassesByUser(classes, UserInfo.getUserId());
            response.otherUsersCount = response.totalCount - response.myClassesCount;
        } else {
            response.myClassesCount = response.totalCount;
            response.otherUsersCount = 0;
        }
        
        // Calculate statistics
        response.activeCount = countClassesByStatus(classes, 'Active');
        response.inactiveCount = countClassesByStatus(classes, 'Deleted');
        response.totalLinesOfCode = calculateTotalLinesOfCode(classes);
        response.averageLinesPerClass = response.totalCount > 0 ? response.totalLinesOfCode / response.totalCount : 0;
        
        // Handle count-only queries
        if (scope.contains('COUNT')) {
            response.formattedMessage = formatCountResponse(response, originalQuery);
            response.message = response.formattedMessage; // For Agentforce compatibility
            return response;
        }
        
        // Format the main response message
        response.formattedMessage = formatClassesResponse(response, originalQuery, classes);
        response.message = response.formattedMessage; // For Agentforce compatibility
        
        return response;
    }
    
    // Count classes created by specific user
    private static Integer countClassesByUser(List<ApexClass> classes, Id userId) {
        Integer count = 0;
        for (ApexClass cls : classes) {
            if (cls.CreatedById == userId) {
                count++;
            }
        }
        return count;
    }
    
    // Count classes by status
    private static Integer countClassesByStatus(List<ApexClass> classes, String status) {
        Integer count = 0;
        for (ApexClass cls : classes) {
            if (cls.Status == status) {
                count++;
            }
        }
        return count;
    }
    
    // Calculate total lines of code
    private static Integer calculateTotalLinesOfCode(List<ApexClass> classes) {
        Integer total = 0;
        for (ApexClass cls : classes) {
            if (cls.LengthWithoutComments != null) {
                total += cls.LengthWithoutComments;
            }
        }
        return total;
    }
    
    // Format count-only responses - Simplified for Agentforce
    private static String formatCountResponse(ApexClassResponse response, String originalQuery) {
        String message = '';
        
        if (originalQuery != null && originalQuery.toLowerCase().contains('my')) {
            message = 'Your Apex Classes Count:\n\n';
            message += 'You have created ' + response.myClassesCount + ' Apex class';
            message += (response.myClassesCount == 1) ? '' : 'es';
            message += '\nActive: ' + response.activeCount;
            message += '\nInactive: ' + response.inactiveCount;
            message += '\nTotal lines of code: ' + response.totalLinesOfCode;
            
            if (response.hasAdminAccess) {
                message += '\n\nOrganization totals:';
                message += '\nTotal classes: ' + response.totalCount;
                message += '\nClasses by others: ' + response.otherUsersCount;
            }
        } else {
            if (response.hasAdminAccess) {
                message = 'Organization Apex Classes Count:\n\n';
                message += 'Total Apex classes: ' + response.totalCount + '\n';
                message += 'Your classes: ' + response.myClassesCount + '\n';
                message += 'Classes by others: ' + response.otherUsersCount + '\n';
                message += 'Active classes: ' + response.activeCount + '\n';
                message += 'Inactive classes: ' + response.inactiveCount + '\n';
                message += 'Total lines of code: ' + response.totalLinesOfCode;
            } else {
                message = 'Your Apex Classes Count:\n\n';
                message += 'You have created ' + response.myClassesCount + ' Apex class';
                message += (response.myClassesCount == 1) ? '' : 'es';
                message += '\nActive: ' + response.activeCount;
                message += '\nInactive: ' + response.inactiveCount;
                message += '\nTotal lines of code: ' + response.totalLinesOfCode;
                message += '\n\nNote: You can only see classes you created. Contact your admin for org-wide access.';
            }
        }
        
        return message;
    }
    
    // Format main classes listing response - Simplified for Agentforce
    private static String formatClassesResponse(ApexClassResponse response, String originalQuery, List<ApexClass> classes) {
        String message = '';
        
        if (response.totalCount == 0) {
            if (originalQuery != null && originalQuery.toLowerCase().contains('my')) {
                message = 'No Apex Classes Found\n\n';
                message += 'You have not created any Apex classes yet.\n';
                message += 'Would you like help creating a new Apex class?';
            } else {
                message = 'No Apex Classes Found\n\n';
                message += 'No Apex classes found in the system.\n';
                message += 'Would you like help creating a new Apex class?';
            }
            return message;
        }
        
        // Header based on query type
        if (originalQuery != null && originalQuery.toLowerCase().contains('my')) {
            message = 'Your Apex Classes (' + response.myClassesCount + ')\n';
        } else {
            if (response.hasAdminAccess) {
                message = 'All Apex Classes (' + response.totalCount + ')\n';
                message += 'Your classes: ' + response.myClassesCount + ' | Others: ' + response.otherUsersCount + '\n';
            } else {
                message = 'Your Apex Classes (' + response.myClassesCount + ')\n';
                message += 'Showing only classes you created\n';
            }
        }
        
        message += 'Active: ' + response.activeCount + ' | Inactive: ' + response.inactiveCount + '\n\n';
        
        // List classes (limit to 5 for better readability in Agentforce)
        Integer displayLimit = Math.min(classes.size(), 5);
        for (Integer i = 0; i < displayLimit; i++) {
            ApexClass cls = classes[i];
            
            message += cls.Name;
            
            // Add status indicator
            if (cls.Status == 'Active') {
                message += ' (Active)';
            } else {
                message += ' (Inactive)';
            }
            
            if (cls.CreatedById == UserInfo.getUserId()) {
                message += ' - Your Class';
            }
            
            message += '\n';
            message += '  API Version: ' + cls.ApiVersion + '\n';
            message += '  Created by: ' + cls.CreatedBy.Name + '\n';
            message += '  Modified: ' + cls.LastModifiedDate.format('MMM d, yyyy') + '\n';
            
            if (cls.LengthWithoutComments != null) {
                message += '  Lines of code: ' + cls.LengthWithoutComments + '\n';
            }
            
            message += '\n';
        }
        
        if (response.totalCount > displayLimit) {
            message += '... and ' + (response.totalCount - displayLimit) + ' more classes\n\n';
        }
        
        message += 'Need help managing these classes? I can help you with specific operations.';
        
        return message;
    }
    
    // Input class for the invocable method
    public class ApexClassRequest {
        @InvocableVariable(label='Query Type' description='Type of query: my, all, count, active, inactive, etc.')
        public String queryType;
    }
    
    // Output class for the invocable method
    public class ApexClassResponse {
        @InvocableVariable(label='Success' description='Whether the operation was successful')
        public Boolean success;
        
        @InvocableVariable(label='Message' description='Main response message for Agentforce')
        public String message;
        
        @InvocableVariable(label='Total Count' description='Total number of classes found')
        public Integer totalCount;
        
        @InvocableVariable(label='My Classes Count' description='Number of classes created by current user')
        public Integer myClassesCount;
        
        @InvocableVariable(label='Other Users Count' description='Number of classes created by other users')
        public Integer otherUsersCount;
        
        @InvocableVariable(label='Active Count' description='Number of active classes')
        public Integer activeCount;
        
        @InvocableVariable(label='Inactive Count' description='Number of inactive/deleted classes')
        public Integer inactiveCount;
        
        @InvocableVariable(label='Total Lines of Code' description='Total lines of code across all classes')
        public Integer totalLinesOfCode;
        
        @InvocableVariable(label='Average Lines Per Class' description='Average lines of code per class')
        public Integer averageLinesPerClass;
        
        @InvocableVariable(label='Has Admin Access' description='Whether user has permission to see all classes')
        public Boolean hasAdminAccess;
        
        @InvocableVariable(label='Query Scope' description='Scope of the query performed')
        public String queryScope;
        
        @InvocableVariable(label='Formatted Message' description='Ready-to-display response message')
        public String formattedMessage;
        
        @InvocableVariable(label='Error Message' description='Error details if operation failed')
        public String errorMessage;
    }
}