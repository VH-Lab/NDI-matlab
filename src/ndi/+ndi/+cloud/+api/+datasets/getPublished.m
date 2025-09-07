function [b, answer, apiResponse, apiURL] = getPublished(options)
%GETPUBLISHED User-facing wrapper to get published datasets from NDI Cloud.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.datasets.getPublished(...)
%
%   Retrieves a paginated list of published datasets from the NDI Cloud.
%
%   Optional Inputs (Name-Value Pairs):
%       page     - The page number of results to retrieve (default 1).
%       pageSize - The number of results per page (default 20).
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - The datasets struct on success, or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       % Get the first page of published datasets
%       [success, data] = ndi.cloud.api.datasets.getPublished();
%
%       % Get the third page, with 5 results per page
%       [success, data] = ndi.cloud.api.datasets.getPublished('page', 3, 'pageSize', 5);
%
%   See also: ndi.cloud.api.implementation.datasets.GetPublished

    arguments
        options.page (1,1) double = 1
        options.pageSize (1,1) double = 20
    end

    % 1. Create an instance of the implementation class, passing options.
    api_call = ndi.cloud.api.implementation.datasets.GetPublished(...
        'page', options.page, 'pageSize', options.pageSize);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end

