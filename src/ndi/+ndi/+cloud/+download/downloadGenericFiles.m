function [success, errorMessage, report] = downloadGenericFiles(cloudDatasetId, ndiDocumentIds, targetFolder, options)
%DOWNLOADGENERICFILES Download generic_file documents from cloud to a folder with extensions.
%
% Syntax:
%   [SUCCESS, ERRORMESSAGE, REPORT] = ...
%       ndi.cloud.download.downloadGenericFiles(CLOUDDATASETID, NDIDOCUMENTIDS, TARGETFOLDER, ...)
%
%   This function identifies 'generic_file' documents among the specified
%   NDI document IDs, and downloads their associated data files to the
%   specified TARGETFOLDER using their original filenames (including extensions).
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
    report = struct('downloaded_filenames', string.empty, ...
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
            warning('NDI:downloadGenericFiles:DocumentsNotFound', ...
                'The following %d NDI document IDs were not found on the remote and will be skipped:\n%s', ...
                numel(actuallyMissing), strjoin(actuallyMissing, ', '));
        end

        if isempty(cloudApiIdsToDownload)
             if options.Verbose
                fprintf('No valid documents found on remote to process.\n');
             end
             return;
        end

        % 2. Download document metadata
        if options.Verbose
            fprintf('Downloading metadata for %d documents from cloud dataset %s...\n', ...
                numel(cloudApiIdsToDownload), cloudDatasetId);
        end
        allDocuments = ndi.cloud.download.downloadDocumentCollection(cloudDatasetId, cloudApiIdsToDownload);

        % Filter for generic_file documents
        isGenericFile = cellfun(@(d) isfield(d.document_properties, 'generic_file'), allDocuments);
        documents = allDocuments(isGenericFile);

        if isempty(documents)
            if options.Verbose, fprintf('No generic_file documents found for provided IDs.\n'); end
            return;
        end

        % 3. Extract file information (UIDs and filenames)
        downloadList = struct('uid', {}, 'filename', {});
        for i = 1:numel(documents)
            doc = documents{i};
            if doc.has_files()
                fileInfo = doc.document_properties.files.file_info;
                for j = 1:numel(fileInfo)
                    if isfield(fileInfo(j), 'locations') && ~isempty(fileInfo(j).locations)
                        uid = fileInfo(j).locations(1).uid;
                        % Use the registered name for the file, which includes extension
                        filename = fileInfo(j).name;
                        downloadList(end+1).uid = uid; %#ok<AGROW>
                        downloadList(end).filename = filename;
                    end
                end
            end
        end

        if isempty(downloadList)
            if options.Verbose, fprintf('No files associated with these documents.\n'); end
            return;
        end

        % 4. Download files
        numFiles = numel(downloadList);
        if options.Verbose
            fprintf('Downloading %d files to %s...\n', numFiles, targetFolder);
        end

        downloadedFiles = string.empty;
        for i = 1:numFiles
            uid = downloadList(i).uid;
            filename = downloadList(i).filename;
            targetPath = fullfile(targetFolder, filename);

            if options.Verbose
                fprintf('  [%d/%d] Downloading %s (UID: %s)...\n', i, numFiles, filename, uid);
            end

            [success_api, answer, ~] = ndi.cloud.api.files.getFileDetails(cloudDatasetId, uid);
            if ~success_api
                warning('NDI:downloadGenericFiles:ApiError', 'Failed to get download URL for file %s: %s', filename, answer.message);
                continue;
            end

            try
                websave(targetPath, answer.downloadUrl);
                downloadedFiles(end+1) = filename; %#ok<AGROW>
            catch ME
                warning('NDI:downloadGenericFiles:DownloadError', 'Failed to download file %s: %s', filename, ME.message);
            end
        end

        report.downloaded_filenames = downloadedFiles;

        % 5. Optional Zip
        if options.Zip && ~isempty(downloadedFiles)
            zipFileName = fullfile(targetFolder, sprintf('exported_generic_files_%s.zip', datestr(now, 'yyyymmdd_HHMMSS')));
            if options.Verbose
                fprintf('Zipping %d files into: %s\n', numel(downloadedFiles), zipFileName);
            end

            % Use the targetFolder as the root for the zip operation
            zip(zipFileName, cellstr(downloadedFiles), targetFolder);
            report.zip_file = zipFileName;

            if options.Verbose
                fprintf('Zip complete.\n');
            end
        end

    catch ME
        success = false;
        errorMessage = ME.message;
        if options.Verbose
             fprintf('Error in downloadGenericFiles: %s\n', errorMessage);
        end
    end
end
