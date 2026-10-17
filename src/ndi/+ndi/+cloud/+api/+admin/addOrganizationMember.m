function [b, answer, apiResponse, apiURL] = addOrganizationMember(cloudOrganizationID, cloudUserID)
%ADDORGANIZATIONMEMBER Add a user to an NDI Cloud organization by user id (admin only).
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.admin.addOrganizationMember(CLOUDORGANIZATIONID, CLOUDUSERID)
%
%   Adding a user who is already a member succeeds and changes nothing.
%   Requires an account with administrator rights; other accounts get
%   B = false and a 403 response. To add a user by email address, use
%   ndi.cloud.api.admin.addOrganizationMemberByEmail.
%
%   Inputs:
%       cloudOrganizationID - The organization's id.
%       cloudUserID         - The user's id.
%
%   Outputs:
%       b           - True if the call succeeded, false otherwise.
%       answer      - On success, the organization with its updated member
%                     list (see ndi.cloud.api.admin.getOrganization).
%                     On failure, the server's error struct (400 for a
%                     malformed id, 404 for an unknown user or organization).
%       apiResponse - The full matlab.net.http.ResponseMessage object.
%       apiURL      - The URL that was called.
%
%   See also: ndi.cloud.api.admin.addOrganizationMemberByEmail,
%             ndi.cloud.api.admin.removeOrganizationMember,
%             ndi.cloud.api.implementation.admin.AddOrganizationMember

    arguments
        cloudOrganizationID (1,1) string
        cloudUserID (1,1) string
    end

    api_call = ndi.cloud.api.implementation.admin.AddOrganizationMember( ...
        'cloudOrganizationID', cloudOrganizationID, 'cloudUserID', cloudUserID);
    [b, answer, apiResponse, apiURL] = api_call.execute();
end
