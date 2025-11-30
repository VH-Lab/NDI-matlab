function [success, errorMessage, report] = mirrorFromRemote(ndiDataset, syncOptions)
%MIRRORFROMREMOTE Mirrors the remote dataset to the local dataset.
%
% Syntax:
%   [SUCCESS, ERRORMESSAGE, REPORT] = ndi.cloud.sync.mirrorFromRemote(NDIDATASET, SYNCOPTIONS)
%
%   This function implements the "MirrorFromRemote" synchronization mode.
%   It ensures the local dataset becomes an exact representation of the
%   remote dataset by:
%   1. Downloading any documents present on the remote but not locally.
%   2. Deleting any local documents that are not present on the remote.
%
%   The remote dataset is not modified by this operation.
%   The local dataset is modified (additions and deletions).
%
%   It relies on a sync index file ([NDIDATASET.path]/.ndi/sync/index.json)
%   and updates it after the operation.
%
%   Inputs:
%       ndiDataset (1,1) ndi.dataset - The local NDI dataset object.
%       syncOptions (name, value pairs) - Optional synchronization options:
%       - SyncFiles (logical) - If true, files will be synced (default: true).
%       - Verbose (logical) - If true, verbose output is printed (default: true).
%       - DryRun (logical) - If true, actions are simulated but not performed (default: false).
%
%   Outputs:
%       success (logical) - True if the operation completed successfully, false otherwise.
%       errorMessage (string) - Error message if success is false, empty otherwise.
%       report (struct) - Structure containing details of the changes applied.
%           Fields:
%           - downloaded_document_ids (string array)
%           - deleted_local_document_ids (string array)
%
%   See also:
%       ndi.cloud.syncDataset
%       ndi.cloud.sync.SyncOptions,
%       ndi.cloud.sync.enum.SyncMode

    arguments
        ndiDataset (1,1) ndi.dataset
        syncOptions.?ndi.cloud.sync.SyncOptions
    end

    success = true;
    errorMessage = '';
    report = struct('downloaded_document_ids', string.empty, 'deleted_local_document_ids', string.empty);

    try
        syncOptions = ndi.cloud.sync.SyncOptions(syncOptions);

        if syncOptions.Verbose
            fprintf(['Syncing dataset "%s". \nMode: MirrorFromRemote. ', ...
                'Local will be made a mirror of remote.\n'], ndiDataset.path);
        end

        % Resolve cloud dataset identifier
        cloudDatasetId = ndi.cloud.internal.getCloudDatasetIdForLocalDataset(ndiDataset);
        if syncOptions.Verbose
            fprintf('Using Cloud Dataset ID: %s\n', cloudDatasetId);
        end

        % --- Phase 1: Get initial states ---
        [~, initialLocalDocumentIds] = ndi.cloud.sync.internal.listLocalDocuments(ndiDataset);
        initialRemoteDocumentIdMap = ndi.cloud.sync.internal.listRemoteDocumentIds(cloudDatasetId); % Nx2 table: ndiId, apiId

        if syncOptions.Verbose
            fprintf('Initial state: %d local documents, %d remote documents.\n', ...
                numel(initialLocalDocumentIds), numel(initialRemoteDocumentIdMap.ndiId));
        end

        % --- Phase 2: Download missing documents from remote ---
        [ndiIdsToDownload, documentIndToDownload] = ...
            setdiff(initialRemoteDocumentIdMap.ndiId, initialLocalDocumentIds);

        if ~isempty(ndiIdsToDownload)
            if syncOptions.Verbose
                fprintf('Found %d documents on remote to download to local.\n', numel(ndiIdsToDownload));
            end
            cloudApiIdsToDownload = initialRemoteDocumentIdMap.apiId(documentIndToDownload);

            if syncOptions.DryRun
                fprintf('[DryRun] Would download %d documents from remote.\n', numel(ndiIdsToDownload));
                if syncOptions.Verbose
                    for i = 1:numel(ndiIdsToDownload)
                        fprintf('  [DryRun] - Download NDI ID: %s (Cloud API ID: %s)\n', ...
                            ndiIdsToDownload(i), cloudApiIdsToDownload(i));
                    end
                end
            else
                downloadedDocs = ndi.cloud.sync.internal.downloadNdiDocuments(cloudDatasetId, cloudApiIdsToDownload, ndiDataset, syncOptions);
                if ~isempty(downloadedDocs)
                     % Extract IDs
                     docIds = cellfun(@(d) d.id(), downloadedDocs, 'UniformOutput', false);
                     report.downloaded_document_ids = string(docIds);
                end

                if syncOptions.Verbose
                    fprintf('Completed download phase.\n');
                end
            end
        elseif syncOptions.Verbose
            fprintf('No new documents to download from remote.\n');
        end

        % --- Phase 3: Delete local documents not present on remote ---
        % Re-list local documents as they might have changed after downloads
        [~, localDocumentIdsAfterDownload] = ndi.cloud.sync.internal.listLocalDocuments(ndiDataset);

        % Documents to delete are those now local but NOT in the *initial* remote list
        localIdsToDelete = setdiff(localDocumentIdsAfterDownload, initialRemoteDocumentIdMap.ndiId);

        if ~isempty(localIdsToDelete)
            if syncOptions.Verbose
                fprintf('Found %d local documents to delete (not on remote).\n', numel(localIdsToDelete));
            end
            if syncOptions.DryRun
                fprintf('[DryRun] Would delete %d local documents.\n', numel(localIdsToDelete));
                if syncOptions.Verbose
                    for i = 1:numel(localIdsToDelete)
                        fprintf('  [DryRun] - Delete Local NDI ID: %s\n', localIdsToDelete(i));
                    end
                end
            else
                ndi.cloud.sync.internal.deleteLocalDocuments(ndiDataset, localIdsToDelete, syncOptions);
                report.deleted_local_document_ids = string(localIdsToDelete);
                if syncOptions.Verbose
                    fprintf('Completed local deletion phase.\n');
                end
            end
        elseif syncOptions.Verbose
            fprintf('No local documents to delete.\n');
        end

        % --- Phase 4: Update sync index ---
        if ~syncOptions.DryRun
            % Update local state after update. Remote was not change by this mode
            [~, finalLocalDocumentIds] = ndi.cloud.sync.internal.listLocalDocuments(ndiDataset);

            ndi.cloud.sync.internal.index.updateSyncIndex(...
                ndiDataset, cloudDatasetId, ...
                "LocalDocumentIds", finalLocalDocumentIds, ...
                "RemoteDocumentIds", initialRemoteDocumentIdMap.ndiId)

            if syncOptions.Verbose
                fprintf('Sync index updated.\n');
            end
        else
            if syncOptions.Verbose
                fprintf('[DryRun] Sync index would have been updated.\n');
            end
        end

        if syncOptions.Verbose
            fprintf('"MirrorFromRemote" sync completed for dataset: %s\n', ndiDataset.path);
        end

    catch ME
        success = false;
        errorMessage = ME.message;
        if exist('syncOptions', 'var') && isprop(syncOptions, 'Verbose') && syncOptions.Verbose
             fprintf('Error in mirrorFromRemote: %s\n', errorMessage);
        end
    end
end
