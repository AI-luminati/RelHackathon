// apiCallsCard.js
import { LightningElement, api } from 'lwc';

export default class ApiCallsCard extends LightningElement {
    @api apiUsage = {
        limit: 0,
        used: 0,
        remaining: 0
    };

    get apiUsagePercentage() {
        if (!this.apiUsage || !this.apiUsage.limit || this.apiUsage.limit === 0) return 0;
        return Math.round((this.apiUsage.used / this.apiUsage.limit) * 100);
    }

    get apiUsageStyle() {
        const percentage = this.apiUsagePercentage;
        let color = 'var(--success-color)'; // Default to success color variable
        
        if (percentage > 90) {
            color = 'var(--error-color)';
        } else if (percentage > 70) {
            color = 'var(--warning-color)';
        }
        
        return `width: ${percentage}%; background-color: ${color};`;
    }

    get usageStatusClass() {
        const percentage = this.apiUsagePercentage;
        if (percentage > 90) return 'usage-status error';
        if (percentage > 70) return 'usage-status warning';
        return 'usage-status good';
    }

    get usageStatusText() {
        const percentage = this.apiUsagePercentage;
        if (percentage > 90) return 'Critical';
        if (percentage > 70) return 'Warning';
        return 'Good';
    }
}