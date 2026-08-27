function downloadDatasetFiles(cloudDatasetId, targetFolder, fileUuids, options)
% DOWNLOAD_DATASET_FILES - Downloads dataset files from a cloud dataset.
%
% Syntax:
%   ndi.cloud.download.downloadDatasetFiles(CLOUDDATASETID, TARGETFOLDER, [FILEUUIDS], [OPTIONS])
%   Downloads specified files or all files from a cloud dataset to the target
%   folder.
%
% Inputs:
%   CLOUDDATASETID (1,1) string     - The identifier of the cloud dataset.
%   TARGETFOLDER (1,1) string       - The folder where files will be downloaded. 
%                                     Must be a valid folder path.
%   FILEUUIDS (1,:) string          - (Optional) The unique identifiers of the
%                                     files to download. Default is missing, which 
%                                     indicates all files will be downloaded.
%   OPTIONS.Verbose (1,1) logical   - (Optional) Flag to enable verbose 
%                                     output. Default is true.
%   OPTIONS.AbortOnError (1,1) logical - (Optional) Flag to control whether to 
%                                     abort on download errors. Default is true.
%
% Outputs:
%   None

    arguments
        cloudDatasetId (1,1) string
        targetFolder (1,1) string {mustBeFolder}
        fileUuids (1,:) string = missing % Default: Will download all files
        options.Verbose (1,1) logical = true
        options.AbortOnError (1,1) logical = true
    end

    [success, datasetInfo] = ndi.cloud.api.datasets.getDataset(cloudDatasetId);
    if ~success
        error(['Failed to get dataset: ' datasetInfo.message]);
    end

    if ~isstruct(datasetInfo) && ~all(ismissing(fileUuids))
        error('No files found in the dataset despite files requested.');
    elseif ~isstruct(datasetInfo)
        % no dataset
        return;
    end
   
    if ~isstruct(datasetInfo.files) && ~all(ismissing(fileUuids))
        error('No files found in the dataset despite files requested.');
    end
    if ~isstruct(datasetInfo.files) % nothing to do
        return;
    end

    files = filterFilesToDownload(datasetInfo.files, fileUuids);
    
    numFiles = numel(files);
    if options.Verbose; fprintf('Will download %d files...\n', numFiles ); end
    
    for i = 1:numFiles
        if options.Verbose, displayProgress(i, numFiles); end
        
        file_uid = files(i).uid;
        existsOnCloud = files(i).uploaded;
                
        if ~existsOnCloud
            warning('File with uuid "%s" does not exist on the cloud, skipping...\n', file_uid)
            continue;
        end

        % file_uid comes verbatim from the getDataset API response and is used
        % below as a local destination path. A malicious value such as
        % '../../../.matlab/R2024b/startup.m' would otherwise let a downloaded
        % dataset write outside targetFolder -- e.g. overwrite an auto-executed
        % MATLAB startup script. Reduce the uid to its final path component
        % (dropping any directory parts), reject empty / '.' / '..', and assert
        % the resolved path stays inside targetFolder before writing.
        %
        % Coordinated with the NDI-python fix to src/ndi/database.py
        % (get_binary_path), which closes the identical unsanitized-traversal
        % hole on the Python side; NDI-python download.py:317-321 already applies
        % the equivalent basename + containment guard.
        [safeFileName, isSafe] = ndi.cloud.download.internal.safeLocalFilename(file_uid);
        if ~isSafe
            warning('NDI:Cloud:UnsafeFileUid', ...
                'File uid "%s" does not yield a safe filename; skipping.', file_uid);
            continue;
        end
        targetFilepath = fullfile(targetFolder, safeFileName);
        if ~startsWith(fullfile(targetFilepath), fullfile(targetFolder))
            warning('NDI:Cloud:UnsafeFileUid', ...
                'Refusing to write file uid "%s" outside the target folder; skipping.', ...
                file_uid);
            continue;
        end
        if isfile(targetFilepath)
            if options.Verbose; fprintf('File %d already exists locally, skipping...\n', i); end
            continue;
        end
        [success, answer, ~] = ndi.cloud.api.files.getFileDetails(cloudDatasetId, file_uid);
        if ~success
            warning(['Failed to get file details: ' answer.message]);
            continue;
        end
        downloadURL = answer.downloadUrl;

        % Save the file using curl so gateway-level HTTP compression
        % does not corrupt the saved bytes (websave auto-decompresses).
        try
            [success_d, answer_d] = ndi.cloud.api.files.getFile(downloadURL, targetFilepath, 'useCurl', true);
            if ~success_d
                error('NDI:Cloud:FileDownloadFailed', ...
                    'curl download failed: %s', char(string(answer_d)));
            end
        catch ME
            if options.AbortOnError
                rethrow(ME)
            else
                warning('NDI:Cloud:FileDownloadFailed', ...
                    'Download failed for file %d', i)
            end
        end
    end
    if options.Verbose; disp('File download complete.'); end
end

function files = filterFilesToDownload(files, fileUuids)
    if ~ismissing(fileUuids) % Filter by uids
        allFileUuids = arrayfun(@(f) f.uid, files, 'UniformOutput', false);
        [~, idx] = intersect(allFileUuids, fileUuids, "stable");

        files = files(idx);

        assert(isequal(sort(string({files.uid})), sort(fileUuids)), ...
            'Expected filtered files list to match IDs for filtering.')
    end
end

function displayProgress(currentFileNumber, totalFileNumber)
% displayProgress - Display progress for file download
    percentFinished = round((currentFileNumber / totalFileNumber) * 100);
     
    fprintf('Downloading file %d of %d (%d%% complete) ...\n', ...
        currentFileNumber, totalFileNumber, percentFinished)
end
