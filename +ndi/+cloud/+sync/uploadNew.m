function uploadNew(ndiDataset, syncOptions)
%UPLOADNEW Upload new local documents (and associated files) to remote.
%
% Syntax:
%   ndi.cloud.sync.uploadNew(NDI_DATASET, SYNC_OPTIONS)
%
%   This function implements the "UploadNew" synchronization mode.
%   mode, it compares the current local state to the local state from the
%   last sync (from a sync index) to identify newly added local documents,
%   which are then uploaded.
%
%   No remote documents are deleted by this mode.
%   No local documents are deleted by this mode.
%
%   It relies on a sync index file ([NDIDATASET.path]/.ndi/sync/index.json)
%   to keep track of previously synced states and updates it after the operation.
%
%   Inputs:
%       ndiDataset (1,1) ndi.dataset - The local NDI dataset object.
%       syncOptions (name, value pairs) - Optional synchronization options:
%       - SyncFiles (logical) - If true, files will be synced (default: true).
%       - Verbose (logical) - If true, verbose output is printed (default: true).
%       - DryRun (logical) - If true, actions are simulated but not performed (default: false).
%
%   See also:
%       ndi.cloud.syncDataset
%       ndi.cloud.sync.SyncOptions,
%       ndi.cloud.sync.enum.SyncMode

    arguments
        ndiDataset (1,1) ndi.dataset
        syncOptions.?ndi.cloud.sync.SyncOptions
    end
    
    syncOptions = ndi.cloud.sync.SyncOptions(syncOptions);

    if syncOptions.Verbose
        fprintf(['Syncing dataset "%s". \nWill upload new local documents ', ...
            'to remote.\n'], ndiDataset.path);
    end

    % Resolve cloud dataset identifier
    cloudDatasetId = ndi.cloud.internal.getCloudDatasetIdForLocalDataset(ndiDataset);
    if syncOptions.Verbose
        fprintf('Using Cloud Dataset ID: %s\n', cloudDatasetId);
    end

    % 1. Read sync index
    syncIndex = ndi.cloud.sync.internal.index.readSyncIndex(ndiDataset);
    if isempty(syncIndex) || isempty(syncIndex.localDocumentIdsLastSync)
        localIdsLastSync = strings(0,1); % Ensure it's an empty string array for setdiff
    else
        localIdsLastSync = string(syncIndex.localDocumentIdsLastSync); % Ensure string array
    end
    if syncOptions.Verbose
        fprintf('Read sync index. Last sync recorded %d local documents.\n', numel(localIdsLastSync));
    end

    % 2. Get current local state
    [localDocuments, localDocumentIds] = ndi.cloud.sync.internal.listLocalDocuments(ndiDataset);
    if syncOptions.Verbose
        fprintf('Found %d documents locally.\n', numel(localDocumentIds));
    end

    % 3. Calculate differences: documents added locally since last sync
    [ndiIdsToUpload, indToUpload] = setdiff(localDocumentIds, localIdsLastSync, 'stable');
    documentsToUpload = localDocuments(indToUpload);

    if syncOptions.Verbose
        fprintf('Found %d documents added locally since last sync.\n', numel(ndiIdsToUpload));
    end

    % 4. Perform upload actions
    if ~isempty(ndiIdsToUpload)
        if syncOptions.DryRun
            fprintf('[DryRun] Would upload %d documents to remote.\n', ...
                numel(ndiIdsToUpload));
            if syncOptions.Verbose
                for i = 1:numel(ndiIdsToUpload)
                    fprintf('  [DryRun] - NDI ID: %s\n', ndiIdsToUpload(i));
                end
            end
        else
            if syncOptions.Verbose
                fprintf('Uploading %d documents...\n', numel(ndiIdsToUpload));
            end
            ndi.cloud.upload.upload_document_collection(cloudDatasetId, documentsToUpload)

            % Upload associated files if SyncFiles is true
            if syncOptions.SyncFiles
                if syncOptions.Verbose
                    fprintf('SyncFiles is true. Uploading associated data files...\n');
                end
                ndi.cloud.sync.internal.upload_files_for_dataset_documents( ...
                    cloudDatasetId, ...
                    ndiDataset, ...
                    documentsToUpload, ...
                    "Verbose", syncOptions.Verbose);
            elseif syncOptions.Verbose
                fprintf('"SyncFiles" option is false. Skipping upload of associated data files.\n');
            end
                
            if syncOptions.Verbose
                fprintf('Completed uploading %d documents.\n', numel(ndiIdsToUpload));
            end
        end
    else
        if syncOptions.Verbose
            fprintf('No new local documents to upload to remote.\n');
        end
    end

    % 5. Update sync index
    if ~syncOptions.DryRun
        % Re-fetch final remote states to ensure accuracy
        finalRemoteDocumentIdMap = ndi.cloud.sync.internal.listRemoteDocumentIds(cloudDatasetId);
        
        ndi.cloud.sync.internal.index.updateSyncIndex(...
            ndiDataset, cloudDatasetId, ...
            "LocalDocumentIds", localDocumentIds, ...
            "RemoteDocumentIds", finalRemoteDocumentIdMap.ndiId)

        if syncOptions.Verbose
            fprintf('Sync index updated.\n');
        end
    end

    if syncOptions.Verbose
        fprintf('Syncing complete for dataset: %s\n', ndiDataset.path);
    end
end
