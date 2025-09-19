function [b, answer, apiResponse, apiURL] = updateDataset(cloudDatasetID, datasetInfoStruct)
%UPDATEDATASET User-facing wrapper to update a dataset's metadata.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.datasets.updateDataset(CLOUDDATASETID, DATASETINFOSTRUCT)
%
%   Updates a dataset on the NDI Cloud with new metadata.
%
%   Inputs:
%       cloudDatasetID    - The ID of the dataset to update.
%       datasetInfoStruct - A struct containing the new metadata for the dataset.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - The API response body on success, or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       updateInfo = struct('name', 'My New Dataset Name', 'abstract', 'A new description.');
%       [success, result] = ndi.cloud.api.datasets.updateDataset('d-12345', updateInfo);
%
%   See also: ndi.cloud.api.implementation.datasets.UpdateDataset

    arguments
        cloudDatasetID (1,1) string
        datasetInfoStruct (1,1) struct
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.datasets.UpdateDataset(...
        'cloudDatasetID', cloudDatasetID, ...
        'datasetInfoStruct', datasetInfoStruct);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end

