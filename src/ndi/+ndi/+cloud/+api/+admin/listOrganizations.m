function [b, answer, apiResponse, apiURL] = listOrganizations(options)
%LISTORGANIZATIONS List NDI Cloud organizations (admin only).
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.admin.listOrganizations(...)
%
%   Lists one page of all organizations, sorted by name. Requires an
%   account with administrator rights; other accounts get B = false and a
%   403 response.
%
%   Optional name-value inputs:
%       query    - Case-insensitive substring of the organization name.
%                  Default "" (all organizations).
%       page     - 1-based page number. Default 1.
%       pageSize - Organizations per page, 1-100. Default 25.
%
%   Outputs:
%       b           - True if the call succeeded, false otherwise.
%       answer      - On success, a struct with fields:
%                       organizations - the organizations on this page, each
%                                       with 'id', 'name', 'canUploadDataset',
%                                       'memberCount' and 'teams'. A struct
%                                       array, or a cell array of structs if
%                                       their fields differ.
%                       page, limit, total, totalPages
%                     On failure, the server's error struct.
%       apiResponse - The full matlab.net.http.ResponseMessage object.
%       apiURL      - The URL that was called.
%
%   Example:
%       [ok, r] = ndi.cloud.api.admin.listOrganizations('query', "lab");
%
%   See also: ndi.cloud.api.admin.getOrganization,
%             ndi.cloud.api.implementation.admin.ListOrganizations

    arguments
        options.query (1,1) string = ""
        options.page (1,1) double {mustBePositive, mustBeInteger} = 1
        options.pageSize (1,1) double {mustBeInteger, mustBeInRange(options.pageSize, 1, 100)} = 25
    end

    api_call = ndi.cloud.api.implementation.admin.ListOrganizations( ...
        'query', options.query, 'page', options.page, 'pageSize', options.pageSize);
    [b, answer, apiResponse, apiURL] = api_call.execute();
end
