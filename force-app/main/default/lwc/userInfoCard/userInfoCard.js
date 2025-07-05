// userInfoCard.js
import { LightningElement, api } from 'lwc';

export default class UserInfoCard extends LightningElement {
    _userInfo = {
        Id: '', // Ensure Id is part of the userInfo structure
        Name: 'Loading...',
        Email: 'Loading...',
        SmallPhotoUrl: ''
    };

    @api 
    get userInfo() {
        return this._userInfo;
    }
    set userInfo(value) {
        // Ensure Id is initialized even if value is null/undefined
        this._userInfo = value ? { ...this._userInfo, ...value } : { Name: '', Email: '', SmallPhotoUrl: '', Id: ''};
    }

    get userProfileLink() {
        if (this.userInfo && this.userInfo.Id) {
            // Construct the specific "Manage User" setup URL
            const userId = this.userInfo.Id;
            // The value for the 'address' parameter needs to be URL encoded
            const addressParamValue = `/${userId}?noredirect=1&isUserEntityOverride=1`;
            const encodedAddressParam = encodeURIComponent(addressParamValue);
            
            return `/lightning/setup/ManageUsers/page?address=${encodedAddressParam}`;
        }
        return '#'; // Fallback if no user Id
    }

    get trailheadProfileLink() {
        // Direct link to your Trailhead profile
        return 'https://www.salesforce.com/trailblazer/profile';
    }
}