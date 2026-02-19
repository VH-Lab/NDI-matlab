function [success, errorMessage, report] = downloadSelectedFiles(ndiDataset, ndiDocumentIds, syncOptions)
%DOWNLOADSELECTEDFILES Download only the files for specific NDI documents.
%
% Syntax:
%   [SUCCESS, ERRORMESSAGE, REPORT] = ...
%       ndi.cloud.sync.downloadSelectedFiles(NDIDATASET, NDIDOCUMENTIDS, SYNCOPTIONS)
%
%   This function ensures that the data files associated with the specified
%   NDI documents are downloaded to the local dataset.
%
%   It will attempt to use local document metadata to identify files, but
%   will fetch metadata from the cloud for any documents not found locally.
%
%   Inputs:
%       ndiDataset (1,1) ndi.dataset - The local NDI dataset object.
%       ndiDocumentIds (1,:) cellstr or string array - The NDI document IDs.
%       syncOptions (name, value pairs) - Optional synchronization options:
%       - Verbose (logical) - If true, verbose output is printed (default: true).
%       - DryRun (logical) - If true, actions are simulated but not performed (default: false).
%
%   Outputs:
%       success (logical) - True if the operation completed successfully, false otherwise.
%       errorMessage (string) - Error message if success is false, empty otherwise.
%       report (struct) - Structure containing details of the changes applied.
%
%   See also:
%       ndi.cloud.sync.downloadSelectedDocuments,
%       ndi.cloud.sync.SyncOptions

    arguments
        ndiDataset (1,1) ndi.dataset
        ndiDocumentIds (1,:) string
        syncOptions.?ndi.cloud.sync.SyncOptions
    end

    success = true;
    errorMessage = '';
    report = struct('downloaded_file_uids', string.empty, ...
                    'updated_document_ids', string.empty);

    try
        syncOptions = ndi.cloud.sync.SyncOptions(syncOptions);
        syncOptions.SyncFiles = true; % Force file sync

        if isempty(ndiDocumentIds)
            return;
        end

        if syncOptions.Verbose
            fprintf('Ensuring files are local for %d selected documents in dataset "%s".\n', ...
                numel(ndiDocumentIds), ndiDataset.path);
        end

        % 1. Find documents locally
        q = ndi.query('base.id', 'hasmember', ndiDocumentIds);
        localDocs = ndiDataset.database_search(q);

        localDocIds = string(cellfun(@(d) d.id(), localDocs, 'UniformOutput', false));
        missingIds = setdiff(ndiDocumentIds, localDocIds);

        allDocs = localDocs;

        % 2. Resolve cloud dataset identifier
        cloudDatasetId = ndi.cloud.internal.getCloudDatasetIdForLocalDataset(ndiDataset);

        % 3. Fetch metadata for missing documents
        if ~isempty(missingIds)
            if syncOptions.Verbose
                fprintf('Fetching metadata from cloud for %d documents not found locally...\n', numel(missingIds));
            end

            % Map NDI IDs to Cloud API IDs for download
            remoteIdMap = ndi.cloud.sync.internal.listRemoteDocumentIds(cloudDatasetId);
            [found, loc] = ismember(missingIds, remoteIdMap.ndiId);
            cloudApiIdsToDownload = remoteIdMap.apiId(loc(found));

            if ~isempty(cloudApiIdsToDownload)
                % Download metadata only (we'll handle files for all together)
                newDocs = ndi.cloud.download.downloadDocumentCollection(cloudDatasetId, cloudApiIdsToDownload);
                allDocs = [allDocs, newDocs];
            end

            actuallyMissing = missingIds(~found);
            if ~isempty(actuallyMissing) && syncOptions.Verbose
                warning('NDI:downloadSelectedFiles:DocumentsNotFound', ...
                    'The following %d IDs were not found locally or on remote: %s', ...
                    numel(actuallyMissing), strjoin(actuallyMissing, ', '));
            end
        end

        if isempty(allDocs)
            if syncOptions.Verbose, fprintf('No documents found to process.\n'); end
            return;
        end

        % 4. Download files for all identified documents
        if syncOptions.DryRun
            fileUids = ndi.cloud.sync.internal.getFileUidsFromDocuments(allDocs);
            fprintf('[DryRun] Would ensure %d files are local for %d documents.\n', ...
                numel(fileUids), numel(allDocs));
        else
            % Use internal function logic to download files and update docs
            % We reuse the core part of downloadNdiDocuments

            rootFilesFolder = ndiDataset.path;
            filesTargetFolder = fullfile(rootFilesFolder, ndi.cloud.sync.internal.Constants.FileSyncLocation);
            fileUidsToDownload = ndi.cloud.sync.internal.getFileUidsFromDocuments(allDocs);

            if ~isempty(fileUidsToDownload)
                if ~isfolder(filesTargetFolder), mkdir(filesTargetFolder); end

                ndi.cloud.download.downloadDatasetFiles(...
                    cloudDatasetId, ...
                    filesTargetFolder, ...
                    fileUidsToDownload, ...
                    "Verbose", syncOptions.Verbose);

                report.downloaded_file_uids = string(fileUidsToDownload);
            end

            % Update documents to point to local files
            documentUpdateFcn = @(doc) ...
                ndi.cloud.sync.internal.updateFileInfoForLocalFiles(doc, filesTargetFolder);
            updatedDocs = ndi.docs.docfun(documentUpdateFcn, allDocs);

            % Save/Update in database
            if syncOptions.Verbose
                fprintf('Updating %d documents in the local dataset...\n', numel(updatedDocs));
            end
            ndiDataset.database_add(updatedDocs);

            report.updated_document_ids = string(cellfun(@(d) d.id(), updatedDocs, 'UniformOutput', false));

            % Update sync index
            [~, finalLocalDocumentIds] = ndi.cloud.sync.internal.listLocalDocuments(ndiDataset);
            remoteDocumentIdMap = ndi.cloud.sync.internal.listRemoteDocumentIds(cloudDatasetId);
            ndi.cloud.sync.internal.index.updateSyncIndex(...
                ndiDataset, cloudDatasetId, ...
                "LocalDocumentIds", finalLocalDocumentIds, ...
                "RemoteDocumentIds", remoteDocumentIdMap.ndiId)
        end

    catch ME
        success = false;
        errorMessage = ME.message;
        if exist('syncOptions', 'var') && isprop(syncOptions, 'Verbose') && syncOptions.Verbose
             fprintf('Error in downloadSelectedFiles: %s\n', errorMessage);
        end
    end
end
