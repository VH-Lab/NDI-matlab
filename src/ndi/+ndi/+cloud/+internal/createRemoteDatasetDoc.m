function remoteDatasetDoc = createRemoteDatasetDoc(cloudDatasetId, ndiDataset, options)
% CREATEREMOTEDATASETDOC - Create NDI document with remote dataset details.
%
% REMOTEDATASETDOC = CREATEREMOTEDATASETDOC(CLOUDDATASETID, NDIDATASET, ...
%   'replaceExisting', REPLACEEXISTING)
%
% Creates a 'dataset_remote' NDI document, which links a local NDI dataset
% to a remote cloud dataset.
%
% This function first checks if a 'dataset_remote' document already exists
% for the given local dataset. If one is found, it will be replaced if
% 'replaceExisting' is true; otherwise, the function will error.
%
% After ensuring no existing document is present (or removing it), the
% function fetches the metadata for the specified cloud dataset from the
% remote server. It then uses this information to create a new
% 'dataset_remote' document in memory. This new document contains the cloud
% dataset ID and the organization ID.
%
% NOTE: This function only creates the document in memory. The calling
% function is responsible for adding it to the database if desired.
%
% Inputs:
%   cloudDatasetId (string) - The unique identifier for the cloud dataset.
%   ndiDataset (ndi.dataset) - The local NDI dataset object to be associated
%     with the cloud dataset.
%
% Name-Value Pairs:
%   replaceExisting (logical) - If true, any existing 'dataset_remote'
%     document for the local dataset will be removed before creating the
%     new one. Defaults to false.
%
% Outputs:
%   remoteDatasetDoc (ndi.document) - A new 'dataset_remote' document object
%     containing the remote dataset ID and organization ID.
%
% Example:
%   % Assume my_dataset is a valid ndi.dataset object and a cloud dataset
%   % with ID 'd-12345' exists.
%   newDoc = ndi.cloud.internal.createRemoteDatasetDoc('d-12345', my_dataset);
%   my_dataset.database_add(newDoc); % Add the document to the database
%
% See also: ndi.cloud.internal.getCloudDatasetIdForLocalDataset
    
    arguments
        cloudDatasetId (1,:) char
        ndiDataset (1,1) ndi.dataset
        options.replaceExisting (1,1) logical = false
    end

    [~, existingDoc] = ndi.cloud.internal.getCloudDatasetIdForLocalDataset(ndiDataset);

    if ~isempty(existingDoc)
        if options.replaceExisting
            ndiDataset.database_rm(existingDoc{1}.id());
        else
            error('An existing remote dataset document was found. Use ''replaceExisting'', true to replace it.');
        end
    end

    [success, remoteDataset] = ndi.cloud.api.datasets.getDataset(cloudDatasetId);
    if ~success
        msg = remoteDataset.message;
        if isstruct(msg) && isfield(msg, 'error')
             msg = msg.error;
        end
        error(['Failed to get dataset: ' msg]);
    end
    remoteDatasetDoc = ndi.document('dataset_remote', ...
            'base.session_id', ndiDataset.id, ...
            'dataset_remote', struct( ...
                'dataset_id', remoteDataset.x_id, ...
                'organization_id', remoteDataset.organizationId) ...
                );
end
