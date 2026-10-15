function [b, answer, apiResponse, apiURL] = getOrganization(cloudOrganizationID)
%GETORGANIZATION Retrieve an NDI Cloud organization and its members (admin only).
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.admin.getOrganization(CLOUDORGANIZATIONID)
%
%   Requires an account with administrator rights; other accounts get
%   B = false and a 403 response.
%
%   Inputs:
%       cloudOrganizationID - The organization's id.
%
%   Outputs:
%       b           - True if the call succeeded, false otherwise.
%       answer      - On success, the organization struct with fields 'id',
%                     'name', 'canUploadDataset', 'memberCount', 'teams' and
%                     'members' (each member has 'id', 'name' and 'email'),
%                     plus parallel cell arrays of char:
%                       memberID, memberName, memberEmail
%                     On failure, the server's error struct (400 for a
%                     malformed id, 404 for an unknown organization).
%       apiResponse - The full matlab.net.http.ResponseMessage object.
%       apiURL      - The URL that was called.
%
%   See also: ndi.cloud.api.admin.listOrganizations,
%             ndi.cloud.api.implementation.admin.GetOrganization

    arguments
        cloudOrganizationID (1,1) string
    end

    api_call = ndi.cloud.api.implementation.admin.GetOrganization( ...
        'cloudOrganizationID', cloudOrganizationID);
    [b, answer, apiResponse, apiURL] = api_call.execute();
end
