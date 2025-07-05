// myTableauEmbedComponent.js
import { LightningElement, api } from 'lwc';
import generateEmbeddingJwt from '@salesforce/apex/TableauJwtService.generateEmbeddingJwt'; // Adjust path if needed

export default class MyTableauEmbedComponent extends LightningElement {
    // This property will receive the List<CopilotActionOutput> from the flow output
    @api actionOutputItem; // Now expects a List

    vizUrl = '';
    prefix = '';
    suffix = '';
    errorMessage = '';
    apiLoaded = false;
    viz = null; // To hold the TableauViz instance for cleanup

    connectedCallback() {
        console.log('Tableau Embed Component connected');
        this.processActionOutput(); // Extract relevant data

        if (this.vizUrl) {
            this.checkAndEmbedViz();
        } else {
            // Error message set in processActionOutput if URL not found
        }
    }

    disconnectedCallback() {
        console.log('Tableau Embed Component disconnected');
        if (this.viz) {
            this.viz.dispose();
            this.viz = null;
            console.log('Tableau Viz disposed');
        }
    }

    processActionOutput() {
        // Expecting actionOutputItem to be a List<CopilotActionOutput>
        // Based on debug output, expecting a list with at least one item
        if (Array.isArray(this.actionOutputItem) && this.actionOutputItem.length > 0) {
            const firstItem = this.actionOutputItem[0]; // Get the first item
            if (firstItem && firstItem.type === 'copilotActionOutput/Tabelau_Display2') {
                 // Access the value and its properties
                if (firstItem.value) {
                    this.vizUrl = firstItem.value.url;
                    this.prefix = firstItem.value.prefix;
                    this.suffix = firstItem.value.suffix;
                    console.log('Extracted Viz URL:', this.vizUrl);
                    if (!this.vizUrl) {
                         this.errorMessage = 'Tableau visualization URL is missing in the output data.';
                         console.error('Tableau URL missing in output data');
                    }
                } else {
                    this.errorMessage = 'Action output item missing "value" property.';
                    console.error('Action output item missing "value" property', firstItem);
                }
            } else {
                 this.errorMessage = 'First item in output list is not the expected Tableau display type.';
                 console.error('First item in output list has wrong type', firstItem);
            }
        } else {
            this.errorMessage = 'Action output data is not a valid list or is empty.';
            console.error('Invalid action output data received', this.actionOutputItem);
        }
    }

    checkAndEmbedViz() {
        if (!this.vizUrl) {
            console.log('Cannot check for API, URL not available.');
            return;
        }
         // Check if the Tableau Embedding API is loaded globally
        if (typeof window.tableau !== 'undefined' && typeof window.tableau.embedding !== 'undefined') {
            console.log('Tableau Embedding API detected. Proceeding to embed.');
            this.apiLoaded = true;
            this.embedViz();
        } else {
            console.log('Tableau Embedding API not yet detected. Waiting...');
            // API not loaded, wait a bit and check again
            setTimeout(() => {
                this.checkAndEmbedViz();
            }, 500); // Check every 500ms
        }
    }

    async embedViz() {
        if (!this.apiLoaded || !this.vizUrl) {
            console.warn('Attempted to embed viz before API loaded or URL available.');
            return;
        }

        try {
            const jwt = await generateEmbeddingJwt();
            console.log('Received JWT (truncated):', jwt ? jwt.substring(0, 50) + '...' : 'No JWT received');

            if (!jwt) {
                 this.errorMessage = 'Failed to retrieve Tableau JWT.';
                 console.error('Failed to retrieve Tableau JWT');
                 return;
            }

            const options = {
                token: jwt,
                hideTabs: true,
                hideToolbar: true,
                onFirstInteractive: () => {
                    console.log('Viz is interactive!');
                    // Optional: Remove loading message here
                    const loadingDiv = this.template.querySelector('.loading-message');
                    if(loadingDiv) loadingDiv.style.display = 'none';
                },
                onError: (err) => {
                     this.errorMessage = 'Tableau Embedding Error: ' + (typeof err === 'object' ? JSON.stringify(err) : err);
                     console.error('Tableau Embedding Error', err);
                },
                url: this.vizUrl
            };

            const container = this.template.querySelector('.tableau-viz');
            if (!container) {
                 this.errorMessage = 'Embedding container element not found.';
                 console.error('Embedding container element not found');
                 return;
            }

            container.innerHTML = ''; // Clear previous content

            this.viz = new window.tableau.embedding.Embed(container, options);

            console.log('Tableau Embedding initiated for URL:', this.vizUrl);

        } catch (error) {
            this.errorMessage = 'Error during Tableau embedding process: ' + error.message;
            console.error('Error embedding viz', error);
        }
    }
}