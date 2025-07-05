import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';

import getMyScheduledJobsPagedApex from '@salesforce/apex/DashboardController.getMyScheduledJobsPaged';
import getSystemScheduledJobsPagedApex from '@salesforce/apex/DashboardController.getSystemScheduledJobsPaged';
// Import other paginated Apex methods as you create them

const PAGE_SIZE = 10;

export default class FullListPage extends NavigationMixin(LightningElement) {
    @track pageTitle = 'Full List';
    @track listType;
    @track columns = [];
    @track records = [];
    @track pageNumber = 1;
    @track pageSize = PAGE_SIZE;
    @track totalRecords = 0;
    @track totalPages = 0;
    @track isLoading = true;
    @track errorText = '';

    @track currentUserId; // For methods that need it (like myScheduledJobs, or system jobs if user lacks perm)
    @track parentIsDarkMode = false;
    @track dashboardPageApiName = 'Home'; // Default, should be passed from previous page state

    @wire(CurrentPageReference)
    processPageReference(currentPageReference) {
        if (currentPageReference && currentPageReference.state) {
            const state = currentPageReference.state;
            this.listType = state.c__listType;
            this.pageTitle = state.c__pageTitle || 'Full List';
            this.currentUserId = state.c__userId;
            this.parentIsDarkMode = state.c__isDarkMode === 'true';
            this.dashboardPageApiName = state.c__dashboardPageApiName || this.dashboardPageApiName;
            
            this.pageNumber = 1; // Reset page number on new list type or state change
            this.setupColumns();
            this.fetchData();
        }
    }

    setupColumns() {
        switch (this.listType) {
            case 'myScheduledJobs':
            case 'upcomingScheduledJobs':
            case 'succeededScheduledJobs':
            case 'failedScheduledJobs':
                this.columns = [
                    { label: 'Job Name', fieldName: 'CronJobDetailName', type: 'text', wrapText: true, initialWidth: 350 },
                    { label: 'Next Run', fieldName: 'FormattedNextFireTime', type: 'text', initialWidth: 200 },
                    { label: 'Last Run', fieldName: 'FormattedPreviousFireTime', type: 'text', initialWidth: 200 },
                    { label: 'State', fieldName: 'State', type: 'text', initialWidth: 120 },
                    { label: 'Submitted By', fieldName: 'CreatedByName', type: 'text', initialWidth: 180 }
                ];
                break;
            // Add cases for 'myApexClasses', 'lowCoverageApexClasses', 'myPermissions'
            // Example for a generic list:
            // case 'genericList':
            //     this.columns = [
            //         { label: 'Name', fieldName: 'Name', type: 'text' },
            //         { label: 'Details', fieldName: 'Details', type: 'text' }
            //     ];
            //     break;
            default:
                this.columns = [{ label: 'Name', fieldName: 'Name', type: 'text' }]; 
        }
    }

    async fetchData() {
        this.isLoading = true;
        this.errorText = '';
        try {
            let result;
            switch (this.listType) {
                case 'myScheduledJobs':
                    result = await getMyScheduledJobsPagedApex({ 
                        createdById: this.currentUserId, 
                        pageSize: this.pageSize, 
                        pageNumber: this.pageNumber 
                    });
                    break;
                case 'upcomingScheduledJobs':
                    result = await getSystemScheduledJobsPagedApex({
                        jobStateCategory: 'upcoming',
                        currentUserId: this.currentUserId, // Apex handles permission check
                        pageSize: this.pageSize,
                        pageNumber: this.pageNumber
                    });
                    break;
                case 'succeededScheduledJobs':
                     result = await getSystemScheduledJobsPagedApex({
                        jobStateCategory: 'succeeded',
                        currentUserId: this.currentUserId,
                        pageSize: this.pageSize,
                        pageNumber: this.pageNumber
                    });
                    break;
                case 'failedScheduledJobs':
                     result = await getSystemScheduledJobsPagedApex({
                        jobStateCategory: 'failed',
                        currentUserId: this.currentUserId,
                        pageSize: this.pageSize,
                        pageNumber: this.pageNumber
                    });
                    break;
                default:
                    console.error(`Unsupported list type: ${this.listType}`);
                    this.errorText = `Configuration error: List type "${this.listType}" is not supported.`;
                    this.records = []; this.totalRecords = 0; this.totalPages = 0;
                    this.isLoading = false;
                    return;
            }

            if (result) {
                this.records = result.records;
                this.pageNumber = result.pageNumber;
                this.pageSize = result.pageSize;
                this.totalRecords = result.totalRecords;
                this.totalPages = result.totalPages;
            } else {
                this.records = []; this.totalRecords = 0; this.totalPages = 0;
            }
        } catch (error) {
            console.error('Error fetching data for fullListPage:', error);
            this.errorText = this.reduceErrors(error).join(', ');
            this.records = []; this.totalRecords = 0; this.totalPages = 0;
        } finally {
            this.isLoading = false;
        }
    }

    handlePrevious() {
        if (this.pageNumber > 1) {
            this.pageNumber--;
            this.fetchData();
        }
    }

    handleNext() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber++;
            this.fetchData();
        }
    }

    handleGoBack() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: this.dashboardPageApiName 
            }
        }).catch(error => {
            console.warn('Navigation to dashboard failed, trying history.back():', error);
            window.history.back(); // Fallback
        });
    }

    get hasRecords() {
        return this.records && this.records.length > 0;
    }
    get isPreviousDisabled() {
        return this.isLoading || this.pageNumber <= 1;
    }
    get isNextDisabled() {
        return this.isLoading || this.pageNumber >= this.totalPages;
    }
    get containerClass() {
        return this.parentIsDarkMode ? 'full-list-page-container dark-theme-on-full-page slds-text-color_inverse-weak' : 'full-list-page-container slds-text-color_default';
    }

    reduceErrors(errors) {
        if (!Array.isArray(errors)) errors = [errors];
        return errors
            .filter(error => !!error)
            .map(error => {
                if (Array.isArray(error.body)) return error.body.map(e => e.message);
                if (error.body && typeof error.body.message === 'string') return error.body.message;
                if (typeof error.message === 'string') return error.message;
                return 'Unknown error';
            })
            .reduce((prev, curr) => prev.concat(curr), [])
            .filter(message => !!message);
    }
}