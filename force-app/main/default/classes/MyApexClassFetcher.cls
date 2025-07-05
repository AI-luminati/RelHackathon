public with sharing class MyApexClassFetcher {

    public class Request {
        @InvocableVariable(required=false)
        public String dummyInput; // Placeholder input, not used
    }

    public class Response {
        @InvocableVariable public String status;
        @InvocableVariable public String data;
        public Response(String status, String data) {
            this.status = status;
            this.data = data;
        }
    }

    @InvocableMethod(label='Get My Apex Classes' category='AgentForce')
    public static List<Response> getMyApexClasses(List<Request> requests) {
        List<Response> responses = new List<Response>();
        String currentUser = UserInfo.getUserId();
        
        try {
            List<ApexClass> classes = [SELECT Name, CreatedDate 
                                       FROM ApexClass 
                                       WHERE CreatedById = :currentUser 
                                       ORDER BY CreatedDate DESC];
            
            if (classes.isEmpty()) {
                responses.add(new Response('NO_CLASSES_FOUND', 'You haven’t created any Apex classes yet.'));
            } else {
                // Extract names from classes and join them by line breaks
                List<String> classNames = new List<String>();
                for (ApexClass ac : classes) {
                    classNames.add(ac.Name);
                }
                responses.add(new Response('SUCCESS', String.join(classNames, '\n')));
            }
        } catch (Exception e) {
            responses.add(new Response('ERROR', 'An error occurred: ' + e.getMessage()));
        }
        
        return responses;
    }
}