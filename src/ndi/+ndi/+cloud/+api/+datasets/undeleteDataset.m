function [b, answer, apiResponse, apiURL] = undeleteDataset(cloudDatasetID)
%UNDELETEDATASET User-facing wrapper to undelete a dataset on NDI Cloud.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.datasets.undeleteDataset(CLOUD_DATASET_ID)
%
%   Restores a soft-deleted dataset if it hasn't been permanently removed yet.
%
%   Inputs:
%       cloudDatasetID - The string ID of the dataset to undelete.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - The body of the API response on success.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   See also: ndi.cloud.api.implementation.datasets.UndeleteDataset

    arguments
        cloudDatasetID (1,1) string
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.datasets.UndeleteDataset(...
        'cloudDatasetID', cloudDatasetID);

    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();

end
