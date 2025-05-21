function download_dataset_files(cloudDatasetId, targetFolder, fileUuids, options)
% DOWNLOAD_DATASET_FILES - Downloads dataset files from a cloud dataset.
%
% Syntax:
%   ndi.cloud.download.download_dataset_files(CLOUDDATASETID, TARGETFOLDER, [FILEUUIDS], [OPTIONS])
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

    [datasetInfo, ~] = ndi.cloud.api.datasets.get_dataset(cloudDatasetId);

    files = filterFilesToDownload(datasetInfo.files, fileUuids);

    targetFolder = createSubFolderForDownloadedFiles(targetFolder);
    
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

        targetFilepath = fullfile(targetFolder, file_uid);
        if isfile(targetFilepath)
            if options.Verbose; fprintf('File %d already exists locally, skipping...\n', i); end
            continue;
        end
        [~, downloadURL, ~] = ndi.cloud.api.datasets.get_file_details(cloudDatasetId, file_uid);

        % Save the file
        try
            websave(targetFilepath, downloadURL);
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

function filesTargetFolder = createSubFolderForDownloadedFiles(targetFolder)
    filesTargetFolder = fullfile(targetFolder, 'download', 'files');
    if ~isfolder(filesTargetFolder)
        mkdir(filesTargetFolder)
    end
end

function displayProgress(currentFileNumber, totalFileNumber)
% displayProgress - Display progress for file download
    percentFinished = round((currentFileNumber / totalFileNumber) * 100);
     
    fprintf('Downloading file %d of %d (%d%% complete) ...\n', ...
        currentFileNumber, totalFileNumber, percentFinished)
end
