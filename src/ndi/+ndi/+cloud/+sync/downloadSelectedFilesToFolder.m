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

        if ~options.DryRun && ~isfolder(targetFolder)
            mkdir(targetFolder);
        end

        if options.Verbose
            fprintf('Downloading files for %d documents to: %s\n', ...
                numel(ndiDocumentIds), targetFolder);
        end

        % 1. Find documents (metadata) to get file UIDs
        % We check locally first, then cloud if needed.
        q = ndi.query('base.id', 'hasmember', ndiDocumentIds);
        allDocs = ndiDataset.database_search(q);

        localDocIds = string(cellfun(@(d) d.id(), allDocs, 'UniformOutput', false));
        missingIds = setdiff(ndiDocumentIds, localDocIds);

        cloudDatasetId = ndi.cloud.internal.getCloudDatasetIdForLocalDataset(ndiDataset);

        if ~isempty(missingIds)
            if options.Verbose
                fprintf('Fetching metadata from cloud for %d documents not found locally...\n', numel(missingIds));
            end
            remoteIdMap = ndi.cloud.sync.internal.listRemoteDocumentIds(cloudDatasetId);
            [found, loc] = ismember(missingIds, remoteIdMap.ndiId);
            cloudApiIdsToDownload = remoteIdMap.apiId(loc(found));

            if ~isempty(cloudApiIdsToDownload)
                newDocs = ndi.cloud.download.downloadDocumentCollection(cloudDatasetId, cloudApiIdsToDownload);
                allDocs = [allDocs, newDocs];
            end
        end

        if isempty(allDocs)
            if options.Verbose, fprintf('No valid documents found.\n'); end
            return;
        end

        % 2. Get unique file UIDs
        fileUids = ndi.cloud.sync.internal.getFileUidsFromDocuments(allDocs);

        if isempty(fileUids)
            if options.Verbose, fprintf('No files found for these documents.\n'); end
            return;
        end

        % 3. Download files
        if options.DryRun
            fprintf('[DryRun] Would download %d files to %s\n', numel(fileUids), targetFolder);
            report.downloaded_file_uids = string(fileUids);
        else
            ndi.cloud.download.downloadDatasetFiles(...
                cloudDatasetId, ...
                targetFolder, ...
                string(fileUids), ...
                "Verbose", options.Verbose);

            report.downloaded_file_uids = string(fileUids);

            % 4. Optional Zip
            if options.Zip
                zipFileName = fullfile(targetFolder, sprintf('exported_files_%s.zip', datestr(now, 'yyyymmdd_HHMMSS')));
                if options.Verbose
                    fprintf('Zipping files into: %s\n', zipFileName);
                end

                % We only zip the files we just downloaded, and we keep them at the zip root
                % by using the targetFolder as the root for the zip operation.
                zip(zipFileName, cellstr(fileUids), targetFolder);
                report.zip_file = zipFileName;

                if options.Verbose
                    fprintf('Zip complete. Zip file size: %.2f MB\n', ...
                        dir(zipFileName).bytes / 1024^2);
                end
            end
        end

    catch ME
        success = false;
        errorMessage = ME.message;
        if options.Verbose
             fprintf('Error in downloadSelectedFilesToFolder: %s\n', errorMessage);
        end
    end
end
