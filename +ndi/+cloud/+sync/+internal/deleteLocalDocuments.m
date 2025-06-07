function deleteLocalDocuments(ndiDataset, localIdsToDelete, syncOptions)
% DELETELOCALDOCUMENTS Deletes specified documents from the local NDI dataset.
%
%   ndi.cloud.sync.internal.DELETELOCALDOCUMENTS(NDIDATASET, LOCALIDSTODELETE, SYNCOPTIONS)
%
%   Inputs:
%       ndiDataset (1,1) ndi.dataset - The local NDI dataset object.
%       localIdsToDelete (1,:) string - A string array of NDI document UUIDs
%           to delete from the local dataset.
%       syncOptions (1,1) ndi.cloud.sync.SyncOptions - Synchronization options,
%           primarily for DryRun and Verbose flags.
%
%   This function iterates through the provided document IDs, searches for them
%   in the local dataset, and removes them if found. It respects the
%   DryRun option in syncOptions.

    arguments
        ndiDataset (1,1) ndi.dataset
        localIdsToDelete (1,:) string
        syncOptions (1,1) ndi.cloud.sync.SyncOptions
    end

    if isempty(localIdsToDelete)
        if syncOptions.Verbose
            fprintf('No local document IDs provided for deletion.\n');
        end
        return;
    end

    if syncOptions.Verbose
        fprintf('Attempting to delete %d documents from local dataset: %s...\n', ...
            numel(localIdsToDelete), ndiDataset.path);
    end

    numDeleted = 0;
    numNotFound = 0;

    for i = 1:numel(localIdsToDelete)
        docId = localIdsToDelete(i);
        
        if syncOptions.DryRun
            % In DryRun, we can't confirm if the doc exists without searching,
            % but the intent is to log what *would* be deleted.
            % A search could be done even in DryRun for more accurate logging.
            query = ndi.query('base.id', 'exact_string', docId, '');
            docs = ndiDataset.database_search(query);
            if ~isempty(docs)
                fprintf('[DryRun] Would delete local document with ID: %s\n', docId);
                numDeleted = numDeleted + 1; % Count as if it would be deleted
            else
                fprintf('[DryRun] Local document with ID: %s not found, would not delete.\n', docId);
                numNotFound = numNotFound + 1;
            end
        else
            query = ndi.query('base.id', 'exact_string', docId, '');
            docs = ndiDataset.database_search(query);

            if ~isempty(docs)
                try
                    ndiDataset.database_rm(docId);
                    if syncOptions.Verbose
                        fprintf('Deleted local document with ID: %s\n', docId);
                    end
                    numDeleted = numDeleted + 1;
                catch e
                    fprintf('Error deleting local document ID %s: %s\n', docId, e.message);
                end
            else
                if syncOptions.Verbose
                    fprintf('Local document with ID: %s not found for deletion.\n', docId);
                end
                numNotFound = numNotFound + 1;
            end
        end
    end

    if syncOptions.Verbose
        if syncOptions.DryRun
            fprintf('[DryRun] Summary: Would have attempted to delete %d documents. %d would be deleted, %d not found.\n', ...
                numel(localIdsToDelete), numDeleted, numNotFound);
        else
            fprintf('Deletion summary: Attempted to delete %d documents. %d deleted, %d not found.\n', ...
                numel(localIdsToDelete), numDeleted, numNotFound);
        end
    end
end
