function deleteRemoteDocuments(cloudDatasetId, remoteApiIdsToDelete, syncOptions)
% DELETEREMOTEDOCUMENTS Deletes specified documents from the remote cloud storage.
%
%   ndi.cloud.sync.internal.DELETEREMOTEDOCUMENTS(CLOUDDATASETID, REMOTEAPIIDSTODELETE, SYNCOPTIONS)
%
%   Inputs:
%       cloudDatasetId (1,1) string - The ID of the NDI dataset on the cloud.
%       remoteApiIdsToDelete (1,:) string - A string array of cloud-provider-specific
%           API document IDs to delete from the remote storage.
%       syncOptions (1,1) ndi.cloud.sync.SyncOptions - Synchronization options,
%           primarily for DryRun and Verbose flags.
%
%   This function iterates through the provided API document IDs and calls
%   an NDI cloud API function (assumed to be ndi.cloud.api.documents.delete)
%   to remove each document from the remote storage. It respects the
%   DryRun option in syncOptions.

    arguments
        cloudDatasetId (1,1) string
        remoteApiIdsToDelete (1,:) string
        syncOptions (1,1) ndi.cloud.sync.SyncOptions
    end

    if isempty(remoteApiIdsToDelete)
        if syncOptions.Verbose
            fprintf('No remote document API IDs provided for deletion.\n');
        end
        return;
    end

    if syncOptions.Verbose
        fprintf('Attempting to delete %d documents from remote cloud dataset ID: %s...\n', ...
            numel(remoteApiIdsToDelete), cloudDatasetId);
    end

    if syncOptions.DryRun
        fprintf('[DryRun] Would delete remote documents with API IDs from cloud dataset %s:\n%s\n', ...
            cloudDatasetId, strjoin("  " + remoteApiIdsToDelete, newline) );
    else
        % TODO: Update deprecated function call. Replace ndi.cloud.api.documents.bulk_delete_documents with ndi.cloud.api.documents.bulkDeleteDocuments
        ndi.cloud.api.documents.bulk_delete_documents(cloudDatasetId, remoteApiIdsToDelete)
        if syncOptions.Verbose
            fprintf('Deleted documents.')
        end
    end
end
