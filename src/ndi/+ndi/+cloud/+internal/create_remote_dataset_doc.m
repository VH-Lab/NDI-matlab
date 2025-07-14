function remoteDatasetDoc = create_remote_dataset_doc(cloudDatasetId, ndiDataset)
% create_remote_dataset_doc - Create NDI document with remote dataset details.
% 
% Syntax:
%   remoteDatasetDoc = create_remote_dataset_doc(cloudDatasetId) 
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

    [remoteDataset, ~] = ndi.cloud.api.datasets.get_dataset(cloudDatasetId);
    remoteDatasetDoc = ndi.document('dataset_remote', ...
            'base.session_id', ndiDataset.id, ...
            'dataset_remote', struct( ...
                'dataset_id', remoteDataset.x_id, ...
                'organization_id', remoteDataset.organizationId) ...
                );
end
