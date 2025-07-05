public with sharing class TrailheadService {
    @AuraEnabled(cacheable=true)
    public static TrailheadData getTrailheadData() {
        // In a real scenario, callout to Trailhead API or integration here
        // For now, return mock data
        TrailheadData data = new TrailheadData();
        data.points = 54321;
        data.rangerLevel = 'Ranger';
        data.superbadgesCompleted = 5;
        data.badges = 120;
        data.recommendedModules = new List<String>{
            'Lightning Web Components Basics',
            'Apex Integration Services',
            'Data Security',
            'Process Automation'
        };
        return data;
    }

    public class TrailheadData {
        @AuraEnabled public Integer points;
        @AuraEnabled public String rangerLevel;
        @AuraEnabled public Integer superbadgesCompleted;
        @AuraEnabled public Integer badges;
        @AuraEnabled public List<String> recommendedModules;
    }
}