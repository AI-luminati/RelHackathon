global with sharing class AgentforceApexClassFetcher {
    @InvocableMethod(label='Get My Apex Classes')
    global static List<ResponseWrapper> getMyApexClasses(List<String> input) {
        List<ResponseWrapper> result = new List<ResponseWrapper>();
        List<String> classNames = new List<String>();
        String status = 'SUCCESS';

        try {
            for (ApexClass cls : [SELECT Name FROM ApexClass WHERE CreatedById = :UserInfo.getUserId()]) {
                classNames.add(cls.Name);
            }
            if (classNames.isEmpty()) {
                status = 'NO_CLASSES_FOUND';
            }
        } catch (Exception e) {
            status = 'ERROR';
        }

        ResponseWrapper res = new ResponseWrapper();
        res.classNames = classNames;
        res.status = status;
        result.add(res);

        return result;
    }

    global class ResponseWrapper {
        @InvocableVariable(label='Class Names')
        public List<String> classNames;

        @InvocableVariable(label='Status')
        public String status;
    }
}