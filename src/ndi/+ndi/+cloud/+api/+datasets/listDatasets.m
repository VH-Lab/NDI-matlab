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
%       page - The page number to retrieve (default 1).
%       pageSize - The number of datasets per page (default 20).
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - A structure with fields 'totalNumber', 'page', 'pageSize',
%                      and 'datasets' on success, or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       % List datasets in the default organization (first page, default size)
%       [success, result] = ndi.cloud.api.datasets.listDatasets();
%       my_datasets = result.datasets;
%
%       % List datasets with pagination
%       [s, res] = ndi.cloud.api.datasets.listDatasets('page', 2, 'pageSize', 50);
%
%   See also: ndi.cloud.api.implementation.datasets.ListDatasets

    arguments
        options.cloudOrganizationID (1,1) string = missing
        options.page (1,1) double = 1
        options.pageSize (1,1) double = 20
    end

    % 1. Create an instance of the implementation class, passing options.
    api_call = ndi.cloud.api.implementation.datasets.ListDatasets(...
        'cloudOrganizationID', options.cloudOrganizationID, ...
        'page', options.page, ...
        'pageSize', options.pageSize);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end
