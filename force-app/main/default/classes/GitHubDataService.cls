public class GitHubDataService {

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getGitHubDetailsFromSalesforce(String createdBy, String repository) {
        try {
            System.debug('### Querying GitHub Details for: ' + createdBy + ' in repo: ' + repository);
            
            // Query all GitHub Details records 
            List<GitHub_Details__c> allRecords = [
                SELECT Id, Name, PR_Number__c, Title__c, State__c, Created_By__c,
                       PR_URL__c, Source_Branch__c, Target_Branch__c, Repository__c, 
                       Reviewers__c, CreatedDate, LastModifiedDate
                FROM GitHub_Details__c 
                WHERE Repository__c = :repository
                ORDER BY PR_Number__c DESC
                LIMIT 200
            ];
            
            // Filter records for the specific user
            List<GitHub_Details__c> userRecords = new List<GitHub_Details__c>();
            for (GitHub_Details__c record : allRecords) {
                if (record.Created_By__c == createdBy) {
                    userRecords.add(record);
                }
            }
            
            System.debug('### Total records found: ' + allRecords.size());
            System.debug('### User records found: ' + userRecords.size());
            
            // Process data for LWC
            List<Map<String, Object>> processedPRs = new List<Map<String, Object>>();
            Integer openCount = 0;
            Integer mergedCount = 0;
            Integer closedCount = 0;
            Integer prodPRsCount = 0;
            
            for (GitHub_Details__c record : userRecords) {
                Map<String, Object> prData = new Map<String, Object>();
                
                // Basic information
                prData.put('id', record.Id);
                prData.put('number', record.PR_Number__c);
                prData.put('title', record.Title__c);
                prData.put('url', record.PR_URL__c);
                prData.put('state', record.State__c);
                prData.put('createdBy', record.Created_By__c);
                prData.put('repository', record.Repository__c);
                
                // Branch information
                prData.put('sourceBranch', record.Source_Branch__c);
                prData.put('targetBranch', record.Target_Branch__c);
                
                // Format created date for display
                String formattedDate = '';
                if (record.CreatedDate != null) {
                    formattedDate = record.CreatedDate.format('MMM d, yyyy');
                }
                prData.put('formattedDate', formattedDate);
                prData.put('createdDate', record.CreatedDate);
                prData.put('lastModifiedDate', record.LastModifiedDate);
                
                // Production deployment check
                Boolean pushedToProd = record.Target_Branch__c == 'main' || 
                                     record.Target_Branch__c == 'master' || 
                                     record.Target_Branch__c == 'prod';
                prData.put('pushedToProd', pushedToProd);
                
                // Process reviewers
                List<String> reviewersList = new List<String>();
                if (String.isNotBlank(record.Reviewers__c)) {
                    String[] reviewersArray = record.Reviewers__c.split(',');
                    for (String reviewer : reviewersArray) {
                        reviewersList.add(reviewer.trim());
                    }
                }
                prData.put('reviewers', reviewersList);
                prData.put('hasReviewers', !reviewersList.isEmpty());
                prData.put('reviewersText', String.isNotBlank(record.Reviewers__c) ? record.Reviewers__c : 'No reviewers');
                
                // Branch display text
                prData.put('branchText', record.Source_Branch__c + ' → ' + record.Target_Branch__c);
                
                // Count by status
                if (record.State__c == 'Open') {
                    openCount++;
                } else if (record.State__c == 'Merged') {
                    mergedCount++;
                } else {
                    closedCount++;
                }
                
                // Count production PRs
                if (pushedToProd) {
                    prodPRsCount++;
                }
                
                processedPRs.add(prData);
            }
            
            // Create summary statistics
            Map<String, Object> stats = new Map<String, Object>();
            stats.put('totalCount', userRecords.size());
            stats.put('openCount', openCount);
            stats.put('mergedCount', mergedCount);
            stats.put('closedCount', closedCount);
            stats.put('prodPRsCount', prodPRsCount);
            
            // Repository statistics (all PRs in the repo)
            Map<String, Integer> repoStats = new Map<String, Integer>();
            Set<String> allCreators = new Set<String>();
            for (GitHub_Details__c record : allRecords) {
                String creator = record.Created_By__c;
                allCreators.add(creator);
                if (!repoStats.containsKey(creator)) {
                    repoStats.put(creator, 0);
                }
                repoStats.put(creator, repoStats.get(creator) + 1);
            }
            
            stats.put('totalRepoRecords', allRecords.size());
            stats.put('uniqueContributors', allCreators.size());
            stats.put('contributorStats', repoStats);
            
            // Last sync information
            DateTime lastSync = null;
            for (GitHub_Details__c record : allRecords) {
                if (lastSync == null || record.LastModifiedDate > lastSync) {
                    lastSync = record.LastModifiedDate;
                }
            }
            stats.put('lastSyncDate', lastSync);
            
            // Return complete data structure
            Map<String, Object> result = new Map<String, Object>();
            result.put('pullRequests', processedPRs);
            result.put('statistics', stats);
            result.put('repository', repository);
            result.put('user', createdBy);
            result.put('success', true);
            
            System.debug('### Successfully processed ' + processedPRs.size() + ' PRs for user');
            return result;
            
        } catch (Exception e) {
            System.debug('### Error querying GitHub Details: ' + e.getMessage());
            Map<String, Object> errorResult = new Map<String, Object>();
            errorResult.put('success', false);
            errorResult.put('error', e.getMessage());
            errorResult.put('pullRequests', new List<Map<String, Object>>());
            errorResult.put('statistics', new Map<String, Object>{
                'totalCount' => 0,
                'openCount' => 0,
                'mergedCount' => 0,
                'closedCount' => 0,
                'prodPRsCount' => 0
            });
            return errorResult;
        }
    }

    // FIXED: Method to refresh GitHub data - calls GitHubService.getMyPullRequests
    @AuraEnabled
    public static String refreshGitHubData(String repoOwner, String repoName, String githubUsername) {
        try {
            // Call the method from GitHubService class (not from this class)
            List<Map<String, Object>> prs = GitHubService.getMyPullRequests(repoOwner, repoName, githubUsername);
            return 'Successfully refreshed ' + prs.size() + ' pull requests from GitHub API';
        } catch (Exception e) {
            throw new AuraHandledException('Failed to refresh GitHub data: ' + e.getMessage());
        }
    }
}