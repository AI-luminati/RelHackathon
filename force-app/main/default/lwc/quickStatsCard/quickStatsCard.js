// quickStatsCard.js
import { LightningElement, api } from 'lwc';

export default class QuickStatsCard extends LightningElement {
    _apexClassesData = { 
        classes: [],
        myClasses: [],
        lowCoverageClasses: [],
        classCount: 0,
        myClassesCount: 0,
        lowCoverageCount: 0,
        canViewDetails: false
    };

    _permissionsData = {
        permissions: [],
        myPermissions: [],
        permissionCount: 0,
        userPermissionCount: 0,
        myPermissionCount: 0,
        canViewAllPerms: false,
        viewType: ''
    };

    @api 
    get apexClassesData() {
        return this._apexClassesData;
    }
    set apexClassesData(data) {
        if (data) {
            this._apexClassesData = {
                ...this._apexClassesData,
                ...data,
                classes: data.classes || [],
                myClasses: data.myClasses || []
            };
        } else {
            this._apexClassesData = { 
                classes: [],
                myClasses: [],
                lowCoverageClasses: [],
                classCount: 0,
                myClassesCount: 0,
                lowCoverageCount: 0,
                canViewDetails: false
            };
        }
    }

    @api 
    get permissionsData() {
        return this._permissionsData;
    }
    set permissionsData(data) {
        if (data) {
            this._permissionsData = {
                ...this._permissionsData,
                ...data,
                permissions: data.permissions || [],
                myPermissions: data.myPermissions || []
            };
        } else {
            this._permissionsData = {
                permissions: [],
                myPermissions: [],
                permissionCount: 0,
                userPermissionCount: 0,
                myPermissionCount: 0,
                canViewAllPerms: false,
                viewType: ''
            };
        }
    }

    get apexClassesLink() {
        return '/lightning/setup/ApexClasses/home';
    }

    get permissionSetsLink() {
        return '/lightning/setup/PermSets/home';
    }
}