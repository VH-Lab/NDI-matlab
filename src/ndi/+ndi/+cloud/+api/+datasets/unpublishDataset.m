function [b, answer, apiResponse, apiURL] = unpublishDataset(cloudDatasetID)
%UNPUBLISHDATASET User-facing wrapper to unpublish a dataset.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.datasets.unpublishDataset(CLOUDDATASETID)
%
%   Unpublishes a dataset on the NDI Cloud.
%
%   Inputs:
%       cloudDatasetID - The ID of the dataset to unpublish.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - A struct with the API response on success, or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       [success, result] = ndi.cloud.api.datasets.unpublishDataset('d-12345');
%
%   See also: ndi.cloud.api.implementation.datasets.UnpublishDataset

    arguments
        cloudDatasetID (1,1) string
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.datasets.UnpublishDataset(...
        'cloudDatasetID', cloudDatasetID);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end

