function remoteDatasetDoc = createRemoteDatasetDoc(cloudDatasetId, ndiDataset, options)
% createRemoteDatasetDoc - Create NDI document with remote dataset details.
% 
% Syntax:
%   remoteDatasetDoc = createRemoteDatasetDoc(cloudDatasetId, ndiDataset)
%   remoteDatasetDoc = createRemoteDatasetDoc(cloudDatasetId, ndiDataset, 'replaceExisting', true)
%
%   This function retrieves a remote dataset from the cloud and creates 
%   a "dataset remote" NDI document for that dataset.
% 
% Input Arguments:
%   cloudDatasetId - The unique identifier for the cloud dataset to be 
%                    retrieved.
%   ndiDataset - The NDI dataset object.
%   options.replaceExisting - A boolean that if true, will replace an
%                       existing remote dataset document.
% 
% Output Arguments:
%   remoteDatasetDoc - A document object containing the remote dataset 
%                      ID and organization ID.
    
    arguments
        cloudDatasetId
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
        error(['Failed to get dataset: ' remoteDataset.message]);
    end
    remoteDatasetDoc = ndi.document('dataset_remote', ...
            'base.session_id', ndiDataset.id, ...
            'dataset_remote', struct( ...
                'dataset_id', remoteDataset.x_id, ...
                'organization_id', remoteDataset.organizationId) ...
                );
end
