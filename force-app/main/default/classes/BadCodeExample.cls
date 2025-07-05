public class BadCodeExample {
    
    // Poor variable naming - should be descriptive
    public String s;
    public String a;
    public Integer i;
    
    // Missing access modifier - should be explicit
    String badVariable;
    
    // Unused variable
    private String unusedVariable = 'never used';
    
    // Method with poor naming and too many parameters
    public void m(String a, String b, String c, String d, String e, String f) {
        // Poor variable naming
        String x = a + b;
        String y = c + d;
        
        // Hardcoded values - should be constants
        if(x == 'test') {
            System.debug('hardcoded string');
        }
        
        // Poor formatting and structure
        if(true){System.debug('bad formatting');}
        
        // Unused local variable
        String temp = 'unused';
        
        // Deep nesting - complexity issue
        if(a != null) {
            if(b != null) {
                if(c != null) {
                    if(d != null) {
                        if(e != null) {
                            System.debug('too much nesting');
                        }
                    }
                }
            }
        }
    }
    
    // Empty catch block - bad practice
    public void badExceptionHandling() {
        try {
            Integer result = 10 / 0;
        } catch(Exception e) {
            // Empty catch block - PMD violation
        }
    }
    
    // Method that's too long and complex
    public void tooLongMethod() {
        String s1 = 'line1';
        String s2 = 'line2';
        String s3 = 'line3';
        String s4 = 'line4';
        String s5 = 'line5';
        
        // Poor variable reuse
        s1 = s2;
        s2 = s3;
        s3 = s4;
        
        // Unnecessary string concatenation in loop
        String result = '';
        for(Integer j = 0; j < 10; j++) {
            result += 'iteration' + j;  // Poor performance
        }
        
        // Hardcoded SOQL limit
        List<User> users = [SELECT Id FROM User LIMIT 50000];
        
        // Poor null checking
        if(s1 != null && s1.length() > 0) {
            // Should use String.isNotBlank()
            System.debug(s1);
        }
    }
    
    // Public field - should be private with getter/setter
    public String publicField;
    
    // Method with no return documentation
    public String getValue() {
        return this.s;
    }
    
    // Boolean method with poor naming
    public Boolean check() {
        return true;
    }
    
    // Unused parameter
    public void methodWithUnusedParam(String notUsed) {
        System.debug('parameter not used');
    }
}