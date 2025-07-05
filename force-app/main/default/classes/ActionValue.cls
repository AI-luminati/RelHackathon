// File Name: ActionValue.cls
 // *** ADD THIS ANNOTATION TO THE CLASS ***
public class ActionValue {
    @AuraEnabled
    @InvocableVariable(label='Chart URL')
    public String url; // The actual Tableau embed URL
    @AuraEnabled
    @InvocableVariable(label='Prefix Text')
    public String prefix; // Text to display before the chart
    @AuraEnabled
    @InvocableVariable(label='Suffix Text')
    public String suffix; // Text to display after the chart

    // Optional: if the component specifically expects 'copilotResponse' within the value
    // @InvocableVariable(label='Copilot Response Value')
    // public String copilotResponse;
}