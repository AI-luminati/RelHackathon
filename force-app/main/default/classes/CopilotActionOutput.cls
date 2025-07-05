// File Name: CopilotActionOutput.cls
 // *** ADD THIS ANNOTATION TO THE CLASS ***
public class CopilotActionOutput {
    @AuraEnabled

    @InvocableVariable(label='Output Type')
    public String type; // Specifies the type of component (e.g., 'copilotActionOutput/Tabelau_Display')
    @AuraEnabled
    // *** This references the top-level ActionValue class defined in ActionValue.cls ***
    @InvocableVariable(label='Output Value')
    public ActionValue value; // Contains the data for the component (references the top-level ActionValue class)
}