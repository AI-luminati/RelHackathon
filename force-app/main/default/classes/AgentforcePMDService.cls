/**
 * AgentforcePMDService - Service class for PMD Analysis integration with Agentforce
 */
public with sharing class AgentforcePMDService {
    
    /**
     * Main method called by Agentforce to analyze an Apex class
     */
    @AuraEnabled
    public static String analyzeApexClassForAgentforce(String className) {
        try {
            // Create master analysis record
            PMD_Analysis__c analysis = new PMD_Analysis__c(
                Apex_Class_Name__c = className,
                Analysis_Date__c = DateTime.now(),
                Status__c = 'In Progress',
                Analyzed_By__c = UserInfo.getUserId(),
                Class_Type__c = determineClassType(className)
            );
            insert analysis;
            
            // Run your existing PMD analysis logic
            List<Map<String, Object>> findings = runPMDAnalysis(className);
            
            // Create finding records
            List<PMD_Finding__c> findingRecords = new List<PMD_Finding__c>();
            Integer totalIssues = 0;
            Integer highIssues = 0;
            Integer mediumIssues = 0;
            Integer lowIssues = 0;
            Integer infoIssues = 0;
            
            for (Map<String, Object> finding : findings) {
                String severity = (String) finding.get('severity');
                
                PMD_Finding__c findingRecord = new PMD_Finding__c(
                    PMD_Analysis__c = analysis.Id,
                    Rule_Name__c = (String) finding.get('ruleName'),
                    Rule_Category__c = (String) finding.get('category'),
                    Severity__c = severity,
                    Line_Number__c = (Decimal) finding.get('lineNumber'),
                    Column_Number__c = (Decimal) finding.get('columnNumber'),
                    Message__c = (String) finding.get('message'),
                    Code_Snippet__c = (String) finding.get('codeSnippet'),
                    Suggestion_Generated__c = false
                );
                findingRecords.add(findingRecord);
                
                // Count by severity
                totalIssues++;
                if (severity == 'High') highIssues++;
                else if (severity == 'Medium') mediumIssues++;
                else if (severity == 'Low') lowIssues++;
                else if (severity == 'Info') infoIssues++;
            }
            
            // Insert findings
            if (!findingRecords.isEmpty()) {
                insert findingRecords;
            }
            
            // Update master record with counts
            analysis.Total_Issues__c = totalIssues;
            analysis.High_Issues__c = highIssues;
            analysis.Medium_Issues__c = mediumIssues;
            analysis.Low_Issues__c = lowIssues;
            analysis.Info_Issues__c = infoIssues;
            analysis.Status__c = 'Completed';
            analysis.Analysis_Summary__c = buildAnalysisSummary(totalIssues, highIssues, mediumIssues, lowIssues, infoIssues);
            update analysis;
            
            return analysis.Id;
            
        } catch (Exception e) {
            System.debug('PMD Analysis Error: ' + e.getMessage());
            throw new AuraHandledException('Analysis failed: ' + e.getMessage());
        }
    }
    
    /**
     * Generate AI suggestion for a specific finding
     */
    @AuraEnabled
    public static String generateAISuggestion(String findingId) {
        try {
            PMD_Finding__c finding = [
                SELECT Id, Rule_Name__c, Rule_Category__c, Message__c, Line_Number__c, 
                       Code_Snippet__c, PMD_Analysis__c, PMD_Analysis__r.Apex_Class_Name__c
                FROM PMD_Finding__c 
                WHERE Id = :findingId 
                LIMIT 1
            ];
            
            // Create AI interaction tracking record (simplified)
            PMD_AI_Interaction__c interaction = new PMD_AI_Interaction__c(
                PMD_Finding__c = finding.Id,
                User__c = UserInfo.getUserId()
            );
            
            // Generate AI suggestion using your existing logic
            String aiSuggestion = generateSuggestionForFinding(finding);
            
            insert interaction;
            
            // Update the finding record
            finding.AI_Suggestion__c = aiSuggestion;
            finding.Suggestion_Generated__c = true;
            update finding;
            
            // Update analysis record
            updateAnalysisWithNewSuggestion(finding.PMD_Analysis__c);
            
            return aiSuggestion;
            
        } catch (Exception e) {
            System.debug('AI Suggestion Error: ' + e.getMessage());
            throw new AuraHandledException('AI Suggestion generation failed: ' + e.getMessage());
        }
    }
    
    /**
     * Get analysis history for Agentforce queries
     */
    @AuraEnabled
    public static List<Map<String, Object>> getAnalysisHistory(Integer limitCount) {
        if (limitCount == null) limitCount = 10;
        
        List<PMD_Analysis__c> analyses = [
            SELECT Id, Name, Apex_Class_Name__c, Analysis_Date__c, Total_Issues__c, 
                   High_Issues__c, Medium_Issues__c, Low_Issues__c, Status__c, Class_Type__c,
                   Analyzed_By__r.Name, AI_Suggestions_Generated__c
            FROM PMD_Analysis__c 
            WHERE Analyzed_By__c = :UserInfo.getUserId()
            ORDER BY Analysis_Date__c DESC 
            LIMIT :limitCount
        ];
        
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (PMD_Analysis__c analysis : analyses) {
            Map<String, Object> analysisMap = new Map<String, Object>{
                'id' => analysis.Id,
                'name' => analysis.Name,
                'className' => analysis.Apex_Class_Name__c,
                'analysisDate' => analysis.Analysis_Date__c,
                'totalIssues' => analysis.Total_Issues__c,
                'highIssues' => analysis.High_Issues__c,
                'mediumIssues' => analysis.Medium_Issues__c,
                'lowIssues' => analysis.Low_Issues__c,
                'status' => analysis.Status__c,
                'classType' => analysis.Class_Type__c,
                'aiSuggestions' => analysis.AI_Suggestions_Generated__c,
                'analyzedBy' => analysis.Analyzed_By__r.Name
            };
            result.add(analysisMap);
        }
        
        return result;
    }
    
    /**
     * Get findings for a specific analysis (for Agentforce queries)
     */
    @AuraEnabled
    public static List<Map<String, Object>> getFindingsForAnalysis(String analysisId, String severityFilter) {
        String query = 'SELECT Id, Rule_Name__c, Rule_Category__c, Severity__c, Line_Number__c, ' +
                      'Message__c, AI_Suggestion__c, Suggestion_Generated__c, Code_Snippet__c ' +
                      'FROM PMD_Finding__c WHERE PMD_Analysis__c = :analysisId';
        
        if (String.isNotBlank(severityFilter)) {
            query += ' AND Severity__c = :severityFilter';
        }
        
        query += ' ORDER BY Severity__c, Line_Number__c';
        
        List<PMD_Finding__c> findings = Database.query(query);
        
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (PMD_Finding__c finding : findings) {
            Map<String, Object> findingMap = new Map<String, Object>{
                'id' => finding.Id,
                'ruleName' => finding.Rule_Name__c,
                'ruleCategory' => finding.Rule_Category__c,
                'severity' => finding.Severity__c,
                'lineNumber' => finding.Line_Number__c,
                'message' => finding.Message__c,
                'aiSuggestion' => finding.AI_Suggestion__c,
                'hasSuggestion' => finding.Suggestion_Generated__c,
                'codeSnippet' => finding.Code_Snippet__c
            };
            result.add(findingMap);
        }
        
        return result;
    }
    
    // Helper methods
    private static String determineClassType(String className) {
        className = className.toLowerCase();
        if (className.contains('controller')) return 'Controller';
        if (className.contains('service')) return 'Service';
        if (className.contains('test')) return 'Test Class';
        if (className.contains('batch')) return 'Batch';
        if (className.contains('util')) return 'Utility';
        return 'Other';
    }
    
    private static String buildAnalysisSummary(Integer total, Integer high, Integer medium, Integer low, Integer info) {
        return String.format(
            'PMD Analysis completed. Found {0} total issues: {1} high, {2} medium, {3} low, {4} info severity.',
            new List<Object>{total, high, medium, low, info}
        );
    }
    
    private static void updateAnalysisWithNewSuggestion(String analysisId) {
        PMD_Analysis__c analysis = [
            SELECT AI_Suggestions_Generated__c 
            FROM PMD_Analysis__c 
            WHERE Id = :analysisId
        ];
        
        analysis.AI_Suggestions_Generated__c = (analysis.AI_Suggestions_Generated__c != null) 
            ? analysis.AI_Suggestions_Generated__c + 1 : 1;
        update analysis;
    }
    
    // Your existing PMD analysis logic
    private static List<Map<String, Object>> runPMDAnalysis(String className) {
        // Replace with your actual PMD analysis implementation
        // This should return findings in the format expected above
        return new List<Map<String, Object>>();
    }
    
    // Your existing AI suggestion logic  
    private static String generateSuggestionForFinding(PMD_Finding__c finding) {
        // Replace with your actual AI suggestion implementation
        return 'AI-generated suggestion for ' + finding.Rule_Name__c + ' issue';
    }
}