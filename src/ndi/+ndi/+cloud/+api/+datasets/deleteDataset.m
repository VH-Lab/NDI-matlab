function [b, answer, apiResponse, apiURL] = deleteDataset(cloudDatasetID, options)
%DELETEDATASET User-facing wrapper to delete a dataset on NDI Cloud.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.datasets.deleteDataset(CLOUD_DATASET_ID)
%
%   Deletes a dataset from the NDI Cloud.
%
%   Inputs:
%       cloudDatasetID - The string ID of the dataset to delete.
%       options.when   - (Optional) Duration string (e.g., '7d', 'now') specifying
%                        when the dataset should be permanently removed. Default: '7d'.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - The body of the API response on success.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   See also: ndi.cloud.api.implementation.datasets.DeleteDataset

    arguments
        cloudDatasetID (1,1) string
        options.when (1,1) string = "7d"
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.datasets.DeleteDataset(...
        'cloudDatasetID', cloudDatasetID, 'when', options.when);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end
