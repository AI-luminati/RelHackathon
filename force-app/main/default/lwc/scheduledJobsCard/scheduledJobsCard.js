// scheduledJobsCard.js
import { LightningElement, api, track } from 'lwc';

export default class ScheduledJobsCard extends LightningElement {
    _scheduledJobsData = {
        upcomingJobs: [], succeededJobs: [], failedJobs: [], myJobs: [],
        upcomingCount: 0, succeededCount: 0, failedCount: 0, myJobsCount: 0,
        myUpcomingJobs: [], mySucceededJobs: [], myFailedJobs: [],
        myUpcomingCount: 0, mySucceededCount: 0, myFailedCount: 0
    };

    @api 
    get scheduledJobsData() {
        return this._scheduledJobsData;
    }
    set scheduledJobsData(data) {
        if (data) {
            const formattedData = this.formatJobDataInternal(data);
            this._scheduledJobsData = {
                upcomingJobs: formattedData.upcomingJobs || [],
                succeededJobs: formattedData.succeededJobs || [],
                failedJobs: formattedData.failedJobs || [],
                myJobs: formattedData.myJobs || [],
                upcomingCount: formattedData.upcomingCount || 0,
                succeededCount: formattedData.succeededCount || 0,
                failedCount: formattedData.failedCount || 0,
                myJobsCount: formattedData.myJobsCount || (formattedData.myJobs ? formattedData.myJobs.length : 0),
                myUpcomingJobs: formattedData.myUpcomingJobs || [],
                mySucceededJobs: formattedData.mySucceededJobs || [],
                myFailedJobs: formattedData.myFailedJobs || [],
                myUpcomingCount: formattedData.myUpcomingCount || 0,
                mySucceededCount: formattedData.mySucceededCount || 0,
                myFailedCount: formattedData.myFailedCount || 0
            };
            this.updateDisplayedJobs();
            this.updateDisplayedMyJobs();
        } else {
            this._scheduledJobsData = { 
                upcomingJobs: [], succeededJobs: [], failedJobs: [], myJobs: [],
                upcomingCount: 0, succeededCount: 0, failedCount: 0, myJobsCount: 0,
                myUpcomingJobs: [], mySucceededJobs: [], myFailedJobs: [],
                myUpcomingCount: 0, mySucceededCount: 0, myFailedCount: 0
            };
            this.displayedJobs = [];
            this.displayedMyJobs = [];
        }
    }
    
    @track activeTab = 'upcoming';
    @track activeSection = 'running';
    @track myActiveTab = 'upcoming'; // Separate active tab for My Jobs section
    
    @track sortField = 'NextFireTime';
    @track sortDirection = 'asc';
    @track displayedJobs = [];
    
    @track mySortField = 'NextFireTime'; // Separate sort field for My Jobs
    @track mySortDirection = 'asc'; // Separate sort direction for My Jobs
    @track displayedMyJobs = []; // Separate displayed jobs for My Jobs

    connectedCallback() {
        this.updateDisplayedJobs();
        this.updateDisplayedMyJobs();
    }

