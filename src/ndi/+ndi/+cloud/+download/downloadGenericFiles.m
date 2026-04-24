function [success, errorMessage, report] = downloadGenericFiles(ndiDataset, ndiDocumentIds, targetFolder, options)
%DOWNLOADGENERICFILES Download generic_file documents from cloud to a folder with extensions.
%
% Syntax:
%   [SUCCESS, ERRORMESSAGE, REPORT] = ...
%       ndi.cloud.download.downloadGenericFiles(NDIDATASET, NDIDOCUMENTIDS, TARGETFOLDER, ...)
%
%   This function identifies 'generic_file' documents among the specified
%   NDI document IDs and their dependencies, and downloads their associated
%   data files to the specified TARGETFOLDER using their original filenames
%   (including extensions).
%
%   Inputs:
%       ndiDataset (1,1) - The local NDI dataset (or session) object.
%       ndiDocumentIds string - The NDI document IDs (can be string array or cell array).
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
        ndiDataset (1,1)
        ndiDocumentIds string
        targetFolder (1,1) string
        options.Verbose (1,1) logical = true
        options.Zip (1,1) logical = false
        options.NamingStrategy (1,1) string {mustBeMember(options.NamingStrategy, ["original", "id", "id_original"])} = "original"
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

        % 1. Retrieve initial documents and their dependencies from the local database
        if options.Verbose, fprintf('Retrieving documents and identifying dependencies...\n'); end

        % Use docinput2docs to get document objects for the provided IDs
        initialDocs = ndi.session.docinput2docs(ndiDataset, cellstr(ndiDocumentIds));
        if isempty(initialDocs)
            if options.Verbose, fprintf('No matching documents found in the dataset.\n'); end
            return;
        end

        % Find all documents that depend on these
        dependentDocs = ndi.database.fun.findalldependencies(ndiDataset, [], initialDocs{:});

        allDocs = [initialDocs(:)', dependentDocs(:)'];

        % Ensure uniqueness of documents based on ID
        allDocIds = cellfun(@(d) d.id(), allDocs, 'UniformOutput', false);
        [~, uniqueIdx] = unique(allDocIds, 'stable');
        allDocs = allDocs(uniqueIdx);

        % Filter for generic_file documents
        isGenericFile = cellfun(@(d) isfield(d.document_properties, 'generic_file'), allDocs);
        documents = allDocs(isGenericFile);

        if isempty(documents)
            if options.Verbose, fprintf('No generic_file documents found for provided IDs or their dependents.\n'); end
            return;
        end

        % 2. Resolve cloud dataset identifier
        cloudDatasetIdQuery = ndi.query('','isa','dataset_remote');
        cloudDatasetIdDocs = ndiDataset.database_search(cloudDatasetIdQuery);
        if isempty(cloudDatasetIdDocs)
            error('NDI:downloadGenericFiles:NoRemoteLink', ...
                'The provided dataset/session is not linked to an NDI cloud dataset (no dataset_remote document found).');
        end
        cloudDatasetId = cloudDatasetIdDocs{1}.document_properties.dataset_remote.dataset_id;

        % 3. Extract file information (UIDs and filenames)
        downloadList = struct('uid', {}, 'filename', {});

        for i = 1:numel(documents)
            doc = documents{i};
            if doc.has_files()
                fileInfo = doc.document_properties.files.file_info;
                for j = 1:numel(fileInfo)
                    if isfield(fileInfo(j), 'locations') && ~isempty(fileInfo(j).locations)
                        uid = fileInfo(j).locations(1).uid;

                        % Determine filename with appropriate extension
                        % We check the generic_file.filename property for the original name
                        originalFullname = doc.document_properties.generic_file.filename;
                        [~, name_part, ext_part] = fileparts(originalFullname);

                        if isempty(name_part)
                            % Fallback to the registered name in file_info
                            [~, name_part, ext_part] = fileparts(fileInfo(j).name);
                        end
                        if contains(fileInfo(j).locations.location,'.zip') & isempty(ext_part)
                            ext_part = '.zip';
                        end

                        switch options.NamingStrategy
                            case "id"
                                filename = [doc.id() ext_part];
                            case "id_original"
                                filename = [doc.id() '_' name_part ext_part];
                            case "original"
                                filename = [name_part ext_part];
                        end

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

        % 4. Download files from the cloud
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

            % Get the download URL for the specific file
            [success_api, answer, ~] = ndi.cloud.api.files.getFileDetails(cloudDatasetId, uid);
            if ~success_api
                if isfield(answer,'error')
                    errorMsg = answer.error;
                else
                    errorMsg = answer.message;
                end
                warning('NDI:downloadGenericFiles:ApiError', ...
                    'Failed to get download URL for file %s (UID: %s): %s', filename, uid, errorMsg);
                continue;
            end

            % Download using curl so gateway-level HTTP compression does not
            % corrupt the saved bytes (websave auto-decompresses responses).
            try
                [success_d, answer_d] = ndi.cloud.api.files.getFile(answer.downloadUrl, targetPath, 'useCurl', true);
                if ~success_d
                    error('NDI:downloadGenericFiles:DownloadError', ...
                        'curl download failed: %s', char(string(answer_d)));
                end
                downloadedFiles(end+1) = filename; %#ok<AGROW>
            catch ME
                warning('NDI:downloadGenericFiles:DownloadError', ...
                    'Failed to download file %s: %s', filename, ME.message);
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
