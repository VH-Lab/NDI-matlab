function [b, answer, apiResponse, apiURL] = listDeletedDatasets(options)
%LISTDELETEDDATASETS Retrieves a list of soft-deleted datasets.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.datasets.listDeletedDatasets(OPTIONS)
%
%   Inputs:
%       options.page     - (Optional) Page number (default: 1).
%       options.pageSize - (Optional) Number of results per page (default: 20).
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - The API response body on success (JSON object with totalNumber and datasets).
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   See also: ndi.cloud.api.implementation.datasets.ListDeletedDatasets

    arguments
        options.page (1,1) double = 1
        options.pageSize (1,1) double = 20
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.datasets.ListDeletedDatasets(...
        'page', options.page, 'pageSize', options.pageSize);

    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();

end
