function [success, errorMessage, report] = downloadNew(ndiDataset, syncOptions)
%DOWNLOADNEW Download new documents (and associated data files) from remote to local.
%
% Syntax:
%   [SUCCESS, ERRORMESSAGE, REPORT] = ndi.cloud.sync.downloadNew(NDIDATASET, SYNCOPTIONS)
%
%   This function implements the "DownloadNew" synchronization mode.
%   It identifies documents present on the remote cloud storage that are
%   not present in the local NDI dataset and downloads them.
%
%   No local documents are deleted or modified.
%   No remote documents are deleted or modified.
%
%   It relies on a sync index file ([NDIDATASET.path]/.ndi/sync/index.json)
%   to keep track of previously synced states, though for "DownloadNew"
%   mode, it compares the current remote state to the remote state from the
%   last sync (from the index) to identify newly added remote documents.
%   The index is updated after the operation.
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
    report = struct('downloaded_document_ids', string.empty);

    try
        syncOptions = ndi.cloud.sync.SyncOptions(syncOptions);

        if syncOptions.Verbose
            fprintf(['Syncing dataset "%s". \nWill download new documents ', ...
                'from remote.\n'], ndiDataset.path);
        end

        % Resolve cloud dataset identifier
        cloudDatasetId = ndi.cloud.internal.getCloudDatasetIdForLocalDataset(ndiDataset);
        if syncOptions.Verbose
            fprintf('Using Cloud Dataset ID: %s\n', cloudDatasetId);
        end

        % 1. Read sync index
        syncIndex = ndi.cloud.sync.internal.index.readSyncIndex(ndiDataset);
        if isempty(syncIndex) || isempty(syncIndex.remoteDocumentIdsLastSync)
            remoteIdsLastSync = strings(0,1); % Ensure it's an empty string array for setdiff
        else
            remoteIdsLastSync = string(syncIndex.remoteDocumentIdsLastSync); % Ensure string array
        end
        if syncOptions.Verbose
            fprintf('Read sync index. Last sync recorded %d remote documents.\n', numel(remoteIdsLastSync));
        end

        % 2. Get current remote state - Returns Nx2 table with variables ndiId, apiId
        remoteDocumentIdMap = ndi.cloud.sync.internal.listRemoteDocumentIds(cloudDatasetId);
        currentRemoteNdiIds = remoteDocumentIdMap.ndiId;

        % 3. Calculate differences: documents added to remote since last sync
        [ndiIdsToDownload, indicesToDownload] = setdiff(currentRemoteNdiIds, remoteIdsLastSync, 'stable');

        if syncOptions.Verbose
            fprintf('Found %d documents added on remote since last sync.\n', ...
                numel(ndiIdsToDownload));
        end

        % 4. Perform download actions
        if ~isempty(ndiIdsToDownload)
            cloudApiIdsToDownload = remoteDocumentIdMap.apiId(indicesToDownload);

            if syncOptions.DryRun
                fprintf('[DryRun] Would download %d documents from remote.\n', ...
                    numel(ndiIdsToDownload));
                if syncOptions.Verbose
                    for i = 1:numel(ndiIdsToDownload)
                        fprintf('  [DryRun] - NDI ID: %s (Cloud Specific ID: %s)\n', ...
                            ndiIdsToDownload(i), cloudApiIdsToDownload(i));
                    end
                end
            else
                if syncOptions.Verbose
                    fprintf('Downloading %d documents...\n', numel(ndiIdsToDownload));
                end
                % This internal function handles batch download and adding to ndiDataset,
                % respecting syncOptions.SyncFiles and syncOptions.Verbose internally.
                downloadedDocs = ndi.cloud.sync.internal.downloadNdiDocuments(...
                    cloudDatasetId, cloudApiIdsToDownload, ndiDataset, syncOptions);

                if ~isempty(downloadedDocs)
                     % Extract IDs. downloadedDocs is a cell array of ndi.document objects.
                     docIds = cellfun(@(d) d.id(), downloadedDocs, 'UniformOutput', false);
                     report.downloaded_document_ids = string(docIds);
                end

                if syncOptions.Verbose
                    fprintf('Completed downloading %d documents.\n', numel(ndiIdsToDownload));
                end
            end
        else
            if syncOptions.Verbose
                fprintf('No new documents to download from remote.\n');
            end
        end

        % 5. Update sync index
        if ~syncOptions.DryRun

            % Update local state after download
            [~, finalLocalDocumentIds] = ndi.cloud.sync.internal.listLocalDocuments(ndiDataset);

            ndi.cloud.sync.internal.index.updateSyncIndex(...
                ndiDataset, cloudDatasetId, ...
                "LocalDocumentIds", finalLocalDocumentIds, ...
                "RemoteDocumentIds", remoteDocumentIdMap.ndiId)

            if syncOptions.Verbose
                fprintf('Sync index updated.\n');
            end
        end

        if syncOptions.Verbose
            fprintf('Syncing complete for dataset: %s\n', ndiDataset.path);
        end

    catch ME
        success = false;
        errorMessage = ME.message;
        % Check if syncOptions is an object with Verbose property before accessing
        if exist('syncOptions', 'var') && isprop(syncOptions, 'Verbose') && syncOptions.Verbose
             fprintf('Error in downloadNew: %s\n', errorMessage);
        end
    end
end