    formatJobDataInternal(jobsData) {
        if (!jobsData) return {};
        const formattedData = JSON.parse(JSON.stringify(jobsData)); 
        
        const formatList = (list) => {
            if (list && Array.isArray(list)) {
                return list.map(job => ({
                    ...job,
                    formattedNextFireTime: this.formatDateTime(job.NextFireTime),
                    formattedPreviousFireTime: this.formatDateTime(job.PreviousFireTime)
                }));
            }
            return [];
        };

        formattedData.upcomingJobs = formatList(formattedData.upcomingJobs);
        formattedData.succeededJobs = formatList(formattedData.succeededJobs);
        formattedData.failedJobs = formatList(formattedData.failedJobs);

        if (formattedData.myJobs && Array.isArray(formattedData.myJobs)) {
            formattedData.myJobs = formattedData.myJobs.map(job => {
                const formattedNext = this.formatDateTime(job.NextFireTime);
                const formattedPrev = this.formatDateTime(job.PreviousFireTime);
                const progressPercentage = job.progress || 0;

                return {
                    ...job,
                    formattedNextFireTime: formattedNext,
                    formattedNextFireTimeIsNA: formattedNext === 'N/A',
                    formattedPreviousFireTime: formattedPrev,
                    formattedPreviousFireTimeIsNA: formattedPrev === 'N/A',
                    statusClass: this.getJobStatusClass(job.State),
                    statusLabel: job.State || 'Unknown',
                    progressPercentage: progressPercentage,
                    showProgress: (job.State === 'EXECUTING' || job.State === 'Running' || job.State === 'COMPLETED' || job.State === 'Complete') && progressPercentage > 0,
                    progressColorClass: this.getProgressColorClass(job.State),
                    progressWidthStyle: `width: ${progressPercentage}%;`
                };
            });
            
            // Categorize My Jobs into upcoming, succeeded, failed
            formattedData.myUpcomingJobs = formattedData.myJobs.filter(job => 
                job.State === 'WAITING' || job.State === 'ACQUIRED' || job.State === 'EXECUTING'
            );
            formattedData.mySucceededJobs = formattedData.myJobs.filter(job => 
                job.State === 'COMPLETE' || job.State === 'DELETED'
            );
            formattedData.myFailedJobs = formattedData.myJobs.filter(job => 
                job.State === 'ERROR'
            );
            
            formattedData.myUpcomingCount = formattedData.myUpcomingJobs.length;
            formattedData.mySucceededCount = formattedData.mySucceededJobs.length;
            formattedData.myFailedCount = formattedData.myFailedJobs.length;
        } else {
            formattedData.myJobs = [];
            formattedData.myUpcomingJobs = [];
            formattedData.mySucceededJobs = [];
            formattedData.myFailedJobs = [];
            formattedData.myUpcomingCount = 0;
            formattedData.mySucceededCount = 0;
            formattedData.myFailedCount = 0;
        }
        
        formattedData.upcomingCount = formattedData.upcomingJobs.length;
        formattedData.succeededCount = formattedData.succeededJobs.length;
        formattedData.failedCount = formattedData.failedJobs.length;
        formattedData.myJobsCount = formattedData.myJobs.length;

        return formattedData;
    }
    
