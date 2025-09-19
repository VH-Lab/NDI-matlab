function [b, answer, apiResponse, apiURL] = getDataset(cloudDatasetID)
%GETDATASET User-facing wrapper to get a dataset from NDI Cloud.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.datasets.getDataset(CLOUD_DATASET_ID)
%
%   Retrieves the full details for a given dataset on the NDI Cloud.
%
%   Inputs:
%       cloudDatasetID - The string ID of the dataset.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - The dataset struct on success, or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   See also: ndi.cloud.api.implementation.datasets.GetDataset

    arguments
        cloudDatasetID (1,1) string
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.datasets.GetDataset(...
        'cloudDatasetID', cloudDatasetID);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end

