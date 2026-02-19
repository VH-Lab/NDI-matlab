function [success, errorMessage, report] = downloadDocumentFiles(cloudDatasetId, ndiDocumentIds, targetFolder, options)
%DOWNLOADDOCUMENTFILES Download files for specific NDI documents to a folder.
%
% Syntax:
%   [SUCCESS, ERRORMESSAGE, REPORT] = ...
%       ndi.cloud.download.downloadDocumentFiles(CLOUDDATASETID, NDIDOCUMENTIDS, TARGETFOLDER, ...)
%
%   This function downloads the data files associated with the specified
%   NDI document IDs and saves them into the specified TARGETFOLDER.
%
%   Inputs:
%       cloudDatasetId (1,1) string - The ID of the dataset on the cloud.
%       ndiDocumentIds (1,:) string - The NDI document IDs.
%       targetFolder (1,1) string - The destination folder for the files.
%
%   Name-Value Pairs:
%       - Verbose (1,1) logical - If true, verbose output is printed (default: true).
%       - Zip (1,1) logical - If true, the downloaded files will be zipped into
%                         a single archive in the target folder (default: false).
%
%   Outputs:
%       success (logical) - True if the operation completed successfully, false otherwise.
%       errorMessage (string) - Error message if success is false, empty otherwise.
%       report (struct) - Structure containing details of the changes applied.
%
%   See also:
%       ndi.cloud.download.downloadDatasetFiles,
%       ndi.cloud.download.downloadDocumentCollection

    arguments
        cloudDatasetId (1,1) string
        ndiDocumentIds string
        targetFolder (1,1) string
        options.Verbose (1,1) logical = true
        options.Zip (1,1) logical = false
    end

    ndiDocumentIds = string(ndiDocumentIds(:).'); % Ensure it's a row vector of strings

    success = true;
    errorMessage = '';
    report = struct('downloaded_file_uids', string.empty, ...
                    'zip_file', '');

    try
        if isempty(ndiDocumentIds)
            if options.Verbose, fprintf('No NDI document IDs provided.\n'); end
            return;
        end

        if ~isfolder(targetFolder)
            mkdir(targetFolder);
        end

        % 1. Map NDI IDs to Cloud API IDs
        if options.Verbose, fprintf('Mapping NDI IDs to Cloud API IDs...\n'); end
        remoteIdMap = ndi.cloud.sync.internal.listRemoteDocumentIds(cloudDatasetId);
        [found, loc] = ismember(ndiDocumentIds, remoteIdMap.ndiId);
        cloudApiIdsToDownload = remoteIdMap.apiId(loc(found));

        actuallyMissing = ndiDocumentIds(~found);
        if ~isempty(actuallyMissing) && options.Verbose
            warning('NDI:downloadDocumentFiles:DocumentsNotFound', ...
                'The following %d NDI document IDs were not found on the remote and will be skipped:\n%s', ...
                numel(actuallyMissing), strjoin(actuallyMissing, ', '));
        end

        if isempty(cloudApiIdsToDownload)
             if options.Verbose
                fprintf('No valid documents found on remote to process.\n');
             end
             return;
        end

        % 2. Download document metadata to get file UIDs
        if options.Verbose
            fprintf('Downloading metadata for %d documents from cloud dataset %s...\n', ...
                numel(cloudApiIdsToDownload), cloudDatasetId);
        end
        documents = ndi.cloud.download.downloadDocumentCollection(cloudDatasetId, cloudApiIdsToDownload);

        if isempty(documents)
            if options.Verbose, fprintf('No documents found for provided IDs.\n'); end
            return;
        end

        % 3. Extract unique file UIDs
        fileUids = ndi.cloud.sync.internal.getFileUidsFromDocuments(documents);

        if isempty(fileUids)
            if options.Verbose, fprintf('No files associated with these documents.\n'); end
            return;
        end

        % 4. Download files
        if options.Verbose
            fprintf('Downloading %d unique files to %s...\n', numel(fileUids), targetFolder);
        end
        ndi.cloud.download.downloadDatasetFiles(...
            cloudDatasetId, ...
            targetFolder, ...
            string(fileUids), ...
            "Verbose", options.Verbose);

        report.downloaded_file_uids = string(fileUids);

        % 5. Optional Zip
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

    catch ME
        success = false;
        errorMessage = ME.message;
        if options.Verbose
             fprintf('Error in downloadDocumentFiles: %s\n', errorMessage);
        end
    end
end
