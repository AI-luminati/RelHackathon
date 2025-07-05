// File Name: TableauChartURLResponder.cls (Modified)
public with sharing class TableauChartURLResponder {

    // This inner class for requests can remain here
    public class RequestWrapper {
        @InvocableVariable(label='Input')
        public String input;
    }

    /**
     * @InvocableMethod
     * Label: Get Tableau Chart Data Wrapped for Copilot
     * Description: Returns wrapped structured data for displaying a Tableau chart in Copilot.
     */
    @InvocableMethod(label='Get Tableau Chart Data Wrapped for Copilot' description='Returns wrapped structured data for displaying a Tableau chart in Copilot.')
    // *** CHANGE RETURN TYPE to List<ChartOutputWrapper> ***
    public static List<ChartOutputWrapper> getChartData(List<RequestWrapper> requests) {
        List<ChartOutputWrapper> outputs = new List<ChartOutputWrapper>(); // List to return

        // Define your Tableau URL and surrounding text
        String chartUrl = 'https://prod-apsoutheast-b.online.tableau.com/t/amarendrakumar-df2a38ef8a/views/TestAccount/Sheet1?:embed=y&:display_count=yes';
        String prefixText = 'Here is the Account and Revenue chart you requested:';
        String suffixText = 'Let me know if you would like to apply filters or view something else.';

        // Create the structured output object (CopilotActionOutput)
        CopilotActionOutput structuredOutput = new CopilotActionOutput();
        structuredOutput.type = 'copilotActionOutput/Tabelau_Display'; // MUST match component type

        // Create the data object for the component (ActionValue)
        ActionValue actionValue = new ActionValue();
        actionValue.url = chartUrl;
        actionValue.prefix = prefixText;
        actionValue.suffix = suffixText;
        structuredOutput.value = actionValue;

        // *** Create the Wrapper object and add the structured output to its list ***
        ChartOutputWrapper wrapper = new ChartOutputWrapper();
        wrapper.chartDataList.add(structuredOutput); // Add the single output object to the wrapper's list

        // *** Add the single wrapper object to the list being returned by the method ***
        outputs.add(wrapper);

        return outputs;
    }
}