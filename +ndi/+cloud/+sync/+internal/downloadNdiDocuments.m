function downloadedNdiDocuments = downloadNdiDocuments(cloudDatasetId, cloudDocumentIds, ndiDataset, syncOptions)
% DOWNLOADNDIDOCUMENTS Downloads a collection of NDI documents and their files.
%
%   ndi.cloud.sync.internal.DOWNLOADEDNDIDOCUMENTS = ndi.cloud.sync.internal.DOWNLOADNDIDOCUMENTS(...
%       CLOUDDATASETID, CLOUDDOCUMENTIDS, NDIDATASET, SYNCOPTIONS)
%
%   This function downloads document metadata from the cloud, and if
%   syncOptions.SyncFiles is true, it also downloads the associated data files
%   to a local staging location and updates document file information.
%   Finally, it adds the documents to the local NDI dataset if provided
%
%   Inputs:
%       cloudDatasetId (1,1) string - The ID of the dataset on the cloud.
%       cloudDocumentIds (cellstr or string array) - A list of
%           cloud-specific document IDs to download.
%       ndiDataset (1,1) ndi.dataset - Optional: The local NDI dataset object.
%       syncOptions (1,1) ndi.cloud.sync.SyncOptions - Synchronization options.
%
%   Outputs:
%       downloadedNdiDocuments (cell): A cell array of the ndi.document objects
%           that were downloaded and added to the dataset.
%
%   See also: ndi.cloud.download.download_document_collection,
%             ndi.cloud.sync.internal.getFileUidsFromDocuments,
%             ndi.cloud.download.download_dataset_files,
%             ndi.cloud.sync.internal.updateFileInfoForRemoteFiles,
%             ndi.cloud.sync.internal.updateFileInfoForLocalFiles

    arguments
        cloudDatasetId (1,1) string
        cloudDocumentIds (1,:) string % string array of document IDs. Cell arrays will be converted.
        ndiDataset ndi.dataset = ndi.dataset.empty
        syncOptions (1,1) ndi.cloud.sync.SyncOptions = ndi.cloud.sync.SyncOptions()
    end
    
    downloadedNdiDocuments = {}; % Initialize to empty cell

    if isempty(cloudDocumentIds)
        if syncOptions.Verbose
            fprintf('No document IDs provided to download.\n');
        end
        return;
    end

    if syncOptions.Verbose
        if cloudDocumentIds == ""
            fprintf('Attempting to download all documents...\n');
        else
            fprintf('Attempting to download %d documents...\n', numel(cloudDocumentIds));
        end
    end

    % 1. Download documents
    % This function should return a cell array of ndi.document objects
    newNdiDocuments = ndi.cloud.download.download_document_collection(cloudDatasetId, cloudDocumentIds);

    if isempty(newNdiDocuments)
        warning('No documents were retrieved from the cloud for the given IDs.\n');
        return;
    end
    if syncOptions.Verbose
        fprintf('Successfully retrieved metadata for %d documents.\n', numel(newNdiDocuments));
    end

    % 2. Handle associated data files
    if syncOptions.SyncFiles
        if syncOptions.Verbose
            fprintf('SyncFiles is true. Processing associated data files...\n');
        end
        if isempty(ndiDataset)
            rootFilesFolder = tempdir();
        else
            rootFilesFolder = ndiDataset.path;
        end

        % Todo: Ensure proper cleanup if anything goes wrong before files
        % are ingested to database.
        filesTargetFolder = fullfile(rootFilesFolder, ndi.cloud.sync.internal.Constants.FileSyncLocation);

        fileUidsToDownload = ndi.cloud.sync.internal.getFileUidsFromDocuments(newNdiDocuments);

        if ~isempty(fileUidsToDownload)
            if syncOptions.Verbose
                fprintf('Found %d unique file UIDs to download for these documents.\n', numel(fileUidsToDownload));
                fprintf('Ensuring download directory exists: %s\n', filesTargetFolder);
            end
            if ~isfolder(filesTargetFolder)
                mkdir(filesTargetFolder);
            end
            
            % This function should download files to the filesTargetFolder
            ndi.cloud.download.download_dataset_files(...
                cloudDatasetId, ...
                filesTargetFolder, ...
                fileUidsToDownload, ...
                "Verbose", syncOptions.Verbose);
            if syncOptions.Verbose
                fprintf('Completed downloading data files.\n');
            end
            
            % Update document file info to point to local files
            if syncOptions.Verbose
                fprintf('Updating document file info to point to local files.\n');
            end
        else
            if syncOptions.Verbose
                fprintf('No associated files found for these documents, or files already local.\n');
                fprintf('Updating document file info (SyncMode.Local, but no new files to point to).\n');
            end
        end
        documentUpdateFcn = @(doc) ...
            ndi.cloud.sync.internal.updateFileInfoForLocalFiles(doc, filesTargetFolder);
    else
        if syncOptions.Verbose
            fprintf('"SyncFiles" option is false. Updating document file info to reflect remote files.\n');
        end
        documentUpdateFcn = @(doc) ...
            ndi.cloud.sync.internal.updateFileInfoForRemoteFiles(doc, cloudDatasetId);
    end

    % 3. Update file info for documents based on local / remote location
    newNdiDocuments = ndi.docs.docfun(documentUpdateFcn, newNdiDocuments);

    % 4. Add documents to the local dataset
    if ~isempty(ndiDataset)
        if syncOptions.Verbose
            fprintf('Adding %d processed documents to the local dataset...\n', ...
                numel(newNdiDocuments));
        end
        ndiDataset.database_add(newNdiDocuments);
        if syncOptions.Verbose
            fprintf('Documents added to the dataset.\n');
        end
    end

    if nargout > 0
        downloadedNdiDocuments = newNdiDocuments;
    end
end
