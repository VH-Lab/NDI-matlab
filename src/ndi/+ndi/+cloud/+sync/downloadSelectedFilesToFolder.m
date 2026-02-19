function [success, errorMessage, report] = downloadSelectedFilesToFolder(ndiDataset, ndiDocumentIds, targetFolder, options)
%DOWNLOADSELECTEDFILESTOFOLDER Download files for specific NDI documents to a folder.
%
% Syntax:
%   [SUCCESS, ERRORMESSAGE, REPORT] = ...
%       ndi.cloud.sync.downloadSelectedFilesToFolder(NDIDATASET, NDIDOCUMENTIDS, TARGETFOLDER, ...)
%
%   This function downloads the data files associated with the specified
%   NDI documents and saves them into the specified TARGETFOLDER.
%
%   Unlike downloadSelectedFiles, this function does NOT update the local
%   NDI dataset or the sync index. It is intended for exporting data files.
%
%   Inputs:
%       ndiDataset (1,1) ndi.dataset - The local NDI dataset object.
%       ndiDocumentIds (1,:) cellstr or string array - The NDI document IDs.
%       targetFolder (1,1) string - The destination folder for the files.
%
%   Name-Value Pairs:
%       - Verbose (logical) - If true, verbose output is printed (default: true).
%       - DryRun (logical) - If true, actions are simulated but not performed (default: false).
%       - Zip (logical) - If true, the downloaded files will be zipped into
%                         a single archive in the target folder (default: false).
%
%   Outputs:
%       success (logical) - True if the operation completed successfully, false otherwise.
%       errorMessage (string) - Error message if success is false, empty otherwise.
%       report (struct) - Structure containing details of the changes applied.
%
%   See also:
%       ndi.cloud.download.downloadDocumentFiles,
%       ndi.cloud.sync.downloadSelectedFiles,
%       ndi.cloud.sync.downloadSelectedDocuments

    arguments
        ndiDataset (1,1) ndi.dataset
        ndiDocumentIds (1,:) string
        targetFolder (1,1) string
        options.Verbose (1,1) logical = true
        options.DryRun (1,1) logical = false
        options.Zip (1,1) logical = false
    end

    success = true;
    errorMessage = '';
    report = struct('downloaded_file_uids', string.empty, ...
                    'zip_file', '');

    try
        if isempty(ndiDocumentIds)
            return;
        end

        if options.Verbose
            fprintf('Processing request to export files for %d documents to: %s\n', ...
                numel(ndiDocumentIds), targetFolder);
        end

        % 1. Resolve cloud dataset identifier
        cloudDatasetId = ndi.cloud.internal.getCloudDatasetIdForLocalDataset(ndiDataset);

        % 2. Map NDI IDs to Cloud API IDs
        if options.Verbose, fprintf('Mapping NDI IDs to Cloud API IDs...\n'); end
        remoteIdMap = ndi.cloud.sync.internal.listRemoteDocumentIds(cloudDatasetId);
        [found, loc] = ismember(ndiDocumentIds, remoteIdMap.ndiId);
        cloudApiIdsToDownload = remoteIdMap.apiId(loc(found));

        actuallyMissing = ndiDocumentIds(~found);
        if ~isempty(actuallyMissing) && options.Verbose
            warning('NDI:downloadSelectedFilesToFolder:DocumentsNotFound', ...
                'The following %d NDI document IDs were not found on the remote and will be skipped:\n%s', ...
                numel(actuallyMissing), strjoin(actuallyMissing, ', '));
        end

        if isempty(cloudApiIdsToDownload)
             if options.Verbose
                fprintf('No valid documents found on remote to process.\n');
             end
             return;
        end

        % 3. Perform download actions
        if options.DryRun
            % For DryRun, we still need to fetch metadata to know which files would be downloaded
            if options.Verbose, fprintf('[DryRun] Fetching metadata to identify files...\n'); end
            documents = ndi.cloud.download.downloadDocumentCollection(cloudDatasetId, cloudApiIdsToDownload);
            fileUids = ndi.cloud.sync.internal.getFileUidsFromDocuments(documents);

            fprintf('[DryRun] Would download %d files for %d documents to %s\n', ...
                numel(fileUids), numel(cloudApiIdsToDownload), targetFolder);
            if options.Zip
                fprintf('[DryRun] Would zip downloaded files.\n');
            end
            report.downloaded_file_uids = string(fileUids);
        else
            % Call the specialized download function
            [success, errorMessage, report] = ndi.cloud.download.downloadDocumentFiles(...
                cloudDatasetId, cloudApiIdsToDownload, targetFolder, ...
                "Verbose", options.Verbose, ...
                "Zip", options.Zip);
        end

    catch ME
        success = false;
        errorMessage = ME.message;
        if options.Verbose
             fprintf('Error in downloadSelectedFilesToFolder: %s\n', errorMessage);
        end
    end
end
