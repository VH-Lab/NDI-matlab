function [success, errorMessage, report] = downloadDocumentFiles(cloudDatasetId, cloudDocumentIds, targetFolder, options)
%DOWNLOADDOCUMENTFILES Download files for specific cloud documents to a folder.
%
% Syntax:
%   [SUCCESS, ERRORMESSAGE, REPORT] = ...
%       ndi.cloud.download.downloadDocumentFiles(CLOUDDATASETID, CLOUDDOCUMENTIDS, TARGETFOLDER, ...)
%
%   This function downloads the data files associated with the specified
%   cloud API document IDs and saves them into the specified TARGETFOLDER.
%
%   Inputs:
%       cloudDatasetId (1,1) string - The ID of the dataset on the cloud.
%       cloudDocumentIds (1,:) string - The cloud API document IDs.
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
        cloudDocumentIds (1,:) string
        targetFolder (1,1) string
        options.Verbose (1,1) logical = true
        options.Zip (1,1) logical = false
    end

    success = true;
    errorMessage = '';
    report = struct('downloaded_file_uids', string.empty, ...
                    'zip_file', '');

    try
        if isempty(cloudDocumentIds)
            if options.Verbose, fprintf('No document IDs provided.\n'); end
            return;
        end

        if ~isfolder(targetFolder)
            mkdir(targetFolder);
        end

        % 1. Download document metadata to get file UIDs
        if options.Verbose
            fprintf('Downloading metadata for %d documents from cloud dataset %s...\n', ...
                numel(cloudDocumentIds), cloudDatasetId);
        end
        documents = ndi.cloud.download.downloadDocumentCollection(cloudDatasetId, cloudDocumentIds);

        if isempty(documents)
            if options.Verbose, fprintf('No documents found for provided IDs.\n'); end
            return;
        end

        % 2. Extract unique file UIDs
        fileUids = ndi.cloud.sync.internal.getFileUidsFromDocuments(documents);

        if isempty(fileUids)
            if options.Verbose, fprintf('No files associated with these documents.\n'); end
            return;
        end

        % 3. Download files
        if options.Verbose
            fprintf('Downloading %d unique files to %s...\n', numel(fileUids), targetFolder);
        end
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

    catch ME
        success = false;
        errorMessage = ME.message;
        if options.Verbose
             fprintf('Error in downloadDocumentFiles: %s\n', errorMessage);
        end
    end
end
