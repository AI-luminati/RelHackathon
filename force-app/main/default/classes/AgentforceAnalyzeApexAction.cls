/**
 * Invocable Actions for Agentforce - PMD Analysis
 */
public class AgentforceAnalyzeApexAction {
    
    public class ActionRequest {
        @InvocableVariable(required=true label='Apex Class Name')
        public String apexClassName;
        
        @InvocableVariable(label='Generate AI Suggestions')
        public Boolean generateAllSuggestions = false;
        
        @InvocableVariable(label='Severity Filter')
        public String severityFilter;
    }
    
    public class ActionResponse {
        @InvocableVariable
        public String analysisId;
        
        @InvocableVariable
        public Integer totalIssues;
        
        @InvocableVariable
        public Integer highIssues;
        
        @InvocableVariable
        public Integer mediumIssues;
        
        @InvocableVariable
        public String status;
        
        @InvocableVariable
        public String summary;
        
        @InvocableVariable
        public String classType;
    }
    
    @InvocableMethod(label='PMD: Analyze Apex Class' 
                     description='Runs PMD analysis on specified Apex class and stores results')
    public static List<ActionResponse> analyzeApexClass(List<ActionRequest> requests) {
        List<ActionResponse> responses = new List<ActionResponse>();
        
        for (ActionRequest request : requests) {
            ActionResponse response = new ActionResponse();
            
            try {
                String analysisId = AgentforcePMDService.analyzeApexClassForAgentforce(
                    request.apexClassName
                );
                
                // Get analysis results
                PMD_Analysis__c analysis = [
                    SELECT Total_Issues__c, High_Issues__c, Medium_Issues__c, 
                           Low_Issues__c, Status__c, Class_Type__c, Analysis_Summary__c
                    FROM PMD_Analysis__c 
                    WHERE Id = :analysisId
                ];
                
                response.analysisId = analysisId;
                response.totalIssues = Integer.valueOf(analysis.Total_Issues__c);
                response.highIssues = Integer.valueOf(analysis.High_Issues__c);
                response.mediumIssues = Integer.valueOf(analysis.Medium_Issues__c);
                response.status = analysis.Status__c;
                response.summary = analysis.Analysis_Summary__c;
                response.classType = analysis.Class_Type__c;
                
                // Optionally generate AI suggestions for high severity issues
                if (request.generateAllSuggestions && response.highIssues > 0) {
                    generateSuggestionsForHighSeverity(analysisId);
                }
                
            } catch (Exception e) {
                response.status = 'Error';
                response.summary = 'Analysis failed: ' + e.getMessage();
            }
            
            responses.add(response);
        }
        
        return responses;
    }
    
    private static void generateSuggestionsForHighSeverity(String analysisId) {
        List<PMD_Finding__c> highSeverityFindings = [
            SELECT Id FROM PMD_Finding__c 
            WHERE PMD_Analysis__c = :analysisId 
            AND Severity__c = 'High' 
            AND Suggestion_Generated__c = false
        ];
        
        for (PMD_Finding__c finding : highSeverityFindings) {
            try {
                AgentforcePMDService.generateAISuggestion(finding.Id);
            } catch (Exception e) {
                System.debug('Failed to generate suggestion for finding: ' + finding.Id);
            }
        }
    }
}