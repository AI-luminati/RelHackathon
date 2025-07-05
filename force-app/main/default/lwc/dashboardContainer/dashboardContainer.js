// dashboardContainer.js
import { LightningElement, wire, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import getCurrentUserInfo from '@salesforce/apex/DashboardController.getCurrentUserInfo';
import getScheduledJobs from '@salesforce/apex/DashboardController.getScheduledJobs';
import getApexClassesInfo from '@salesforce/apex/DashboardController.getApexClassesInfo';
import getApiUsage from '@salesforce/apex/DashboardController.getApiUsage';
import getPermissionsInfo from '@salesforce/apex/DashboardController.getPermissionsInfo';
import getTrailheadData from '@salesforce/apex/TrailheadService.getTrailheadData';


export default class DashboardContainer extends LightningElement {
    @track isDarkMode = false;

    @track trailheadInfo = null;
    @track recommendedBadges = [];
    
    // Initialize with default empty structures to prevent undefined errors
    @track userInfo = {
        Name: '',
        Email: '',
        SmallPhotoUrl: ''
    };
    
    @track scheduledJobs = {
        upcomingJobs: [],
        succeededJobs: [],
        failedJobs: [],
        myJobs: [],
        upcomingCount: 0,
        succeededCount: 0,
        failedCount: 0
    };
    
    @track apexClasses = {
        classes: [],
        myClasses: [],
        lowCoverageClasses: [],
        classCount: 0,
        myClassesCount: 0,
        lowCoverageCount: 0,
        canViewDetails: false
    };
    
    @track apiUsage = {
        limit: 0,
        used: 0,
        remaining: 0
    };
    
    @track permissions = {
        permissions: [],
        myPermissions: [],
        permissionCount: 0,
        userPermissionCount: 0,
        myPermissionCount: 0,
        canViewAllPerms: false,
        viewType: ''
    };
    
    @track isLoading = true;
    @track error = null;
    
    // Tab state
    @track activeTab = 'upcoming';
    @track activeSection = 'running'; // 'running' or 'myJobs'
    
    // Sorting state
    @track sortField = 'NextFireTime';
    @track sortDirection = 'asc';
    @track displayedJobs = [];

    connectedCallback() {
        // Load data - no localStorage usage
        this.loadAllData();
    }

    // Wire methods for data retrieval
    @wire(getCurrentUserInfo)
    wiredUserInfo({ error, data }) {
        if (data) {
            this.userInfo = { ...this.userInfo, ...data };
            this.error = null;
        } else if (error) {
            this.error = error;
            console.error('Error loading user info', error);
        }
    }

    @wire(getScheduledJobs)
    wiredScheduledJobs({ error, data }) {
        if (data) {
            // Format dates for display and ensure all arrays exist
            const formattedJobs = this.formatJobDates(data);
            this.scheduledJobs = {
                upcomingJobs: formattedJobs.upcomingJobs || [],
                succeededJobs: formattedJobs.succeededJobs || [],
                failedJobs: formattedJobs.failedJobs || [],
                myJobs: formattedJobs.myJobs || [],
                upcomingCount: formattedJobs.upcomingCount || 0,
                succeededCount: formattedJobs.succeededCount || 0,
                failedCount: formattedJobs.failedCount || 0
            };
            this.updateDisplayedJobs();
            this.error = null;
        } else if (error) {
            this.error = error;
            console.error('Error loading scheduled jobs', error);
        }
        this.isLoading = false;
    }

    @wire(getApexClassesInfo)
    wiredApexClasses({ error, data }) {
        if (data) {
            this.apexClasses = {
                classes: data.classes || [],
                myClasses: data.myClasses || [],
                lowCoverageClasses: data.lowCoverageClasses || [],
                classCount: data.classCount || 0,
                myClassesCount: data.myClassesCount || 0,
                lowCoverageCount: data.lowCoverageCount || 0,
                canViewDetails: data.canViewDetails || false
            };
            this.error = null;
        } else if (error) {
            this.error = error;
            console.error('Error loading apex classes', error);
        }
    }

    @wire(getApiUsage)
    wiredApiUsage({ error, data }) {
        if (data) {
            this.apiUsage = {
                limit: data.limit || 0,
                used: data.used || 0,
                remaining: data.remaining || 0
            };
            this.error = null;
        } else if (error) {
            this.error = error;
            console.error('Error loading API usage', error);
        }
    }

    @wire(getPermissionsInfo)
    wiredPermissions({ error, data }) {
        if (data) {
            this.permissions = {
                permissions: data.permissions || [],
                myPermissions: data.myPermissions || [],
                permissionCount: data.permissionCount || 0,
                userPermissionCount: data.userPermissionCount || 0,
                myPermissionCount: data.myPermissionCount || 0,
                canViewAllPerms: data.canViewAllPerms || false,
                viewType: data.viewType || ''
            };
            this.error = null;
        } else if (error) {
            this.error = error;
            console.error('Error loading permissions', error);
        }
    }

    @wire(getTrailheadData)
    wiredTrailheadData({ error, data }) {
        if (data) {
            this.trailheadInfo = {
                points: data.points,
                rangerLevel: data.rangerLevel,
                superbadgesCompleted: data.superbadgesCompleted,
                badges: data.badges
            };
            this.recommendedBadges = data.recommendedModules || [];
        } else if (error) {
            this.trailheadInfo = null;
            this.recommendedBadges = [];
        }
    }

    // Helper method to format job dates
    formatJobDates(jobsData) {
        const formattedData = { ...jobsData };
        
        // Format upcoming jobs dates
        if (formattedData.upcomingJobs && Array.isArray(formattedData.upcomingJobs)) {
            formattedData.upcomingJobs = formattedData.upcomingJobs.map(job => {
                return {
                    ...job,
                    formattedNextFireTime: this.formatDateTime(job.NextFireTime),
                    formattedPreviousFireTime: this.formatDateTime(job.PreviousFireTime)
                };
            });
        }
        
        // Format succeeded jobs dates
        if (formattedData.succeededJobs && Array.isArray(formattedData.succeededJobs)) {
            formattedData.succeededJobs = formattedData.succeededJobs.map(job => {
                return {
                    ...job,
                    formattedNextFireTime: this.formatDateTime(job.NextFireTime),
                    formattedPreviousFireTime: this.formatDateTime(job.PreviousFireTime)
                };
            });
        }
        
        // Format failed jobs dates
        if (formattedData.failedJobs && Array.isArray(formattedData.failedJobs)) {
            formattedData.failedJobs = formattedData.failedJobs.map(job => {
                return {
                    ...job,
                    formattedNextFireTime: this.formatDateTime(job.NextFireTime),
                    formattedPreviousFireTime: this.formatDateTime(job.PreviousFireTime)
                };
            });
        }

        // Format my jobs dates and add status properties
        if (formattedData.myJobs && Array.isArray(formattedData.myJobs)) {
            formattedData.myJobs = formattedData.myJobs.map(job => {
                return {
                    ...job,
                    formattedNextFireTime: this.formatDateTime(job.NextFireTime),
                    formattedPreviousFireTime: this.formatDateTime(job.PreviousFireTime),
                    statusClass: this.getJobStatusClass(job.State),
                    statusLabel: job.State || 'Unknown',
                    progress: job.progress || 0
                };
            });
        }
        
        return formattedData;
    }
    
    // Helper method to get job status CSS class
    getJobStatusClass(state) {
        const baseClass = 'my-job-item';
        switch (state?.toLowerCase()) {
            case 'running':
                return `${baseClass} running`;
            case 'complete':
            case 'completed':
                return `${baseClass} completed`;
            case 'failed':
            case 'error':
                return `${baseClass} failed`;
            case 'waiting':
            case 'queued':
                return `${baseClass} waiting`;
            default:
                return baseClass;
        }
    }
    
    // Helper method to format date time
    formatDateTime(dateTimeStr) {
        if (!dateTimeStr) return 'N/A';
        
        try {
            const date = new Date(dateTimeStr);
            return new Intl.DateTimeFormat('en-US', {
                year: 'numeric',
                month: 'short',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            }).format(date);
        } catch (e) {
            return 'Invalid Date';
        }
    }

    // Load all data
    loadAllData() {
        this.isLoading = true;
        // Wire services will handle the actual loading
        // Set a timeout to hide loading if wire services take too long
        setTimeout(() => {
            if (this.isLoading) {
                this.isLoading = false;
            }
        }, 5000);
    }

    // Refresh data
    refreshData() {
        this.isLoading = true;
        
        // In a real implementation, you would refresh the wire services
        // For now, simulate refresh with timeout
        setTimeout(() => {
            this.isLoading = false;
        }, 1000);
    }

    // Handle theme toggle
    handleThemeToggle(event) {
        this.isDarkMode = event.target.checked;
        // Note: Cannot use localStorage in LWC, consider using custom settings instead
    }

    // Section navigation methods
    showRunningJobs() {
        this.activeSection = 'running';
        this.activeTab = 'upcoming'; // Reset to first tab when switching sections
        this.updateDisplayedJobs();
    }

    showMyJobs() {
        this.activeSection = 'myJobs';
        this.updateDisplayedJobs();
    }

    // Tab navigation methods
    showUpcomingJobs() {
        this.activeTab = 'upcoming';
        this.updateDisplayedJobs();
    }

    showSucceededJobs() {
        this.activeTab = 'succeeded';
        this.updateDisplayedJobs();
    }

    showFailedJobs() {
        this.activeTab = 'failed';
        this.updateDisplayedJobs();
    }

    // Update displayed jobs based on active tab and sorting
    updateDisplayedJobs() {
        let jobs = [];
        
        if (this.activeSection === 'myJobs') {
            // No sorting needed for my jobs section
            return;
        }
        
        if (this.activeTab === 'upcoming') {
            jobs = [...(this.scheduledJobs.upcomingJobs || [])];
        } else if (this.activeTab === 'succeeded') {
            jobs = [...(this.scheduledJobs.succeededJobs || [])];
        } else if (this.activeTab === 'failed') {
            jobs = [...(this.scheduledJobs.failedJobs || [])];
        }
        
        // Apply sorting
        this.displayedJobs = this.sortData(jobs, this.sortField, this.sortDirection);
    }

    // Sorting methods
    sortData(data, field, direction) {
        if (!Array.isArray(data)) return [];
        
        const cloneData = [...data];
        
        cloneData.sort((a, b) => {
            let valueA, valueB;
            
            // Handle nested fields
            if (field === 'CronJobDetail.Name') {
                valueA = a.CronJobDetail?.Name || '';
                valueB = b.CronJobDetail?.Name || '';
            } else if (field === 'CreatedBy.Name') {
                valueA = a.CreatedBy?.Name || '';
                valueB = b.CreatedBy?.Name || '';
            } else {
                valueA = a[field] || '';
                valueB = b[field] || '';
            }
            
            // Handle date fields
            if (field === 'NextFireTime' || field === 'PreviousFireTime') {
                valueA = valueA ? new Date(valueA) : new Date(0);
                valueB = valueB ? new Date(valueB) : new Date(0);
            }
            
            // Compare values
            let result = 0;
            if (valueA > valueB) {
                result = 1;
            } else if (valueA < valueB) {
                result = -1;
            }
            
            // Apply direction
            return direction === 'asc' ? result : -result;
        });
        
        return cloneData;
    }

    // Sort handlers
    sortByJobName() {
        this.updateSorting('CronJobDetail.Name');
    }

    sortByNextRun() {
        this.updateSorting('NextFireTime');
    }

    sortByLastRun() {
        this.updateSorting('PreviousFireTime');
    }

    sortByState() {
        this.updateSorting('State');
    }

    sortByCreatedBy() {
        this.updateSorting('CreatedBy.Name');
    }

    updateSorting(field) {
        const direction = this.sortField === field && this.sortDirection === 'asc' ? 'desc' : 'asc';
        this.sortField = field;
        this.sortDirection = direction;
        this.updateDisplayedJobs();
    }

    // Computed properties
    get containerClass() {
        return this.isDarkMode ? 'dashboard-container dark-theme' : 'dashboard-container light-theme';
    }

    get apiUsagePercentage() {
        if (!this.apiUsage.limit || this.apiUsage.limit === 0) return 0;
        return Math.round((this.apiUsage.used / this.apiUsage.limit) * 100);
    }

    get apiUsageStyle() {
        const percentage = this.apiUsagePercentage;
        let colorClass = 'var(--success-color)';
        
        if (percentage > 90) {
            colorClass = 'var(--error-color)';
        } else if (percentage > 70) {
            colorClass = 'var(--warning-color)';
        }
        
        return `width: ${percentage}%; background-color: ${colorClass}`;
    }

    // Section classes
    get runningJobsSectionClass() {
        return this.activeSection === 'running' ? 'section-tab active' : 'section-tab';
    }

    get myJobsSectionClass() {
        return this.activeSection === 'myJobs' ? 'section-tab active' : 'section-tab';
    }

    // Tab classes
    get upcomingTabClass() {
        return this.activeTab === 'upcoming' ? 'tab active' : 'tab';
    }

    get succeededTabClass() {
        return this.activeTab === 'succeeded' ? 'tab active' : 'tab';
    }

    get failedTabClass() {
        return this.activeTab === 'failed' ? 'tab active' : 'tab';
    }

    // Section visibility
    get isRunningJobsSectionActive() {
        return this.activeSection === 'running';
    }

    get isMyJobsSectionActive() {
        return this.activeSection === 'myJobs';
    }

    // Tab visibility
    get isUpcomingTabActive() {
        return this.activeTab === 'upcoming';
    }

    get isSucceededTabActive() {
        return this.activeTab === 'succeeded';
    }

    get isFailedTabActive() {
        return this.activeTab === 'failed';
    }

    // Sort indicators
    get isSortedByJobName() {
        return this.sortField === 'CronJobDetail.Name';
    }

    get isSortedByNextRun() {
        return this.sortField === 'NextFireTime';
    }

    get isSortedByLastRun() {
        return this.sortField === 'PreviousFireTime';
    }

    get isSortedByState() {
        return this.sortField === 'State';
    }

    get isSortedByCreatedBy() {
        return this.sortField === 'CreatedBy.Name';
    }

    get jobNameSortIcon() {
        return this.sortDirection === 'asc' ? 'utility:arrowup' : 'utility:arrowdown';
    }

    get nextRunSortIcon() {
        return this.sortDirection === 'asc' ? 'utility:arrowup' : 'utility:arrowdown';
    }

    get lastRunSortIcon() {
        return this.sortDirection === 'asc' ? 'utility:arrowup' : 'utility:arrowdown';
    }

    get stateSortIcon() {
        return this.sortDirection === 'asc' ? 'utility:arrowup' : 'utility:arrowdown';
    }

    get createdBySortIcon() {
        return this.sortDirection === 'asc' ? 'utility:arrowup' : 'utility:arrowdown';
    }
}