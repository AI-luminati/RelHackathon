import { LightningElement, track } from 'lwc';

export default class DocumentationCard extends LightningElement {
    @track isLoading = false;
    @track error = null;
    @track documentationData = [];
    @track docTitle = '';
    @track docContent = '';
    @track isModalOpen = false;
    @track acceptedFormats = ['.jpg', '.jpeg', '.png', '.pdf', '.docx'];

    connectedCallback() {
        this.loadDocumentationData();
    }

    loadDocumentationData() {
        this.isLoading = true;
        try {
            // Simulated data for demo
            this.documentationData = [
                { id: 1, title: 'Project Overview', description: 'General project documentation.', url: 'https://sharepoint.com/' },
                { id: 2, title: 'API Documentation', description: 'Details about project APIs.', url: 'https://sharepoint.com/' },
                { id: 3, title: 'Release Notes', description: 'Changelog for version updates.', url: 'https://sharepoint.com/' }
            ];
            this.error = null;
        } catch (error) {
            this.error = error.message;
            console.error('Error loading documentation data:', error);
        } finally {
            this.isLoading = false;
        }
    }
    handleRefreshRequest() {
        this.dispatchEvent(new CustomEvent('refreshrequest', {
            detail: { component: 'documentation' }
        }));
        this.loadDocumentationData();
    }
    openCreateDocModal() {
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
    }

    handleRedirect(event) {
        window.open('https://sharepoint.com/', '_blank');
    }

    handleTitleChange(event) {
        this.docTitle = event.target.value;
    }

    handleContentChange(event) {
        this.docContent = event.target.value;
    }

    handleFileUpload(event) {
        console.log('Files uploaded:', event.detail.files);
    }

    saveDocumentation() {
        if (this.docTitle && this.docContent) {
            const newDoc = {
                id: Date.now(),
                title: this.docTitle,
                description: this.docContent,
                url: '#'
            };

            this.documentationData = [...this.documentationData, newDoc];
            this.docTitle = '';
            this.docContent = '';
            this.isModalOpen = false;

            alert('Your documentation has been saved!');
        } else {
            alert('Please provide both a title and content for your documentation!');
        }
    }

    get containerClass() {
        return `documentation-card ${this.isDarkModeActive ? 'dark-mode' : 'light-mode'}`;
    }

    get hasDocumentationData() {
        return this.documentationData && this.documentationData.length > 0;
    }
}