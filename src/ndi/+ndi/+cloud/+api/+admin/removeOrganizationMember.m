function [b, answer, apiResponse, apiURL] = removeOrganizationMember(cloudOrganizationID, cloudUserID)
%REMOVEORGANIZATIONMEMBER Remove a user from an NDI Cloud organization by user id (admin only).
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.admin.removeOrganizationMember(CLOUDORGANIZATIONID, CLOUDUSERID)
%
%   Removing a user who is not a member succeeds and changes nothing.
%   Requires an account with administrator rights; other accounts get
%   B = false and a 403 response.
%
%   Inputs:
%       cloudOrganizationID - The organization's id.
%       cloudUserID         - The user's id.
%
%   Outputs:
%       b           - True if the call succeeded, false otherwise.
%       answer      - On success, the organization with its updated member
%                     list (see ndi.cloud.api.admin.getOrganization).
%                     On failure, the server's error struct.
%       apiResponse - The full matlab.net.http.ResponseMessage object.
%       apiURL      - The URL that was called.
%
%   See also: ndi.cloud.api.admin.removeOrganizationMemberByEmail,
%             ndi.cloud.api.admin.addOrganizationMember,
%             ndi.cloud.api.implementation.admin.RemoveOrganizationMember

    arguments
        cloudOrganizationID (1,1) string
        cloudUserID (1,1) string
    end

    api_call = ndi.cloud.api.implementation.admin.RemoveOrganizationMember( ...
        'cloudOrganizationID', cloudOrganizationID, 'cloudUserID', cloudUserID);
    [b, answer, apiResponse, apiURL] = api_call.execute();
end
