function [b, answer, apiResponse, apiURL] = createOrganization(name, options)
%CREATEORGANIZATION Create an NDI Cloud organization (admin only).
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.admin.createOrganization(NAME, ...)
%
%   Creates an organization with no members. Requires an account with
%   administrator rights; other accounts get B = false and a 403 response.
%
%   The API has no endpoint for deleting an organization, so an
%   organization created here can only be renamed afterwards, not removed.
%   Organization names are not required to be unique.
%
%   Inputs:
%       name - The organization's name.
%
%   Optional name-value inputs:
%       canUploadDataset - Whether members may upload datasets. Default false.
%
%   Outputs:
%       b           - True if the call succeeded, false otherwise.
%       answer      - On success, the new organization struct (with its 'id').
%                     On failure, the server's error struct.
%       apiResponse - The full matlab.net.http.ResponseMessage object.
%       apiURL      - The URL that was called.
%
%   See also: ndi.cloud.api.admin.updateOrganization,
%             ndi.cloud.api.admin.addOrganizationMember,
%             ndi.cloud.api.implementation.admin.CreateOrganization

    arguments
        name (1,1) string {mustBeNonzeroLengthText}
        options.canUploadDataset (1,1) logical = false
    end

    api_call = ndi.cloud.api.implementation.admin.CreateOrganization( ...
        'name', name, 'canUploadDataset', options.canUploadDataset);
    [b, answer, apiResponse, apiURL] = api_call.execute();
end
