function [b, answer, apiResponse, apiURL] = createDatasetBranch(cloudDatasetID, branchName)
%CREATEDATASETBRANCH User-facing wrapper to branch a dataset on NDI Cloud.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.datasets.createDatasetBranch(CLOUD_DATASET_ID, BRANCH_NAME)
%
%   Creates a new branch from an existing dataset on the NDI Cloud.
%
%   Inputs:
%       cloudDatasetID - The string ID of the dataset to branch from.
%       branchName     - The name for the new branch.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - The body of the API response on success.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   See also: ndi.cloud.api.implementation.datasets.CreateDatasetBranch

    arguments
        cloudDatasetID (1,1) string
        branchName (1,1) string
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.datasets.CreateDatasetBranch(...
        'cloudDatasetID', cloudDatasetID, 'branchName', branchName);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end


