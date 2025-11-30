function [success, errorMessage, report] = mirrorToRemote(ndiDataset, syncOptions)
%MIRRORTOREMOTE Mirrors the local dataset to the remote dataset.
%
% Syntax:
%   [SUCCESS, ERRORMESSAGE, REPORT] = ndi.cloud.sync.mirrorToRemote(NDIDATASET, SYNCOPTIONS)
%
%   This function implements the "MirrorToRemote" synchronization mode.
%   It ensures the remote dataset becomes an exact representation of the
%   local dataset by:
%   1. Uploading any documents present locally but not on the remote.
%   2. Deleting any remote documents that are not present locally.
%
%   The local dataset is not modified by this operation.
%   The remote dataset is modified (additions and deletions).
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
%           - deleted_remote_document_ids (string array)
%           - uploaded_documents_report (struct) - Detailed report from uploadDocumentCollection
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
                    'deleted_remote_document_ids', string.empty, ...
                    'uploaded_documents_report', struct());

    try
        syncOptions = ndi.cloud.sync.SyncOptions(syncOptions);

        if syncOptions.Verbose
            fprintf(['Syncing dataset "%s". \nMode: MirrorToRemote. ', ...
                'Remote will be made a mirror of local.\n'], ndiDataset.path);
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

        % --- Phase 2: Upload missing documents to remote ---
        [ndiIdsToUpload, indicesToUpload] = setdiff(initialLocalDocumentIds, initialRemoteDocumentIdMap.ndiId);
        documentsToUpload = initialLocalDocuments(indicesToUpload);

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
                [b, uploadReport] = ndi.cloud.upload.uploadDocumentCollection(cloudDatasetId, documentsToUpload);
                report.uploaded_documents_report = uploadReport;
                % Try to extract IDs from the report if available, or just use intended IDs if successful
                if isfield(uploadReport, 'uploaded_document_ids')
                     report.uploaded_document_ids = string(uploadReport.uploaded_document_ids);
                else
                     report.uploaded_document_ids = string(ndiIdsToUpload);
                end

                if syncOptions.SyncFiles
                    if syncOptions.Verbose
                        fprintf('SyncFiles is true. Uploading associated data files...\n');
                    end
                    ndi.cloud.sync.internal.uploadFilesForDatasetDocuments( ...
                        cloudDatasetId, ...
                        ndiDataset, ...
                        documentsToUpload, ...
                        "Verbose", syncOptions.Verbose, ...
                        "FileUploadStrategy", syncOptions.FileUploadStrategy);
                elseif syncOptions.Verbose
                    fprintf('"SyncFiles" option is false. Skipping upload of associated data files.\n');
                end
                if syncOptions.Verbose
                    fprintf('Completed upload phase.\n');
                end
            end
        elseif syncOptions.Verbose
            fprintf('No new local documents to upload to remote.\n');
        end

        % --- Phase 3: Delete remote documents not present locally ---
        % Re-list remote documents as they might have changed after uploads
        remoteDocumentIdMapAfterUpload = ndi.cloud.sync.internal.listRemoteDocumentIds(cloudDatasetId);

        % Documents to delete are those now remote but NOT in the *initial* local list
        [remoteNdiIdsToDelete, indTodelete] = ...
            setdiff(remoteDocumentIdMapAfterUpload.ndiId, initialLocalDocumentIds);

        if ~isempty(remoteNdiIdsToDelete)
            if syncOptions.Verbose
                fprintf('Found %d remote documents to delete (not on local).\n', numel(remoteNdiIdsToDelete));
            end
            cloudApiIdsToDelete = remoteDocumentIdMapAfterUpload.apiId(indTodelete);

            if syncOptions.DryRun
                fprintf('[DryRun] Would delete %d remote documents.\n', numel(cloudApiIdsToDelete));
                if syncOptions.Verbose
                    for i = 1:numel(cloudApiIdsToDelete)
                        fprintf('  [DryRun] - Delete Remote API ID: %s (corresponds to NDI ID: %s)\n', ...
                            cloudApiIdsToDelete(i), remoteNdiIdsToDelete(i));
                    end
                end
            else
                ndi.cloud.sync.internal.deleteRemoteDocuments(cloudDatasetId, cloudApiIdsToDelete, syncOptions);
                report.deleted_remote_document_ids = string(remoteNdiIdsToDelete);
                if syncOptions.Verbose
                    fprintf('Completed remote deletion phase.\n');
                end
            end
        elseif syncOptions.Verbose
            fprintf('No remote documents to delete.\n');
        end

        % --- Phase 4: Update sync index ---
        if ~syncOptions.DryRun
            % Update remote state after update. Local was not change by this mode
            finalRemoteDocumentIdMap = ndi.cloud.sync.internal.listRemoteDocumentIds(cloudDatasetId);

            ndi.cloud.sync.internal.index.updateSyncIndex(...
                ndiDataset, cloudDatasetId, ...
                "LocalDocumentIds", initialLocalDocumentIds, ...
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
            fprintf('"MirrorToRemote" sync completed for dataset: %s\n', ndiDataset.path);
        end

    catch ME
        success = false;
        errorMessage = ME.message;
        if exist('syncOptions', 'var') && isprop(syncOptions, 'Verbose') && syncOptions.Verbose
             fprintf('Error in mirrorToRemote: %s\n', errorMessage);
        end
    end
end
