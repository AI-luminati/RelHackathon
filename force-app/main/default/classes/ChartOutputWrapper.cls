// File Name: ChartOutputWrapper.cls // Add this for better Flow compatibility
public class ChartOutputWrapper {
    @AuraEnabled
    // This field holds the actual list of CopilotOutput objects
    @InvocableVariable(label='Chart Data List')
    public List<CopilotActionOutput> chartDataList;

    // Add a default constructor (good practice for wrapper classes)
    public ChartOutputWrapper() {
        chartDataList = new List<CopilotActionOutput>();
    }
}