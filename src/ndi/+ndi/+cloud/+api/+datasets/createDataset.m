function [b, cloudDatasetID, apiResponse, apiURL] = createDataset(datasetInfoStruct, options)
%CREATEDATASET User-facing wrapper to create a new dataset on NDI Cloud.
%
%   [B, CLOUDDATASETID, APIRESPONSE, APIURL] = ndi.cloud.api.datasets.createDataset(DATASETINFOSTRUCT, ...)
%
%   Creates a new dataset record on NDI Cloud based on the provided
%   DATASETINFOSTRUCT, in one of the organizations the current user belongs
%   to.
%
%   Inputs:
%       datasetInfoStruct - A struct containing the metadata for the new dataset.
%
%   Optional Inputs (Name-Value Pairs):
%       organizationName - The NAME of the organization in which to create
%           the dataset. Mutually exclusive with organizationID.
%       organizationID - The ID of the organization in which to create the
%           dataset.
%       If neither is given and the user may upload to exactly one
%       organization, that one is used; otherwise the user is asked to
%       choose (in the MATLAB desktop) or an error lists the organizations.
%       See ndi.cloud.internal.chooseOrganization.
%
%   Outputs:
%       b              - True if the call succeeded, false otherwise.
%       cloudDatasetID - The unique identifier (_id) of the newly created dataset.
%       apiResponse    - The full matlab.net.http.ResponseMessage object.
%       apiURL         - The URL that was called.
%
%   Example:
%       [b, id] = ndi.cloud.api.datasets.createDataset(struct('name', 'My dataset'), ...
%           'organizationName', 'My Lab');
%
%   See also: ndi.cloud.api.implementation.datasets.CreateDataset,
%             ndi.cloud.internal.chooseOrganization

    arguments
        datasetInfoStruct (1,1) struct
        options.organizationName (1,:) char = ''
        options.organizationID (1,:) char = ''
    end

    % 1. Decide which organization the dataset belongs to.
    organizationID = ndi.cloud.internal.chooseOrganization( ...
        'organizationName', options.organizationName, ...
        'organizationID', options.organizationID, ...
        'RequireUpload', true, ...
        'PromptString', "Create the new dataset in which organization?");

    % 2. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.datasets.CreateDataset( ...
        'datasetInfoStruct', datasetInfoStruct, ...
        'cloudOrganizationID', organizationID);
    
    % 3. Call the execute method and return its outputs directly.
    [b, cloudDatasetID, apiResponse, apiURL] = api_call.execute();
    
end
