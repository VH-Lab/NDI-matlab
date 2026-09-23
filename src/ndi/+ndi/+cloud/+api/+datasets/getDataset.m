function [b, answer, apiResponse, apiURL] = getDataset(cloudDatasetID)
%GETDATASET User-facing wrapper to get a dataset from NDI Cloud.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.datasets.getDataset(CLOUD_DATASET_ID)
%
%   Retrieves a dataset's metadata from the NDI Cloud.
%
%   The dataset struct does NOT embed the file list: it reports the file
%   count in the 'fileCount' field instead. To enumerate a dataset's files
%   use ndi.cloud.api.files.listFilesAll (or listFiles for a single page).
%
%   Inputs:
%       cloudDatasetID - The string ID of the dataset.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - The dataset struct on success (with 'fileCount' but no
%                      embedded file list), or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   See also: ndi.cloud.api.files.listFilesAll, ndi.cloud.api.files.listFiles,
%             ndi.cloud.api.implementation.datasets.GetDataset

    arguments
        cloudDatasetID (1,1) string
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.datasets.GetDataset(...
        'cloudDatasetID', cloudDatasetID);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end