    getJobStatusClass(state) {
        const baseClass = 'my-job-item';
        switch (state?.toLowerCase()) {
            case 'executing':
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

    getProgressColorClass(state) {
        switch (state?.toLowerCase()) {
            case 'executing': case 'running': return 'progress-bar-info';
            case 'complete': case 'completed': return 'progress-bar-success';
            case 'failed': case 'error': return 'progress-bar-error';
            case 'waiting': case 'queued': return 'progress-bar-warning';
            default: return 'progress-bar-default'; 
        }
    }
    
    formatDateTime(dateTimeStr) {
        if (!dateTimeStr) return 'N/A';
        try {
            const date = new Date(dateTimeStr);
            if (isNaN(date.getTime())) return 'N/A';
            return new Intl.DateTimeFormat('en-US', {
                year: 'numeric', month: 'short', day: 'numeric',
                hour: '2-digit', minute: '2-digit', hour12: true
            }).format(date);
        } catch (e) {
            return 'N/A';
        }
    }

    handleRefresh() {
        this.dispatchEvent(new CustomEvent('refreshrequest'));
    }

    // Jobs Running section methods
    showRunningJobs() {
        this.activeSection = 'running';
        this.activeTab = 'upcoming'; 
        this.sortField = 'NextFireTime';
        this.sortDirection = 'asc';
        this.updateDisplayedJobs();
    }

    showMyJobs() {
        this.activeSection = 'myJobs';
        this.myActiveTab = 'upcoming';
        this.mySortField = 'NextFireTime';
        this.mySortDirection = 'asc';
        this.updateDisplayedMyJobs();
    }

    showUpcomingJobs() {
        this.activeTab = 'upcoming';
        this.sortField = 'NextFireTime';
        this.sortDirection = 'asc';
        this.updateDisplayedJobs();
    }

    showSucceededJobs() {
        this.activeTab = 'succeeded';
        this.sortField = 'PreviousFireTime';
        this.sortDirection = 'desc';
        this.updateDisplayedJobs();
    }

    showFailedJobs() {
        this.activeTab = 'failed';
        this.sortField = 'PreviousFireTime';
        this.sortDirection = 'desc';
        this.updateDisplayedJobs();
    }

    // My Jobs section methods
    showMyUpcomingJobs() {
        this.myActiveTab = 'upcoming';
        this.mySortField = 'NextFireTime';
        this.mySortDirection = 'asc';
        this.updateDisplayedMyJobs();
    }

    showMySucceededJobs() {
        this.myActiveTab = 'succeeded';
        this.mySortField = 'PreviousFireTime';
        this.mySortDirection = 'desc';
        this.updateDisplayedMyJobs();
    }

    showMyFailedJobs() {
        this.myActiveTab = 'failed';
        this.mySortField = 'PreviousFireTime';
        this.mySortDirection = 'desc';
        this.updateDisplayedMyJobs();
    }

    updateDisplayedJobs() {
        if (this.activeSection === 'myJobs') {
            this.displayedJobs = [];
            return;
        }
        
        let jobsToDisplay = [];
        if (this._scheduledJobsData) {
            if (this.activeTab === 'upcoming') {
                jobsToDisplay = [...(this._scheduledJobsData.upcomingJobs || [])];
            } else if (this.activeTab === 'succeeded') {
                jobsToDisplay = [...(this._scheduledJobsData.succeededJobs || [])];
            } else if (this.activeTab === 'failed') {
                jobsToDisplay = [...(this._scheduledJobsData.failedJobs || [])];
            }
        }
        this.displayedJobs = this.sortData(jobsToDisplay, this.sortField, this.sortDirection);
    }

    updateDisplayedMyJobs() {
        if (this.activeSection !== 'myJobs') {
            this.displayedMyJobs = [];
            return;
        }
        
        let jobsToDisplay = [];
        if (this._scheduledJobsData) {
            if (this.myActiveTab === 'upcoming') {
                jobsToDisplay = [...(this._scheduledJobsData.myUpcomingJobs || [])];
            } else if (this.myActiveTab === 'succeeded') {
                jobsToDisplay = [...(this._scheduledJobsData.mySucceededJobs || [])];
            } else if (this.myActiveTab === 'failed') {
                jobsToDisplay = [...(this._scheduledJobsData.myFailedJobs || [])];
            }
        }
        this.displayedMyJobs = this.sortData(jobsToDisplay, this.mySortField, this.mySortDirection);
    }

    handleSort(event) {
        const field = event.currentTarget.dataset.sortField;
        this.updateSorting(field);
    }

    handleMyJobsSort(event) {
        const field = event.currentTarget.dataset.sortField;
        this.updateMySorting(field);
    }
    
    updateSorting(field) {
        const newDirection = (this.sortField === field && this.sortDirection === 'asc') ? 'desc' : 'asc';
        this.sortField = field;
        this.sortDirection = newDirection;
        this.updateDisplayedJobs();
    }

    updateMySorting(field) {
        const newDirection = (this.mySortField === field && this.mySortDirection === 'asc') ? 'desc' : 'asc';
        this.mySortField = field;
        this.mySortDirection = newDirection;
        this.updateDisplayedMyJobs();
    }

    sortData(data, field, direction) {
        if (!Array.isArray(data) || data.length === 0) return [];
        
        const cloneData = [...data];
        cloneData.sort((a, b) => {
            let valA, valB;
            if (field.includes('.')) {
                const [objKey, propKey] = field.split('.');
                valA = a[objKey] ? a[objKey][propKey] : null;
                valB = b[objKey] ? b[objKey][propKey] : null;
            } else {
                valA = a[field];
                valB = b[field];
            }

            const isTimeField = field === 'NextFireTime' || field === 'PreviousFireTime';
            if (isTimeField) {
                valA = (valA && valA !== 'N/A') ? new Date(a[field]).getTime() : (direction === 'asc' ? Infinity : -Infinity);
                valB = (valB && valB !== 'N/A') ? new Date(b[field]).getTime() : (direction === 'asc' ? Infinity : -Infinity);
                 if (isNaN(valA)) valA = (direction === 'asc' ? Infinity : -Infinity);
                 if (isNaN(valB)) valB = (direction === 'asc' ? Infinity : -Infinity);
            } else {
                valA = (valA === null || valA === undefined) ? '' : String(valA).toLowerCase();
                valB = (valB === null || valB === undefined) ? '' : String(valB).toLowerCase();
            }
            
            let comparison = 0;
            if (valA > valB) comparison = 1;
            else if (valA < valB) comparison = -1;
            return direction === 'asc' ? comparison : -comparison;
        });
        return cloneData;
    }

    // Section tab classes
    get runningJobsSectionClass() { return `section-tab ${this.activeSection === 'running' ? 'active' : ''}`.trim(); }
    get myJobsSectionClass() { return `section-tab ${this.activeSection === 'myJobs' ? 'active' : ''}`.trim(); }
    
    // Running Jobs tab classes
    get upcomingTabClass() { return `tab ${this.activeTab === 'upcoming' && this.isRunningJobsSectionActive ? 'active' : ''}`.trim(); }
    get succeededTabClass() { return `tab ${this.activeTab === 'succeeded' && this.isRunningJobsSectionActive ? 'active' : ''}`.trim(); }
    get failedTabClass() { return `tab ${this.activeTab === 'failed' && this.isRunningJobsSectionActive ? 'active' : ''}`.trim(); }

    // My Jobs tab classes
    get myUpcomingTabClass() { return `tab ${this.myActiveTab === 'upcoming' && this.isMyJobsSectionActive ? 'active' : ''}`.trim(); }
    get mySucceededTabClass() { return `tab ${this.myActiveTab === 'succeeded' && this.isMyJobsSectionActive ? 'active' : ''}`.trim(); }
    get myFailedTabClass() { return `tab ${this.myActiveTab === 'failed' && this.isMyJobsSectionActive ? 'active' : ''}`.trim(); }

    // Section active state
    get isRunningJobsSectionActive() { return this.activeSection === 'running'; }
    get isMyJobsSectionActive() { return this.activeSection === 'myJobs'; }

    // Running Jobs tab active state
    get isUpcomingTabActive() { return this.activeTab === 'upcoming' && this.isRunningJobsSectionActive; }
    get isSucceededTabActive() { return this.activeTab === 'succeeded' && this.isRunningJobsSectionActive; }
    get isFailedTabActive() { return this.activeTab === 'failed' && this.isRunningJobsSectionActive; }

    // My Jobs tab active state
    get isMyUpcomingTabActive() { return this.myActiveTab === 'upcoming' && this.isMyJobsSectionActive; }
    get isMySucceededTabActive() { return this.myActiveTab === 'succeeded' && this.isMyJobsSectionActive; }
    get isMyFailedTabActive() { return this.myActiveTab === 'failed' && this.isMyJobsSectionActive; }

    // Running Jobs sort icons
    getSortIconForField(field) {
        if (this.isRunningJobsSectionActive && this.sortField === field) {
            return this.sortDirection === 'asc' ? 'utility:arrowup' : 'utility:arrowdown';
        }
        return null;
    }

    // My Jobs sort icons
    getMySortIconForField(field) {
        if (this.isMyJobsSectionActive && this.mySortField === field) {
            return this.mySortDirection === 'asc' ? 'utility:arrowup' : 'utility:arrowdown';
        }
        return null;
    }

    // Running Jobs sort state
    get isSortedByJobName() { return this.sortField === 'CronJobDetail.Name'; }
    get isSortedByNextRun() { return this.sortField === 'NextFireTime'; }
    get isSortedByLastRun() { return this.sortField === 'PreviousFireTime'; }
    get isSortedByState() { return this.sortField === 'State'; }
    get isSortedByCreatedBy() { return this.sortField === 'CreatedBy.Name'; }

    get jobNameSortIcon() { return this.getSortIconForField('CronJobDetail.Name'); }
    get nextRunSortIcon() { return this.getSortIconForField('NextFireTime'); }
    get lastRunSortIcon() { return this.getSortIconForField('PreviousFireTime'); }
    get stateSortIcon() { return this.getSortIconForField('State'); }
    get createdBySortIcon() { return this.getSortIconForField('CreatedBy.Name'); }

    // My Jobs sort state
    get isSortedByMyJobName() { return this.mySortField === 'CronJobDetail.Name'; }
    get isSortedByMyNextRun() { return this.mySortField === 'NextFireTime'; }
    get isSortedByMyLastRun() { return this.mySortField === 'PreviousFireTime'; }
    get isSortedByMyState() { return this.mySortField === 'State'; }
    get isSortedByMyCreatedBy() { return this.mySortField === 'CreatedBy.Name'; }

    get myJobNameSortIcon() { return this.getMySortIconForField('CronJobDetail.Name'); }
    get myNextRunSortIcon() { return this.getMySortIconForField('NextFireTime'); }
    get myLastRunSortIcon() { return this.getMySortIconForField('PreviousFireTime'); }
    get myStateSortIcon() { return this.getMySortIconForField('State'); }
    get myCreatedBySortIcon() { return this.getMySortIconForField('CreatedBy.Name'); }
}