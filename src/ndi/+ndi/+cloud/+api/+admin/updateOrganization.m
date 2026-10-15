function [b, answer, apiResponse, apiURL] = updateOrganization(cloudOrganizationID, options)
%UPDATEORGANIZATION Rename an NDI Cloud organization or change its upload permission (admin only).
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.admin.updateOrganization(CLOUDORGANIZATIONID, ...)
%
%   Only the fields given are changed; at least one must be given.
%   Requires an account with administrator rights; other accounts get
%   B = false and a 403 response.
%
%   Inputs:
%       cloudOrganizationID - The organization's id.
%
%   Optional name-value inputs:
%       name             - New organization name.
%       canUploadDataset - Whether members may upload datasets.
%
%   Outputs:
%       b           - True if the call succeeded, false otherwise.
%       answer      - On success, the updated organization struct.
%                     On failure, the server's error struct.
%       apiResponse - The full matlab.net.http.ResponseMessage object.
%       apiURL      - The URL that was called.
%
%   Example:
%       ndi.cloud.api.admin.updateOrganization(orgId, 'canUploadDataset', true);
%
%   See also: ndi.cloud.api.admin.getOrganization,
%             ndi.cloud.api.implementation.admin.UpdateOrganization

    arguments
        cloudOrganizationID (1,1) string
        options.name (1,1) string {mustBeNonzeroLengthText}
        options.canUploadDataset (1,1) logical
    end

    if isempty(fieldnames(options))
        error('NDI:Cloud:Admin:NoUpdates', ...
            'Give at least one of ''name'' or ''canUploadDataset''.');
    end

    api_call = ndi.cloud.api.implementation.admin.UpdateOrganization( ...
        'cloudOrganizationID', cloudOrganizationID, 'updates', options);
    [b, answer, apiResponse, apiURL] = api_call.execute();
end
