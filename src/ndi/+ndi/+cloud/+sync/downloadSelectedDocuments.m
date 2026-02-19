function [success, errorMessage, report] = downloadSelectedDocuments(ndiDataset, ndiDocumentIds, syncOptions)
%DOWNLOADSELECTEDDOCUMENTS Download specific documents (and files) from remote to local.
%
% Syntax:
%   [SUCCESS, ERRORMESSAGE, REPORT] = ...
%       ndi.cloud.sync.downloadSelectedDocuments(NDIDATASET, NDIDOCUMENTIDS, SYNCOPTIONS)
%
%   This function downloads a specified set of NDI documents from the cloud
%   and adds them to the local dataset.
%
%   Inputs:
%       ndiDataset (1,1) ndi.dataset - The local NDI dataset object.
%       ndiDocumentIds (1,:) cellstr or string array - The NDI document IDs to download.
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
%           - missing_document_ids (string array) - IDs that were requested but not found on remote.
%
%   See also:
%       ndi.cloud.syncDataset,
%       ndi.cloud.sync.downloadNew,
%       ndi.cloud.sync.SyncOptions

    arguments
        ndiDataset (1,1) ndi.dataset
        ndiDocumentIds (1,:) string
        syncOptions.?ndi.cloud.sync.SyncOptions
    end

    success = true;
    errorMessage = '';
    report = struct('downloaded_document_ids', string.empty, ...
                    'missing_document_ids', string.empty);

    try
        syncOptions = ndi.cloud.sync.SyncOptions(syncOptions);

        if isempty(ndiDocumentIds)
            if syncOptions.Verbose
                fprintf('No NDI document IDs provided to downloadSelectedDocuments. Nothing to do.\n');
            end
            return;
        end

        if syncOptions.Verbose
            fprintf('Syncing %d selected documents for dataset "%s".\n', ...
                numel(ndiDocumentIds), ndiDataset.path);
        end

        % Resolve cloud dataset identifier
        cloudDatasetId = ndi.cloud.internal.getCloudDatasetIdForLocalDataset(ndiDataset);
        if syncOptions.Verbose
            fprintf('Using Cloud Dataset ID: %s\n', cloudDatasetId);
        end

        % 1. Get current remote state to map NDI IDs to Cloud API IDs
        remoteDocumentIdMap = ndi.cloud.sync.internal.listRemoteDocumentIds(cloudDatasetId);

        % 2. Map requested NDI IDs to Cloud API IDs
        [found, loc] = ismember(ndiDocumentIds, remoteDocumentIdMap.ndiId);

        cloudApiIdsToDownload = remoteDocumentIdMap.apiId(loc(found));
        report.missing_document_ids = ndiDocumentIds(~found);

        if ~isempty(report.missing_document_ids) && syncOptions.Verbose
            warning('NDI:downloadSelectedDocuments:DocumentsNotFound', ...
                'The following %d NDI document IDs were not found on the remote and will be skipped:\n%s', ...
                numel(report.missing_document_ids), strjoin(report.missing_document_ids, ', '));
        end

        if isempty(cloudApiIdsToDownload)
             if syncOptions.Verbose
                fprintf('No valid documents found on remote to download.\n');
             end
             return;
        end

        % 3. Perform download actions
        if syncOptions.DryRun
            fprintf('[DryRun] Would download %d selected documents from remote.\n', ...
                numel(cloudApiIdsToDownload));
        else
            if syncOptions.Verbose
                fprintf('Downloading %d documents...\n', numel(cloudApiIdsToDownload));
            end

            % This internal function handles batch download and adding to ndiDataset
            downloadedDocs = ndi.cloud.sync.internal.downloadNdiDocuments(...
                cloudDatasetId, cloudApiIdsToDownload, ndiDataset, syncOptions);

            if ~isempty(downloadedDocs)
                 % Extract IDs. downloadedDocs is a cell array of ndi.document objects.
                 docIds = cellfun(@(d) d.id(), downloadedDocs, 'UniformOutput', false);
                 report.downloaded_document_ids = string(docIds);
            end

            if syncOptions.Verbose
                fprintf('Completed downloading %d documents.\n', numel(report.downloaded_document_ids));
            end
        end

        % 4. Update sync index
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

    catch ME
        success = false;
        errorMessage = ME.message;
        if exist('syncOptions', 'var') && isprop(syncOptions, 'Verbose') && syncOptions.Verbose
             fprintf('Error in downloadSelectedDocuments: %s\n', errorMessage);
        end
    end
end
