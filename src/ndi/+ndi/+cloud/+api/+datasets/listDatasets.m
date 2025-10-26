function [b, answer, apiResponse, apiURL] = listDatasets(options)
%LISTDATASETS User-facing wrapper to list datasets in an organization.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.datasets.listDatasets(...)
%
%   Retrieves a list of all datasets within a given organization.
%
%   Optional Inputs (Name-Value Pairs):
%       cloudOrganizationID - The ID of the organization to query. If not
%           provided, the function will use the organization ID stored in
%           the 'NDI_CLOUD_ORGANIZATION_ID' environment variable.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - A struct array of datasets on success, or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       % List datasets in the default organization
%       [success, my_datasets] = ndi.cloud.api.datasets.listDatasets();
%
%       % List datasets in a specific organization
%       [s, org_datasets] = ndi.cloud.api.datasets.listDatasets('cloudOrganizationID', 'org-12345');
%
%   See also: ndi.cloud.api.implementation.datasets.ListDatasets

    arguments
        options.cloudOrganizationID (1,1) string = missing
    end

    % 1. Create an instance of the implementation class, passing options.
    api_call = ndi.cloud.api.implementation.datasets.ListDatasets(...
        'cloudOrganizationID', options.cloudOrganizationID);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end

