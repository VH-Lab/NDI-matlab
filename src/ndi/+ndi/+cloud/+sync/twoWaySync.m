function [success, errorMessage, report] = twoWaySync(ndiDataset, syncOptions)
%TWOWAYSYNC Performs a bidirectional additive synchronization.
%
% Syntax:
%   [SUCCESS, ERRORMESSAGE, REPORT] = ndi.cloud.sync.twoWaySync(NDIDATASET, SYNCOPTIONS)
%
%   This function implements the "TwoWaySync" synchronization mode.
%   It ensures that both local and remote datasets are updated with
%   documents from the other, without deleting any documents.
%   1. Uploads any documents present locally but not on the remote.
%   2. Downloads any documents present on the remote but not locally.
%
%   Both local and remote datasets may be modified (additions only).
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
%           - uploaded_document_ids (string array)
%           - downloaded_document_ids (string array)
%           - uploaded_documents_report (struct)
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
    report = struct('uploaded_document_ids', string.empty, ...
                    'downloaded_document_ids', string.empty, ...
                    'uploaded_documents_report', struct());

    try
        syncOptions = ndi.cloud.sync.SyncOptions(syncOptions);

        if syncOptions.Verbose
            fprintf(['Syncing dataset "%s". \nMode: TwoWaySync. ', ...
                'Performing bidirectional additive sync.\n'], ndiDataset.path);
        end

        % Resolve cloud dataset identifier
        cloudDatasetId = ndi.cloud.internal.getCloudDatasetIdForLocalDataset(ndiDataset);
        if syncOptions.Verbose
            fprintf('Using Cloud Dataset ID: %s\n', cloudDatasetId);
        end

        % --- Phase 1: Get Initial States ---
        [initialLocalDocuments, initialLocalDocumentIds] = ndi.cloud.sync.internal.listLocalDocuments(ndiDataset);
        initialRemoteDocumentIdMap = ndi.cloud.sync.internal.listRemoteDocumentIds(cloudDatasetId); % Nx2 table: ndiId, apiId

        if syncOptions.Verbose
            fprintf('Initial state: %d local documents, %d remote documents.\n', ...
                numel(initialLocalDocumentIds), numel(initialRemoteDocumentIdMap.ndiId));
        end

        % --- Phase 2: Upload local-only documents to remote ---
        if isempty(initialRemoteDocumentIdMap)
            ndiIdsToUpload = initialLocalDocumentIds;
            documentsToUpload = initialLocalDocuments;
        else
            [ndiIdsToUpload, indToUpload] = setdiff(initialLocalDocumentIds, initialRemoteDocumentIdMap.ndiId);
            documentsToUpload = initialLocalDocuments(indToUpload);
        end

        if ~isempty(ndiIdsToUpload)
            if syncOptions.Verbose
                fprintf('Found %d local documents to upload to remote.\n', numel(ndiIdsToUpload));
            end
            if syncOptions.DryRun
                fprintf('[DryRun] Would upload %d documents to remote.\n', numel(ndiIdsToUpload));
                if syncOptions.Verbose
                    for i = 1:numel(ndiIdsToUpload)
                        fprintf('  [DryRun] - Upload NDI ID: %s\n', ndiIdsToUpload(i));
                    end
                end
            else
                [b, uploadReport]=ndi.cloud.upload.uploadDocumentCollection(cloudDatasetId, documentsToUpload);
                report.uploaded_documents_report = uploadReport;
                 if isfield(uploadReport, 'uploaded_document_ids')
                     report.uploaded_document_ids = string(uploadReport.uploaded_document_ids);
                else
                     report.uploaded_document_ids = string(ndiIdsToUpload);
                end

                if syncOptions.SyncFiles
                    if syncOptions.Verbose
                        fprintf('SyncFiles is true. Uploading associated data files for %d documents...\n', numel(documentsToUpload));
                    end
                    ndi.cloud.sync.internal.uploadFilesForDatasetDocuments( ...
                        cloudDatasetId, ...
                        ndiDataset, ...
                        documentsToUpload, ...
                        "Verbose", syncOptions.Verbose, ...
                        "FileUploadStrategy", syncOptions.FileUploadStrategy);
                elseif syncOptions.Verbose
                    fprintf('SyncFiles is false. Skipping upload of associated data files.\n');
                end
                if syncOptions.Verbose
                    fprintf('Completed upload phase.\n');
                end
            end
        elseif syncOptions.Verbose
            fprintf('No new local documents to upload to remote.\n');
        end

        % --- Phase 3: Download remote-only documents to local ---
        % Re-list remote state as it might have changed due to uploads
        remoteDocumentIdMapAfterUpload = ndi.cloud.sync.internal.listRemoteDocumentIds(cloudDatasetId);
        [ndiIdsToDownload, indToDownload] = setdiff(remoteDocumentIdMapAfterUpload.ndiId, initialLocalDocumentIds, 'stable');

        if ~isempty(ndiIdsToDownload)
            if syncOptions.Verbose
                fprintf('Found %d documents on remote to download to local.\n', numel(ndiIdsToDownload));
            end
            cloudApiIdsToDownload = remoteDocumentIdMapAfterUpload.apiId(indToDownload);

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

        % --- Phase 4: Update sync index ---
        if ~syncOptions.DryRun
            % Get final states. Both sides changed
            [~, finalLocalDocumentIds] = ndi.cloud.sync.internal.listLocalDocuments(ndiDataset);
            finalRemoteDocumentIdMap = ndi.cloud.sync.internal.listRemoteDocumentIds(cloudDatasetId);

            ndi.cloud.sync.internal.index.updateSyncIndex(...
                ndiDataset, cloudDatasetId, ...
                "LocalDocumentIds", finalLocalDocumentIds, ...
                "RemoteDocumentIds", finalRemoteDocumentIdMap.ndiId)

            if syncOptions.Verbose
                fprintf('Sync index updated.\n');
            end
        else
            if syncOptions.Verbose
                fprintf('[DryRun] Sync index would have been updated.\n');
            end
        end

        if syncOptions.Verbose
            fprintf('"TwoWaySync" sync completed for dataset: %s\n', ndiDataset.path);
        end

    catch ME
        success = false;
        errorMessage = ME.message;
        if exist('syncOptions', 'var') && syncOptions.Verbose
             fprintf('Error in twoWaySync: %s\n', errorMessage);
        end
    end
end
