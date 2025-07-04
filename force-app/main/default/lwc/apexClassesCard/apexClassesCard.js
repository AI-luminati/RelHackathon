// apexClassesCard.js
import { LightningElement, api } from 'lwc';

export default class ApexClassesCard extends LightningElement {
    _apexClassesData = { // Default empty state
        classes: [],
        myClasses: [],
        lowCoverageClasses: [],
        classCount: 0,
        myClassesCount: 0,
        lowCoverageCount: 0,
        canViewDetails: false
    };

    @api 
    get apexClassesData() {
        return this._apexClassesData;
    }
    set apexClassesData(data) {
        if (data) {
            this._apexClassesData = {
                ...this._apexClassesData, // Keep defaults for any missing properties in incoming data
                ...data,                 // Override with new data
                classes: data.classes || [], // Ensure it's an array
                myClasses: data.myClasses || [], // Ensure it's an array
                // Process lowCoverageClasses to add style upon receiving data
                lowCoverageClasses: (data.lowCoverageClasses || []).map(cls => ({
                    ...cls,
                    coverageStyle: this.getCoverageStyle(cls.coverage) // 'this' is available here
                }))
            };
        } else {
             // Reset to a well-defined empty state if null/undefined data is passed
             this._apexClassesData = { 
                classes: [], myClasses: [], lowCoverageClasses: [],
                classCount: 0, myClassesCount: 0, lowCoverageCount: 0, canViewDetails: false
            };
        }
    }

    handleRefresh() {
        this.dispatchEvent(new CustomEvent('refreshrequest'));
    }

    // This method is now used in the setter
    getCoverageStyle(coverage) {
        let color = 'var(--accent-red)'; 
        if (coverage >= 75) color = 'var(--accent-green)';
        else if (coverage >= 50) color = 'var(--accent-orange)';
        return `width: ${coverage}%; background-color: ${color};`;
    }

    get apexClassesSetupLink() {
        return '/lightning/setup/ApexClasses/home';
    }
}