public with sharing class GitHubService {
    private static final String GITHUB_API = 'callout:GitHub';
 
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getMyPullRequests(String repoOwner, String repoName, String githubUsername) {
        String pullsUrl = GITHUB_API + '/repos/' + repoOwner + '/' + repoName + '/pulls?state=all';
       // String pullsUrl = GITHUB_API + '/repos/' + repoOwner + '/' + repoName + '/pulls';
 
        System.debug('### Step 1: Building GitHub PR URL → ' + pullsUrl);
 
        HttpRequest req = new HttpRequest();
        req.setEndpoint(pullsUrl);
        req.setMethod('GET');
        req.setHeader('Accept', 'application/vnd.github.v3+json');
        System.debug('### Step 2: Preparing GitHub request headers.');
 
        Http http = new Http();
        HttpResponse res = http.send(req);
        System.debug('### Step 3: GitHub response status → ' + res.getStatus());
        System.debug('### Step 4: GitHub raw response body → ' + res.getBody());
 
        if (res.getStatusCode() != 200) {
            System.debug('### ERROR: GitHub API call failed.');
            throw new AuraHandledException('GitHub API call failed: ' + res.getStatus());
        }
 
        List<Object> rawList = (List<Object>) JSON.deserializeUntyped(res.getBody());
        System.debug('### rawList → ' + rawList);
        System.debug('### Step 5: Number of PRs fetched → ' + rawList.size());
 
        // Count PRs by state and creator
        Integer openPRs = 0;
        Integer closedPRs = 0;
        Map<String, Integer> prsByCreator = new Map<String, Integer>();
        List<GitHub_Details__c> prsToUpsert = new List<GitHub_Details__c>();
        
        for (Object item : rawList) {
            Map<String, Object> pr = (Map<String, Object>) item;
            String state = String.valueOf(pr.get('state'));
            Map<String, Object> user = (Map<String, Object>) pr.get('user');
            String creator = user != null ? String.valueOf(user.get('login')) : 'Unknown';
            Integer prNumber = Integer.valueOf(pr.get('number'));
            
            // Get source and target branch info
            Map<String, Object> head = (Map<String, Object>) pr.get('head');
            Map<String, Object> base = (Map<String, Object>) pr.get('base');
            String sourceBranch = head != null ? String.valueOf(head.get('ref')) : '';
            String targetBranch = base != null ? String.valueOf(base.get('ref')) : '';
            
            // Get reviewers information
            List<String> reviewers = getReviewers(repoOwner, repoName, prNumber);
            String reviewersString = String.join(reviewers, ', ');
            
            if (state == 'open') {
                openPRs++;
            } else {
                closedPRs++;
            }
            
            if (!prsByCreator.containsKey(creator)) {
                prsByCreator.put(creator, 0);
            }
            prsByCreator.put(creator, prsByCreator.get(creator) + 1);

            // Create PR record
            GitHub_Details__c prRecord = new GitHub_Details__c(
                Name = 'PR-' + String.valueOf(prNumber),
                PR_Number__c = prNumber,
                Title__c = String.valueOf(pr.get('title')),
                PR_URL__c = String.valueOf(pr.get('html_url')),
                State__c = pr.get('merged_at') != null ? 'Merged' : (state == 'open' ? 'Open' : 'Closed'),
                Created_By__c = creator,
                Source_Branch__c = sourceBranch,
                Target_Branch__c = targetBranch,
                Repository__c = repoOwner + '/' + repoName,
                Reviewers__c = reviewersString
            );
            
            prsToUpsert.add(prRecord);
        }
        
        // Save PR records
        if (!prsToUpsert.isEmpty()) {
            try {
                upsert prsToUpsert PR_Number__c;
                System.debug('### Successfully saved ' + prsToUpsert.size() + ' PR records');
            } catch (DmlException e) {
                System.debug('### ERROR: Failed to save PR records: ' + e.getMessage());
                throw new AuraHandledException('Failed to save PR records: ' + e.getMessage());
            }
        }
        
        System.debug('### PR Statistics:');
        System.debug('### - Total PRs: ' + rawList.size());
        System.debug('### - Open PRs: ' + openPRs);
        System.debug('### - Closed PRs: ' + closedPRs);
        System.debug('### - PRs by Creator:');
        for (String creator : prsByCreator.keySet()) {
            System.debug('###   ' + creator + ': ' + prsByCreator.get(creator) + ' PR(s)');
        }
        
        List<Map<String, Object>> result = new List<Map<String, Object>>();
 
        for (Object item : rawList) {
            Map<String, Object> pr = (Map<String, Object>) item;
            System.debug('### Processing PR object → ' + pr);
 
            Map<String, Object> user = (Map<String, Object>) pr.get('user');
            String login = user != null ? String.valueOf(user.get('login')) : '';
            System.debug('### PR Created by → ' + login);
 
            if (login != githubUsername) {
                System.debug('### Skipping PR not created by the current user → ' + login);
                continue;
            }
 
            Map<String, Object> prInfo = new Map<String, Object>();
 
            // Basic info
            prInfo.put('title', pr.get('title'));
            prInfo.put('url', pr.get('html_url'));
            prInfo.put('created_at', pr.get('created_at'));
            System.debug('### PR Title: ' + pr.get('title'));
            System.debug('### PR URL: ' + pr.get('html_url'));
            System.debug('### PR Created At: ' + pr.get('created_at'));
 
            // Source/Target branches
            Map<String, Object> head = (Map<String, Object>) pr.get('head');
            Map<String, Object> base = (Map<String, Object>) pr.get('base');
 
            String sourceBranch = head != null ? String.valueOf(head.get('ref')) : '';
            String targetBranch = base != null ? String.valueOf(base.get('ref')) : '';
 
            prInfo.put('sourceBranch', sourceBranch);
            prInfo.put('targetBranch', targetBranch);
 
            System.debug('### Source Branch: ' + sourceBranch);
            System.debug('### Target Branch: ' + targetBranch);
 
            // Status
            String prState = String.valueOf(pr.get('state'));
            Boolean isMerged = pr.containsKey('merged_at') && pr.get('merged_at') != null;
 
            String status = isMerged ? 'Merged' : prState;
            prInfo.put('status', status);
 
            System.debug('### PR State: ' + prState);
            System.debug('### PR Merged? ' + isMerged);
            System.debug('### Final Status: ' + status);
 
            // Prod check
            Boolean pushedToProd = targetBranch == 'main' || targetBranch == 'master';
            prInfo.put('pushedToProd', pushedToProd);
            System.debug('### Is Target Prod? ' + pushedToProd);
 
            // Pull number
            Integer prNumber = Integer.valueOf(pr.get('number'));
            System.debug('### PR Number for Reviews → ' + prNumber);
 
            // Get approvers (inline here — not @future for immediate return)
            List<String> approvers = getApproversInline(repoOwner, repoName, prNumber);
            prInfo.put('approvers', approvers);
 
            System.debug('### Final PR Info → ' + prInfo);
            result.add(prInfo);
        }
 
        System.debug('### Total PRs Returned to LWC → ' + result.size());
        return result;
    }
 
    // Inline reviewer fetch
   public static List<String> getApproversInline(String repoOwner, String repoName, Integer pullNumber) {
    List<String> reviewerUsers = new List<String>();
    String reviewUrl = GITHUB_API + '/repos/' + repoOwner + '/' + repoName + '/pulls/' + pullNumber + '/reviews';
    System.debug('### Fetching reviewers from URL → ' + reviewUrl);
 
    try {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(reviewUrl);
        req.setMethod('GET');
        req.setHeader('Accept', 'application/vnd.github.v3+json');
 
        Http http = new Http();
        HttpResponse res = http.send(req);
 
        System.debug('### Review API Status: ' + res.getStatusCode());
        System.debug('### Review API Body: ' + res.getBody());
 
        if (res.getStatusCode() == 200) {
            List<Object> reviews = (List<Object>) JSON.deserializeUntyped(res.getBody());
 
            for (Object obj : reviews) {
                Map<String, Object> review = (Map<String, Object>) obj;
                String state = String.valueOf(review.get('state'));
 
                Map<String, Object> reviewer = (Map<String, Object>) review.get('user');
                String reviewerName = reviewer != null ? String.valueOf(reviewer.get('login')) : 'Unknown';
 
                System.debug('### Reviewer: ' + reviewerName + ' | State: ' + state);
 
                // Only add unique approved reviewers (avoid duplicates)
                if ('APPROVED'.equalsIgnoreCase(state) && !reviewerUsers.contains(reviewerName)) {
                    reviewerUsers.add(reviewerName);
                }
            }
        } else {
            System.debug('### Review API Call Failed with Status: ' + res.getStatusCode());
        }
    } catch (Exception e) {
        System.debug('### Error Fetching Approvers: ' + e.getMessage());
    }
 
    return reviewerUsers;
  }

    private static List<String> getReviewers(String repoOwner, String repoName, Integer prNumber) {
        Set<String> uniqueReviewers = new Set<String>(); // To avoid duplicates
        
        // First, get assigned reviewers
        String assignedReviewersUrl = GITHUB_API + '/repos/' + repoOwner + '/' + repoName + '/pulls/' + prNumber + '/requested_reviewers';
        System.debug('### Fetching assigned reviewers from URL → ' + assignedReviewersUrl);
        
        try {
            HttpRequest reqAssigned = new HttpRequest();
            reqAssigned.setEndpoint(assignedReviewersUrl);
            reqAssigned.setMethod('GET');
            reqAssigned.setHeader('Accept', 'application/vnd.github.v3+json');
            
            Http http = new Http();
            HttpResponse resAssigned = http.send(reqAssigned);
            
            System.debug('### Assigned Reviewers API Response Status: ' + resAssigned.getStatusCode());
            System.debug('### Assigned Reviewers API Response Body: ' + resAssigned.getBody());
            
            if (resAssigned.getStatusCode() == 200) {
                Map<String, Object> assignedData = (Map<String, Object>) JSON.deserializeUntyped(resAssigned.getBody());
                List<Object> requestedReviewers = (List<Object>) assignedData.get('users');
                
                if (requestedReviewers != null) {
                    System.debug('### Number of assigned reviewers found: ' + requestedReviewers.size());
                    
                    for (Object reviewer : requestedReviewers) {
                        Map<String, Object> reviewerMap = (Map<String, Object>) reviewer;
                        String reviewerName = String.valueOf(reviewerMap.get('login'));
                        uniqueReviewers.add(reviewerName + ' (Assigned)');
                        System.debug('### Added assigned reviewer: ' + reviewerName);
                    }
                }
            }
        } catch (Exception e) {
            System.debug('### ERROR: Failed to fetch assigned reviewers: ' + e.getMessage());
        }
        
        // Then, get submitted reviews
        String reviewsUrl = GITHUB_API + '/repos/' + repoOwner + '/' + repoName + '/pulls/' + prNumber + '/reviews';
        System.debug('### Fetching submitted reviews from URL → ' + reviewsUrl);
        
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(reviewsUrl);
            req.setMethod('GET');
            req.setHeader('Accept', 'application/vnd.github.v3+json');
            System.debug('### Preparing review request for PR #' + prNumber);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('### Review API Response Status: ' + res.getStatusCode());
            System.debug('### Review API Response Body: ' + res.getBody());
            
            if (res.getStatusCode() == 200) {
                List<Object> reviews = (List<Object>) JSON.deserializeUntyped(res.getBody());
                System.debug('### Number of reviews found: ' + reviews.size());
                
                for (Object review : reviews) {
                    Map<String, Object> reviewMap = (Map<String, Object>) review;
                    Map<String, Object> user = (Map<String, Object>) reviewMap.get('user');
                    String reviewState = String.valueOf(reviewMap.get('state'));
                    String reviewBody = String.valueOf(reviewMap.get('body'));
                    Datetime reviewSubmittedAt = reviewMap.get('submitted_at') != null ? 
                        (Datetime)JSON.deserialize('"' + String.valueOf(reviewMap.get('submitted_at')) + '"', Datetime.class) : null;
                    
                    System.debug('### Review Details:');
                    System.debug('### - State: ' + reviewState);
                    System.debug('### - Submitted At: ' + reviewSubmittedAt);
                    System.debug('### - Comment: ' + (String.isBlank(reviewBody) ? 'No comment provided' : reviewBody));
                    
                    if (user != null) {
                        String reviewerName = String.valueOf(user.get('login'));
                        System.debug('### - Reviewer: ' + reviewerName);
                        // Only add reviewers who have submitted a review
                        if (reviewState == 'APPROVED' || reviewState == 'CHANGES_REQUESTED' || reviewState == 'COMMENTED') {
                            String reviewInfo = reviewerName + ' (' + reviewState + 
                                (reviewSubmittedAt != null ? ' on ' + reviewSubmittedAt.format('MMM d, yyyy HH:mm:ss') : '') + ')';
                            uniqueReviewers.add(reviewInfo);
                            System.debug('### Added reviewer with state: ' + reviewInfo);
                        }
                    }
                }
            } else {
                System.debug('### WARNING: Failed to get reviews. Status Code: ' + res.getStatusCode());
                System.debug('### Error Response: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('### ERROR: Failed to fetch reviewers: ' + e.getMessage());
            System.debug('### Error Stack Trace: ' + e.getStackTraceString());
        }
        
        List<String> reviewers = new List<String>(uniqueReviewers);
        System.debug('### Final list of all reviewers for PR #' + prNumber + ': ' + reviewers);
        return reviewers;
    }
}