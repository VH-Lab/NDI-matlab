function remoteDatasetDoc = createRemoteDatasetDoc(cloudDatasetId, ndiDataset)
% createRemoteDatasetDoc - Create NDI document with remote dataset details.
% 
% Syntax:
%   remoteDatasetDoc = createRemoteDatasetDoc(cloudDatasetId)
%   This function retrieves a remote dataset from the cloud and creates 
%   a "dataset remote" NDI document for that dataset.
% 
% Input Arguments:
%   cloudDatasetId - The unique identifier for the cloud dataset to be 
%                    retrieved.
% 
% Output Arguments:
%   remoteDatasetDoc - A document object containing the remote dataset 
%                      ID and organization ID.
    
    arguments
        cloudDatasetId
        ndiDataset (1,1) ndi.dataset
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
