function updateSyncIndex(ndiDataset, cloudDatasetId, indexData)
% updateSyncIndex - Updates synchronization index for the dataset.
%
% Syntax:
%   updateSynchIndex(ndiDataset, cloudDatasetId, indexData) updates the
%       synchronization index for the specified dataset using the provided
%       index data.
%
% Input Arguments:
%   ndiDataset (1,1) ndi.dataset - The dataset to be updated.
%   cloudDatasetId (1,1) string - The identifier for the cloud dataset.
%   indexData.LocalDocumentIds (1,:) string - Local document IDs (optional).
%   indexData.RemoteDocumentIds (1,:) string - Remote document IDs (optional).
%
% Output Arguments:
%   None - This function does not return any outputs; it saves an updated sync
%   index to the dataset.

    arguments
        ndiDataset (1,1) ndi.dataset
        cloudDatasetId (1,1) string
        indexData.LocalDocumentIds (1,:) string = missing
        indexData.RemoteDocumentIds (1,:) string = missing
    end
    
    if ismissing(indexData.LocalDocumentIds)
        [~, indexData.LocalDocumentIds] = ...
            ndi.cloud.sync.internal.listLocalDocuments(ndiDataset);
    end

    if ismissing(indexData.RemoteDocumentIds)
        remoteDocumentIds = ...
            ndi.cloud.sync.internal.listRemoteDocumentIds(cloudDatasetId);
        indexData.RemoteDocumentIds = remoteDocumentIds.ndiId;
    end

    synchIndex = ndi.cloud.sync.internal.index.createSyncIndexStruct(...
        indexData.LocalDocumentIds, indexData.RemoteDocumentIds);

    ndi.cloud.sync.internal.index.writeSyncIndex(ndiDataset, synchIndex);
end
