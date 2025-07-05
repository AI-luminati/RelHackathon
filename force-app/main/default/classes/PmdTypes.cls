public class PmdTypes {
    
    /**
     * Represents a PMD code analysis finding/violation
     * Used to structure the results from PMD scanning
     */
    public class Finding {
        @AuraEnabled public String rule;        // PMD rule name (e.g., "VariableNamingConventions")
        @AuraEnabled public Integer line;       // Line number where violation occurs
        @AuraEnabled public String message;     // Description of the violation
        @AuraEnabled public String severity;    // Severity level (Error, Warning, Info)
        
        /**
         * Default constructor
         */
        public Finding() {
            this.rule = '';
            this.line = 1;
            this.message = '';
            this.severity = 'Info';
        }
        
        /**
         * Constructor with all fields
         */
        public Finding(String rule, Integer line, String message, String severity) {
            this.rule = rule != null ? rule : '';
            this.line = line != null && line > 0 ? line : 1;
            this.message = message != null ? message : '';
            this.severity = severity != null ? severity : 'Info';
        }
    }
    
    /**
     * Represents the overall scan result
     * Can be used for future enhancements
     */
    public class ScanResult {
        @AuraEnabled public List<Finding> findings;
        @AuraEnabled public String className;
        @AuraEnabled public Integer totalViolations;
        @AuraEnabled public Datetime scanTime;
        @AuraEnabled public Boolean hasErrors;
        
        public ScanResult() {
            this.findings = new List<Finding>();
            this.className = '';
            this.totalViolations = 0;
            this.scanTime = Datetime.now();
            this.hasErrors = false;
        }
    }
}