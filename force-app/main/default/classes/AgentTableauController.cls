// File: AgentTableauController.cls
public with sharing class AgentTableauController {

    // Your Tableau Share Link
    private static final String RAW_TABLEAU_SHARE_LINK = 'https://prod-apsoutheast-b.online.tableau.com/t/amarendrakumar-df2a38ef8a/views/TestAccount/Sheet1';

    // Construct the embeddable/viewable URL
    // ?:embed=y  -- Optimizes for embedding (hides some Tableau chrome)
    // &:display_count=no -- Hides the "view count"
    // &:toolbar=bottom -- Shows the toolbar at the bottom (as per your <tableau-viz> tag). You can change to "no" to hide it.
    // &:showVizHome=no -- Prevents navigating to Tableau home from the viz
    private static final String EMBEDDABLE_TABLEAU_URL = RAW_TABLEAU_SHARE_LINK + '?:embed=y&:display_count=no&:toolbar=bottom&:showVizHome=no';

    public class AgentPromptRequest {
        @InvocableVariable(label='User Prompt or Intent' description='The text prompt from the user or a classified intent' required=true)
        public String prompt;
    }

    public class TableauChartResponse {
        @InvocableVariable(label='Tableau Chart URL' description='The URL of the Tableau chart to display/link to')
        public String chartUrl;

        @InvocableVariable(label='Response Message' description='A message to show the user, can be an error or success guidance')
        public String messageToUser;

        @InvocableVariable(label='Display Type Hint' description='Hint for Agentforce: "link" or "embed_url"')
        public String displayTypeHint; // "link" or "embed_url"
    }

    @InvocableMethod(label='Get Tableau View Info for Agent' description='Returns a Tableau view URL or a message based on the user prompt.')
    public static List<TableauChartResponse> getTableauViewInfo(List<AgentPromptRequest> requests) {
        List<TableauChartResponse> responses = new List<TableauChartResponse>();
        AgentPromptRequest request = requests[0];
        TableauChartResponse response = new TableauChartResponse();

        if (String.isBlank(request.prompt)) {
            response.messageToUser = 'I didn\'t receive a prompt. Please try again.';
            response.displayTypeHint = 'message_only';
            responses.add(response);
            return responses;
        }

        String lowerCasePrompt = request.prompt.toLowerCase();

        // Keywords to match your specific dashboard ("TestAccount/Sheet1")
        if (lowerCasePrompt.contains('account') &&
            (lowerCasePrompt.contains('annual revenue') || lowerCasePrompt.contains('revenue chart') || lowerCasePrompt.contains('test account'))) { // Added 'test account' as it's in your URL

            response.chartUrl = EMBEDDABLE_TABLEAU_URL;
            response.messageToUser = 'Here is the Account Revenue chart:';
            response.displayTypeHint = 'link'; // Or 'embed_url' if Agentforce supports it
        } else {
            response.messageToUser = 'Sorry, I can only show the "account annual revenue chart" right now. Please try a prompt like "show test account revenue".';
            response.displayTypeHint = 'message_only';
        }

        responses.add(response);
        return responses;
    }
}