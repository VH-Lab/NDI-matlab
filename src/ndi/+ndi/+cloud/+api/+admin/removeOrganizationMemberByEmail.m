function [b, answer, apiResponse, apiURL] = removeOrganizationMemberByEmail(cloudOrganizationID, email)
%REMOVEORGANIZATIONMEMBERBYEMAIL Remove a user from an NDI Cloud organization by email address (admin only).
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.admin.removeOrganizationMemberByEmail(CLOUDORGANIZATIONID, EMAIL)
%
%   Looks the user up with ndi.cloud.api.admin.findUserByEmail and then
%   calls ndi.cloud.api.admin.removeOrganizationMember. Requires an account
%   with administrator rights.
%
%   Inputs:
%       cloudOrganizationID - The organization's id.
%       email               - The user's email address (exact, any case).
%
%   Outputs:
%       b           - True if the user was found and removed, false otherwise.
%       answer      - On success, the organization with its updated member
%                     list (see ndi.cloud.api.admin.getOrganization). On
%                     failure, the error from whichever step failed.
%       apiResponse - The ResponseMessage of the last call made.
%       apiURL      - The URL of the last call made.
%
%   See also: ndi.cloud.api.admin.removeOrganizationMember,
%             ndi.cloud.api.admin.addOrganizationMemberByEmail

    arguments
        cloudOrganizationID (1,1) string
        email (1,1) string {mustBeNonzeroLengthText}
    end

    [b, user, apiResponse, apiURL] = ndi.cloud.api.admin.findUserByEmail(email);
    if ~b
        answer = user;
        return
    end
    [b, answer, apiResponse, apiURL] = ndi.cloud.api.admin.removeOrganizationMember( ...
        cloudOrganizationID, user.id);
end
