function [b, cloudDatasetID, apiResponse, apiURL] = createDataset(datasetInfoStruct)
%CREATEDATASET User-facing wrapper to create a new dataset on NDI Cloud.
%
%   [B, CLOUDDATASETID, APIRESPONSE, APIURL] = ndi.cloud.api.datasets.createDataset(DATASETINFOSTRUCT)
%
%   Creates a new dataset record on NDI Cloud based on the provided
%   DATASETINFOSTRUCT.
%
%   Inputs:
%       datasetInfoStruct - A struct containing the metadata for the new dataset.
%
%   Outputs:
%       b              - True if the call succeeded, false otherwise.
%       cloudDatasetID - The unique identifier (_id) of the newly created dataset.
%       apiResponse    - The full matlab.net.http.ResponseMessage object.
%       apiURL         - The URL that was called.
%
%   See also: ndi.cloud.api.implementation.datasets.CreateDataset

    arguments
        datasetInfoStruct (1,1) struct
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.datasets.CreateDataset('datasetInfoStruct', datasetInfoStruct);
    
    % 2. Call the execute method and return its outputs directly.
    [b, cloudDatasetID, apiResponse, apiURL] = api_call.execute();
    
end


