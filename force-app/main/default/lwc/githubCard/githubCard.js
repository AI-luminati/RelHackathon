// githubCard.js
import { LightningElement, track, api } from 'lwc';
// CORRECT - these methods exist in GitHubDataService
import getGitHubDetailsFromSalesforce from '@salesforce/apex/GitHubDataService.getGitHubDetailsFromSalesforce';
import refreshGitHubData from '@salesforce/apex/GitHubDataService.refreshGitHubData';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class GithubCard extends LightningElement {
    @api isDarkModeActive = false;
    @api currentUserId;
    @api dashboardPageApiName = 'Home';

    @track pullRequestsData = {
        prs: [],
        totalCount: 0,
        openCount: 0,
        mergedCount: 0,
        closedCount: 0,
        prodPRsCount: 0,
        lastSyncDate: null,
        totalRepoRecords: 0,
        uniqueContributors: 0
    };
    
    @track isLoading = false;
    @track isRefreshing = false;
    @track error = null;
    @track showAllPRs = false;
    @track activeTab = 'overview';
    @track hasInitialLoad = false;
    @track isReady = false;

    // GitHub repository configuration
    repoOwner = 'AI-luminati';
    repoName = 'RelHackathon';
    githubUsername = 'AI-luminati';

    // Wire property to store the result for refreshApex
    _wiredResult;

    connectedCallback() {
        // Delay loading to prevent flickering and sync with parent dashboard
        setTimeout(() => {
            this.isReady = true;
            this.loadGitHubData();
        }, 300); // Small delay to let parent dashboard settle
    }

    async loadGitHubData() {
        if (!this.isReady) return; // Don't load until component is ready
        
        this.isLoading = true;
        this.error = null;
        this.hasInitialLoad = true;

        try {
            const repository = `${this.repoOwner}/${this.repoName}`;
            const result = await getGitHubDetailsFromSalesforce({
                createdBy: this.githubUsername,
                repository: repository
            });

            if (result.success) {
                this.processGitHubData(result);
            } else {
                this.error = result.error || 'Failed to load GitHub data';
            }
        } catch (error) {
            this.error = 'Failed to load GitHub data: ' + (error.body?.message || error.message);
            console.error('GitHub Data Error:', error);
        } finally {
            // Add small delay before hiding loading to reduce flicker
            setTimeout(() => {
                this.isLoading = false;
            }, 100);
        }
    }

    processGitHubData(data) {
        const prs = data.pullRequests || [];
        const stats = data.statistics || {};

        // Process each PR for display
        const processedPRs = prs.map(pr => ({
            ...pr,
            statusClass: this.getStatusClass(pr.state),
            approvers: pr.reviewers || [],
            approversText: pr.reviewersText || 'No reviewers',
            hasApprovers: pr.hasReviewers || false
        }));

        this.pullRequestsData = {
            prs: processedPRs,
            totalCount: stats.totalCount || 0,
            openCount: stats.openCount || 0,
            mergedCount: stats.mergedCount || 0,
            closedCount: stats.closedCount || 0,
            prodPRsCount: stats.prodPRsCount || 0,
            lastSyncDate: stats.lastSyncDate,
            totalRepoRecords: stats.totalRepoRecords || 0,
            uniqueContributors: stats.uniqueContributors || 0,
            contributorStats: stats.contributorStats || {}
        };
    }

    getStatusClass(status) {
        switch (status?.toLowerCase()) {
            case 'merged':
                return 'status-merged';
            case 'open':
                return 'status-open';
            case 'closed':
                return 'status-closed';
            default:
                return 'status-default';
        }
    }

    async handleRefresh() {
        this.loadGitHubData();
    }

    async handleRefreshFromAPI() {
        if (this.isRefreshing) return;
        
        this.isRefreshing = true;
        
        try {
            const message = await refreshGitHubData({
                repoOwner: this.repoOwner,
                repoName: this.repoName,
                githubUsername: this.githubUsername
            });
            
            this.showToast('Success', message, 'success');
            
            // Reload data from Salesforce after API refresh
            setTimeout(() => {
                this.loadGitHubData();
            }, 1000);
            
        } catch (error) {
            const errorMessage = error.body?.message || error.message;
            this.showToast('Error', 'Failed to refresh from GitHub API: ' + errorMessage, 'error');
            console.error('GitHub API Refresh Error:', error);
        } finally {
            this.isRefreshing = false;
        }
    }

    handleTabChange(event) {
        this.activeTab = event.target.dataset.tab;
    }

    handleToggleView() {
        this.showAllPRs = !this.showAllPRs;
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(event);
    }

    // Getters
    get displayedPRs() {
        if (this.showAllPRs) {
            return this.pullRequestsData.prs;
        }
        return this.pullRequestsData.prs.slice(0, 5);
    }

    get hasMorePRs() {
        return this.pullRequestsData.prs.length > 5;
    }

    get toggleButtonText() {
        return this.showAllPRs ? 'Show Less' : `Show All (${this.pullRequestsData.totalCount})`;
    }

    get overviewTabClass() {
        return `tab ${this.activeTab === 'overview' ? 'active' : ''}`;
    }

    get detailsTabClass() {
        return `tab ${this.activeTab === 'details' ? 'active' : ''}`;
    }

    get githubRepoUrl() {
        return `https://github.com/${this.repoOwner}/${this.repoName}`;
    }

    get isOverviewTab() {
        return this.activeTab === 'overview';
    }

    get isDetailsTab() {
        return this.activeTab === 'details';
    }

    get hasData() {
        return this.pullRequestsData.totalCount > 0;
    }

    get showInitialState() {
        return !this.hasInitialLoad && !this.isLoading && this.isReady;
    }

    get showLoadingState() {
        return this.isLoading && this.isReady;
    }

    get showMainContent() {
        return this.isReady && this.hasInitialLoad && !this.isLoading && !this.isRefreshing && !this.error;
    }

    get formattedLastSync() {
        if (!this.pullRequestsData.lastSyncDate) return 'Never';
        
        try {
            const syncDate = new Date(this.pullRequestsData.lastSyncDate);
            return syncDate.toLocaleDateString('en-US', {
                year: 'numeric',
                month: 'short',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            });
        } catch (e) {
            return 'Unknown';
        }
    }

    get repositoryName() {
        return `${this.repoOwner}/${this.repoName}`;
    }
}