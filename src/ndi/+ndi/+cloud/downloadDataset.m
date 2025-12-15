function ndiDataset = downloadDataset(cloudDatasetId, targetFolder, syncOptions)
% DOWNLOADDATASET - Downloads a dataset from the NDI Cloud to a local folder.
%
% Syntax:
%   NDIDATASET = ndi.cloud.downloadDataset(CLOUD_DATASET_ID, TARGET_FOLDER, OPTIONS)
%   Downloads a dataset specified by CLOUD_DATASET_ID to TARGET_FOLDER,
%   with additional options for controlling synchronization mode.
%
% Inputs:
%   CLOUD_DATASET_ID (string)       - Identifier for the dataset in the cloud.
%   TARGET_FOLDER (string)          - Local folder to save the downloaded dataset.
%   OPTIONS (name, value pairs)     - Optional synchronization options:
%       - SyncFiles (logical)       - If true, files will be synced (default: false).
%       - Verbose (logical)         - If true, verbose output is printed (default: true).
%
% Outputs:
%   NDIDATASET - An ndi.dataset object representing the downloaded dataset.

    arguments
        cloudDatasetId (1,1) string = missing
        targetFolder (1,1) string = missing
        syncOptions.?ndi.cloud.sync.SyncOptions
    end
        
    syncOptions = ndi.cloud.sync.SyncOptions(syncOptions);

    if syncOptions.DryRun
        error("NDICLOUD:DownloadDataset:DryRunNotSupported", ...
            '"DryRun" option is not implemented for dataset download.')
    end

    % Prompt user for required values if missing
    if ismissing(cloudDatasetId)
        cloudDatasetId = ndi.cloud.ui.dialog.selectCloudDataset();
    end
    if ismissing(targetFolder)
        if ismac || isunix % title for uigetdir not displayed on these oses
            choice = questdlg('You will be prompted to select a download directory', ' ', 'OK', 'OK');
        end
        targetFolder = uigetdir(pwd, 'Select a dataset target folder');
        if targetFolder == 0
            error('NDI:DownloadCloudDataset:UserCanceled', ...
                'Operation aborted during selection of a dataset target folder.')
        end
    end

    % Verify dataset existence
    if syncOptions.Verbose
        disp('Verifying dataset existence...');
    end
    [success, answer] = ndi.cloud.api.datasets.getDataset(cloudDatasetId);
    if ~success
        if isstruct(answer) && isfield(answer, 'message')
            reason = answer.message;
        elseif ischar(answer) || isstring(answer)
            reason = answer;
        else
            reason = 'Unknown error.';
        end
        error('NDI:DownloadDataset:DatasetNotFound', ...
            'Could not find or access dataset "%s". Reason: %s', cloudDatasetId, reason);
    end
    
    % Download dataset documents
    if syncOptions.Verbose
        disp('Downloading dataset documents...')
    end
    ndiDocuments = ndi.cloud.sync.internal.downloadNdiDocuments(...
        cloudDatasetId, "", ndi.dataset.empty, syncOptions);

    % Create new dataset with downloaded document
    if syncOptions.Verbose
        disp('Building dataset from documents...')
        if syncOptions.SyncFiles
            disp(['Will copy downloaded files into dataset. May take ', ...
                'several minutes if the dataset is large...'])
        end
    end
    datasetFolder = fullfile(targetFolder, cloudDatasetId);
    if ~isfolder(datasetFolder)
        mkdir(datasetFolder)
    end

    ndiDataset = ndi.dataset.dir([], datasetFolder, ndiDocuments);
    if syncOptions.Verbose
        disp('Created dataset.')
    end

    % Save sync index
    ndi.cloud.sync.internal.index.updateSyncIndex(ndiDataset, cloudDatasetId)
    if syncOptions.Verbose
        disp('Saved sync index.')
    end

    % Add document with the cloud dataset ID to the local dataset
    doc = ndiDataset.database_search( ndi.query('','isa','dataset_remote') );
    if isempty(doc)
        remoteDatasetDoc = ndi.cloud.internal.createRemoteDatasetDoc(cloudDatasetId, ndiDataset);
        ndiDataset.database_add(remoteDatasetDoc);
    end
end
