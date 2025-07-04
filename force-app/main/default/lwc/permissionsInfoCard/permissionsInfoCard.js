// permissionsInfoCard.js
import { LightningElement, api } from 'lwc';

export default class PermissionInfoCard extends LightningElement {
    @api permissionsData = {
        permissions: [],
        myPermissions: [],
        permissionCount: 0,
        userPermissionCount: 0,
        myPermissionCount: 0,
        canViewAllPerms: false,
        viewType: ''
    };
    @api currentUserId; // To receive the current user's ID from the parent

    handleRefresh() {
        this.dispatchEvent(new CustomEvent('refreshrequest'));
    }

    get viewAccessLabel() {
        return this.permissionsData.canViewAllPerms ? 'Administrator View' : 'User View (Assigned)';
    }

    get myPermissionsWithClass() {
        // Ensure myPermissions is an array before mapping
        return (this.permissionsData.myPermissions || []).map(perm => ({
            ...perm,
            badgeClass: perm.IsCustom ? 'badge admin' : 'badge active',
            permissionType: perm.IsCustom ? 'Custom' : 'Standard'
        }));
    }

    get permissionSetsSetupLink() {
        return '/lightning/setup/PermSets/home';
    }
    get userProfileLink() {
        // This is the getter that needs to be changed for the "ON USER" stat
        if (this.currentUserId) {
            // Construct the specific "Manage User" setup URL for the current user
            const addressParamValue = `/${this.currentUserId}?noredirect=1&isUserEntityOverride=1`;
            const encodedAddressParam = encodeURIComponent(addressParamValue);
            
            return `/lightning/setup/ManageUsers/page?address=${encodedAddressParam}`;
        }
        return '#'; // Fallback if no currentUserId
    }
}