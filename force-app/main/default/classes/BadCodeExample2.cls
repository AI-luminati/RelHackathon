public class BadCodeExample2 {
    
    // PMD Violation: ApexDoc (Priority 3 - Warning)
    // Missing class-level ApexDoc comment
    
    public String s; // PMD Violation: PropertyNamingConventions (Priority 3 - Warning)
                     // Variable name 's' is too short and not descriptive
    
    public String accountId = '0012345678901234'; // PMD Violation: AvoidHardcodingId (Priority 1 - Critical)
                                                  // Hardcoded Salesforce ID will break in other orgs
    
    // PMD Violation: ApexDoc (Priority 3 - Warning)
    // Missing method-level ApexDoc comment
    public void processAccounts() {
        
        List<Account> accounts = [SELECT Id, Name FROM Account LIMIT 10];
        
        // PMD Violation: OperationWithLimitsInLoop (Priority 1 - Critical)
        // SOQL inside loop will hit governor limits
        for(Account acc : accounts) {
            List<Contact> contacts = [SELECT Id, Name FROM Contact WHERE AccountId = :acc.Id];
            System.debug(contacts); // PMD Violation: DebugsShouldUseLoggingLevel (Priority 3 - Warning)
                                   // Should specify logging level like System.debug(LoggingLevel.DEBUG, contacts)
        }
        
        String unusedVariable = 'test'; // PMD Violation: UnusedLocalVariable (Priority 3 - Warning)
                                       // Variable declared but never used
        
        // PMD Violation: EmptyCatchBlock (Priority 1 - Critical)
        // Empty catch block swallows exceptions
        try {
            insert new Account(Name = 'Test Account');
        } catch(Exception e) {
            // Empty catch block - very dangerous!
        }
    }
    
    // PMD Violation: CyclomaticComplexity (Priority 3 - Warning)
    // Method too complex with multiple decision points
    public String complexMethod(Integer value) {
        if(value > 100) {
            if(value > 200) {
                if(value > 300) {
                    if(value > 400) {
                        if(value > 500) {
                            return 'Very High';
                        } else {
                            return 'High';
                        }
                    } else {
                        return 'Medium High';
                    }
                } else {
                    return 'Medium';
                }
            } else {
                return 'Low Medium';
            }
        } else {
            return 'Low';
        }
    }
    
    // Removed test method - must be in separate test class
    
    // PMD Violation: AvoidDeeplyNestedIfStmts (Priority 3 - Warning)
    public void deeplyNestedMethod(Boolean condition1, Boolean condition2, Boolean condition3) {
        if(condition1) {
            if(condition2) {
                if(condition3) {
                    if(true) {
                        if(false) {
                            System.debug('Too deeply nested');
                        }
                    }
                }
            }
        }
    }
    
    // PMD Violation: MethodNamingConventions (Priority 3 - Warning)
    public void BADMETHODNAME() {
        // Method name should be camelCase, not ALL CAPS
        System.debug('Bad method name');
    }
    
    // PMD Violation: WhileLoopsMustUseBraces (Priority 3 - Warning)
    public void badWhileLoop() {
        Integer i = 0;
        while(i < 5)
            i++; // Missing braces around while loop body
    }
}